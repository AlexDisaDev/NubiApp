import Foundation
import SwiftUI

// MARK: - Bebé
struct Bebe: Codable, Identifiable, Hashable {
    var id = UUID()
    var nombre: String
    var fechaNacimiento: Date
    var semanasPrematuro: Int = 0

    var edadEnDias: Int {
        let bruta = Calendar.current.dateComponents([.day], from: fechaNacimiento, to: .now).day ?? 0
        return max(0, bruta - semanasPrematuro * 7)
    }

    var edadEnMeses: Double { Double(edadEnDias) / 30.44 }

    var edadLegible: String {
        L10n.edadBebe(dias: edadEnDias, meses: Int(edadEnMeses))
    }
}

enum UnidadBiberon: String, Codable, CaseIterable, Identifiable {
    case ml, oz
    
    var id: String { rawValue }
    var etiqueta: String { self == .ml ? "ml" : "oz" }
    var factor: Double { self == .ml ? 1.0 : 29.5735 }  // a ml
}

// MARK: - Medicina

struct Medicina: Codable, Identifiable, Hashable {
    var id = UUID()
    var fechaToma: Date = .now
    var nombre: String = ""
    var nota: String = ""
    var horaSiguiente: Date?
}

// MARK: - Lado de lactancia
enum LadoPecho: String, Codable, CaseIterable, Identifiable {
    case izquierda, derecha

    var id: String { rawValue }

    var letra: String {
    self == .derecha ? L10n.t("D") : L10n.t("I")
    }
    var titulo: String {
        self == .derecha ? L10n.t("Pecho derecho") : L10n.t("Pecho izquierdo")
    }
    var tituloCorto: String {
        L10n.t("Pecho") + " \(letra)"
    }
}

// MARK: - Registros del día
enum TipoRegistro: String, Codable, CaseIterable, Identifiable {
    case siesta, noche, biberon, pecho, panal, despertar

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .siesta:    return L10n.t("Siesta")
        case .noche:     return L10n.t("Sueño nocturno")
        case .biberon:   return L10n.t("Biberón")
        case .pecho:     return L10n.t("Pecho")
        case .panal:     return L10n.t("Pañal")
        case .despertar: return L10n.t("Despertar")
        }
    }

    var simbolo: Ilus.Simbolo {
        switch self {
        case .siesta:    return .nube
        case .noche:     return .luna
        case .biberon:   return .biberon
        case .pecho:     return .corazon
        case .panal:     return .hoja
        case .despertar: return .lunaOjoAbierto
        }
    }

    var color: Color {
        switch self {
        case .siesta:    return Theme.menta
        case .noche:     return Theme.lila
        case .biberon:   return Theme.mantequilla
        case .pecho:     return Theme.melocoton
        case .panal:     return Theme.cielo
        case .despertar: return Theme.coral
        }
    }

    var esIntervalo: Bool { self == .siesta || self == .noche || self == .despertar }
    var esSueño: Bool { self == .siesta || self == .noche }
    var restaSueño: Bool { self == .despertar }
    var esAlimentacion: Bool { self == .biberon || self == .pecho }
}

struct Registro: Codable, Identifiable, Hashable {
    var id = UUID()
    var tipo: TipoRegistro
    var inicio: Date
    var fin: Date?
    var nota: String = ""
    var lado: LadoPecho? = nil
    var cantidadBiberon: Double? = nil        
    var unidadBiberon: UnidadBiberon? = nil   
    var panalPis: Bool? = nil       
    var panalCaca: Bool? = nil
    var tipoLeche: TipoLeche? = nil

    var tituloVisible: String {
        if tipo == .pecho, let lado {
            return lado.tituloCorto
        }
        return tipo.titulo
    }

    var enCurso: Bool {
        fin == nil && (tipo.esIntervalo || tipo == .pecho)
    }

    var duracion: TimeInterval? {
        guard let fin else { return nil }
        return fin.timeIntervalSince(inicio)
    }
}

// MARK: - Crecimiento
struct Medida: Codable, Identifiable, Hashable {
    var id = UUID()
    var fecha: Date = .now
    var pesoKg: Double?
    var alturaCm: Double?
    var perimetroCm: Double?
    var nota: String = ""
    var vacia: Bool { pesoKg == nil && alturaCm == nil && perimetroCm == nil }
}

