import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Live Activity de Nubi (estilo app)

struct NubiLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SueñoActivityAttributes.self) { context in
            VistaBloqueo(state: context.state, attributes: context.attributes)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .activityBackgroundTint(Theme.lienzoAlto)
                .activitySystemActionForegroundColor(Theme.tinta)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Insignia(
                        simbolo: simboloDe(context.state.modo),
                        fondo: colorDe(context.state.modo),
                        diametro: 32
                    )
                    .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(inicioTimer(context.state), style: .timer)
                        .font(Theme.display(22, .semibold))
                        .foregroundStyle(Theme.tinta)
                        .monospacedDigit()
                        .padding(.trailing, 2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(tituloDe(context.state.modo, ladoPecho: context.state.ladoPecho))
                        .font(Theme.cuerpo(12, .medium))
                        .foregroundStyle(Theme.tintaSuave)
                }
            } compactLeading: {
                Ilus(simboloDe(context.state.modo), 14, color: colorDe(context.state.modo))
            } compactTrailing: {
                Text(inicioTimer(context.state), style: .timer)
                    .font(Theme.cuerpo(12, .semibold))
                    .foregroundStyle(Theme.tinta)
                    .monospacedDigit()
            } minimal: {
                Ilus(simboloDe(context.state.modo), 14, color: colorDe(context.state.modo))
            }
        }
    }
    
    private func simboloDe(_ modo: SueñoActivityAttributes.ContentState.Modo) -> Ilus.Simbolo {
        switch modo {
        case .siesta:    return .nube
        case .noche:     return .luna
        case .despertar: return .lunaOjoAbierto
        case .pecho:     return .corazon
        }
    }
    
    private func colorDe(_ modo: SueñoActivityAttributes.ContentState.Modo) -> Color {
        switch modo {
        case .siesta:    return Theme.menta
        case .noche:     return Theme.lila
        case .despertar: return Theme.coral
        case .pecho:     return Theme.melocoton
        }
    }
    
    private func tituloDe(
        _ modo: SueñoActivityAttributes.ContentState.Modo,
        ladoPecho: SueñoActivityAttributes.ContentState.LadoPechoLA?
    ) -> String {
        switch modo {
        case .siesta:    return "Siesta"
        case .noche:     return "Sueño nocturno"
        case .despertar: return "Despertar nocturno"
        case .pecho:
            if let lado = ladoPecho { return "Pecho " + lado.etiqueta }
            return "Pecho"
        }
    }
    
    private func inicioTimer(_ state: SueñoActivityAttributes.ContentState) -> Date {
        let cal = Calendar.current
        let inicioDia = cal.startOfDay(for: Date())
        return max(state.inicio, inicioDia)
    }
}

// MARK: - Vista pantalla de bloqueo

