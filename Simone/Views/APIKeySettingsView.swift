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
        // v1.2.1: lock status hues to Fog cool axis + two permitted warms.
        // sage → accentIndigo (healthy/connected), sand → accentBrass
        // (warming up / retrying), rose → dangerEmber (error).
        switch state.lyriaClient.connectionState {
        case .connected: return FogTokens.accentIndigo
        case .connecting, .reconnecting: return FogTokens.accentBrass
        case .disconnected:
            switch testStatus {
            case .success: return FogTokens.accentIndigo
            case .failed: return FogTokens.dangerEmber
            case .testing: return FogTokens.accentBrass
            case .idle: return FogTokens.textTertiary.opacity(0.6)
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
                    .foregroundStyle(FogTokens.accentIndigo.opacity(0.55))

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
                        .foregroundStyle(FogTokens.dangerEmber.opacity(0.55))
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
                            .tint(FogTokens.accentIndigo)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 14))
                    }
                    Text(testStatus == .testing ? "Testing..." : "Test Connection")
                        .font(.system(size: 15, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(FogTokens.accentIndigo.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(FogTokens.accentIndigo)
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
                    .background(FogTokens.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isInputFocused
                                    ? FogTokens.accentIndigo.opacity(0.35)
                                    : FogTokens.lineHairline,
                                lineWidth: 1
                            )
                    )
                    .foregroundStyle(FogTokens.textPrimary.opacity(0.9))
                    .onSubmit { saveAndTest() }

                if let msg = validationMessage {
                    Text(msg)
                        .font(.system(size: 12))
                        .foregroundStyle(FogTokens.dangerEmber.opacity(0.85))
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
                            ? FogTokens.bgSurface
                            : FogTokens.accentIndigo.opacity(0.18)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(
                        keyInput.isEmpty
                            ? FogTokens.textTertiary
                            : FogTokens.accentIndigo
                    )
                }
                .buttonStyle(.plain)
                .disabled(keyInput.isEmpty)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Get a free Gemini API Key:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FogTokens.textSecondary.opacity(0.65))

                guideStep("1", "Visit aistudio.google.com")
                guideStep("2", "Sign in with Google")
                guideStep("3", "Click Get API Key → Create")
            }
            .padding(16)
            .background(FogTokens.bgSurface.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    private func guideStep(_ num: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Text(num)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(FogTokens.accentIndigo.opacity(0.7))
                .frame(width: 18, height: 18)
                .background(FogTokens.accentIndigo.opacity(0.12))
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(FogTokens.textTertiary)
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
