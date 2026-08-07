import Foundation
import SwiftUI

enum IdiomaNubi: String, CaseIterable, Identifiable {
    case sistema
    case espanol = "es"
    case ingles = "en"
    case italiano = "it"
    case frances = "fr"

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .sistema:  return "Automático"
        case .espanol:  return "Español"
        case .ingles:   return "English"
        case .italiano: return "Italiano"
        case .frances:  return "Français"
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .sistema:
            return nil

        case .espanol:
            return "es_ES"

        case .ingles:
            // Si prefieres inglés americano, cambia "en_GB" por "en_US".
            // "en_GB" suele ir bien para formato 24 h y estilo europeo.
            return "en_GB"

        case .italiano:
            return "it_IT"

        case .frances:
            return "fr_FR"
        }
    }

    var locale: Locale {
        if let id = localeIdentifier {
            return Locale(identifier: id)
        }

        return Locale.current
    }
}