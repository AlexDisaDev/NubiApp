import Foundation

/// Generador de mensajes bonitos para las notificaciones de hora de dormir.
/// Combina fragmentos de varias listas, así el número de combinaciones posibles
/// es el producto de todas las piezas — decenas de miles de frases distintas.
/// Además recuerda las últimas usadas para no repetir en el corto plazo.
enum MensajesBonitos {
    
    // MARK: Piezas combinables
    
    private static let aperturas = [
        "Se acerca la hora mágica",
        "El día se despide",
        "Las estrellas ya asoman",
        "Llega el momento más dulce",
        "La luna está lista",
        "El cielo se pone de pijama",
        "Termina un día precioso",
        "Se enciende la primera estrella",
        "El mundo baja la voz",
        "La noche abre sus brazos",
        "Es hora de recoger el día",
        "Los sueños ya hacen cola"
    ]
    
    private static let cuerpos = [
        "%@ ha jugado, comido y crecido",
        "%@ ha llenado el día de momentos bonitos",
        "%@ ha explorado el mundo con ganas",
        "%@ merece un descanso de campeón",
        "%@ ha repartido sonrisas todo el día",
        "%@ está listo para recargar energías",
        "%@ ha vivido un día lleno de aventuras",
        "los ojitos de %@ empiezan a pesar",
        "%@ ha dado lo mejor de sí hoy",
        "el corazón de %@ pide mimos y mantita"
    ]
    
    private static let cierres = [
        "Es momento de acurrucarse.",
        "Hora de soñar bonito.",
        "A dormir entre nubes.",
        "Que descanse como un angelito.",
        "A viajar al país de los sueños.",
        "Un besito y a la camita.",
        "Que los sueños sean dulces.",
        "A recargar pilas hasta mañana.",
        "Buenas noches, pequeñín.",
        "A soñar con estrellas."
    ]
    
    // MARK: Historial anti-repetición
    
    private static let claveHistorial = "mensajesBonitosUsados"
    private static let maxHistorial = 40
    
    /// Genera un mensaje para el bebé indicado, evitando repetir los últimos usados.
    static func generar(nombreBebe: String) -> String {
        var intentos = 0
        var candidato = componer(nombreBebe: nombreBebe)
        var huella = huellaDe(candidato)
        
        var usados = historial()
        
        // Reintenta hasta encontrar uno no usado recientemente (máx 20 intentos)
        while usados.contains(huella) && intentos < 20 {
            candidato = componer(nombreBebe: nombreBebe)
            huella = huellaDe(candidato)
            intentos += 1
        }
        
        // Guarda la huella en el historial
        usados.append(huella)
        if usados.count > maxHistorial {
            usados.removeFirst(usados.count - maxHistorial)
        }
        UserDefaults.standard.set(usados, forKey: claveHistorial)
        
        return candidato
    }
    
    // MARK: Interno
    
    private static func componer(nombreBebe: String) -> String {
        let apertura = aperturas.randomElement() ?? aperturas[0]
        let cuerpoPlantilla = cuerpos.randomElement() ?? cuerpos[0]
        let cierre = cierres.randomElement() ?? cierres[0]
        
        let cuerpo = String(format: cuerpoPlantilla, nombreBebe)
        
        return "\(apertura). \(cuerpo.prefix(1).uppercased() + cuerpo.dropFirst()). \(cierre)"
    }
    
    private static func huellaDe(_ mensaje: String) -> String {
        // Huella corta para no guardar el texto completo
        String(mensaje.hashValue)
    }
    
    private static func historial() -> [String] {
        UserDefaults.standard.stringArray(forKey: claveHistorial) ?? []
    }
}