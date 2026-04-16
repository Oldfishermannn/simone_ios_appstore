import SwiftUI

/// Embeddable API Key management section — used inside SettingsView.
struct APIKeySettingsView: View {
    @Bindable var state: AppState
    @State private var keyInput: String = ""
    @State private var savedKey: String? = KeychainHelper.loadAPIKey()
    @State private var showKey = false
    @State private var validationMessage: String?
    @State private var testStatus: TestStatus = .idle
    @FocusState private var isInputFocused: Bool

    enum TestStatus: Equatable {
        case idle
        case testing
        case success
        case failed(String)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Connection status
            connectionStatusBar

            if let saved = savedKey, !saved.isEmpty {
                savedKeySection(saved)
            } else {
                inputSection
            }
        }
    }

    // MARK: - Connection Status Bar

    private var connectionStatusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(statusColor.opacity(0.3))
                        .frame(width: 16, height: 16)
                )

            Text(statusText)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))

            Spacer()

            if testStatus == .testing {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(statusColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(statusColor.opacity(0.15), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch state.lyriaClient.connectionState {
        case .connected: return MorandiPalette.sage
        case .connecting, .reconnecting: return MorandiPalette.sand
        case .disconnected:
            switch testStatus {
            case .success: return MorandiPalette.sage
            case .failed: return MorandiPalette.rose
            case .testing: return MorandiPalette.sand
            case .idle: return .white.opacity(0.3)
            }
        }
    }

    private var statusText: String {
        switch state.lyriaClient.connectionState {
        case .connected: return "Connected to Lyria"
        case .connecting: return "Connecting..."
        case .reconnecting: return "Reconnecting..."
        case .disconnected:
            switch testStatus {
            case .idle:
                if savedKey != nil { return "Disconnected" }
                return "No key set"
            case .testing: return "Testing connection..."
            case .success: return "Connection successful"
            case .failed(let msg): return "Failed: \(msg)"
            }
        }
    }

    // MARK: - Saved Key Section

    private func savedKeySection(_ saved: String) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(MorandiPalette.sage.opacity(0.5))

                Text(showKey ? saved : maskKey(saved))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)

                Spacer()

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)

                Button {
                    _ = KeychainHelper.deleteAPIKey()
                    savedKey = nil
                    keyInput = ""
                    validationMessage = nil
                    testStatus = .idle
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(MorandiPalette.rose.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                testConnection()
            } label: {
                HStack(spacing: 8) {
                    if testStatus == .testing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(MorandiPalette.sage)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 14))
                    }
                    Text(testStatus == .testing ? "Testing..." : "Test Connection")
                        .font(.system(size: 15, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(MorandiPalette.sage.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(MorandiPalette.sage)
            }
            .buttonStyle(.plain)
            .disabled(testStatus == .testing)
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                TextField("Paste your Gemini API Key", text: $keyInput)
                    .font(.system(size: 15, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isInputFocused)
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isInputFocused
                                    ? MorandiPalette.sage.opacity(0.3)
                                    : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
                    .foregroundStyle(.white.opacity(0.8))
                    .onSubmit { saveAndTest() }

                if let msg = validationMessage {
                    Text(msg)
                        .font(.system(size: 12))
                        .foregroundStyle(MorandiPalette.rose.opacity(0.8))
                }

                Button {
                    saveAndTest()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 14))
                        Text("Save & Test")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        keyInput.isEmpty
                            ? Color.white.opacity(0.04)
                            : MorandiPalette.sage.opacity(0.2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(
                        keyInput.isEmpty
                            ? .white.opacity(0.2)
                            : MorandiPalette.sage
                    )
                }
                .buttonStyle(.plain)
                .disabled(keyInput.isEmpty)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Get a free Gemini API Key:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))

                guideStep("1", "Visit aistudio.google.com")
                guideStep("2", "Sign in with Google")
                guideStep("3", "Click Get API Key → Create")
            }
            .padding(16)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    private func guideStep(_ num: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Text(num)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(MorandiPalette.sage.opacity(0.5))
                .frame(width: 18, height: 18)
                .background(MorandiPalette.sage.opacity(0.1))
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private func maskKey(_ key: String) -> String {
        guard key.count > 8 else { return "****" }
        return "\(key.prefix(6))...\(key.suffix(4))"
    }

    private func saveAndTest() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed.hasPrefix("AIza") else {
            validationMessage = "Invalid format — should start with AIza"
            return
        }
        if KeychainHelper.saveAPIKey(trimmed) {
            savedKey = trimmed
            keyInput = ""
            validationMessage = nil
            isInputFocused = false
            testConnection()
        } else {
            validationMessage = "Save failed, please try again"
        }
    }

    private func testConnection() {
        testStatus = .testing
        state.lyriaClient.disconnect()
        state.audioEngine.start()
        state.lyriaClient.connect()

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if state.lyriaClient.connectionState == .connected {
                testStatus = .success
            } else if testStatus == .testing {
                testStatus = .failed(state.lyriaClient.statusMessage.isEmpty ? "Timeout" : state.lyriaClient.statusMessage)
            }
        }
        observeConnection()
    }

    private func observeConnection() {
        for i in 1...15 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                guard testStatus == .testing else { return }
                if state.lyriaClient.connectionState == .connected {
                    testStatus = .success
                }
            }
        }
    }
}
