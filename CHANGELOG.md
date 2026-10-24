# Changelog

All notable user-facing features, improvements, and fixes for LightL.

---

## [Unreleased]

## [1.3.0] - 2026-10-24

### Changed
- Updated Gemini model lineup to `gemini-3.5-flash-lite` (default, ~0.5s), `gemini-3.1-flash-lite` (~1.0s), `gemini-3.5-flash` (~1.0s), and `gemini-3.6-flash` (~0.9s) with `thinkingLevel: "minimal"`.
- **Double-tap ⌘C is now off by default for new installs** (it sends the selection to Google Gemini); installs that already have an API key keep their current setting. Change it in Settings → Translation.
- Translations cut off at the length limit now fail with a clear message instead of showing partial text that could be pasted over the original.
- Replacing text re-checks that the selection is unchanged, also for apps that are read through the clipboard.
- Unavailable or conflicting shortcuts now blink the menu bar icon and name the shortcut.

### Fixed
- Clipboard restore now waits 2 s after the paste is posted, so slow apps no longer paste the old clipboard instead of the replacement.
- In editors that copy the whole caret line when nothing is selected (VS Code, JetBrains, Sublime), a clipboard capture that looks like such a line is never pasted back over the document: translation shows without Replace, and rewrite needs a second hotkey press within 5 s and then puts the result on the clipboard.
- The menu bar spinner now stays until the translation finishes, including the non-streaming fallback after an interrupted stream.
- A model is remembered as rejecting `thinkingBudget` only after the retry without it succeeds.
- Streaming updates are throttled (about 20 per second) and a late chunk can no longer overwrite the final result in the popover.
- Streaming translation: events were merged into one invalid payload (blank separator lines are dropped by `URLSession`), so every translation silently fell back to a second non-streaming request.
- A stream that closes without a finish reason is no longer shown as a complete translation, and blocked responses are no longer re-requested.
- Clipboard is restored even when a replacement is cancelled.
- Accessibility queries no longer run on the main thread.
- Models that reject `thinkingBudget` are remembered, so the extra failed request happens once.
- Only one shortcut recorder records at a time; quitting releases the global hotkeys.

### Added
- **Launch at Login**: menu bar item and Settings toggle (checkbox at the bottom of the Settings sidebar). Off by default; managed through System Settings → Login Items.

## [1.2.2] - 2026-10-23

Changes since 1.1.0 (versions 1.2.0 and 1.2.1 were withdrawn because the app crashed on launch when installed from the DMG).

### Security
- **Prompt isolation**: selected text is wrapped in a random per-request tag instead of a fixed `<input>` tag, so it cannot close the delimiter and inject instructions.
- **Safer text replacement**: replacement is cancelled if the selection changed while the request was running; responses cut off at the length limit are rejected instead of overwriting your text; selections over 12,000 characters are refused with a clear message.
- **Password managers**: double-tap ⌘C is skipped while Apple Passwords, 1Password, Bitwarden, KeePassXC, Dashlane, LastPass, Proton Pass or Keychain Access is the active app, and when the clipboard is marked as concealed.
- **Model ID validation**: custom model IDs may contain only letters, digits, `.`, `-` and `_`, so a pasted value can no longer redirect the request.
- **Keychain**: the legacy key is deleted only after it is safely re-saved; Settings warns when the key could not be stored.
- **Streaming errors**: bad key, quota and other 4xx errors are reported immediately instead of triggering a second request.
- **Privacy**: README and Settings now explain that selected text is sent to Google Gemini; the startup connection warm-up only happens when an API key is set.
- **Release pipeline**: strict Developer ID signing, notarization with stapling, Gatekeeper and signature verification, build provenance attestation (`gh attestation verify`), SHA-pinned GitHub Actions, least-privilege permissions, tag validation.

### Fixed
- App crashed on launch when installed from the release DMG ("could not load resource bundle"). Icons are loaded from the app bundle first; CI now launches the packaged app as a smoke test.
- Translation and proofreading results no longer show internal delimiter tags at the start and end of the text.

### Changed
- API key is saved on Enter, Save or when Settings closes (not on every keystroke); hotkeys are re-registered only when shortcuts change.
- Version and build number: bundle version comes from the release tag, build number is the commit count.
- Documentation: README privacy section, corrected notes on Gatekeeper and the double-tap monitor.

### Internal
- CI: ShellCheck, gitleaks secret scan, packaged-app launch smoke test, Dependabot for Actions.
- Tests: 52 automated tests (prompt isolation, truncation handling, model ID validation, password-manager guard); the screenshot generator runs only with `LIGHTL_GENERATE_SCREENSHOTS=1`.
- Repository cleanup: duplicate screenshots removed, local-only files ignored.

