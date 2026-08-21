import AppIntents
import Foundation

// MARK: - Enum para tipos de ruido
enum TipoRuidoSiri: String, AppEnum {
    case blanco
    case rosa
    case marron
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Tipo de ruido"
    }
    
    static var caseDisplayRepresentations: [TipoRuidoSiri: DisplayRepresentation] {
        [
            .blanco: "Blanco",
            .rosa: "Rosa",
            .marron: "Marrón"
        ]
    }
}

// MARK: - Enum para tipo de leche
enum TipoLecheSiri: String, AppEnum {
    case materna
    case formula
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Tipo de leche"
    }
    
    static var caseDisplayRepresentations: [TipoLecheSiri: DisplayRepresentation] {
        [
            .materna: "Materna",
            .formula: "Fórmula"
        ]
    }
}

// MARK: - Enum para lado del pecho
enum LadoPechoSiri: String, AppEnum {
    case izquierdo
    case derecho
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Lado"
    }
    
    static var caseDisplayRepresentations: [LadoPechoSiri: DisplayRepresentation] {
        [
            .izquierdo: "Izquierdo",
            .derecho: "Derecho"
        ]
    }
}

// MARK: - Enum para contenido del pañal
enum ContenidoPanalSiri: String, AppEnum {
    case pis
    case caca
    case ambos
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Contenido"
    }
    
    static var caseDisplayRepresentations: [ContenidoPanalSiri: DisplayRepresentation] {
        [
            .pis: "Pis",
            .caca: "Caca",
            .ambos: "Pis y caca"
        ]
    }
}

// MARK: - 1. Empezar sueño nocturno
struct EmpezarNocheIntent: AppIntent {
    static var title: LocalizedStringResource = "Empezar noche"
    static var description = IntentDescription("Inicia el sueño nocturno")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            AlmacenCompartido.empezarSueñoNoche?()
        }
        return .result(dialog: "Sueño nocturno iniciado.")
    }
}

// MARK: - 2. Terminar sueño nocturno
struct TerminarNocheIntent: AppIntent {
    static var title: LocalizedStringResource = "Terminar noche"
    static var description = IntentDescription("Termina el sueño nocturno")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            AlmacenCompartido.terminarSueño?()
        }
        return .result(dialog: "Buenos días.")
    }
}

// MARK: - 3. Empezar siesta
struct EmpezarSiestaIntent: AppIntent {
    static var title: LocalizedStringResource = "Empezar siesta"
    static var description = IntentDescription("Inicia una siesta")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            AlmacenCompartido.empezarSiesta?()
        }
        return .result(dialog: "Siesta iniciada.")
    }
}

// MARK: - 4. Terminar siesta
struct TerminarSiestaIntent: AppIntent {
    static var title: LocalizedStringResource = "Terminar siesta"
    static var description = IntentDescription("Termina la siesta")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            AlmacenCompartido.terminarSueño?()
        }
        return .result(dialog: "Siesta terminada.")
    }
}

// MARK: - Enum para unidad del biberón
enum UnidadBiberonSiri: String, AppEnum {
    case ml
    case oz
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Unidad"
    }
    
    static var caseDisplayRepresentations: [UnidadBiberonSiri: DisplayRepresentation] {
        [
            .ml: DisplayRepresentation(title: "Mililitros", subtitle: "ml"),
            .oz: DisplayRepresentation(title: "Onzas", subtitle: "oz")
        ]
    }
}

// MARK: - 5. Registrar biberón
struct RegistrarBiberonIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar biberón"
    static var description = IntentDescription("Registra un biberón")
    
    @Parameter(title: "Tipo de leche", default: .materna)
    var tipo: TipoLecheSiri
    
    @Parameter(title: "Cantidad")
    var cantidad: Double
    
    @Parameter(title: "Unidad")
    var unidad: UnidadBiberonSiri
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let unidadTexto = unidad.rawValue
        
        await MainActor.run {
            AlmacenCompartido.registrarBiberon?(tipo.rawValue, cantidad, unidadTexto)
        }
        
        return .result(dialog: "Biberón de \(Int(cantidad)) \(unidadTexto) registrado.")
    }
}

// MARK: - 6. Empezar pecho
struct EmpezarPechoIntent: AppIntent {
    static var title: LocalizedStringResource = "Empezar pecho"
    static var description = IntentDescription("Inicia toma de pecho")
    
