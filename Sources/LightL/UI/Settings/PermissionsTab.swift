import SwiftUI
import AppKit

// MARK: - Tab 4: Permissions Content

struct PermissionsTab: View {
    @State private var isAxGranted = TextCaptureService.isAccessibilityGranted()
    @State private var isChecking = false
    @State private var feedbackText: String? = nil
    @State private var feedbackIsSuccess = true
    @State private var feedbackResetTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill((isAxGranted ? Color.green : Color.orange).opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: isAxGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(isAxGranted ? .green : .orange)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(isAxGranted
                            ? L10n.tr(ru: "Универсальный доступ разрешен", en: "Accessibility Granted")
                            : L10n.tr(ru: "Требуется Универсальный доступ", en: "Accessibility Required"))
                            .font(.system(size: 14, weight: .semibold))
                        Text(isAxGranted
                            ? L10n.tr(ru: "LightL имеет права для чтения и вставки текста в любых приложениях macOS.", en: "LightL has permission to read and insert text across macOS apps.")
                            : L10n.tr(ru: "Необходимо разрешить LightL в Системных настройках для работы горячих клавиш и замены текста.", en: "Enable LightL in System Settings for shortcuts and in-place replacement to function."))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Button(action: checkAccessibilityStatus) {
                        HStack(spacing: 6) {
                            if isChecking {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                                    .frame(width: 12, height: 12)
                                Text(L10n.tr(ru: "Проверка...", en: "Checking..."))
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(L10n.tr(ru: "Проверить статус", en: "Check Status"))
                            }
                        }
                    }
                    .buttonStyle(MacOS27GlassPillButtonStyle(isProminent: false))
                    .disabled(isChecking)

                    Button(L10n.tr(ru: "Открыть Системные настройки", en: "Open System Settings")) {
                        TextCaptureService.openAccessibilitySettings()
                    }
                    .buttonStyle(MacOS27GlassPillButtonStyle(isProminent: true))

                    if let text = feedbackText {
                        HStack(spacing: 5) {
                            Image(systemName: feedbackIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text(text)
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .foregroundColor(feedbackIsSuccess ? .green : .orange)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill((feedbackIsSuccess ? Color.green : Color.orange).opacity(0.12))
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }

                if !isAxGranted {
                    Text(L10n.tr(
                        ru: "Если macOS не показала системный запрос, нажмите «Открыть Системные настройки» и включите тумблер LightL вручную.",
                        en: "If macOS didn't show a system prompt, click \"Open System Settings\" and enable the LightL toggle manually."
                    ))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .macos27ContentCard(cornerRadius: 12)
        }
        .onAppear {
            isAxGranted = TextCaptureService.isAccessibilityGranted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            let granted = TextCaptureService.isAccessibilityGranted()
            isAxGranted = granted
            if granted {
                HotKeyManager.shared.recheckDoubleCmdCMonitor()
            }
        }
    }

    private func checkAccessibilityStatus() {
        feedbackResetTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) {
            isChecking = true
            feedbackText = nil
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)

            let granted = TextCaptureService.isAccessibilityGranted(prompt: !isAxGranted)

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.isAxGranted = granted
                self.isChecking = false
                if granted {
                    HotKeyManager.shared.recheckDoubleCmdCMonitor()
                    self.feedbackIsSuccess = true
                    self.feedbackText = L10n.tr(
                        ru: "Права активны",
                        en: "Permission active"
                    )
                } else {
                    self.feedbackIsSuccess = false
                    self.feedbackText = L10n.tr(
                        ru: "Доступ не включен",
                        en: "Not yet enabled"
                    )
                }
            }

            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)

            feedbackResetTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if !Task.isCancelled {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.feedbackText = nil
                    }
                }
            }
        }
    }
}
