import Foundation

enum L10n {

    /// Idioma seleccionado por el usuario.
    /// Se actualiza desde NubiApp / RaizVista.
    static var idioma: IdiomaNubi = .espanol

    /// Idioma efectivo. Si el usuario eligió "Automático",
    /// usamos el idioma del dispositivo.
    static var idiomaEfectivo: IdiomaNubi {
        if idioma != .sistema {
            return idioma
        }

        let id = Locale.current.identifier.lowercased()

        if id.hasPrefix("en") {
            return .ingles
        }

        if id.hasPrefix("it") {
            return .italiano
        }

        if id.hasPrefix("fr") {
            return .frances
        }

        return .espanol
    }

    /// Función principal para traducir.
    /// Si no hay traducción, devuelve el texto original en español.
    static func t(_ textoEspanol: String) -> String {
        guard let trad = tabla[textoEspanol] else {
            return textoEspanol
        }

        switch idiomaEfectivo {
        case .espanol, .sistema:
            return textoEspanol

        case .ingles:
            return trad["en"] ?? textoEspanol

        case .italiano:
            return trad["it"] ?? textoEspanol

        case .frances:
            return trad["fr"] ?? textoEspanol
        }
    }

     static var ahoraMismo: String {
        switch idiomaEfectivo {
        case .ingles:   return "just now"
        case .italiano: return "adesso"
        case .frances:  return "à l'instant"
        default:        return "ahora mismo"
        }
    }

    static func haceMin(_ m: Int) -> String {
        switch idiomaEfectivo {
        case .ingles:   return "\(m) min ago"
        case .italiano: return "\(m) min fa"
        case .frances:  return "il y a \(m) min"
        default:        return "hace \(m) min"
        }
    }

    static func haceHoras(_ h: Int, _ m: Int) -> String {
        switch idiomaEfectivo {
        case .ingles:   return m == 0 ? "\(h) h ago" : "\(h) h \(m) min ago"
        case .italiano: return m == 0 ? "\(h) h fa" : "\(h) h \(m) min fa"
        case .frances:  return m == 0 ? "il y a \(h) h" : "il y a \(h) h \(m) min"
        default:        return m == 0 ? "hace \(h) h" : "hace \(h) h \(m) min"
        }
    }

    static func edadBebe(dias: Int, meses: Int) -> String {
        switch idiomaEfectivo {
        case .ingles:
            if meses < 1 {
                let w = dias / 7
                return w <= 1 ? "\(dias) days" : "\(w) weeks"
            }
            if meses < 24 { return "\(meses) \(meses == 1 ? "month" : "months")" }
            let y = meses / 12, r = meses % 12
            return r == 0
                ? "\(y) \(y == 1 ? "year" : "years")"
                : "\(y) \(y == 1 ? "year" : "years") \(r) \(r == 1 ? "month" : "months")"

        case .italiano:
            if meses < 1 {
                let w = dias / 7
                return w <= 1 ? "\(dias) giorni" : "\(w) settimane"
            }
            if meses < 24 { return "\(meses) \(meses == 1 ? "mese" : "mesi")" }
            let y = meses / 12, r = meses % 12
            return r == 0
                ? "\(y) \(y == 1 ? "anno" : "anni")"
                : "\(y) \(y == 1 ? "anno" : "anni") e \(r) \(r == 1 ? "mese" : "mesi")"

        case .frances:
            if meses < 1 {
                let w = dias / 7
                return w <= 1 ? "\(dias) jours" : "\(w) semaines"
            }
            if meses < 24 { return "\(meses) mois" }
            let y = meses / 12, r = meses % 12
            return r == 0
                ? "\(y) \(y == 1 ? "an" : "ans")"
                : "\(y) \(y == 1 ? "an" : "ans") et \(r) mois"

        default:
            if meses < 1 {
                let w = dias / 7
                return w <= 1 ? "\(dias) días" : "\(w) semanas"
            }
            if meses < 24 { return "\(meses) meses" }
            let y = meses / 12, r = meses % 12
            return r == 0 ? "\(y) años" : "\(y) años y \(r) meses"
        }
    }

    static func sueleDormir(_ a: String, _ b: String) -> String {
        switch idiomaEfectivo {
        case .ingles:   return "At this age babies usually sleep between \(a) and \(b) h a day."
        case .italiano: return "A questa età di solito dorme tra \(a) e \(b) h al giorno."
        case .frances:  return "À cet âge, un bebé suele dormir entre \(a) et \(b) h par jour."
        default:        return "A su edad se suele dormir entre \(a) y \(b) h al día."
        }
    }


    // MARK: - Primera tanda de traducciones

