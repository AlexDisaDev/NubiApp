import Foundation

enum L10n {
    // MARK: - Idioma (thread-safe SIN @MainActor)
    // El candado evita avisos de "data race" sin impedir que se llame
    // a L10n desde cualquier sitio (vistas, modelos, notificaciones…).
    private static let lock = NSLock()
    private static var _idioma: IdiomaNubi = .espanol

    static var idioma: IdiomaNubi {
        get { lock.lock(); defer { lock.unlock() }; return _idioma }
        set { lock.lock(); defer { lock.unlock() }; _idioma = newValue }
    }

    /// Idioma efectivo. Si el usuario eligió "Automático",
    /// usamos el idioma del dispositivo.
    static var idiomaEfectivo: IdiomaNubi {
        if idioma != .sistema { return idioma }
        let id = Locale.current.identifier.lowercased()
        if id.hasPrefix("en") { return .ingles }
        if id.hasPrefix("it") { return .italiano }
        if id.hasPrefix("fr") { return .frances }
        return .espanol
    }

    /// Función principal para traducir.
    /// Si no hay traducción, devuelve el texto original en español.
    static func t(_ textoEspanol: String) -> String {
        guard let trad = tabla[textoEspanol] else { return textoEspanol }
        switch idiomaEfectivo {
        case .espanol, .sistema: return textoEspanol
        case .ingles:   return trad["en"] ?? textoEspanol
        case .italiano: return trad["it"] ?? textoEspanol
        case .frances:  return trad["fr"] ?? textoEspanol
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

    static func enDias(_ n: Int) -> String {
        switch idiomaEfectivo {
        case .ingles:   return n == 1 ? "in \(n) day" : "in \(n) days"
        case .italiano: return n == 1 ? "tra \(n) giorno" : "tra \(n) giorni"
        case .frances:  return n == 1 ? "dans \(n) jour" : "dans \(n) jours"
        default:        return n == 1 ? "en \(n) día" : "en \(n) días"
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
        case .frances:  return "À cet âge, un bébé suele dormir entre \(a) et \(b) h par jour."
        default:        return "A su edad se suele dormir entre \(a) y \(b) h al día."
        }
    }
    
    // MARK: - Tabla de traducciones
    
    private static let tabla: [String: [String: String]] = [
        "Hoy": ["en": "Today", "it": "Oggi", "fr": "Aujourd'hui"],
        "Día": ["en": "Day", "it": "Giorno", "fr": "Jour"],
        "Crece": ["en": "Growth", "it": "Crescita", "fr": "Croissance"],
        "Salud": ["en": "Health", "it": "Salute", "fr": "Santé"],
        "Diario": ["en": "Diary", "it": "Diario", "fr": "Journal"],
        "Ajustes": ["en": "Settings", "it": "Impostazioni", "fr": "Réglages"],
        "Empezar": ["en": "Start", "it": "Inizia", "fr": "Commencer"],
        "Guardar": ["en": "Save", "it": "Salva", "fr": "Enregistrer"],
        "Cancelar": ["en": "Cancel", "it": "Annulla", "fr": "Annuler"],
        "Listo": ["en": "Done", "it": "Fatto", "fr": "OK"],
        "Restaurar compras": ["en": "Restore purchases", "it": "Ripristina acquisti", "fr": "Restaurer les achats"],
        "Buenos días": ["en": "Good morning", "it": "Buongiorno", "fr": "Bonjour"],
        "Buenas tardes": ["en": "Good afternoon", "it": "Buon pomeriggio", "fr": "Bon après-midi"],
        "Buenas noches": ["en": "Good evening", "it": "Buonanotte", "fr": "Bonsoir"],
        "Sueño": ["en": "Sleep", "it": "Sonno", "fr": "Sommeil"],
        "Toma": ["en": "Feeding", "it": "Pappa", "fr": "Tétée"],
        "Pañal": ["en": "Diaper", "it": "Pannolino", "fr": "Couche"],
        "Siesta": ["en": "Nap", "it": "Pisolino", "fr": "Sieste"],
        "Noche": ["en": "Night", "it": "Notte", "fr": "Nuit"],
        "ha despertado": ["en": "Woke up", "it": "Si è svegliato", "fr": "Réveillé"],
        "Sin registrar": ["en": "No records", "it": "Nessun dato", "fr": "Aucun enregistrement"],
        "Toca para anotar la primera": ["en": "Tap to log the first one", "it": "Tocca per registrare la prima", "fr": "Touchez pour enregistrer la première"],
        "Toca para anotar el primero": ["en": "Tap to log the first one", "it": "Tocca per registrare il primo", "fr": "Touchez pour enregistrer le premier"],
        "Último a las": ["en": "Last at", "it": "Ultimo alle", "fr": "Dernier à"],
        "Nubi completo": ["en": "Nubi Premium", "it": "Nubi Premium", "fr": "Nubi Premium"],
        "Ver Nubi completo": ["en": "See Nubi Premium", "it": "Vedi Nubi Premium", "fr": "Voir Nubi Premium"],
        "Suscribirme": ["en": "Subscribe", "it": "Abbonati", "fr": "S'abonner"],
        "Empezar prueba gratis": ["en": "Start free trial", "it": "Inizia prova gratuita", "fr": "Essai gratuit"],
        "Últimas 24 horas": ["en": "Last 24 hours", "it": "Ultime 24 ore", "fr": "Dernières 24 heures"],
        "dentro de lo habitual": ["en": "within the usual range", "it": "nella norma", "fr": "dans la norme"],
        "fuera del rango típico": ["en": "outside the typical range", "it": "fuori dal range tipico", "fr": "hors de la fourchette typique"],
        "Despierto desde": ["en": "Awake since", "it": "Sveglio dalle", "fr": "Réveillé depuis"],
        "Dormido desde": ["en": "Asleep since", "it": "Addormentato dalle", "fr": "Endormi depuis"],
        "Aún no hay ningún sueño registrado. Empieza por el primero.": ["en": "No sleep logged yet. Start with the first one.", "it": "Nessun sonno registrato. Inizia dal primo.", "fr": "Aucun sommeil enregistré. Commencez par le premier."],
        "Pecho": ["en": "Breast", "it": "Seno", "fr": "Sein"],
        "Pecho derecho": ["en": "Right breast", "it": "Seno destro", "fr": "Sein droit"],
        "Pecho izquierdo": ["en": "Left breast", "it": "Seno sinistro", "fr": "Sein gauche"],
        "Banco": ["en": "Milk bank", "it": "Banco latte", "fr": "Banque de lait"],
        "Alimentación": ["en": "Feeding", "it": "Alimentazione", "fr": "Alimentation"],
        "Sonidos": ["en": "Sounds", "it": "Suoni", "fr": "Sons"],
        "Última toma": ["en": "Last feeding", "it": "Ultima pappa", "fr": "Dernière tétée"],
        "Sueño nocturno": ["en": "Night sleep", "it": "Sonno notturno", "fr": "Sommeil nocturne"],
        "Despertar": ["en": "Waking", "it": "Risveglio", "fr": "Réveil"],
        "Der": ["en": "Right", "it": "Des", "fr": "Dro"],
        "Izq": ["en": "Left", "it": "Sin", "fr": "Gau"],
        "mes": ["en": "month", "it": "mese", "fr": "mois"],
        "meses": ["en": "months", "it": "mesi", "fr": "mois"],
        "día": ["en": "day", "it": "giorno", "fr": "jour"],
        "días": ["en": "days", "it": "giorni", "fr": "jours"],
        "semana": ["en": "week", "it": "settimana", "fr": "semaine"],
        "y": ["en": "and", "it": "e", "fr": "et"],
        "hoy a las": ["en": "today at", "it": "oggi alle", "fr": "aujourd'hui à"],
        "mañana a las": ["en": "tomorrow at", "it": "domani alle", "fr": "demain à"],
        "ayer": ["en": "yesterday", "it": "ieri", "fr": "hier"],
        "Despertar nocturno": ["en": "Night waking", "it": "Risveglio notturno", "fr": "Réveil nocturne"],
        "Volvió a dormir": ["en": "Back to sleep", "it": "Riaddormentato", "fr": "Rendormi"],
        "Fin de la noche": ["en": "End of night", "it": "Fine della notte", "fr": "Fin de la nuit"],
        "Fin del despertar": ["en": "End of waking", "it": "Fine del risveglio", "fr": "Fin du réveil"],
        "en curso": ["en": "in progress", "it": "in corso", "fr": "en cours"],
        "desde": ["en": "since", "it": "dalle", "fr": "depuis"],
        "Terminar toma": ["en": "End feeding", "it": "Termina la pappa", "fr": "Terminer la tétée"],
        "Cambiar de pecho": ["en": "Switch breast", "it": "Cambia seno", "fr": "Changer de sein"],
        "Sin registrar todavía": ["en": "Nothing logged yet", "it": "Ancora niente", "fr": "Rien pour l'instant"],
        "Biberón": ["en": "Bottle", "it": "Biberon", "fr": "Biberon"],
        "¿Qué hizo?": ["en": "What was it?", "it": "Cosa ha fatto?", "fr": "Qu'a-t-il fait ?"],
        "Pis": ["en": "Pee", "it": "Pipì", "fr": "Pipi"],
        "Caca": ["en": "Poop", "it": "Cacca", "fr": "Caca"],
        "¿Cuánto ha bebido?": ["en": "How much did your baby drink?", "it": "Quanto ha bevuto?", "fr": "Combien a-t-il bu ?"],
        "Rápido": ["en": "Quick picks", "it": "Scelte rapide", "fr": "Choix rapides"],
        "Guardar sin cantidad": ["en": "Save without amount", "it": "Salva senza quantità", "fr": "Enregistrer sans quantité"],
        "Ahora": ["en": "Now", "it": "Adesso", "fr": "Maintenant"],
        "¿A qué hora se ha despertado?": ["en": "What time did your baby wake up?", "it": "A che ora si è svegliato?", "fr": "À quelle heure s'est-il réveillé ?"],
        "Hora de despertar": ["en": "Wake-up time", "it": "Ora del risveglio", "fr": "Heure du réveil"],
        "Empezó a las": ["en": "Started at", "it": "Iniziato alle", "fr": "Commencé à"],
        "Duración total": ["en": "Total duration", "it": "Durata totale", "fr": "Durée totale"],
        "La hora debe estar entre el inicio y ahora": ["en": "The time must be between the start and now", "it": "L'ora deve essere tra l'inizio e adesso", "fr": "L'heure doit être entre le début et maintenant"],
        "Buena ventana ahora": ["en": "Good window now", "it": "Finestra giusta adesso", "fr": "Bonne fenêtre maintenant"],
        "hasta": ["en": "until", "it": "fino alle", "fr": "jusqu'à"],
        "Se ha pasado la ventana ideal": ["en": "The ideal window has passed", "it": "La finestra ideale è passata", "fr": "La fenêtre idéale est passée"],
        "Próxima siesta": ["en": "Next nap", "it": "Prossimo pisolino", "fr": "Prochaine sieste"],
        "Es hora de dormir 🌙": ["en": "Time to sleep 🌙", "it": "È ora di dormire 🌙", "fr": "C'est l'heure de dormir 🌙"],
        "Ajustado a su ritmo real": ["en": "Tuned to your baby's real rhythm", "it": "Adattato al ritmo reale del tuo bambino", "fr": "Ajusté à son rythme réel"],
        "Basado en su edad": ["en": "Based on age", "it": "In base all'età", "fr": "Selon son âge"],
        "Última ventana del día": ["en": "Last window of the day", "it": "Ultima finestra della giornata", "fr": "Dernière fenêtre de la journée"],
        "· última siesta hecha": ["en": "· last nap done", "it": "· ultimo pisolino fatto", "fr": "· dernière sieste faite"],
        "En": ["en": "In", "it": "Tra", "fr": "Dans"],
        "Predicción de ventanas": ["en": "Nap predictions", "it": "Previsioni delle finestre", "fr": "Prédiction des fenêtres"],
        "Nubi calcula cuándo le tocará la próxima siesta según el ritmo real de tu bebé. Con Nubi completo lo ves aquí y en el reloj del día.": ["en": "Nubi works out when the next nap is due based on your baby's real rhythm. With Nubi Premium you see it here and on the day clock.", "it": "Nubi calcola quando toccherà il prossimo pisolino in base al ritmo reale del tuo bambino. Con Nubi Premium lo vedi qui e sull'orologio del giorno.", "fr": "Nubi calcule l'heure de la prochaine sieste selon le rythme réel de votre bébé. Avec Nubi Premium, vous la voyez ici et sur l'horloge du jour."],
        "¿A qué hora despertó hoy?": [
            "en": "What time did your baby wake up today?",
            "it": "A che ora si è svegliato oggi?",
            "fr": "À quelle heure s'est-il réveillé aujourd'hui ?"
        ],
        "semanas": ["en": "weeks", "it": "settimane", "fr": "semaines"],
        "El sueño de tu bebé, sin adivinar.": [
            "en": "Your baby's sleep, without guessing.",
            "it": "Il sonno del tuo bimbo, senza indovinare.",
            "fr": "Le sommeil de votre bébé, sans deviner."
        ],
        "Si nació antes de tiempo, Nubi usa la edad corregida para calcular sus ventanas.": [
            "en": "If born early, Nubi uses corrected age to work out windows.",
            "it": "Se è nato prematuro, Nubi usa l'età corretta per calcolare le finestre.",
            "fr": "S'il est né prématurément, Nubi utilise l'âge corrigé pour calculer les fenêtres."
        ],
        "Nubi aprende de tu bebé": [
            "en": "Nubi learns from your baby",
            "it": "Nubi impara dal tuo bimbo",
            "fr": "Nubi apprend de votre bébé"
        ],
        "Las primeras predicciones se basan en su edad. Durante los primeros 7 días, Nubi observa el ritmo real de tu bebé y ajusta las ventanas de sueño para que cada vez acierten más.": [
            "en": "The first predictions are based on age. During the first 7 days, Nubi watches your baby's real rhythm and fine-tunes the sleep windows to get more and more accurate.",
            "it": "Le prime previsioni si basano sull'età. Nei primi 7 giorni, Nubi osserva il ritmo reale del tuo bimbo e affina le finestre di sonno per essere sempre più preciso.",
            "fr": "Les premières prédictions se basent sur l'âge. Pendant les 7 premiers jours, Nubi observe le rythme réel de votre bébé et affine les fenêtres de sommeil pour être de plus en plus précis."
        ],
        "Empezar a cuidar su sueño": [
            "en": "Start caring for their sleep",
            "it": "Inizia a curare il suo sonno",
            "fr": "Commencer à prendre soin de son sommeil"
        ],
        "Tu bebé": ["en": "your baby", "it": "il tuo bimbo", "fr": "votre bébé"],
        "Mi bebé": ["en": "My baby", "it": "Il mio bimbo", "fr": "Mon bébé"],
        "Idioma": ["en": "Language", "it": "Lingua", "fr": "Langue"],
        "Elige tu idioma": ["en": "Choose your language", "it": "Scegli la tua lingua", "fr": "Choisissez votre langue"]
    ]
}