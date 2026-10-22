# Changelog

All notable user-facing features, improvements, and fixes for LightL.

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
