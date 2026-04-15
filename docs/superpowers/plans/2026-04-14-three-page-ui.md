# Three-Page UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor Simone iOS from a two-state (expanded/collapsed) layout to a three-page vertical swipe UI: Immersive → Main → Details.

**Architecture:** Use a vertical `TabView(.page)` as the root container with three pages. Extract current collapsed view as ImmersiveView, keep Main page mostly as-is (move controls to bottom), and build a new DetailsView with playlist-style favorites, recommendations, evolve controls, and sleep timer. All spectrum/visualizer code stays untouched.

**Tech Stack:** SwiftUI, iOS 17+, @Observable pattern (existing)

---

## File Structure

### Create
- `Simone/Views/ImmersiveView.swift` — Full-screen spectrum, no UI chrome
- `Simone/Views/DetailsView.swift` — Playlist, evolve, sleep timer
- `Simone/Views/MiniPlayerView.swift` — Compact player bar for Details page
- `Simone/Views/StyleRowView.swift` — Reusable row for favorites/recommendations lists

### Modify
- `Simone/Views/ContentView.swift` — Replace expanded/collapsed with vertical TabView
- `Simone/Models/AppState.swift` — Add playback mode, sleep timer, playlist logic

### Delete
- `Simone/Views/ExpandableCardView.swift` — Replaced by DetailsView

### Do Not Touch
- `Simone/Views/SpectrumCarouselView.swift`
- `Simone/Views/Visualizers/*` (all 8 visualizers)
- `Simone/Views/PlayControlView.swift` (component itself unchanged)
- `Simone/Audio/*`
- `Simone/Network/*`
- `Simone/Models/MusicStyle.swift`
- `Simone/Models/VisualizerStyle.swift`

---

### Task 1: Add PlaybackMode and SleepTimer to AppState

**Files:**
- Modify: `Simone/Models/AppState.swift`

- [ ] **Step 1: Add PlaybackMode enum and sleep timer properties**

Add these at the top of `AppState`, after the `EvolveMode` enum:

```swift
enum PlaybackMode: String, CaseIterable {
    case sequential = "顺序"
    case shuffle = "随机"
}

var playbackMode: PlaybackMode = .sequential

// Sleep Timer
enum SleepDuration: Int, CaseIterable {
    case fifteen = 15
    case thirty = 30
    case sixty = 60
    case twoHours = 120

    var label: String {
        switch self {
        case .fifteen: "15分"
        case .thirty: "30分"
        case .sixty: "1小时"
        case .twoHours: "2小时"
        }
    }
}

var activeSleepDuration: SleepDuration? = nil
var sleepTimerEnd: Date? = nil
private var sleepTimer: Timer?
```

- [ ] **Step 2: Add sleep timer methods**

Add these methods to `AppState`:

```swift
func startSleepTimer(_ duration: SleepDuration) {
    sleepTimer?.invalidate()
    activeSleepDuration = duration
    sleepTimerEnd = Date().addingTimeInterval(TimeInterval(duration.rawValue * 60))
    sleepTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(duration.rawValue * 60), repeats: false) { [weak self] _ in
        guard let self else { return }
        self.lyriaClient.sendCommand("pause")
        self.audioEngine.pause()
        self.activeSleepDuration = nil
        self.sleepTimerEnd = nil
    }
}

func cancelSleepTimer() {
    sleepTimer?.invalidate()
    sleepTimer = nil
    activeSleepDuration = nil
    sleepTimerEnd = nil
}
```

- [ ] **Step 3: Add playlist next/previous logic**

Add these methods to `AppState`:

