# Simone iOS - 项目状态文档

> 最后更新: 2026-04-14

## 项目概述

Simone 是一个 AI 音乐陪伴 App，通过 Google Lyria RealTime API 实时生成音乐。用户选择场景和风格，App 通过 WebSocket 连接服务端，服务端调用 Lyria API 生成 PCM 音频流，App 实时播放并展示频谱可视化。

## 架构

```
iOS App (SwiftUI)
    ↕ WebSocket (JSON commands + base64 PCM audio)
Python Bridge Server (colab_server.py)
    ↕ gRPC streaming
Google Lyria RealTime API
```

## 文件结构

```
Simone_ios/
├── Simone/
│   ├── SimoneApp.swift              # iOS 入口
│   ├── Info.plist                   # 后台音频、本地网络权限
│   ├── Assets.xcassets/             # App Icon (1024x1024)
│   ├── Audio/
│   │   ├── AudioEngine.swift        # AVAudioEngine + FFT 频谱分析
│   │   └── AudioBufferQueue.swift   # 线程安全的音频缓冲队列
│   ├── Models/
│   │   ├── AppState.swift           # 全局状态 + Lyria 参数 + Evolve 定时器
│   │   ├── MusicStyle.swift         # 场景/风格数据模型
│   │   └── VisualizerStyle.swift    # 8 种可视化器枚举
│   ├── Network/
│   │   ├── LyriaClient.swift        # WebSocket 客户端 + 自动重连
│   │   └── PromptBuilder.swift      # JSON 命令构造
│   └── Views/
│       ├── ContentView.swift        # 主界面 (展开/折叠)
│       ├── PlayControlView.swift    # 播放控制条
│       ├── ExpandableCardView.swift # 风格选择 + 参数监控 + 控制面板
│       ├── SpectrumCarouselView.swift # 频谱可视化轮播
│       └── Visualizers/             # 8 个可视化器
│           ├── AuroraView.swift
│           ├── ConstellationView.swift
│           ├── FountainView.swift
│           ├── ParticleFlowView.swift
│           ├── RingPulseView.swift
│           ├── RippleView.swift
│           ├── SilkWaveView.swift
│           ├── SpectrumDataProvider.swift
│           └── VinylView.swift
├── project.yml                      # XcodeGen 配置
└── colab_server.py                  # Colab 部署的桥接服务器
```

## 已实现功能

### 核心
- [x] WebSocket 连接 Lyria 桥接服务器
- [x] 实时 PCM 音频流播放 (48kHz stereo)
- [x] FFT 频谱分析 + 8 种可视化器轮播
- [x] 场景/风格选择，拖拽固定/取消固定
- [x] 播放/暂停/切歌
- [x] 音量控制
- [x] 锁屏 Now Playing 控制

### Lyria 参数控制
- [x] Temperature / Guidance 实时调节
- [x] BPM / Density / Brightness
- [x] top_k 采样参数
- [x] Mute Drums / Mute Bass / Only Bass+Drums 开关
- [x] QUALITY / DIVERSITY / VOCALIZATION 模式切换
- [x] 参数面板实时显示当前值

### Evolve 自动演化
- [x] Locked / 10s / 1min / 5min 四档定时器
- [x] 自动漂移 Temperature, Guidance, Density, Brightness
- [x] BPM 锁定不变

### UI
- [x] 展开/折叠视图 (点击频谱切换)
- [x] 折叠时仅显示频谱，无圆点和标题
- [x] App Icon (莫兰迪色系渐变音符)
- [x] 深色沉浸式界面

## 已知问题

### P0 - 影响核心体验

1. **远程访问音质差**
   - 现象: 通过 Cloudflare Tunnel (Colab) 连接时音频断断续续
   - 原因: Tunnel 网络延迟 + Colab 服务器性能不稳定
   - 当前状态: 只能局域网使用 (ws://10.0.0.128:8765/ws)
   - 建议方案:
     - 方案 A: 租用云服务器 (AWS/GCP) 直接部署 server.py
     - 方案 B: 在 Mac 上运行 server.py + cloudflared，手机同网络使用
     - 方案 C: 等 Lyria API 开放直连（无需中转服务器）

### P1 - 体验可优化

2. **暂停后切歌残留旧音频**
   - 现象: 暂停 → 切歌 → 播放，偶尔能听到一小段旧音频
   - 原因: playerNode.stop() 可以清空已调度的 buffer，但服务端切换 prompt 有延迟，新到的前几个 chunk 可能仍是旧音乐
   - 当前缓解: flushScheduledBuffers() 会 stop + 清空队列
   - 根本解决: 需要服务端在 set_prompts 后标记一个 sequence ID，客户端丢弃旧 sequence 的 chunk

3. **切歌时短暂静音**
   - 现象: 播放中切歌，有约 0.5-1s 的静音间隙
   - 原因: clearQueue + 等待新 prompt 的音频到达
   - 优化方向: crossfade 淡入淡出过渡

### P2 - 增强功能

4. **Evolve 变化感知度低**
   - 现象: 自动演化时参数变化不够明显
   - 建议: 增大漂移幅度，或同时轻微修改 prompt 权重

5. **无离线/缓存能力**
   - 现状: 完全依赖网络，无网络时无法使用
   - 建议: 缓存最近播放的音频片段作为 fallback

6. **iPad 适配**
   - 现状: 竖屏可用，但未针对大屏优化
   - 建议: 利用更大屏幕空间展示更多控件

## 部署方式

### 局域网模式（推荐，音质最佳）

1. Mac 上启动服务:
   ```bash
   cd /Users/oldfisherman/Desktop/simone
   GEMINI_API_KEY=xxx python -u server.py
   ```
2. iOS App 连接 `ws://<Mac-IP>:8765/ws`

### Colab 远程模式（可用但音质差）

1. 在 Google Colab 运行 `colab_server.py`
2. 获取 Cloudflare Tunnel 的 wss:// 地址
3. 修改 LyriaClient.swift 中的 serverURL

## 下一步计划

1. 解决远程访问方案 (P0)
2. 实现 sequence ID 消除切歌残留音频 (P1)
3. 添加更多可视化器
4. 支持多 prompt 混合 (weighted prompts)
5. 用户自定义场景/风格
