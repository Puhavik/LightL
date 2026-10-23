# Contributing to LightL

Thanks for helping. LightL is a macOS menu bar app (Swift 6, SwiftUI, macOS 15+).

> The project is under a proprietary [LICENSE](LICENSE). By submitting a contribution you agree it may be distributed under that license.

## Reporting bugs and ideas

- Search [existing issues](https://github.com/Puhavik/LightL/issues) first.
- Use the issue templates. Include macOS version, LightL version, steps to reproduce.
- Never paste your Gemini API key or private text into an issue.
- Security problems: see [SECURITY.md](SECURITY.md), do not open a public issue.

## Development

Requires macOS 15+ and Xcode 16+.

```bash
git clone https://github.com/Puhavik/LightL.git
cd LightL
swift build
swift test
./scripts/create_dmg.sh   # full app bundle + DMG
```

## Pull requests

1. Fork and branch from `main`.
2. Keep changes focused; one concern per PR.
3. Match the surrounding code style. Swift 6 strict concurrency must stay clean.
4. Add or update tests in `Tests/LightLTests` for logic changes.
5. Make sure `swift build` and `swift test` pass; CI runs both.
6. Add user-facing changes to [CHANGELOG.md](CHANGELOG.md).
7. Use [Conventional Commits](https://www.conventionalcommits.org/) (`fix:`, `feat:`, `docs:`, `chore:`).

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
