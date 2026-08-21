import Foundation
import ActivityKit

/// Gestiona el ciclo de vida de la Live Activity de sueño.
/// Un singleton porque solo puede haber una Live Activity a la vez.
@MainActor
final class GestorLiveActivity {
    static let shared = GestorLiveActivity()
    private init() {}
    
    /// Referencia a la actividad en curso, si la hay.
    private var actividadActual: Activity<SueñoActivityAttributes>?
    
    /// Inicia una Live Activity nueva. Si ya había una activa, la actualiza en lugar
    /// de crear otra (iOS no permite dos actividades del mismo tipo).
        func iniciar(modo: SueñoActivityAttributes.ContentState.Modo,
                inicio: Date,
                nombreBebe: String,
                ladoPecho: SueñoActivityAttributes.ContentState.LadoPechoLA? = nil) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities desactivadas por el usuario")
            return
        }
        
        if actividadActual != nil {
            actualizar(modo: modo, inicio: inicio, ladoPecho: ladoPecho)
            return
        }
        
        let attrs = SueñoActivityAttributes(nombreBebe: nombreBebe)
        let state = SueñoActivityAttributes.ContentState(
            modo: modo,
            inicio: inicio,
            ladoPecho: ladoPecho
        )
        
        do {
            let actividad = try Activity.request(
                attributes: attrs,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            actividadActual = actividad
        } catch {
            print("No se pudo iniciar la Live Activity: \(error)")
        }
    }

    func actualizar(modo: SueñoActivityAttributes.ContentState.Modo,
                    inicio: Date,
                    ladoPecho: SueñoActivityAttributes.ContentState.LadoPechoLA? = nil) {
        guard let actividad = actividadActual else { return }
        Task {
            let state = SueñoActivityAttributes.ContentState(
                modo: modo,
                inicio: inicio,
                ladoPecho: ladoPecho
            )
            await actividad.update(.init(state: state, staleDate: nil))
        }
    }

    // ← NUEVO: helper específico para cambio de pecho
    func actualizarPecho(inicio: Date,
                        ladoPecho: SueñoActivityAttributes.ContentState.LadoPechoLA) {
        actualizar(modo: .pecho, inicio: inicio, ladoPecho: ladoPecho)
    }
    
    /// Termina la actividad. Desaparece de la pantalla de bloqueo inmediatamente.
    func terminar() {
        guard let actividad = actividadActual else { return }
        let ref = actividad
        actividadActual = nil
        Task {
            await ref.end(nil, dismissalPolicy: .immediate)
        }
    }
    
    /// Al arrancar la app, limpia actividades huérfanas (por ejemplo, si el usuario
    /// cerró la app durante un sueño y ahora ya no coincide con el estado).
    func recuperarActividadesActivas() {
        actividadActual = Activity<SueñoActivityAttributes>.activities.first
    }
}