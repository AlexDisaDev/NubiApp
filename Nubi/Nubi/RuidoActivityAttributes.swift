import Foundation
import ActivityKit

/// Este archivo debe estar en los targets Nubi y NubiWidgetsExtension.
struct RuidoActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var tipoNombre: String     // "Ruido blanco" / "Ruido rosa" / "Ruido marrón"
        var inicio: Date           // para el contador en vivo
        var fechaFin: Date?        // hora a la que se detendrá; nil = infinito
    }
    var titulo: String
}