// MARK: - Citas
enum TipoCita: String, Codable, CaseIterable, Identifiable {
    case pediatra, enfermeria, otra
    var id: String { rawValue }
    var titulo: String {
        switch self {
        case .pediatra:   return "Pediatra"
        case .enfermeria: return "Enfermería"
        case .otra:       return "Otra"
        }
    }
    var simbolo: Ilus.Simbolo {
        switch self {
        case .pediatra:   return .botiquin
        case .enfermeria: return .jeringa
        case .otra:       return .calendario
        }
    }
    var color: Color {
        switch self {
        case .pediatra:   return Theme.menta
        case .enfermeria: return Theme.cielo
        case .otra:       return Theme.mantequilla
        }
    }
}

struct Cita: Codable, Identifiable, Hashable {
    var id = UUID()
    var tipo: TipoCita = .pediatra
    var titulo: String = ""
    var fecha: Date = .now
    var lugar: String = ""
    var nota: String = ""
    var recordar: Bool = true
    var pasada: Bool { fecha < .now }
    var tituloVisible: String { titulo.isEmpty ? "Revisión con \(tipo.titulo.lowercased())" : titulo }
}

// MARK: - Vacunas
struct EstadoVacuna: Codable, Hashable {
    var puesta: Bool = false
    var fecha: Date?
    var nota: String = ""
}

struct VacunaPropia: Codable, Identifiable, Hashable {
    var id = UUID()
    var nombre: String
    var puesta: Bool = false
    var fecha: Date?
}

struct GrupoPropio: Codable, Identifiable, Hashable {
    var id = UUID()
    var etiqueta: String
    var meses: Double
    var vacunas: [VacunaPropia] = []
}

// MARK: - Diario
struct EntradaDiario: Codable, Identifiable, Hashable {
    var id = UUID()
    var fecha: Date = .now
    var titulo: String = ""
    var texto: String = ""
    var hito: Bool = false
    var tituloVisible: String {
        if !titulo.isEmpty { return titulo }
        let primera = texto.split(separator: "\n").first.map(String.init) ?? "Sin título"
        return String(primera.prefix(60))
    }
}

// MARK: - Formato
enum Fmt {
    static var locale: Locale = Locale(identifier: "es_ES")