```swift
func playNextInPlaylist() {
    guard !pinnedStyles.isEmpty else { return }
    let currentIndex = pinnedStyles.firstIndex(where: { $0.id == selectedStyle?.id })

    let next: MoodStyle
    switch playbackMode {
    case .sequential:
        let nextIndex = ((currentIndex ?? -1) + 1) % pinnedStyles.count
        next = pinnedStyles[nextIndex]
    case .shuffle:
        let available = pinnedStyles.filter { $0.id != selectedStyle?.id }
        next = available.randomElement() ?? pinnedStyles[0]
    }
    selectStyle(next)
}

func playPreviousInPlaylist() {
    guard !pinnedStyles.isEmpty else { return }
    let currentIndex = pinnedStyles.firstIndex(where: { $0.id == selectedStyle?.id })

    switch playbackMode {
    case .sequential:
        let prevIndex = ((currentIndex ?? 1) - 1 + pinnedStyles.count) % pinnedStyles.count
        selectStyle(pinnedStyles[prevIndex])
    case .shuffle:
        // Fall back to history-based previous
        previousStyle()
    }
}

func refreshRecommendations() {
    let excludedIDs = pinnedStyles.map(\.id) + exploredStyles.map(\.id)
    let newStyles = MoodStyle.randomSelection(count: 4, excluding: excludedIDs)
    if newStyles.isEmpty {
        // All styles explored, reset exclusions
        exploredStyles = MoodStyle.randomSelection(count: 4, excluding: pinnedStyles.map(\.id))
    } else {
        exploredStyles = newStyles
    }
}
```

- [ ] **Step 4: Build and verify no compile errors**

Run: `cd /Users/oldfisherman/Desktop/simone/Simone_ios && xcodebuild -scheme Simone -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

- [ ] **Step 5: Commit**

```bash
cd /Users/oldfisherman/Desktop/simone/Simone_ios
git add Simone/Models/AppState.swift
git commit -m "feat: add PlaybackMode, SleepTimer, and playlist logic to AppState"
```

---

### Task 2: Create StyleRowView

**Files:**
- Create: `Simone/Views/StyleRowView.swift`

- [ ] **Step 1: Create StyleRowView**

```swift
import SwiftUI

struct StyleRowView: View {
    let style: MoodStyle
    let isPlaying: Bool
    let isFavorite: Bool
    let showFavoriteButton: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(showFavoriteButton && !isFavorite ? "✨" : "🎵")
                    .font(.system(size: 14))

                Text(style.name)
                    .font(.system(size: 15, weight: isPlaying ? .semibold : .regular))
                    .foregroundStyle(isPlaying ? MorandiPalette.rose : .white.opacity(0.65))
                    .lineLimit(1)

                Spacer()