    private static let tabla: [String: [String: String]] = [

        // Pestañas
        "Hoy": [
            "en": "Today",
            "it": "Oggi",
            "fr": "Aujourd'hui"
        ],

        "Día": [
            "en": "Day",
            "it": "Giorno",
            "fr": "Jour"
        ],

        "Crece": [
            "en": "Growth",
            "it": "Crescita",
            "fr": "Croissance"
        ],

        "Salud": [
            "en": "Health",
            "it": "Salute",
            "fr": "Santé"
        ],

        "Diario": [
            "en": "Diary",
            "it": "Diario",
            "fr": "Journal"
        ],

        // Comunes
        "Ajustes": [
            "en": "Settings",
            "it": "Impostazioni",
            "fr": "Réglages"
        ],

        "Empezar": [
            "en": "Start",
            "it": "Inizia",
            "fr": "Commencer"
        ],

        "Guardar": [
            "en": "Save",
            "it": "Salva",
            "fr": "Enregistrer"
        ],

        "Cancelar": [
            "en": "Cancel",
            "it": "Annulla",
            "fr": "Annuler"
        ],

        "Listo": [
            "en": "Done",
            "it": "Fatto",
            "fr": "OK"
        ],

        "Restaurar compras": [
            "en": "Restore purchases",
            "it": "Ripristina acquisti",
            "fr": "Restaurer les achats"
        ],

        // Saludos
        "Buenos días": [
            "en": "Good morning",
            "it": "Buongiorno",
            "fr": "Bonjour"
        ],

        "Buenas tardes": [
            "en": "Good afternoon",
            "it": "Buon pomeriggio",
            "fr": "Bon après-midi"
        ],

        "Buenas noches": [
            "en": "Good evening",
            "it": "Buonanotte",
            "fr": "Bonsoir"
        ],

        // Inicio
        "Sueño": [
            "en": "Sleep",
            "it": "Sonno",
            "fr": "Sommeil"
        ],

        "Toma": [
            "en": "Feeding",
            "it": "Pappa",
            "fr": "Tétée"
        ],

        "Pañal": [
            "en": "Diaper",
            "it": "Pannolino",
            "fr": "Couche"
        ],

        "Siesta": [
            "en": "Nap",
            "it": "Pisolino",
            "fr": "Sieste"
        ],

        "Noche": [
            "en": "Night",
            "it": "Notte",
            "fr": "Nuit"
        ],

        "Se ha despertado": [
            "en": "Woke up",
            "it": "Si è svegliato",
            "fr": "Réveillé"
        ],

        "Sin registrar": [
            "en": "No records",
            "it": "Nessun dato",
            "fr": "Aucun enregistrement"
        ],

        "Toca para anotar la primera": [
            "en": "Tap to log the first one",
            "it": "Tocca per registrare la prima",
            "fr": "Touchez pour enregistrer la première"
        ],

        "Toca para anotar el primero": [
            "en": "Tap to log the first one",
            "it": "Tocca per registrare il primo",
            "fr": "Touchez pour enregistrer le premier"
        ],

        "Último a las": [
            "en": "Last at",
            "it": "Ultimo alle",
            "fr": "Dernier à"
        ],

        // Premium
        "Nubi completo": [
            "en": "Nubi Premium",
            "it": "Nubi Premium",
            "fr": "Nubi Premium"
        ],

        "Ver Nubi completo": [
            "en": "See Nubi Premium",
            "it": "Vedi Nubi Premium",
            "fr": "Voir Nubi Premium"
        ],

        "Suscribirme": [
            "en": "Subscribe",
            "it": "Abbonati",
            "fr": "S'abonner"
        ],

        "Empezar prueba gratis": [
            "en": "Start free trial",
            "it": "Inizia prova gratuita",
            "fr": "Essai gratuit"
        ],
        "Últimas 24 horas": [
            "en": "Last 24 hours",
            "it": "Ultime 24 ore",
            "fr": "Dernières 24 heures"
        ],

        "dentro de lo habitual": [
            "en": "within the usual range",
            "it": "nella norma",
            "fr": "dans la norme"
        ],

        "fuera del rango típico": [
            "en": "outside the typical range",
            "it": "fuori dal range tipico",
            "fr": "hors de la fourchette typique"
        ],

        "Despierto desde": [
            "en": "Awake since",
            "it": "Sveglio dalle",
            "fr": "Réveillé depuis"
        ],

        "Dormido desde": [
            "en": "Asleep since",
            "it": "Addormentato dalle",
            "fr": "Endormi depuis"
        ],

        "Aún no hay ningún sueño registrado. Empieza por el primero.": [
            "en": "No sleep logged yet. Start with the first one.",
            "it": "Nessun sonno registrato. Inizia dal primo.",
            "fr": "Aucun sommeil enregistré. Commencez par le premier."
        ],
        "Pecho": [
            "en": "Breast",
            "it": "Seno",
            "fr": "Sein"
        ],

        "Pecho derecho": [
            "en": "Right breast",
            "it": "Seno destro",
            "fr": "Sein droit"
        ],

        "Pecho izquierdo": [
            "en": "Left breast",
            "it": "Seno sinistro",
            "fr": "Sein gauche"
        ],
    ]
}
