# Accessibility

LightL is a native SwiftUI/AppKit app and uses standard macOS controls, so VoiceOver, Full Keyboard Access, Dynamic contrast and Reduce Motion settings apply.

## Supported environments

macOS 15 (Sequoia) or later.

## Known limitations

- The translation popover appears near the selection and may not be announced automatically by VoiceOver; use the configured hotkey and Esc to dismiss.
- Reading and replacing selected text requires macOS **Accessibility** permission (Privacy & Security → Accessibility). This is a system permission, unrelated to assistive-technology support in LightL itself.

## Reporting barriers

Open an [issue](https://github.com/Puhavik/LightL/issues/new/choose) titled "Accessibility: …" with your macOS version and assistive technology.