struct VistaBloqueo: View {
    let state: SueñoActivityAttributes.ContentState
    let attributes: SueñoActivityAttributes
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(titulo)
                        .font(Theme.etiqueta)
                        .foregroundStyle(Theme.tintaSuave)
                        .textCase(.uppercase)
                    Text(inicioTimer, style: .timer)
                        .font(Theme.display(28, .semibold))
                        .foregroundStyle(colorAcento)
                        .monospacedDigit()
                    Text(subtitulo)
                        .font(Theme.cuerpo(11))
                        .foregroundStyle(Theme.tintaSuave)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Insignia(simbolo: simboloModo, fondo: colorAcento, diametro: 48)
            }
            botonera
        }
    }
    
    private var inicioTimer: Date {
        let cal = Calendar.current
        let inicioDia = cal.startOfDay(for: Date())
        return max(state.inicio, inicioDia)
    }
    
    @ViewBuilder
    private var botonera: some View {
        switch state.modo {
        case .siesta:
            BotonLink(
                titulo: "ha despertado",
                color: Theme.melocoton,
                url: URL(string: "nubi://fin-siesta")!
            )
            
        case .noche:
            HStack(spacing: 8) {
                BotonLA(titulo: "Se despertó",
                        color: Theme.coral,
                        intent: RegistrarDespertarLiveIntent())
                BotonLink(
                    titulo: "Fin de la noche",
                    color: Theme.melocoton,
                    url: URL(string: "nubi://fin-noche")!
                )
            }
            
        case .despertar:
            HStack(spacing: 8) {
                BotonLA(titulo: "Volvió a dormir",
                        color: Theme.lila,
                        intent: VolverADormirLiveIntent())
                BotonLink(
                    titulo: "Fin de la noche",
                    color: Theme.melocoton,
                    url: URL(string: "nubi://fin-despertar")!
                )
            }
            
        case .pecho:
            HStack(spacing: 8) {
                Button(intent: CambiarPechoLiveIntent()) {
                    HStack(spacing: 10) {
                        Ilus(.corazon, 18, color: coloreadoPecho(.izquierda))
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.tinta.opacity(0.6))
                        Ilus(.corazon, 18, color: coloreadoPecho(.derecha))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.melocoton.opacity(0.6), in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(Theme.tinta.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                Button(intent: TerminarPechoLiveIntent()) {
                    Ilus(.check, 20, color: Theme.tinta)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Theme.menta, in: Capsule())
                        .overlay(
                            Capsule().strokeBorder(Theme.tinta.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func coloreadoPecho(_ lado: SueñoActivityAttributes.ContentState.LadoPechoLA) -> Color {
        state.ladoPecho == lado ? Theme.tinta : Theme.tinta.opacity(0.25)
    }
    
    private var titulo: String {
        switch state.modo {
        case .siesta:    return "Siesta en curso"
        case .noche:     return attributes.nombreBebe + " · sueño nocturno"
        case .despertar: return attributes.nombreBebe + " · despertar nocturno"
        case .pecho:
            let lado = state.ladoPecho?.etiqueta ?? ""
            return attributes.nombreBebe + " · pecho " + lado
        }
    }
    
    private var subtitulo: String {
        let inicioFmt = state.inicio.formatted(date: .omitted, time: .shortened)
        switch state.modo {
        case .siesta, .noche: return "Dormido desde \(inicioFmt)"
        case .despertar:      return "Despierto desde \(inicioFmt)"
        case .pecho:          return "Tomando desde \(inicioFmt)"
        }
    }
    
    private var colorAcento: Color {
        switch state.modo {
        case .siesta:    return Theme.menta
        case .noche:     return Theme.lila
        case .despertar: return Theme.coral
        case .pecho:     return Theme.melocoton
        }
    }
    
    private var simboloModo: Ilus.Simbolo {
        switch state.modo {
        case .siesta:    return .nube
        case .noche:     return .luna
        case .despertar: return .lunaOjoAbierto
        case .pecho:     return .corazon
        }
    }
}

// MARK: - Botón con Intent (acción rápida, sin abrir app)

struct BotonLA<I: AppIntent>: View {
    let titulo: String
    let color: Color
    let intent: I
    
    var body: some View {
        Button(intent: intent) {
            Text(titulo)
                .font(Theme.cuerpo(12, .semibold))
                .foregroundStyle(Theme.tinta)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(Theme.tinta.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct BotonLink: View {
    let titulo: String
    let color: Color
    let url: URL
    
    var body: some View {
        Link(destination: url) {
            Text(titulo)
                .font(Theme.cuerpo(12, .semibold))
                .foregroundStyle(Theme.tinta)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(Theme.tinta.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

struct Insignia: View {
    let simbolo: Ilus.Simbolo
    var fondo: Color = Theme.lila
    var diametro: CGFloat = 36
    var tinta: Color = Theme.tinta
    
    var body: some View {
        Ilus(simbolo, diametro * 0.46, color: tinta)
            .frame(width: diametro, height: diametro)
            .background(fondo, in: Circle())
    }
}