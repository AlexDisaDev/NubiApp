import Foundation
import UserNotifications

enum NotificadorMedicinas {
    private static let prefijo = "nubi.medicina."

    static func pedirPermiso() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func programar(_ medicina: Medicina) {
        guard let horaSiguiente = medicina.horaSiguiente,
              horaSiguiente > Date() else { return }
        
        // ← CORREGIDO: Usamos el callback nativo para evitar el error de Task/Sendable
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || 
                  settings.authorizationStatus == .provisional else { return }
            
            let centro = UNUserNotificationCenter.current()
            let contenido = UNMutableNotificationContent()
            contenido.title = "Hora de la medicina"
            contenido.body = medicina.nombre.isEmpty
                ? "Es hora de la siguiente toma."
                : "Es hora de darle \(medicina.nombre)."
            contenido.sound = .default
            
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: horaSiguiente
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            
            centro.add(UNNotificationRequest(
                identifier: prefijo + medicina.id.uuidString,
                content: contenido,
                trigger: trigger
            ))
        }
    }

    static func cancelar(id: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [prefijo + id.uuidString])
    }

    static func cancelarTodo() {
        let centro = UNUserNotificationCenter.current()
        centro.getPendingNotificationRequests { pendientes in
            let mias = pendientes.map(\.identifier).filter { $0.hasPrefix(prefijo) }
            centro.removePendingNotificationRequests(withIdentifiers: mias)
        }
    }
}