"""
Lyria RealTime Music Generation - WebSocket 桥接服务
浏览器 <-> 本地服务器 <-> Google Lyria RealTime API

核心特性：服务端自动会话轮转
- Lyria 实验模型每 ~30s 超时，server 自动重建会话
- 浏览器 WS 保持连接不断开，音频无缝续播
- 记忆最后的 prompts/config，新会话自动恢复
"""

import asyncio
import json
import os
import base64
from google import genai
from google.genai import types
from aiohttp import web

# ─── 自动从 .env.local 读取 ───
def _load_env_local():
    env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env.local")
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip())

_load_env_local()

# ─── 配置 ───
API_KEY = os.environ.get("GEMINI_API_KEY", "")
MODEL = "models/lyria-realtime-exp"
PORT = int(os.environ.get("PORT", "8765"))

# ─── 工具函数 ───
MODE_MAP = {
    "QUALITY": types.MusicGenerationMode.QUALITY,
    "DIVERSITY": types.MusicGenerationMode.DIVERSITY,
    "VOCALIZATION": types.MusicGenerationMode.VOCALIZATION,
}

def parse_config(config_dict):
    """将前端 config dict 转为 LiveMusicGenerationConfig"""
    d = dict(config_dict)
    d.pop("scale", None)
    mode_str = d.pop("music_generation_mode", None)
    if mode_str and mode_str in MODE_MAP:
        d["music_generation_mode"] = MODE_MAP[mode_str]
    return types.LiveMusicGenerationConfig(**d)

def parse_prompts(prompt_list):
    """将前端 prompt list 转为 WeightedPrompt list"""
    return [
        types.WeightedPrompt(text=p["text"], weight=p.get("weight", 1.0))
        for p in prompt_list
    ]


