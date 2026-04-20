import SwiftUI

/// DetailsView — "Nocturne station log"
///
/// Fog City Nocturne 美学：把频道浏览当作一本摊开的电台航行日志，不是播放器 UI。
/// - 顶部：极简 ledger header（序号 + 一行手绘 italic tagline，不是 app bar）
/// - 中部：雾中黄铜旋钮 dial — 当前项靠侧光 + Fraunces italic 手写下划线强调，
///         邻居隐入冷雾（无彩色 punch）
/// - 底部：每个 channel 一页的 style 目录（由 ChannelPageView 渲染）
///
/// 侧光（非顶光）：一层 oklch(~0.22 0.02 250) 的冷雾光从左下角渗入，
/// 让整个屏感觉被台灯从一侧照着，大半在阴影里。
struct DetailsView: View {
    @Bindable var state: AppState

    private let channels = Channel.all

    /// Browsing cursor — moves freely with horizontal swipe, NOT tied to playback.
    @State private var browseChannel: Channel = .category(.lofi)
    /// Dial scroll cursor. Separate from browseChannel so the dial can be
    /// free-scrubbed without forcing the bottom TabView to chase every pixel.
    @State private var dialIdx: Int? = 0

    var body: some View {
        ZStack {
            // 冷雾侧光：从左下渗入，大半屏在阴影里。
            // 不要用 ContentView 顶部的 rose gradient —— 就地 override 成冷蓝雾。
            sideFogLight
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer().frame(height: 18)

                ledgerHeader
                    .padding(.horizontal, 20)

                Spacer().frame(height: 22)

                nowTunedRow
                    .padding(.horizontal, 20)

                Spacer().frame(height: 26)

                channelDial

                Spacer().frame(height: 2)

                dialTickMarker

                Spacer().frame(height: 14)

                // Bottom: magnetic TabView — full-page pagination stays as before.
                TabView(selection: $browseChannel) {
                    ForEach(channels, id: \.self) { channel in
                        ChannelPageView(
                            state: state,
                            channel: channel,
                            onSelect: { style in
                                state.switchToChannel(channel)
                                state.selectStyle(style)
                            }
                        )
                        .tag(channel)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Spacer().frame(height: 24)
            }
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            let idx = channels.firstIndex(of: state.currentChannel) ?? 0
            browseChannel = state.currentChannel
            dialIdx = idx
        }
        .onChange(of: dialIdx) { _, newIdx in
            // Dial scrub settled on a new item — sync bottom TabView.
            if let idx = newIdx, idx >= 0, idx < channels.count,
               browseChannel != channels[idx] {
                browseChannel = channels[idx]
            }
        }
        .onChange(of: browseChannel) { _, new in
            // TabView swipe (or external change) — scroll dial to match.
            let idx = channels.firstIndex(of: new) ?? 0
            if dialIdx != idx {
                dialIdx = idx
            }
        }
        .onChange(of: state.currentChannel) { _, new in
            if browseChannel != new { browseChannel = new }
        }
    }

    // MARK: - Side fog light (scene lighting, not decoration)

    /// 一层从左下角渗出的冷雾光。侧光，不是顶光；衰减够快不会污染 dial 区。
    private var sideFogLight: some View {
        GeometryReader { geo in
            RadialGradient(
                colors: [
                    Color(red: 0.40, green: 0.48, blue: 0.58).opacity(0.14),
                    Color(red: 0.18, green: 0.22, blue: 0.28).opacity(0.04),
                    .clear
                ],
                center: UnitPoint(x: -0.05, y: 1.05),
                startRadius: 40,
                endRadius: max(geo.size.width, geo.size.height) * 0.9
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Ledger header (序号 + italic tagline)

    /// 顶部 ledger row —— 左边一个 SIDE A/XX 手账编号，右边一行 italic tagline。
    /// 不是 toolbar，不是 section title，是小册子的眉头。
    private var ledgerHeader: some View {
        let totalIdx = channels.count
        let currentIdx = (dialIdx ?? 0) + 1
        return HStack(alignment: .firstTextBaseline) {
            // 左：SIDE A · 02/06，Archivo small caps + SF Mono 数字。
            HStack(spacing: 8) {
                Text("SIDE A")
                    .font(FogTheme.body(9, weight: .medium))
                    .tracking(FogTheme.trackLabel)
                    .textCase(.uppercase)
                    .foregroundStyle(FogTheme.inkTertiary)

                Rectangle()
                    .fill(FogTheme.hairline)
                    .frame(width: 12, height: 0.5)

                HStack(spacing: 0) {
                    Text(String(format: "%02d", currentIdx))
                        .font(FogTheme.mono(10, weight: .regular))
                        .foregroundStyle(FogTheme.inkSecondary)
                    Text(" / ")
                        .font(FogTheme.mono(10, weight: .regular))
                        .foregroundStyle(FogTheme.inkQuiet)
                    Text(String(format: "%02d", totalIdx))
                        .font(FogTheme.mono(10, weight: .regular))
                        .foregroundStyle(FogTheme.inkTertiary)
                }
                .tracking(FogTheme.trackMeta)
            }

            Spacer()

            // 右：一句 Fraunces italic tagline —— 手写感，不是 marketing copy。
            Text("stations at low tide")
                .font(FogTheme.serifItalic(13, weight: .light))
                .foregroundStyle(FogTheme.inkTertiary)
        }
    }

    // MARK: - Now tuned row (原 MiniPlayer 替身，不再是卡片)

    /// "Now Tuned" ledger entry —— 去掉 rounded-rect card 和通用 EQ bar 缩略图。
    /// 左：两行排版（italic 小标 + Unbounded 大字 style name）
    /// 右：一个手绘 play/pause glyph（outline circle + 中心符号），非 SF Symbol 填充三角。
    /// 分隔只靠一根顶部 hairline —— 不是容器，是日志条目。
    private var nowTunedRow: some View {
        let playing = state.audioEngine.isPlaying
        let styleName = state.selectedStyle?.name ?? "untuned"

        return VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(FogTheme.hairline)
                .frame(height: 0.5)

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    // italic small caption — 手写感 tag
                    Text(playing ? "now tuned to" : "resting on")
                        .font(FogTheme.serifItalic(11, weight: .light))
                        .foregroundStyle(FogTheme.inkTertiary)

                    // Unbounded light 大字 style name
                    Text(styleName)
                        .font(FogTheme.display(18, weight: .light))
                        .tracking(FogTheme.trackDisplay)
                        .foregroundStyle(FogTheme.inkPrimary)
                        .lineLimit(1)
                }

                Spacer()

                // 手绘 transport glyph：不是 SF Symbol 填充三角，是 outline + 中心符号。
                Button {
                    state.togglePlayPause()
                } label: {
                    transportGlyph(playing: playing)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
        }
    }

    /// 手绘 play/pause —— outline 圆 + 中心极简符号，冷灰描边不用 accent 色。
    /// 暖意留给更稀缺的锚点（如 dial 被选中项），这里保持克制。
    @ViewBuilder
    private func transportGlyph(playing: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(FogTheme.inkSecondary.opacity(0.42), lineWidth: 0.75)
                .frame(width: 36, height: 36)

            if playing {
                // pause：两根短竖条，不加圆角，手画 ruler 质感
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(FogTheme.inkPrimary.opacity(0.82))
                        .frame(width: 1.5, height: 11)
                    Rectangle()
                        .fill(FogTheme.inkPrimary.opacity(0.82))
                        .frame(width: 1.5, height: 11)
                }
            } else {
                // play：一个轻微偏右的 outline 三角（描边，不填充）
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: 10, y: 6))
                    p.addLine(to: CGPoint(x: 0, y: 12))
                    p.closeSubpath()
                }
                .stroke(FogTheme.inkPrimary.opacity(0.82),
                        style: StrokeStyle(lineWidth: 1, lineJoin: .miter))
                .frame(width: 10, height: 12)
                .offset(x: 1.5) // 视觉光学居中
            }
        }
    }

    // MARK: - Dial（雾中黄铜旋钮）

    /// 顶部 dial —— free-scroll horizontal picker。
    /// 当前项的强调：weight + 下方一笔 Fraunces italic underline（手写感）+ 下方侧光斑。
    /// 不再用 channel accent color 给当前项着色 —— 暖色会 punch 冷雾底，违背美学。
    private var channelDial: some View {
        GeometryReader { geo in
            let sideInset = geo.size.width / 2

            ZStack {
                // 聚焦侧光斑 —— 模拟台灯从右下打在当前旋钮上
                dialSpotlight
                    .frame(width: 180, height: 46)
                    .allowsHitTesting(false)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        Color.clear.frame(width: sideInset)

                        ForEach(Array(channels.enumerated()), id: \.element) { index, channel in
                            dialCell(channel: channel, index: index)
                                .id(index)
                        }

                        Color.clear.frame(width: sideInset)
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $dialIdx, anchor: .center)
            }
        }
        .frame(height: 46)
    }

    /// 一个柔和的冷雾光斑，只照亮 dial 正中央。不是 glow，是 scene light。
    private var dialSpotlight: some View {
        RadialGradient(
            colors: [
                Color(red: 0.52, green: 0.58, blue: 0.68).opacity(0.16),
                Color(red: 0.30, green: 0.36, blue: 0.46).opacity(0.05),
                .clear
            ],
            center: .center,
            startRadius: 6,
            endRadius: 90
        )
    }

    @ViewBuilder
    private func dialCell(channel: Channel, index: Int) -> some View {
        let currentIdx = dialIdx ?? 0
        let distance = abs(index - currentIdx)
        let isCurrent = distance == 0

        // 邻居隐入雾：opacity 快速跌落，不靠颜色区分
        let opacity: Double = isCurrent
            ? 0.96
            : (distance == 1 ? 0.36 : (distance == 2 ? 0.18 : 0.08))

        VStack(spacing: 3) {
            // Channel name —— 全部用 ink 白（无彩色），靠 opacity + weight 分层
            Text(channel.displayName.uppercased())
                .font(FogTheme.display(11,
                                       weight: isCurrent ? .regular : .light))
                .tracking(FogTheme.trackLabel)
                .foregroundStyle(FogTheme.ink.opacity(opacity))
                .lineLimit(1)

            // 当前项：一笔 Fraunces italic underline + 手写短横（唯一强调手法）
            if isCurrent {
                italicUnderline
                    .frame(height: 10)
                    .transition(.opacity)
            } else {
                Color.clear.frame(height: 10)
            }
        }
        .padding(.horizontal, 18)
        .animation(.easeOut(duration: 0.22), value: isCurrent)
    }

    /// 手写 italic underline —— 一个 Fraunces italic 的极小横杠，
    /// 位置略偏左，长度不齐，故意不像 UI 组件，像钢笔一划。
    private var italicUnderline: some View {
        HStack(spacing: 0) {
            // Fraunces italic 的一个极小字符伪装成手写笔触
            Text("‹")
                .font(FogTheme.serifItalic(10, weight: .light))
                .foregroundStyle(FogTheme.inkSecondary)
                .offset(y: -2)
            Rectangle()
                .fill(FogTheme.inkSecondary.opacity(0.55))
                .frame(width: 18, height: 0.75)
                .offset(y: 0)
            Text("›")
                .font(FogTheme.serifItalic(10, weight: .light))
                .foregroundStyle(FogTheme.inkSecondary)
                .offset(y: -2)
        }
    }

    // MARK: - Dial tick marker（取代 pill indicator）

    /// 取代原本的 pill indicator。
    /// 一条居中的单根 hairline 刻度，和 ledger 的手账感呼应，不是 dots。
    private var dialTickMarker: some View {
        ZStack {
            Rectangle()
                .fill(FogTheme.inkQuiet)
                .frame(height: 0.5)

            // 居中一个极小的 fuller tick，标记 dial 对齐点
            Rectangle()
                .fill(FogTheme.inkSecondary.opacity(0.6))
                .frame(width: 1, height: 5)
                .offset(y: -2)
        }
        .frame(height: 8)
        .padding(.horizontal, 60)
    }
}
