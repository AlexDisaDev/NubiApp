import Foundation

/// Punto de entrada estático para que los App Intents (Siri, Live Activity, Shortcuts)
/// puedan controlar la app incluso en segundo plano.
/// IMPORTANTE: solo usa tipos primitivos (String, Bool, Double, Int) para poder
/// vivir en el target de la app Y en el del widget sin necesitar Modelos.swift.
enum AlmacenCompartido {
    // Sueño
    static var empezarDespertar: (() -> Void)?
    static var volverADormir: (() -> Void)?
    static var terminarDespertar: (() -> Void)?
    static var terminarSueño: (() -> Void)?
    static var hayDespertarEnCurso: (() -> Bool)?
    static var haySueñoEnCurso: (() -> Bool)?
    
    // Nuevos para Siri
    static var empezarNoche: (() -> Void)?
    static var terminarSueñoEnCurso: (() -> Void)?
    
    // Alimentación
    static var cambiarPecho: (() -> Void)?
    static var terminarPecho: (() -> Void)?
    
    // Nuevos para Siri (primitivos: la conversión a enums se hace en NubiApp)
    static var empezarPecho: ((String) -> Void)?                      // "izquierda" | "derecha"
    static var registrarBiberon: ((String, Double, String) -> Void)?  // "materna"|"formula", cantidad, "ml"|"oz"
    static var registrarPanal: ((Bool, Bool) -> Void)?                // pis, caca
    static var registrarDespertar: ((Int) -> Void)?                   // minutos
    
    // Ruido
    static var iniciarRuido: ((String) -> Void)?                      // "blanco"|"rosa"|"marron"
    static var pararRuido: (() -> Void)?

    static var empezarSiesta: (() -> Void)?
    static var empezarSueñoNoche: (() -> Void)?
}