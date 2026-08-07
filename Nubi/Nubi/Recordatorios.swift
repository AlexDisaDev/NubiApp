import Foundation
import UserNotifications

/// Avisos locales para las citas. Solo locales: no hay servidor ni push, así
/// que no cambia nada de lo que promete el paywall sobre privacidad.
enum Recordatorios {

    private static let prefijo = "nubi.cita."

    static func pedirPermiso() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func permisoConcedido() async -> Bool {
        let estado = await UNUserNotificationCenter.current().notificationSettings()
        return estado.authorizationStatus == .authorized || estado.authorizationStatus == .provisional
    }

    /// Reprograma todos los avisos desde cero. Es más simple y más fiable que
    /// llevar la cuenta de cuál hay que añadir o quitar.
    static func reprogramar(_ citas: [Cita]) {
        let centro = UNUserNotificationCenter.current()
        centro.getPendingNotificationRequests { pendientes in
            let mias = pendientes.map(\.identifier).filter { $0.hasPrefix(prefijo) }
            centro.removePendingNotificationRequests(withIdentifiers: mias)

            for cita in citas where cita.recordar && !cita.pasada {
                // Aviso la tarde anterior: da tiempo a organizarse.
                guard let dispara = Calendar.current.date(byAdding: .hour, value: -18, to: cita.fecha),
                      dispara > .now else { continue }

                let contenido = UNMutableNotificationContent()
                contenido.title = cita.tituloVisible
                contenido.body = cita.lugar.isEmpty
                    ? "Mañana a las \(Fmt.hora(cita.fecha))."
                    : "Mañana a las \(Fmt.hora(cita.fecha)) en \(cita.lugar)."
                contenido.sound = .default

                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dispara)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                centro.add(UNNotificationRequest(identifier: prefijo + cita.id.uuidString,
                                                 content: contenido,
                                                 trigger: trigger))
            }
        }
    }

    static func cancelarTodo() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
