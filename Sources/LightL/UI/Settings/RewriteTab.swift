import SwiftUI
import AppKit

// MARK: - Tab 3: Rewrite Content

struct RewriteTab: View {
    @Bindable var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 14) {
            // Mode Selection Card
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.tr(ru: "Режим замены на месте", en: "In-place Replacement Mode"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(L10n.tr(ru: "Выберите, как модель обрабатывает выделенный текст по горячим клавишам:", en: "Choose how the model processes text selected in any app:"))
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }

                // Interactive Mode Cards
                HStack(spacing: 12) {
                    modeSelectionCard(
                        mode: .proofread,
                        icon: "checkmark.shield.fill",
                        gradient: [Color(red: 0.15, green: 0.78, blue: 0.55), Color(red: 0.08, green: 0.58, blue: 0.42)]
                    )

                    modeSelectionCard(
                        mode: .improveStyle,
                        icon: "sparkles",
                        gradient: [Color(red: 0.62, green: 0.38, blue: 0.98), Color(red: 0.44, green: 0.22, blue: 0.88)]
                    )
                }

                Divider()

                // What changes section
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr(ru: "Что меняется при переключении:", en: "What changes between modes:"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)

                    VStack(spacing: 7) {
                        modeComparisonRow(
                            label: L10n.tr(ru: "Слова и формулировки:", en: "Words & phrasing:"),
                            value: settings.rewriteMode.wordingBehavior,
                            icon: "textformat.abc"
                        )

                        modeComparisonRow(
                            label: L10n.tr(ru: "Температура модели:", en: "AI temperature:"),
                            value: settings.rewriteMode.temperatureDescription,
                            icon: "thermometer.medium"
                        )

                        modeComparisonRow(
                            label: L10n.tr(ru: "Назначение:", en: "Recommended for:"),
                            value: settings.rewriteMode.recommendedFor,
                            icon: "target"
                        )
                    }

                    // Live Example Card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                            Text(L10n.tr(
                                ru: "Наглядный пример работы (\(settings.rewriteMode.title)):",
                                en: "Transformation example (\(settings.rewriteMode.title)):"
                            ))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.primary)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .top, spacing: 6) {
                                Text(L10n.tr(ru: "Было:", en: "Before:"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 44, alignment: .leading)
                                Text("«\(settings.rewriteMode.exampleOriginal)»")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            HStack(alignment: .top, spacing: 6) {
                                Text(L10n.tr(ru: "Стало:", en: "After:"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 44, alignment: .leading)
                                Text("«\(settings.rewriteMode.exampleResult)»")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)

            // Shortcuts & Protection Card
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.tr(ru: "Горячие клавиши замены", en: "In-place Replacement Shortcuts"))
                    .font(.system(size: 13, weight: .semibold))

                ShortcutRecorderView(
                    label: L10n.tr(ru: "Замена выделенного фрагмента:", en: "Replace selected text:"),
                    shortcut: $settings.rewriteShortcut,
                    defaultShortcut: ShortcutModel.defaultRewrite
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)
                        Text(L10n.tr(ru: "Безопасность и защита текста", en: "Safety & Text Protection"))
                            .font(.system(size: 12, weight: .medium))
                    }

                    Text(L10n.tr(
                        ru: "При ошибке сети или API оригинальный текст в поле ввода не стирается, а иконка в строке меню мягко моргает красным цветом.",
                        en: "If a network or API error occurs, original text in the input field is never erased, and the menu bar icon gently blinks red."
                    ))
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)
        }
    }

    private func modeSelectionCard(mode: RewriteMode, icon: String, gradient: [Color]) -> some View {
        let isSelected = settings.rewriteMode == mode
        return Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                settings.rewriteMode = mode
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 26, height: 26)

                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text(mode.shortBadge)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
                        )
                        .foregroundColor(isSelected ? .accentColor : .secondary)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .accentColor : Color.secondary.opacity(0.4))
                }

                Text(mode.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Text(mode.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func modeComparisonRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}
