import Foundation
import ActivityKit

struct SueñoActivityAttributes: ActivityAttributes {
    
    public struct ContentState: Codable, Hashable {
        var modo: Modo
        var inicio: Date
        
        // ← NUEVO: solo relevante cuando modo == .pecho
        var ladoPecho: LadoPechoLA?
        
        enum Modo: String, Codable, Hashable {
            case siesta
            case noche
            case despertar
            case pecho              // ← NUEVO
        }
        
        // ← NUEVO: enum simple para no depender de LadoPecho del app target.
        enum LadoPechoLA: String, Codable, Hashable {
            case izquierda
            case derecha
            
            var contrario: LadoPechoLA { self == .izquierda ? .derecha : .izquierda }
            var etiqueta: String { self == .izquierda ? "izquierdo" : "derecho" }
        }
    }
    
    let nombreBebe: String
}