import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

struct RuidoActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RuidoActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Insignia(simbolo: .ondas, fondo: Theme.indigo, diametro: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.tipoNombre)
                            .font(Theme.cuerpo(14, .semibold))
                            .foregroundStyle(Theme.tinta)
                            .lineLimit(1)
                        if let fin = context.state.fechaFin {
                            Text("Hasta \(fin.formatted(date: .omitted, time: .shortened))")
                                .font(Theme.cuerpo(11))
                                .foregroundStyle(Theme.tintaSuave)
                        } else {
                            Text("Sonando · sin límite")
                                .font(Theme.cuerpo(11))
                                .foregroundStyle(Theme.tintaSuave)
                        }
                    }
                    Spacer(minLength: 4)
                    Text(context.state.inicio, style: .timer)
                        .font(Theme.cuerpo(15, .semibold))
                        .foregroundStyle(Theme.indigo)
                        .monospacedDigit()
                }

                // ← NUEVO: parar el sonido sin abrir la app
                Button(intent: PararRuidoLiveIntent()) {  // ← antes: PararRuidoIntent()
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Parar sonido")
                            .font(Theme.cuerpo(12, .semibold))
                    }
                    .foregroundStyle(Theme.tinta)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.coral.opacity(0.22), in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(Theme.coral.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .activityBackgroundTint(Theme.lienzoAlto)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Insignia(simbolo: .ondas, fondo: Theme.indigo, diametro: 32)
                        .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.inicio, style: .timer)
                        .font(Theme.cuerpo(13, .semibold))
                        .foregroundStyle(Theme.indigo)
                        .monospacedDigit()
                        .padding(.trailing, 2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        Text(context.state.tipoNombre)
                            .font(Theme.cuerpo(12, .medium))
                            .foregroundStyle(Theme.tintaSuave)
                        Spacer()
                        Button(intent: PararRuidoLiveIntent()) {  // ← antes: PararRuidoIntent()
                            Image(systemName: "stop.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.coral)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } compactLeading: {
                Ilus(.ondas, 14, color: Theme.indigo)
            } compactTrailing: {
                Text(context.state.inicio, style: .timer)
                    .font(Theme.cuerpo(11, .semibold))
                    .foregroundStyle(Theme.indigo)
                    .monospacedDigit()
            } minimal: {
                Ilus(.ondas, 14, color: Theme.indigo)
            }
        }
    }
}