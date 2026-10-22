# Changelog

All notable user-facing features, improvements, and fixes for LightL.

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
- **Dynamic Asset Generation**: Replaced heavy static binary iconsets with dynamic programmatic asset generation during build.

### Security
- **Prompt Injection Defense**: Text sent to Gemini is sanitized and encapsulated in structured XML tags (`<input>...</input>`) with escaping to prevent prompt override attacks.
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
