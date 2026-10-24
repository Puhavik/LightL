import SwiftUI
import AppKit

// MARK: - Tab 2: Translation Content

struct TranslationTab: View {
    @Bindable var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 14) {
            // Target Language Card
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.tr(ru: "Целевой язык перевода", en: "Target Translation Language"))
                    .font(.system(size: 13, weight: .semibold))

                Picker(L10n.tr(ru: "Язык:", en: "Language:"), selection: $settings.targetLanguageCode) {
                    ForEach(LanguageModel.supportedLanguages) { lang in
                        Text("\(lang.localizedName) (\(lang.nativeName))").tag(lang.code)
                    }
                }
                .pickerStyle(.menu)

                Text(L10n.tr(ru: "Язык исходного фрагмента определяется моделью автоматически.", en: "Source language is detected automatically by the model."))
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)

            // Shortcuts Card
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.tr(ru: "Горячие клавиши", en: "Keyboard Shortcuts"))
                    .font(.system(size: 13, weight: .semibold))

                ShortcutRecorderView(
                    label: L10n.tr(ru: "Всплывающее окно перевода:", en: "Translation popover:"),
                    shortcut: $settings.translateShortcut,
                    defaultShortcut: ShortcutModel.defaultTranslate
                )

                Divider()

                Toggle(L10n.tr(ru: "Быстрое двойное нажатие ⌘ + C", en: "Double-tap ⌘ + C"), isOn: $settings.doubleCmdCEnabled)
                    .font(.system(size: 13))

                Text(L10n.tr(
                    ru: "При быстром двойном нажатии ⌘+C выделенный фрагмент текста копируется и сразу открывается перевод в плавающем окне. Приватность: выделенный текст отправляется в Google Gemini. Не используйте с паролями и другими секретами.",
                    en: "Quickly pressing ⌘+C twice copies the selected text and immediately displays the translation in a floating window. Privacy: the selected text is sent to Google Gemini. Don't use this with passwords or other secrets."
                ))
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)
        }
    }
}
