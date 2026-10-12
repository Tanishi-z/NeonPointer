import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @ObservedObject private var loginItem = LoginItemManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("ネオンポインタを表示", isOn: $settings.isEnabled)
                .toggleStyle(.switch)
                .font(.headline)

            Toggle("ログイン時に自動的に起動", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.setEnabled($0) }
            ))
            .toggleStyle(.switch)
            .font(.callout)

            Toggle("カーソルが消えたらネオンも隠す", isOn: $settings.hideWhenCursorHidden)
                .toggleStyle(.switch)
                .font(.callout)
                .disabled(!settings.isEnabled)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Picker("形状", selection: $settings.shape) {
                    ForEach(PointerShape.allCases) { shape in
                        Text(shape.displayName).tag(shape)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                ColorRow(rgba: $settings.rgba)

                SliderRow(
                    title: "サイズ",
                    value: $settings.size,
                    range: SettingsStore.sizeRange
                ) { "\(Int($0)) pt" }

                SliderRow(
                    title: "不透明度",
                    value: $settings.opacity,
                    range: SettingsStore.opacityRange
                ) { "\(Int($0 * 100))%" }

                SliderRow(
                    title: "グロー",
                    value: $settings.glowRadius,
                    range: SettingsStore.glowRange
                ) { "\(Int($0))" }

                if settings.shape.usesStrokeWidth {
                    SliderRow(
                        title: "線幅",
                        value: $settings.strokeWidth,
                        range: SettingsStore.strokeRange
                    ) { "\(Int($0)) pt" }
                }
            }
            .disabled(!settings.isEnabled)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Toggle("修飾キーで線を描く", isOn: $settings.trailEnabled)
                    .toggleStyle(.switch)
                    .font(.callout)

                if settings.trailEnabled {
                    Picker("修飾キー", selection: $settings.trailModifier) {
                        ForEach(TrailModifier.allCases) { modifier in
                            Text(modifier.displayName).tag(modifier)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    SliderRow(
                        title: "消え始めるまで",
                        value: $settings.trailHoldDuration,
                        range: SettingsStore.trailHoldRange
                    ) { String(format: "%.1f 秒", $0) }

                    SliderRow(
                        title: "フェードアウト",
                        value: $settings.trailFadeDuration,
                        range: SettingsStore.trailFadeRange
                    ) { String(format: "%.1f 秒", $0) }

                    SliderRow(
                        title: "線の太さ",
                        value: $settings.trailWidth,
                        range: SettingsStore.trailWidthRange
                    ) { "\(Int($0)) pt" }

                    SliderRow(
                        title: "線のグロー",
                        value: $settings.trailGlowRadius,
                        range: SettingsStore.trailGlowRange
                    ) { "\(Int($0))" }

                    Toggle("カーソルと同じ色", isOn: $settings.trailUsesCursorColor)
                        .toggleStyle(.switch)
                        .font(.callout)

                    if !settings.trailUsesCursorColor {
                        ColorRow(rgba: $settings.trailRGBA)
                    }
                }
            }
            .disabled(!settings.isEnabled)

            Divider()

            HStack {
                Button("デフォルトに戻す") { settings.resetToDefaults() }
                Spacer()
                Button("終了") { NSApplication.shared.terminate(nil) }
            }
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { loginItem.refresh() }
    }
}

private struct ColorRow: View {
    @Binding var rgba: RGBAColor

    var body: some View {
        HStack {
            Text("色")
            Spacer()
            Button {
                ColorPanelController.shared.present(initial: rgba.nsColor) { newColor in
                    rgba = RGBAColor(newColor)
                }
            } label: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: rgba.nsColor))
                    .frame(width: 52, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.5))
                    )
            }
            .buttonStyle(.plain)
        }
        .font(.callout)
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.callout)

            Slider(value: $value, in: range)
        }
    }
}
