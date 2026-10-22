# LightL — Lightweight AI Translator & Proofreader for macOS

[![CI](https://github.com/Puhavik/LightL/actions/workflows/ci.yml/badge.svg)](https://github.com/Puhavik/LightL/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Puhavik/LightL?color=blue)](https://github.com/Puhavik/LightL/releases/latest)
[![macOS 15+](https://img.shields.io/badge/macOS-15%2B%20(Sequoia)-black?logo=apple)](https://www.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)](https://swift.org)

A blazing fast, native macOS menu bar app for seamless translation and AI proofreading built with Swift and SwiftUI.
Powered by **Google Gemini API** (recommended `gemini-3.5-flash-lite` or flagship `gemini-3.8-flash`), consuming minimal system resources (~30–40 MB RAM, 0% CPU idle) with zero Dock clutter.

---

## ⚡️ Features

1. **Menu Bar Resident (`LSUIElement = true`):**
   - Lives quietly in your macOS status bar without cluttering the Dock.
   - Quick-access menu: instant language selection, mode toggles, and API connectivity indicator.

2. **Quick Translation Popover:**
   - Default hotkey: **`⌥ + ⌘ + C`** (or quick double-tap **`⌘ + C`**).
   - Automatic source language detection.
   - Translates selected text to your target language.
   - Floating panel appears contextually adjacent to selected text or cursor.
   - One-click actions: **Copy**, **Replace In-Place**, dismiss on `Esc` or click-outside.

3. **In-place Proofreading & Rewrite:**
   - Default hotkey: **`⌥ + ⌘ + W`**.
   - Two specialized modes:
     - **Fix Grammar & Punctuation:** Corrects typos, grammar, and punctuation while preserving original structure and vocabulary.
     - **Improve Style:** Rewrites text to be more concise, natural, and professional.
   - Directly replaces selected text in any active macOS application without opening popovers.
   - **Fault-tolerant feedback:**
     - If the network drops or API quota is exceeded, **original text is never lost or deleted**.
     - Unobtrusive error notification: status bar icon pulses red instead of disruptive modal dialogs.

4. **Customizable Shortcuts:**
   - Built-in visual keyboard shortcut recorder.
   - Toggle double `⌘ + C` trigger on/off.

---

## 🚀 Installation & Launch

### Prebuilt Binary
1. Download `LightL-macOS.zip` from [GitHub Releases](https://github.com/Puhavik/LightL/releases/latest).
2. Unzip and copy `LightL.app` to `/Applications/`:
   ```bash
   cp -R LightL.app /Applications/
   open /Applications/LightL.app
   ```
*(On first launch, if macOS Gatekeeper prompts for ad-hoc signature, Right-click `LightL.app` → select **Open**).*

### Build From Source
Requirements: macOS 15.0+ and Xcode 16.0+ (Swift 6.0).
```bash
git clone https://github.com/Puhavik/LightL.git
cd LightL
./scripts/build_app.sh
open LightL.app
```

---

## 🔑 Setup

1. **Google Gemini API Key:**
   - Open **Settings** (Click menu bar icon → **Settings...** or press `⌘,`).
   - Paste your Gemini API key (obtainable for free at [Google AI Studio](https://aistudio.google.com/app/apikey)).
   - Click **Save** and **Test API Key** to verify connectivity.

2. **Accessibility Permissions:**
   - macOS requires Accessibility permissions to read selected text from external apps and replace it in-place.
   - Navigate to the **Permissions** tab in LightL Settings and click **Open System Settings**.
   - Enable the toggle for `LightL` (or your terminal if launching via CLI).

---

## 📄 License

Copyright © 2026 Puhavik. All rights reserved.
See [LICENSE](LICENSE) for details.
