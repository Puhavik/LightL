# Security Policy

## Supported versions

Only the [latest release](https://github.com/Puhavik/LightL/releases/latest) receives security fixes.

## Reporting a vulnerability

Do not open a public issue.

Use [private vulnerability reporting](https://github.com/Puhavik/LightL/security/advisories/new). Include affected version, reproduction steps and impact.

Expect an acknowledgement within 7 days and a fix or mitigation plan within 30 days. Reporters are credited in the changelog unless they prefer otherwise.

## Scope

In scope: API key handling (Keychain), prompt injection and text replacement safety, clipboard handling, release signing and pipeline.

Out of scope: issues in Google Gemini itself, or requiring a compromised macOS account.

## Verifying releases

Releases are Developer ID signed, notarized and carry build provenance:

```bash
gh attestation verify LightL.dmg --repo Puhavik/LightL
```