    @Parameter(title: "Lado", default: .izquierdo)
    var lado: LadoPechoSiri
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ladoRaw = (lado == .izquierdo) ? "izquierda" : "derecha"
        
        await MainActor.run {
            AlmacenCompartido.empezarPecho?(ladoRaw)
        }
        
        return .result(dialog: "Pecho \(ladoRaw) iniciado.")
    }
}

// MARK: - 7. Cambiar de pecho
struct CambiarPechoIntent: AppIntent {
    static var title: LocalizedStringResource = "Cambiar pecho"
    static var description = IntentDescription("Cambia al otro pecho")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            AlmacenCompartido.cambiarPecho?()
        }
        return .result(dialog: "Cambiado de pecho.")
    }
}

// MARK: - 8. Terminar pecho
struct TerminarPechoIntent: AppIntent {
    static var title: LocalizedStringResource = "Terminar pecho"
    static var description = IntentDescription("Termina la toma de pecho")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            AlmacenCompartido.terminarPecho?()
        }
        return .result(dialog: "Toma terminada.")
    }
}

// MARK: - 9. Registrar pañal
struct RegistrarPanalIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar pañal"
    static var description = IntentDescription("Registra un cambio de pañal")
    
    @Parameter(title: "Contenido", default: .ambos)
    var contenido: ContenidoPanalSiri
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let pis: Bool
        let caca: Bool
        
        switch contenido {
        case .pis:
            pis = true
            caca = false
        case .caca:
            pis = false
            caca = true
        case .ambos:
            pis = true
            caca = true
        }
        
        await MainActor.run {
            AlmacenCompartido.registrarPanal?(pis, caca)
        }
        
        let descripcion: String
        switch contenido {
        case .pis: descripcion = "pis"
        case .caca: descripcion = "caca"
        case .ambos: descripcion = "pis y caca"
        }
        
        return .result(dialog: "Pañal con \(descripcion) registrado.")
    }
}

// MARK: - 10. Despertar nocturno
struct RegistrarDespertarIntent: AppIntent {
    static var title: LocalizedStringResource = "Despertar nocturno"
    static var description = IntentDescription("Registra un despertar nocturno")
    
    @Parameter(title: "Minutos", default: 15)
    var minutos: Int
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            AlmacenCompartido.registrarDespertar?(minutos)
        }
        return .result(dialog: "Despertar de \(minutos) minutos registrado.")
    }
}

// MARK: - 11. Iniciar ruido
struct IniciarRuidoIntent: AppIntent {
    static var title: LocalizedStringResource = "Iniciar ruido"
    static var description = IntentDescription("Reproduce ruido para dormir")
    
    @Parameter(title: "Tipo", default: .blanco)
    var tipo: TipoRuidoSiri
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            AlmacenCompartido.iniciarRuido?(tipo.rawValue)
        }
        
        let tipoTexto: String
        switch tipo {
        case .blanco: tipoTexto = "blanco"
        case .rosa: tipoTexto = "rosa"
        case .marron: tipoTexto = "marrón"
        }
        
        return .result(dialog: "Reproduciendo ruido \(tipoTexto).")
    }
}

// MARK: - 12. Parar ruido
struct PararRuidoIntent: AppIntent {
    static var title: LocalizedStringResource = "Parar ruido"
    static var description = IntentDescription("Detiene el ruido")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            AlmacenCompartido.pararRuido?()
        }
        return .result(dialog: "Ruido detenido.")
    }
}

