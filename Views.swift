import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: WordStore
    @Environment(\.scenePhase) private var phase

    var body: some View {
        TabView {
            CardView()
                .tabItem { Label("Practice", systemImage: "text.bubble") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onChange(of: phase) { _, new in
            // Top up the notification queue whenever the app opens.
            if new == .active { Task { await Scheduler.reschedule(store: store) } }
        }
    }
}

struct CardView: View {
    @EnvironmentObject var store: WordStore
    @State private var word: Word?
    @State private var entry: Entry?
    @State private var reveal = false
    @State private var loading = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            if let entry, let word {
                Text(highlighted(entry))
                    .font(.title2)
                    .multilineTextAlignment(.center)
                Text("\(word.ko) = \(word.en)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Button(reveal ? entry.en : "Tap to reveal translation") { reveal.toggle() }
                    .buttonStyle(.bordered)
            } else if store.words.isEmpty {
                Text("No words loaded. Check that words.json is in the app target.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack {
                Button("Next word") { next(fresh: false) }
                    .buttonStyle(.borderedProminent)
                if Keychain.get() != nil {
                    Button("Fresh sentence") { next(fresh: true) }
                        .buttonStyle(.bordered)
                        .disabled(loading || word == nil)
                }
            }
            .padding(.bottom, 24)
        }
        .padding()
        .onAppear { if word == nil { next(fresh: false) } }
    }

    private func next(fresh: Bool) {
        reveal = false
        if !fresh { word = store.randomWord() }
        guard let w = word else { return }
        entry = store.bundledEntry(w)
        if (fresh || entry == nil), let key = Keychain.get() {
            loading = true
            Task {
                if let e = try? await ClaudeClient.entry(for: w, apiKey: key) { entry = e }
                loading = false
            }
        }
    }

    private func highlighted(_ e: Entry) -> AttributedString {
        var a = AttributedString(e.ko)
        if let r = a.range(of: e.form) {
            a[r].foregroundColor = .accentColor
            a[r].font = .title.bold()
        }
        return a
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: WordStore
    @AppStorage(Keys.startHour) private var startHour = 8
    @AppStorage(Keys.endHour) private var endHour = 21
    @AppStorage(Keys.intervalMinutes) private var interval = 120
    @AppStorage(Keys.useAPI) private var useAPI = false
    @State private var apiKey = Keychain.get() ?? ""
    @State private var status = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule") {
                    Picker("Every", selection: $interval) {
                        ForEach([30, 60, 90, 120, 180, 240], id: \.self) { m in
                            Text(m < 60 ? "\(m) min" : "\(m / 60) h \(m % 60 == 0 ? "" : "30 min")")
                                .tag(m)
                        }
                    }
                    Picker("From", selection: $startHour) {
                        ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                    }
                    Picker("Until", selection: $endHour) {
                        ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                    }
                }
                Section("Fresh sentences (optional)") {
                    Toggle("Use Claude API", isOn: $useAPI)
                    if useAPI {
                        SecureField("Anthropic API key", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                Section {
                    Button("Save and schedule notifications") { save() }
                    if !status.isEmpty { Text(status).font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func hourLabel(_ h: Int) -> String {
        let hr = h % 12 == 0 ? 12 : h % 12
        return "\(hr) \(h < 12 ? "AM" : "PM")"
    }

    private func save() {
        Keychain.set(useAPI ? apiKey : "")
        status = "Scheduling..."
        Task {
            guard await Scheduler.requestPermission() else {
                status = "Notifications are off. Enable them in iOS Settings."
                return
            }
            await Scheduler.reschedule(store: store)
            status = "Scheduled."
        }
    }
}