### Internal
- `AppCoordinator` takes its collaborators through protocols; new tests cover coordinator flows, settings migration, Gemini edge cases and `notarize.sh`. See TESTING.md.

---

## [1.1.0] - 2026-10-22

### Added
- **Live Streaming Translation (SSE)**: Asynchronous Server-Sent Events stream translations token-by-token directly into the floating popover with zero perceptible delay.
- **Support for Next-Gen Gemini Models**: Added support for Gemini 2.5 Flash, 3.5 Flash-Lite, 3.6 Flash, 3.8 Flash, Gemini Flash (Latest alias), and Gemini 4 Argon models with automatic reasoning/thinking token suppression for ultra-fast response.
- **Smart Popover Positioning**: Dynamic multi-monitor awareness that adapts to cursor bounds, screen edges, menu bar, and dock, preventing off-screen popover placement across complex display setups.
- **Comprehensive Swift Testing Suite**: 45 automated unit tests covering API streaming, prompt injection protection, Keychain lifecycle, coordinate transformations, and hotkey conflict detection.
- **Automated Notarization & Hardened Runtime**: CI/CD pipeline integrated with Apple `notarytool`, Developer ID signing, and security entitlements.

### Changed
- **Modernized macOS 27 Liquid Glass UI**: Enhanced popover with dynamic blur materials, continuous rounded corner clipping, and animated glass button styles.
- **Improved Status Bar Menu**: Menu header now includes an interactive version badge (`NSMenuItemBadge`), and the Accessibility indicator automatically hides once permission is granted.
- **Instant Thread-Safe Localization**: Zero-latency runtime localization using `OSAllocatedUnfairLock` with instant reactive UI updates on language change.
- **Icons**: Removed the heavy static iconset folder; app icons are produced by `scripts/generate_icons.swift`.

### Security
- **Prompt Injection Defense**: Text sent to Gemini is sanitized and encapsulated in delimiter tags to reduce prompt override attacks (the fixed `<input>` tag was replaced by a per-request random tag after 1.1.0).
- **API Key Sanitization**: Automatic filtering of trailing/leading whitespaces, hidden newlines, and carriage returns when saving API keys.
- **Hardened Keychain Storage**: Added data protection keychain fallback, access group support, and memory isolation locks for secure credential storage.

### Fixed
- **Translation Resiliency & SSE Fallback**: Added automatic non-streaming fallback, Accept header, and multi-format decoding for Gemini API translation streaming, preventing empty response errors.
- **Multi-Monitor Coordinate Conversion**: Fixed window coordinate calculation discrepancies between Carbon/Accessibility top-left origins and Cocoa bottom-left origins across secondary monitors and Retina scaling.
- **In-Place Text Replacement Race Condition**: Replaced fragile clipboard timing with re-entrancy protection lock and automatic clipboard restoration for non-AX text substitution.
- **System Hotkey Conflict Prevention**: Shortcut recorder now strictly blocks collisions with critical macOS system hotkeys (⌘C, ⌘V, ⌘A, ⌘Q, ⌘W, ⌘S, etc.).
- **Task Re-entrancy & Cancellation**: Properly cancels previous in-flight AI translation/rewrite requests when triggering a new action or dismissing the popup.

---

## [1.0.1] - 2026-10-22

### 🚀 New Features
- **Drag-and-Drop DMG Installer (`LightL.dmg`)**: Direct installation via macOS disk image with an Applications shortcut. No terminal commands required.

### 🛠 Improvements
- **Clean Release Packaging**: Releases now distribute strictly the standalone `LightL.dmg` installer.
- **English Documentation**: Full English documentation and badges in README.

---

## [1.0.0] - 2026-10-22

### 🚀 Features & Highlights
- **Menu Bar Resident**: Runs silently in the top menu bar (`LSUIElement = true`) with zero Dock clutter and ~30-40 MB RAM footprint.
- **Floating Translation Popover**: Press **`⌥ + ⌘ + C`** (or double **`⌘ + C`**) on highlighted text to translate next to your cursor with automatic language detection.
- **In-Place AI Proofreading & Rewrite**: Press **`⌥ + ⌘ + W`** to fix grammar or polish writing directly inside any active macOS app without popups.
- **Lossless Failure Protection**: If network or API quota fails, input text is never deleted; menu bar icon discreetly pulses red.
- **Secure Key Storage**: Google Gemini API keys are encrypted directly in macOS Keychain (`com.puhavik.LightL`).
- **Shortcut Customization**: Built-in shortcut recorder for custom hotkeys.
- **Native Stack**: Built natively with Swift 6 and SwiftUI for macOS 15+ Sequoia.