// MARK: - Provider de atajos con frases en múltiples idiomas
// Máx. 10 atajos. Ruido queda fuera de Siri (los intents siguen vivos para widget).
struct NubiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // 1. Empezar noche
        AppShortcut(
            intent: EmpezarNocheIntent(),
            phrases: [
                "Empieza la noche en \(.applicationName)",
                "Empieza el sueño nocturno en \(.applicationName)",
                "Start night sleep in \(.applicationName)",
                "Start bedtime in \(.applicationName)",
                "Commence la nuit dans \(.applicationName)",
                "Inizia la notte in \(.applicationName)"
            ],
            shortTitle: "Empezar noche",
            systemImageName: "moon.zzz.fill"
        )
        
        // 2. Terminar noche
        AppShortcut(
            intent: TerminarNocheIntent(),
            phrases: [
                "Buenos días en \(.applicationName)",
                "Termina la noche en \(.applicationName)",
                "Good morning in \(.applicationName)",
                "End night sleep in \(.applicationName)",
                "Bonjour dans \(.applicationName)",
                "Fin de la nuit dans \(.applicationName)",
                "Buongiorno in \(.applicationName)",
                "Fine della notte in \(.applicationName)"
            ],
            shortTitle: "Buenos días",
            systemImageName: "sun.max.fill"
        )
        
        // 3. Empezar siesta
        AppShortcut(
            intent: EmpezarSiestaIntent(),
            phrases: [
                "Empieza la siesta en \(.applicationName)",
                "Start nap in \(.applicationName)",
                "Commence la sieste dans \(.applicationName)",
                "Inizia il pisolino in \(.applicationName)"
            ],
            shortTitle: "Empezar siesta",
            systemImageName: "moon.fill"
        )
        
        // 4. Terminar siesta
        AppShortcut(
            intent: TerminarSiestaIntent(),
            phrases: [
                "Termina la siesta en \(.applicationName)",
                "End nap in \(.applicationName)",
                "Fin de la sieste dans \(.applicationName)",
                "Fine del pisolino in \(.applicationName)"
            ],
            shortTitle: "Terminar siesta",
            systemImageName: "sun.max.fill"
        )
        
        // 5. Registrar biberón
        AppShortcut(
            intent: RegistrarBiberonIntent(),
            phrases: [
                "Registra biberón de \(\.$tipo) en \(.applicationName)",
                "Log \(\.$tipo) bottle in \(.applicationName)",
                "Enregistre biberon de \(\.$tipo) dans \(.applicationName)",
                "Registra biberon di \(\.$tipo) in \(.applicationName)"
            ],
            shortTitle: "Registrar biberón",
            systemImageName: "drop.fill"
        )
        
        // 6. Empezar pecho
        AppShortcut(
            intent: EmpezarPechoIntent(),
            phrases: [
                "Empieza pecho \(\.$lado) en \(.applicationName)",
                "Start \(\.$lado) breast in \(.applicationName)",
                "Commence sein \(\.$lado) dans \(.applicationName)",
                "Inizia seno \(\.$lado) in \(.applicationName)"
            ],
            shortTitle: "Empezar pecho",
            systemImageName: "heart.fill"
        )
        
        // 7. Cambiar pecho
        AppShortcut(
            intent: CambiarPechoIntent(),
            phrases: [
                "Cambia de pecho en \(.applicationName)",
                "Switch breast in \(.applicationName)",
                "Change de sein dans \(.applicationName)",
                "Cambia seno in \(.applicationName)"
            ],
            shortTitle: "Cambiar pecho",
            systemImageName: "arrow.left.arrow.right"
        )
        
        // 8. Terminar pecho
        AppShortcut(
            intent: TerminarPechoIntent(),
            phrases: [
                "Termina el pecho en \(.applicationName)",
                "End breastfeeding in \(.applicationName)",
                "Fin de l'allaitement dans \(.applicationName)",
                "Fine allattamento in \(.applicationName)"
            ],
            shortTitle: "Terminar pecho",
            systemImageName: "stop.fill"
        )
        
        // 9. Registrar pañal
        AppShortcut(
            intent: RegistrarPanalIntent(),
            phrases: [
                "Registra pañal con \(\.$contenido) en \(.applicationName)",
                "Log diaper with \(\.$contenido) in \(.applicationName)",
                "Enregistre couche avec \(\.$contenido) dans \(.applicationName)",
                "Registra pannolino con \(\.$contenido) in \(.applicationName)"
            ],
            shortTitle: "Registrar pañal",
            systemImageName: "leaf.fill"
        )
        
        // 10. Registrar despertar
        AppShortcut(
            intent: RegistrarDespertarIntent(),
            phrases: [
                "Registra despertar nocturno en \(.applicationName)",
                "Log night waking in \(.applicationName)",
                "Enregistre réveil nocturne dans \(.applicationName)",
                "Registra risveglio notturno in \(.applicationName)"
            ],
            shortTitle: "Despertar nocturno",
            systemImageName: "eye.fill"
        )
    }
}