    static func duracion(_ s: TimeInterval) -> String {
        let total = Int(s.rounded())
        if total == 0 { return "0 min" }
        if total < 60 { return "1 min" }
        let h = total / 3600
        let m = (total % 3600) / 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m) min"
    }

    static func hora(_ d: Date) -> String {
        d.formatted(.dateTime.hour().minute().locale(locale))
    }

    static func fechaCorta(_ d: Date) -> String {
        d.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }

    static func fechaLarga(_ d: Date) -> String {
        d.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
    }

    static func numero(_ v: Double, _ decimales: Int = 1) -> String {
        v.formatted(.number.precision(.fractionLength(decimales)).locale(locale))
    }

    static func tiempoDesde(_ fecha: Date, hasta ahora: Date) -> String {
        let intervalo = ahora.timeIntervalSince(fecha)
        guard intervalo > 0 else { return L10n.ahoraMismo }
        let minutos = Int(intervalo / 60)
        let horas = minutos / 60
        let mins = minutos % 60
        if horas == 0 { return L10n.haceMin(mins) }
        return L10n.haceHoras(horas, mins)
    }

    static func cuandoFalta(_ fecha: Date, desde ahora: Date = .now) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(fecha)     { return L10n.t("hoy a las") + " \(hora(fecha))" }
        if cal.isDateInTomorrow(fecha)  { return L10n.t("mañana a las") + " \(hora(fecha))" }
        if cal.isDateInYesterday(fecha) { return L10n.t("ayer") }
        let dias = cal.dateComponents([.day], from: cal.startOfDay(for: ahora), to: cal.startOfDay(for: fecha)).day ?? 0
        if dias > 0 { return dias < 30 ? L10n.enDias(dias) : fechaCorta(fecha) }
        return fechaCorta(fecha)
    }

    static func edadEnFecha(_ fecha: Date, nacimiento: Date) -> String {
        let dias = Calendar.current.dateComponents([.day], from: nacimiento, to: fecha).day ?? 0
        if dias < 31 { return "\(dias) d" }
        let meses = Int(Double(dias) / 30.44)
        return meses < 24 ? "\(meses) m" : "\(meses / 12) a"
    }

    static func edadCompletaEnFecha(_ fecha: Date, nacimiento: Date, semanasPrematuro: Int = 0) -> String {
        let cal = Calendar.current
        let fechaCorregida: Date
        if semanasPrematuro > 0 {
            fechaCorregida = cal.date(byAdding: .day, value: semanasPrematuro * 7, to: nacimiento) ?? nacimiento
        } else {
            fechaCorregida = nacimiento
        }
        let componentes = cal.dateComponents([.month, .day], from: fechaCorregida, to: fecha)
        let meses = componentes.month ?? 0
        let dias = componentes.day ?? 0
        
        if meses == 0 {
            let diasTotales = cal.dateComponents([.day], from: fechaCorregida, to: fecha).day ?? 0
            if diasTotales < 14 {
                return diasTotales == 1 ? "1 " + L10n.t("día") : "\(diasTotales) " + L10n.t("días")
            }
            let semanas = diasTotales / 7
            return semanas == 1 ? "1 " + L10n.t("semana") : "\(semanas) " + L10n.t("semanas")
        } else if dias == 0 {
            return meses == 1 ? "1 " + L10n.t("mes") : "\(meses) " + L10n.t("meses")
        } else {
            let textoMeses = meses == 1 ? "1 " + L10n.t("mes") : "\(meses) " + L10n.t("meses")
            let textoDias = dias == 1 ? "1 " + L10n.t("día") : "\(dias) " + L10n.t("días")
            return textoMeses + " " + L10n.t("y") + " " + textoDias
        }
    }
}
    // MARK: - Banco de Leche

    enum AlmacenamientoLeche: String, Codable, CaseIterable, Identifiable {
        case frigo = "Frigorífico"
        case congelador = "Congelador"
        var id: String { rawValue }
        
        var duracionDias: Int {
            switch self {
            case .frigo: return 4
            case .congelador: return 180
            }
        }
        
        var simbolo: Ilus.Simbolo {
            switch self {
            case .frigo: return .gota
            case .congelador: return .nube
            }
        }
    }

    struct ExtraccionLeche: Codable, Identifiable, Hashable {
        var id = UUID()
        var fecha: Date = .now
        var cantidadMl: Double
        var almacenamiento: AlmacenamientoLeche = .congelador
        var nota: String = ""
        
        /// Fecha estimada de caducidad según almacenamiento
        var caducidad: Date {
            Calendar.current.date(byAdding: .day, value: almacenamiento.duracionDias, to: fecha) ?? fecha
        }
    }

    struct UsoLeche: Codable, Identifiable, Hashable {
        var id = UUID()
        var fecha: Date = .now
        var cantidadMl: Double
        var nota: String = ""
    }

    // MARK: - Alimentación Complementaria

    enum GustoComida: String, Codable, CaseIterable, Identifiable {
        case leGusto
        case noLeGusto
        var id: String { rawValue }
    }

    enum CategoriaAlimento: String, Codable, CaseIterable, Identifiable {
        case fruta = "Fruta"
        case verdura = "Verdura"
        case proteina = "Proteína"
        case cereal = "Cereal"
        case lacteo = "Lácteo"
        case otro = "Otro"
        var id: String { rawValue }
        
        var color: Color {
            switch self {
            case .fruta:   return Theme.melocoton
            case .verdura: return Theme.menta
            case .proteina: return Theme.coral
            case .cereal:  return Theme.mantequilla
            case .lacteo:  return Theme.cielo
            case .otro:    return Theme.lila
            }
        }
    }

    struct ComidaComplementaria: Codable, Identifiable, Hashable {
        var id = UUID()
        var fecha: Date = .now
        var nombre: String = ""
        var categoria: CategoriaAlimento = .otro
        var gusto: GustoComida? = nil
        var nota: String = ""
        /// Fotos comprimidas en JPEG (máx 2)
        var fotos: [Data] = []
    }

    // MARK: - Enfermedades
    struct Enfermedad: Codable, Identifiable, Hashable {
        var id = UUID()
        var nombre: String = ""
        var fechaInicio: Date = .now
        var fechaFin: Date? = nil
        var medicacion: String = ""
        var notas: String = ""
        
        /// ¿Sigue activa?
        var activa: Bool { fechaFin == nil }
        
        /// Texto legible para mostrar la duración
        var textoDuracion: String {
            let ini = Fmt.fechaCorta(fechaInicio)
            if let fin = fechaFin {
                return "\(ini) – \(Fmt.fechaCorta(fin))"
            }
            return "\(ini) – en curso"
        }
    }

    // MARK: - Tipo de leche del biberón
    enum TipoLeche: String, Codable, CaseIterable, Identifiable {
        case materna, formula
        var id: String { rawValue }
        var nombre: String { self == .materna ? "Leche materna" : "Fórmula" }
        var corta: String { self == .materna ? "Materna" : "Fórmula" }
    }


