import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var keyID = ""
    @State private var secretKey = ""
    @State private var usePaper = true
    @State private var pollingInterval: Double = 60
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Alpaca API") {
                    TextField("Key ID", text: $keyID)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Secret Key", text: $secretKey)
                    Toggle("Use paper trading", isOn: $usePaper)
                    Button("Save credentials", action: saveCredentials)
                    if saved {
                        Label("Saved", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }

                Section("Monitoring") {
                    Stepper("Refresh every \(Int(pollingInterval))s", value: $pollingInterval, in: 15...300, step: 15)
                        .onChange(of: pollingInterval) { _, newValue in
                            appState.signalMonitor.pollingInterval = newValue
                        }
                }

                Section("Auto-Trading") {
                    Toggle("Enable auto-trading", isOn: .constant(false))
                        .disabled(true)
                    Text("Disabled in this build — signals are for manual action only. Order submission is already implemented in AlpacaTradingClient; flip `isAutoTradingEnabled` there once you're ready to test it against your Alpaca paper account.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear(perform: loadExisting)
        }
    }

    private func loadExisting() {
        keyID = appState.credentialsStore.keyID ?? ""
        secretKey = appState.credentialsStore.secretKey ?? ""
        usePaper = appState.credentialsStore.usePaperTrading
    }

    private func saveCredentials() {
        appState.credentialsStore.keyID = keyID
        appState.credentialsStore.secretKey = secretKey
        appState.credentialsStore.usePaperTrading = usePaper
        saved = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            saved = false
        }
    }
}
