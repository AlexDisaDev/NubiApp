import Foundation
import UserNotifications

@MainActor
enum NotificadorVentanas {
    nonisolated static let prefijo = "nubi.ventana."
    nonisolated static let prefijoNoche = "nubi.noche."

    static func pedirPermiso() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func programarProximaVentana(bebe: Bebe, registros: [Registro], tieneAcceso: Bool) {
        let esCompartido = Sincronizador.compartido.esParticipante
        let nombreBebe = bebe.nombre
        let bebeCopia = bebe

        UNUserNotificationCenter.current().getPendingNotificationRequests { pendientes in
            let mias = pendientes.map(\.identifier).filter {
                $0.hasPrefix(prefijo) || $0.hasPrefix(prefijoNoche)
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: mias)

            guard tieneAcceso || esCompartido else { return }

            UNUserNotificationCenter.current().getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized ||
                      settings.authorizationStatus == .provisional else { return }

                let ahora = Date()
                let ventanas = MotorSueño.ventanasIdealesDelDia(
                    bebe: bebeCopia,
                    registros: registros,
                    dia: ahora,
                    ahora: ahora
                )

                for ventana in ventanas where !ventana.realizada && ventana.rangoInicioDesde > ahora {
                    let contenido = UNMutableNotificationContent()
                    contenido.sound = .default

                    let identificador: String
                    if ventana.esNocturna {
                        contenido.title = "🌙 Hora de dormir"
                        contenido.body = MensajesBonitos.generar(nombreBebe: nombreBebe)
                        identificador = prefijoNoche + ventana.id.uuidString
                    } else {
                        contenido.title = "Ventana de sueño"
                        contenido.body = "\(nombreBebe) podría dormirse entre \(Fmt.hora(ventana.rangoInicioDesde)) y \(Fmt.hora(ventana.rangoInicioHasta))."
                        identificador = prefijo + ventana.id.uuidString
                    }

                    let comps = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute],
                        from: ventana.rangoInicioDesde
                    )
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    UNUserNotificationCenter.current().add(UNNotificationRequest(
                        identifier: identificador,
                        content: contenido,
                        trigger: trigger
                    ))
                }
            }
        }
    }

    static func cancelarTodo() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { pendientes in
            let mias = pendientes.map(\.identifier).filter {
                $0.hasPrefix(prefijo) || $0.hasPrefix(prefijoNoche)
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: mias)
        }
    }
}