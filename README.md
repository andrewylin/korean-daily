# Korean Daily

Sends one Korean sentence at a time as a push notification. Each sentence uses one target word in otherwise easy language (comprehensible input). Words are picked at random, cycling through the full list before repeating.

## Set up in Xcode

1. File > New > Project > iOS > App. Name it KoreanDaily, Interface: SwiftUI, Language: Swift.
2. Delete the generated `KoreanDailyApp.swift` and `ContentView.swift`.
3. Drag in `KoreanDailyApp.swift`, `Models.swift`, `ClaudeClient.swift`, `Scheduler.swift`, `Views.swift`, and `words.json`. Tick "Copy items if needed" and your app target. `words.json` must be in the target so it lands in the app bundle.
4. Set the iOS deployment target to 17.0 or later.
5. Run on a device or simulator, open Settings, choose your interval and hours, tap "Save and schedule notifications", and allow notifications.

## How it works

- Local notifications only, no server. iOS allows 64 pending local notifications, so the app schedules 60 and tops the queue up each time you open it. If you go more than a few days without opening it, the queue runs dry.
- Notification layout: title is the Korean sentence, subtitle is `word = meaning`, body is the English translation.
- Practice tab: the target word is highlighted, the translation is hidden until you tap.
- Hybrid mode: turn on "Use Claude API" in Settings and paste an Anthropic API key (stored in the Keychain). About half of scheduled notifications, and any word with no bundled sentence, get a fresh generated sentence, capped at 20 API calls per reschedule. If a call fails, the bundled sentence is used.

## Growing the word list to 1000

`words.json` ships with about 110 starter words, each with a hand-written sentence. To reach 1000, add entries in this shape:

    {"ko":"가다","f":"가요","en":"to go","s":"학교에 가요.","t":"I go to school."}

`f` is the word as it appears in the sentence (used for highlighting). `s` and `t` are optional: with the API on, entries without them get sentences generated automatically. Source your list from a published Korean frequency list (for example the TOPIK or NIKL frequency lists) and have a Korean speaker spot check generated sentences.