async def handle_websocket(request):
    """处理浏览器 WebSocket 连接，桥接到 Lyria RealTime（自动会话轮转）"""
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    print("[连接] 浏览器已连接")

    client = genai.Client(api_key=API_KEY, http_options={"api_version": "v1alpha"})

    # ─── 状态：记忆最后的参数，用于新会话恢复 ───
    last_prompts = None      # list of WeightedPrompt
    last_config = None        # LiveMusicGenerationConfig
    last_config_raw = None    # 原始 dict (用于日志)
    is_playing = False
    session_count = 0

    # ─── 当前会话控制 ───
    current_session = None
    recv_task = None
    session_lock = asyncio.Lock()

    async def start_lyria_session():
        """启动一个新的 Lyria 会话并开始转发音频"""
        nonlocal current_session, recv_task, session_count
        session_count += 1
        sid = session_count

        # 取消旧的接收任务
        if recv_task and not recv_task.done():
            recv_task.cancel()
            try:
                await recv_task
            except asyncio.CancelledError:
                pass

        try:
            session_ctx = client.aio.live.music.connect(model=MODEL)
            session = await session_ctx.__aenter__()
            current_session = session
            print(f"[Lyria #{sid}] 已连接")

            # 恢复参数
            if last_prompts:
                await session.set_weighted_prompts(prompts=last_prompts)
                print(f"[Lyria #{sid}] 已恢复 prompts")
            if last_config:
                await session.set_music_generation_config(config=last_config)
                print(f"[Lyria #{sid}] 已恢复 config")
            if is_playing:
                await session.play()
                print(f"[Lyria #{sid}] 已恢复播放")

            # 通知前端
            if not ws.closed:
                await ws.send_json({"type": "status", "message": "connected"})

            # 转发音频（session_ctx 的生命周期在这里管理）
            async def forward_audio():
                chunk_count = 0
                try:
                    async for message in session.receive():
                        if ws.closed:
                            break
                        if hasattr(message, "server_content") and message.server_content:
                            sc = message.server_content
                            if hasattr(sc, "audio_chunks") and sc.audio_chunks:
                                for chunk in sc.audio_chunks:
                                    chunk_count += 1
                                    audio_b64 = base64.b64encode(chunk.data).decode("utf-8")
                                    await ws.send_json({
                                        "type": "audio",
                                        "data": audio_b64
                                    })
                except asyncio.CancelledError:
                    print(f"[Lyria #{sid}] 接收已取消")
                    return  # 主动取消，不自动轮转
                except Exception as e:
                    print(f"[Lyria #{sid}] 接收错误: {e}")
                finally:
                    # 清理 session context
                    try:
                        await session_ctx.__aexit__(None, None, None)
                    except Exception:
                        pass
                    print(f"[Lyria #{sid}] 会话结束 ({chunk_count} chunks)")

                # 会话自然结束（Lyria ~30s 超时），自动轮转
                if not ws.closed and is_playing:
                    print(f"[Lyria #{sid}] 自动轮转...")
                    if not ws.closed:
                        await ws.send_json({"type": "status", "message": "reconnecting"})
                    async with session_lock:
                        await start_lyria_session()

            recv_task = asyncio.create_task(forward_audio())

        except Exception as e:
            print(f"[Lyria #{sid}] 连接失败: {e}")
            if not ws.closed:
                await ws.send_json({"type": "error", "message": str(e)})
                # 重试一次
                await asyncio.sleep(2)
                if not ws.closed and is_playing:
                    print(f"[Lyria #{sid}] 重试连接...")
                    async with session_lock:
                        await start_lyria_session()

    try:
        # 初始连接 Lyria
        async with session_lock:
            await start_lyria_session()

        # 主循环：接收浏览器指令
        async for msg in ws:
            if msg.type == web.WSMsgType.TEXT:
                data = json.loads(msg.data)
                cmd = data.get("command")
                print(f"[指令] {cmd} | {json.dumps(data, ensure_ascii=False)[:200]}")

                session = current_session
                if not session:
                    print(f"[警告] 无活跃会话，忽略指令 {cmd}")
                    continue

                try:
                    if cmd == "set_prompts":
                        last_prompts = parse_prompts(data["prompts"])
                        await session.set_weighted_prompts(prompts=last_prompts)
                        await ws.send_json({"type": "status", "message": "prompts_set"})

                    elif cmd == "set_config":
                        last_config_raw = data.get("config", {})
                        last_config = parse_config(last_config_raw)
                        await session.set_music_generation_config(config=last_config)
                        await ws.send_json({"type": "status", "message": "config_set"})

                    elif cmd == "play":
                        is_playing = True
                        await session.play()
                        await ws.send_json({"type": "status", "message": "playing"})

                    elif cmd == "pause":
                        is_playing = False
                        await session.pause()
                        await ws.send_json({"type": "status", "message": "paused"})

                    elif cmd == "stop":
                        is_playing = False
                        await session.stop()
                        await ws.send_json({"type": "status", "message": "stopped"})

                    elif cmd == "reset_context":
                        await session.reset_context()
                        await ws.send_json({"type": "status", "message": "context_reset"})

                except Exception as e:
                    print(f"[指令错误] {cmd}: {e}")
                    # 如果是 transport closing 错误，等待自动轮转
                    if "closing" in str(e).lower() or "closed" in str(e).lower():
                        print("[指令] 会话正在轮转，指令将在新会话恢复")
                    else:
                        await ws.send_json({"type": "error", "message": str(e)})

            elif msg.type == web.WSMsgType.ERROR:
                print(f"[WS 错误] {ws.exception()}")
                break

    except Exception as e:
        print(f"[错误] {e}")
        try:
            await ws.send_json({"type": "error", "message": str(e)})
        except:
            pass
    finally:
        is_playing = False
        if recv_task:
            recv_task.cancel()
        print("[连接] 浏览器已断开")

    return ws


async def handle_health(request):
    return web.json_response({"status": "ok"})


async def init_app():
    app = web.Application()
    app.router.add_get("/health", handle_health)
    app.router.add_get("/ws", handle_websocket)
    return app


def main():
    if not API_KEY:
        print("错误: 请设置 GEMINI_API_KEY 环境变量")
        print("  export GEMINI_API_KEY='your-api-key'")
        return

    print(f"Lyria RealTime 桥接服务器启动在 http://localhost:{PORT}")
    print("特性：自动会话轮转，浏览器不断连")
    app = asyncio.run(init_app())
    web.run_app(app, port=PORT)


if __name__ == "__main__":
    main()
