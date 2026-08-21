import AppIntents

// MARK: - Acciones que ejecutan los botones de la Live Activity
// Cada intent llama a un closure registrado por la app principal.
// Así el widget nunca depende del Almacen directamente.
// NOTA: Los nombres llevan "Live" al final para no colisionar con los intents de Siri.

struct RegistrarDespertarLiveIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Registrar despertar"
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AlmacenCompartido.empezarDespertar?()
        }
        return .result()
    }
}

struct VolverADormirLiveIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Volvió a dormir"
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AlmacenCompartido.volverADormir?()
        }
        return .result()
    }
}

struct FinDeLaNocheLiveIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Fin de la noche"
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            // Cierra el despertar en curso si lo hay; si no, cierra la noche.
            if AlmacenCompartido.hayDespertarEnCurso?() == true {
                AlmacenCompartido.terminarDespertar?()
            } else if AlmacenCompartido.haySueñoEnCurso?() == true {
                AlmacenCompartido.terminarSueño?()
            }
        }
        return .result()
    }
}

struct TerminarSiestaLiveIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "ha despertado"
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AlmacenCompartido.terminarSueño?()
        }
        return .result()
    }
}

// ← Cambio de pecho desde la Live Activity
struct CambiarPechoLiveIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Cambiar de pecho"
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AlmacenCompartido.cambiarPecho?()
        }
        return .result()
    }
}

// ← Terminar toma
struct TerminarPechoLiveIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Terminar toma"
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AlmacenCompartido.terminarPecho?()
        }
        return .result()
    }
}

struct PararRuidoLiveIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Parar sonido"
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AlmacenCompartido.pararRuido?()
        }
        return .result()
    }
}