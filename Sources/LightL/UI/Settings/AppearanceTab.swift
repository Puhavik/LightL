import SwiftUI
import AppKit

struct AppearanceTab: View {
    @Bindable var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 14) {
            // Language Selection Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 15))
                        .foregroundColor(.accentColor)
                    Text(L10n.tr(ru: "Язык интерфейса", en: "Interface Language"))
                        .font(.system(size: 13, weight: .semibold))
                }

                Picker(L10n.tr(ru: "Язык:", en: "Language:"), selection: $settings.interfaceLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Text(L10n.tr(
                    ru: "По умолчанию используется системный язык macOS.",
                    en: "By default, matches your macOS system language."
                ))
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "macwindow.and.cursor")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr(ru: "Стиль интерфейса", en: "UI Style"))
                            .font(.system(size: 13, weight: .semibold))
                        Text(L10n.tr(
                            ru: "Liquid Glass с динамическим линзированием и структурированными карточками.",
                            en: "Liquid Glass with dynamic lensing and structured content cards."
                        ))
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr(ru: "Принципы дизайна:", en: "Design Principles:"))
                        .font(.system(size: 12, weight: .semibold))

                    bulletPoint(
                        title: L10n.tr(ru: "Навигация на жидком стекле (Liquid Glass):", en: "Liquid Glass Navigation:"),
                        detail: L10n.tr(
                            ru: "Боковые панели, всплывающие окна и кнопки используют полупрозрачный мета-материал с градиентным бликом верхней кромки.",
                            en: "Sidebars, popovers, and buttons use translucent material with specular top-edge highlights."
                        )
                    )

                    bulletPoint(
                        title: L10n.tr(ru: "Золотое правило читаемости контента:", en: "Content Readability Rule:"),
                        detail: L10n.tr(
                            ru: "Текст перевода и поля ввода размещаются на плотных структурированных карточках с контрастными границами для 100% читаемости на любых обоях.",
                            en: "Translations and inputs reside on solid structured cards with contrast borders for 100% legibility on any wallpaper."
                        )
                    )

                    bulletPoint(
                        title: L10n.tr(ru: "Цветные значки боковой панели:", en: "Colored Sidebar Icons:"),
                        detail: L10n.tr(
                            ru: "Возвращение акцентных цветных иконок для быстрого сканирования разделов.",
                            en: "Vibrant colored SF Symbols for rapid visual section recognition."
                        )
                    )

                    bulletPoint(
                        title: L10n.tr(ru: "Поддержка системного слайдера прозрачности:", en: "System Transparency Slider Support:"),
                        detail: L10n.tr(
                            ru: "Интерфейс корректно реагирует на ползунок Liquid Glass в Системных настройках macOS и режим «Уменьшение прозрачности».",
                            en: "Responds seamlessly to system Liquid Glass opacity sliders and Reduce Transparency mode."
                        )
                    )
                }
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)
        }
    }

    private func bulletPoint(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.primary)
            Text(detail)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}
