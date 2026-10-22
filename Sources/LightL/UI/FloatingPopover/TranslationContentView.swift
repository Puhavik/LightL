import SwiftUI
import AppKit

public struct TranslationContentView: View {
    public let originalText: String
    public let translatedText: String?
    public let isLoading: Bool
    public let errorMessage: String?
    public let targetLanguage: LanguageModel
    public let onCopy: () -> Void
    public let onReplace: () -> Void
    public let onClose: () -> Void

    @State private var hasCopied = false
    @Environment(\.colorScheme) private var colorScheme

    public init(
        originalText: String,
        translatedText: String?,
        isLoading: Bool,
        errorMessage: String?,
        targetLanguage: LanguageModel,
        onCopy: @escaping () -> Void,
        onReplace: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.targetLanguage = targetLanguage
        self.onCopy = onCopy
        self.onReplace = onReplace
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Bar (Liquid Glass Navigation)
            headerView

            // Main Content Area (Structured High-Legibility Card)
            contentCard

            // Footer Actions (Liquid Glass Controls)
            footerView
        }
        .padding(14)
        .frame(width: 380)
        .macos27LiquidGlass(cornerRadius: 18)
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(targetLanguage.localizedName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Text(targetLanguage.nativeName)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.07))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr(ru: "Закрыть", en: "Close"))
            .keyboardShortcut(.escape, modifiers: [])
        }
    }

    // MARK: - Content Card (macOS 27 HIG: High Contrast Content Layer)
    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.9)
                        .controlSize(.regular)

                    Text(L10n.tr(ru: "Перевод через Gemini...", en: "Translating with Gemini..."))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 110)
            } else if let error = errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14))

                        Text(L10n.tr(ru: "Ошибка перевода", en: "Translation Error"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                    }

                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let text = translatedText {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(text)
                        .font(.system(size: 13.5, weight: .regular))
                        .lineSpacing(3.5)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(maxHeight: 280)
            }
        }
        .frame(minHeight: 100)
        .macos27ContentCard(cornerRadius: 12)
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack(spacing: 8) {
            if translatedText != nil && !isLoading {
                Button(action: {
                    onCopy()
                    hasCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        hasCopied = false
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                        Text(hasCopied ? L10n.tr(ru: "Скопировано", en: "Copied") : L10n.tr(ru: "Копировать", en: "Copy"))
                    }
                }
                .buttonStyle(MacOS27GlassPillButtonStyle(isProminent: false))

                Button(action: onReplace) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                        Text(L10n.tr(ru: "Заменить", en: "Replace"))
                    }
                }
                .buttonStyle(MacOS27GlassPillButtonStyle(isProminent: true))
            }

            Spacer()

            HStack(spacing: 4) {
                MacOS27Keycap("⎋")
                Text(L10n.tr(ru: "закрыть", en: "close"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - VisualEffectView Helper
public struct VisualEffectView: NSViewRepresentable {
    public let material: NSVisualEffectView.Material
    public let blendingMode: NSVisualEffectView.BlendingMode

    public init(material: NSVisualEffectView.Material, blendingMode: NSVisualEffectView.BlendingMode) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
