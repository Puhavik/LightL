# Testing

## Automated

Run everything with `swift test`. Scripts are checked in CI with `shellcheck scripts/*.sh` and `./scripts/test_notarize.sh`.

| Area | Where | How |
|---|---|---|
| Gemini transport, SSE, retries, truncation, blocked responses | `GeminiStreamTests`, `GeminiServiceEdgeTests`, `GeminiParsingTests` | `URLProtocol` stub (`TruncatedStreamURLProtocol`) with a response queue and request capture |
| `AppCoordinator` flows (translate, rewrite, cancellation, ambiguous line capture) | `AppCoordinatorTests` | fakes behind `TextCapturing`, `TextTransforming`, `StatusIndicating`, `TranslationPresenting` |
| Settings migration (double-tap default, legacy key) | `AppSettingsMigrationTests` | isolated `UserDefaults` suite plus the in-memory Keychain |
| Clipboard capture, backup/restore, pending-restore window, line-copy heuristic | `TextCaptureTests` | testing hooks on `TextCaptureService` |
| Release script behavior | `scripts/test_notarize.sh` | stubbed `xcrun` |

The tests of the shared `LightLTests` suite live in several files (`ShortcutAndHotKeyTests`, `SettingsAndStorageTests`, `UIComponentTests`, ...) as extensions of it. Suites that touch the shared stub or the in-memory Keychain are serialized. Real `CGEvent` posting and Accessibility queries are not automated.

## Manual checklist before a release

- Translate and rewrite in Notes, Safari, VS Code (with a selection and with none), Slack, Terminal.
- In VS Code, Cursor, Sublime and JetBrains: rewrite with nothing selected (needs a second press and ends on the clipboard) and with a full line selected.
- Double-tap ⌘C on and off; with a password manager frontmost nothing is sent.
- Set both shortcuts to the same combination: the menu bar icon blinks and names the shortcut.
- Network drop mid-translation, an invalid key, an exhausted quota.
- First launch without Accessibility permission; Launch at Login.
- Install from the DMG on a clean account with no Keychain entry; verify `spctl -a -vv` on the app and the DMG, including offline.