                if showFavoriteButton {
                    Button {
                        onToggleFavorite()
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundStyle(isFavorite ? MorandiPalette.rose : .white.opacity(0.2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPlaying ? MorandiPalette.rose.opacity(0.08) : Color.white.opacity(0.025))
            )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `cd /Users/oldfisherman/Desktop/simone/Simone_ios && xcodebuild -scheme Simone -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
cd /Users/oldfisherman/Desktop/simone/Simone_ios
git add Simone/Views/StyleRowView.swift
git commit -m "feat: add StyleRowView component for playlist-style lists"
```

---

### Task 3: Create MiniPlayerView

**Files:**
- Create: `Simone/Views/MiniPlayerView.swift`

- [ ] **Step 1: Create MiniPlayerView**

```swift
import SwiftUI

struct MiniPlayerView: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            // Mini spectrum thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    RadialGradient(
                        colors: [MorandiPalette.rose.opacity(0.3), Color(red: 0.165, green: 0.165, blue: 0.18)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 36, height: 36)
                .overlay {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            let height: CGFloat = state.audioEngine.isPlaying
                                ? CGFloat([8, 14, 10][i])
                                : CGFloat([4, 6, 4][i])
                            RoundedRectangle(cornerRadius: 1)
                                .fill(MorandiPalette.rose.opacity(0.7))
                                .frame(width: 2.5, height: height)
                                .animation(.easeInOut(duration: 0.3), value: state.audioEngine.isPlaying)
                        }
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(state.selectedStyle?.name ?? "Simone")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                Text(state.audioEngine.isPlaying ? "播放中" : "已暂停")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
            }

            Spacer()

            Button {
                state.togglePlayPause()
            } label: {
                Image(systemName: state.audioEngine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `cd /Users/oldfisherman/Desktop/simone/Simone_ios && xcodebuild -scheme Simone -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
cd /Users/oldfisherman/Desktop/simone/Simone_ios
git add Simone/Views/MiniPlayerView.swift
git commit -m "feat: add MiniPlayerView component for Details page"
```

---

### Task 4: Create DetailsView

**Files:**
- Create: `Simone/Views/DetailsView.swift`

- [ ] **Step 1: Create DetailsView**

```swift
import SwiftUI

struct DetailsView: View {
    @Bindable var state: AppState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                // Mini Player
                MiniPlayerView(state: state)
                    .padding(.horizontal, 16)

                Spacer().frame(height: 20)

                // Favorites
                favoritesSection
                    .padding(.horizontal, 16)

                Spacer().frame(height: 20)

                // Recommendations
                recommendationsSection
                    .padding(.horizontal, 16)

                Spacer().frame(height: 24)

                // Evolve
                evolveSection
                    .padding(.horizontal, 16)

                Spacer().frame(height: 16)

                // Sleep Timer
                sleepTimerSection
                    .padding(.horizontal, 16)

                Spacer().frame(height: 32)
            }
            .frame(maxWidth: 400)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Favorites

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("喜爱")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.25))

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        state.playbackMode = .sequential
                    } label: {
                        Text("🔁")
                            .font(.system(size: 14))
                            .opacity(state.playbackMode == .sequential ? 1.0 : 0.35)
                    }
                    .buttonStyle(.plain)

                    Button {
                        state.playbackMode = .shuffle
                    } label: {
                        Text("🔀")
                            .font(.system(size: 14))
                            .opacity(state.playbackMode == .shuffle ? 1.0 : 0.35)
                    }
                    .buttonStyle(.plain)
                }
            }

            if state.pinnedStyles.isEmpty {
                Text("点击 ♡ 将喜爱的风格添加到这里")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.15))
                    .padding(.vertical, 12)
            } else {
                ForEach(state.pinnedStyles) { style in
                    StyleRowView(
                        style: style,
                        isPlaying: state.selectedStyle?.id == style.id,
                        isFavorite: true,
                        showFavoriteButton: true,
                        onTap: { state.selectStyle(style) },
                        onToggleFavorite: { state.unpinStyle(style) }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            state.unpinStyle(style)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("推荐")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.25))

                Spacer()

                Button {
                    state.refreshRecommendations()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.trianglehead.2.counterclockwise")
                            .font(.system(size: 11))
                        Text("换一批")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(MorandiPalette.rose)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MorandiPalette.rose.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            ForEach(state.exploredStyles) { style in
                let isFav = state.pinnedStyles.contains(where: { $0.id == style.id })
                StyleRowView(
                    style: style,
                    isPlaying: state.selectedStyle?.id == style.id,
                    isFavorite: isFav,
                    showFavoriteButton: true,
                    onTap: { state.selectStyle(style) },
                    onToggleFavorite: {
                        if isFav {
                            state.unpinStyle(style)
                        } else {
                            state.pinStyle(style)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Evolve

    private var evolveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("演化 EVOLVE")
                .font(.system(size: 11, weight: .medium))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.25))

            HStack(spacing: 6) {
                ForEach(AppState.EvolveMode.allCases, id: \.rawValue) { mode in
                    Button {
                        state.evolveMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                state.evolveMode == mode
                                    ? MorandiPalette.mauve.opacity(0.2)
                                    : Color.white.opacity(0.04)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(
                                state.evolveMode == mode
                                    ? MorandiPalette.mauve
                                    : .white.opacity(0.4)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
    }

    // MARK: - Sleep Timer

    private var sleepTimerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("定时关闭")
                .font(.system(size: 11, weight: .medium))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.25))

            HStack(spacing: 6) {
                ForEach(AppState.SleepDuration.allCases, id: \.rawValue) { duration in
                    Button {
                        if state.activeSleepDuration == duration {
                            state.cancelSleepTimer()
                        } else {
                            state.startSleepTimer(duration)
                        }
                    } label: {
                        Text(duration.label)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                state.activeSleepDuration == duration
                                    ? MorandiPalette.sand.opacity(0.2)
                                    : Color.white.opacity(0.04)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(
                                state.activeSleepDuration == duration
                                    ? MorandiPalette.sand
                                    : .white.opacity(0.4)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `cd /Users/oldfisherman/Desktop/simone/Simone_ios && xcodebuild -scheme Simone -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
cd /Users/oldfisherman/Desktop/simone/Simone_ios
git add Simone/Views/DetailsView.swift
git commit -m "feat: add DetailsView with favorites, recommendations, evolve, sleep timer"
```

---

### Task 5: Create ImmersiveView

**Files:**
- Create: `Simone/Views/ImmersiveView.swift`

- [ ] **Step 1: Create ImmersiveView**

```swift
import SwiftUI

struct ImmersiveView: View {
    @Bindable var state: AppState

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                Color(red: 0.165, green: 0.165, blue: 0.18)
                    .ignoresSafeArea()

                SpectrumCarouselView(state: state, showDots: false)
                    .frame(width: size, height: size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .statusBarHidden(true)
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `cd /Users/oldfisherman/Desktop/simone/Simone_ios && xcodebuild -scheme Simone -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
cd /Users/oldfisherman/Desktop/simone/Simone_ios
git add Simone/Views/ImmersiveView.swift
git commit -m "feat: add ImmersiveView for full-screen spectrum"
```

---

### Task 6: Rewrite ContentView as vertical TabView

**Files:**
- Modify: `Simone/Views/ContentView.swift`

- [ ] **Step 1: Replace ContentView with vertical paging TabView**

Replace the entire contents of `ContentView.swift` with:

```swift
import SwiftUI

struct ContentView: View {
    @State var state = AppState()
    @State private var currentPage: Int = 1  // Start on Main (middle page)

    var body: some View {
        GeometryReader { geo in
            let specSize = min(geo.size.width, 400) - 40

            ZStack {
                Color(red: 0.165, green: 0.165, blue: 0.18)
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [MorandiPalette.rose.opacity(0.06), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()

                TabView(selection: $currentPage) {
                    // Page 0: Immersive
                    ImmersiveView(state: state)
                        .tag(0)

                    // Page 1: Main
                    mainPage(specSize: specSize)
                        .tag(1)

                    // Page 2: Details
                    DetailsView(state: state)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private func mainPage(specSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 28)

            // Spectrum
            SpectrumCarouselView(state: state)
                .frame(width: specSize, height: specSize)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)

            Spacer().frame(height: 14)

            // Style name
            Text(state.selectedStyle?.name ?? "Simone")
                .font(.system(size: 20, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(Color(white: 0.88))
                .lineLimit(1)

            Spacer()

            // Transport controls at bottom
            PlayControlView(state: state)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Build and verify**

Run: `cd /Users/oldfisherman/Desktop/simone/Simone_ios && xcodebuild -scheme Simone -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
cd /Users/oldfisherman/Desktop/simone/Simone_ios
git add Simone/Views/ContentView.swift
git commit -m "feat: rewrite ContentView as vertical three-page TabView"
```

---

### Task 7: Delete ExpandableCardView and verify

**Files:**
- Delete: `Simone/Views/ExpandableCardView.swift`

- [ ] **Step 1: Delete the file**

```bash
cd /Users/oldfisherman/Desktop/simone/Simone_ios
rm Simone/Views/ExpandableCardView.swift
```

- [ ] **Step 2: Remove isDetailsExpanded from AppState**

In `Simone/Models/AppState.swift`, remove this line:

```swift
var isDetailsExpanded = false
```

- [ ] **Step 3: Build and verify no compile errors**

Run: `cd /Users/oldfisherman/Desktop/simone/Simone_ios && xcodebuild -scheme Simone -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

If there are references to `ExpandableCardView` or `ExploreRow` or `StylePill` anywhere else, remove them.

- [ ] **Step 4: Commit**

```bash
cd /Users/oldfisherman/Desktop/simone/Simone_ios
git add -A
git commit -m "refactor: remove ExpandableCardView, replaced by DetailsView"
```

---

### Task 8: Fix vertical swipe direction

**Files:**
- Modify: `Simone/Views/ContentView.swift`

The default `TabView(.page)` swipes horizontally. iOS doesn't have native vertical paging in `TabView`. We need to rotate the TabView trick or use a custom approach.

- [ ] **Step 1: Apply rotation trick for vertical paging**

Replace the `TabView` section in `ContentView.swift` with:

```swift
TabView(selection: $currentPage) {
    // Page 0: Immersive
    ImmersiveView(state: state)
        .rotationEffect(.degrees(-90))
        .frame(width: geo.size.width, height: geo.size.height)
        .tag(0)

    // Page 1: Main
    mainPage(specSize: specSize)
        .rotationEffect(.degrees(-90))
        .frame(width: geo.size.width, height: geo.size.height)
        .tag(1)

    // Page 2: Details
    DetailsView(state: state)
        .rotationEffect(.degrees(-90))
        .frame(width: geo.size.width, height: geo.size.height)
        .tag(2)
}
.tabViewStyle(.page(indexDisplayMode: .never))
.rotationEffect(.degrees(90))
.frame(width: geo.size.height, height: geo.size.width)
.frame(width: geo.size.width, height: geo.size.height)
.ignoresSafeArea()
```

- [ ] **Step 2: Build and verify**

Run: `cd /Users/oldfisherman/Desktop/simone/Simone_ios && xcodebuild -scheme Simone -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

- [ ] **Step 3: Test on simulator**

Launch the app in simulator. Verify:
- Swipe up from Main goes to Immersive
- Swipe down from Main goes to Details
- App starts on Main page (page 1)
- Spectrum left/right swipe still works on all pages

- [ ] **Step 4: Commit**

```bash
cd /Users/oldfisherman/Desktop/simone/Simone_ios
git add Simone/Views/ContentView.swift
git commit -m "fix: apply rotation trick for vertical page swiping"
```

---

### Task 9: Wire up swipe actions for favorites deletion

**Files:**
- Modify: `Simone/Views/DetailsView.swift`

- [ ] **Step 1: Wrap favorites in a List for swipe actions**

The `swipeActions` modifier only works inside a `List` or `ForEach` inside a `List`. Update the favorites section in `DetailsView` to use `List` with plain style:

Replace the `ForEach` block inside `favoritesSection` with:

```swift
List {
    ForEach(state.pinnedStyles) { style in
        StyleRowView(
            style: style,
            isPlaying: state.selectedStyle?.id == style.id,
            isFavorite: true,
            showFavoriteButton: true,
            onTap: { state.selectStyle(style) },
            onToggleFavorite: { state.unpinStyle(style) }
        )
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                state.unpinStyle(style)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}
.listStyle(.plain)
.frame(height: CGFloat(state.pinnedStyles.count) * 48)
.scrollDisabled(true)
```

- [ ] **Step 2: Build and verify**

Run: `cd /Users/oldfisherman/Desktop/simone/Simone_ios && xcodebuild -scheme Simone -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

- [ ] **Step 3: Test on simulator**

Verify left-swipe on a favorite row shows delete button and removes the item.

- [ ] **Step 4: Commit**

```bash
cd /Users/oldfisherman/Desktop/simone/Simone_ios
git add Simone/Views/DetailsView.swift
git commit -m "feat: wire up swipe-to-delete for favorites list"
```

---

### Task 10: End-to-end verification and push

- [ ] **Step 1: Full build**

Run: `cd /Users/oldfisherman/Desktop/simone/Simone_ios && xcodebuild -scheme Simone -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10`

- [ ] **Step 2: Launch in simulator and test all flows**

1. App opens on Main page
2. Swipe up → Immersive (full screen spectrum, no UI)
3. Swipe down → back to Main
4. Swipe down → Details page
5. Mini player shows current style and play/pause
6. Tap a recommended style → it plays
7. Tap ♡ on recommended → appears in favorites
8. Left swipe on favorite → delete
9. Tap 🔀 → shuffle mode active
10. Tap「换一批」→ new recommendations appear
11. Set Evolve to 10s → params drift
12. Set sleep timer 15分 → verify countdown (can shorten for testing)
13. Swipe up → back to Main
14. Spectrum left/right swipe works on all pages
15. Lock screen Now Playing still works

- [ ] **Step 3: Push**

```bash
cd /Users/oldfisherman/Desktop/simone/Simone_ios
git push
```
