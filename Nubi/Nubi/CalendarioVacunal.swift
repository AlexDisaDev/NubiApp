import Foundation

// MARK: - Comunidades

/// El Consejo Interterritorial aprueba un calendario común y después cada
/// comunidad lo adapta: en España conviven 19 calendarios con diferencias de
/// edades y de vacunas financiadas.
///
/// `.otros` representa países sin calendario cargado. En ese caso, la app no
/// debe inventar un calendario oficial: solo deja añadir vacunas a mano.
enum Comunidad: String, Codable, CaseIterable, Identifiable {
    case otros
    case comun
    case andalucia
    case aragon
    case asturias
    case baleares
    case canarias
    case cantabria
    case castillaLaMancha
    case castillaYLeon
    case cataluna
    case ceuta
    case valencia
    case extremadura
    case galicia
    case madrid
    case melilla
    case murcia
    case navarra
    case paisVasco
    case rioja

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .otros:            return "Otros países"
        case .comun:            return "Calendario común (España)"
        case .andalucia:        return "Andalucía"
        case .aragon:           return "Aragón"
        case .asturias:         return "Asturias"
        case .baleares:         return "Illes Balears"
        case .canarias:         return "Canarias"
        case .cantabria:        return "Cantabria"
        case .castillaLaMancha: return "Castilla-La Mancha"
        case .castillaYLeon:    return "Castilla y León"
        case .cataluna:         return "Catalunya"
        case .ceuta:            return "Ceuta"
        case .valencia:         return "Comunitat Valenciana"
        case .extremadura:      return "Extremadura"
        case .galicia:          return "Galicia"
        case .madrid:           return "Comunidad de Madrid"
        case .melilla:          return "Melilla"
        case .murcia:           return "Región de Murcia"
        case .navarra:          return "Navarra"
        case .paisVasco:        return "País Vasco / Euskadi"
        case .rioja:            return "La Rioja"
        }
    }

    var esCalendarioOficial: Bool {
        self != .otros
    }
}

// MARK: - Piezas del calendario

struct ItemVacuna: Identifiable, Hashable {
    let id: String
    let nombre: String
    let detalle: String
}

struct GrupoVacunal: Identifiable, Hashable {
    let id: String
    let etiqueta: String

    /// Edad en meses a la que corresponde el grupo.
    let meses: Double

    let items: [ItemVacuna]
}

// MARK: - Calendarios

/// Calendarios vacunales infantiles de España, curso 2026.
///
/// Fuentes: calendario común de vacunación e inmunización a lo largo de toda la
/// vida aprobado por el Consejo Interterritorial del SNS el 12 de diciembre de
/// 2025, y el análisis comparativo de los calendarios autonómicos publicado en
/// marzo de 2026.
///
/// Estado de la carga: hay diez comunidades con calendario propio verificado
/// (Andalucía, Aragón, Asturias, Castilla-La Mancha, Castilla y León,
/// Catalunya, Galicia, Madrid, Comunitat Valenciana y País Vasco). Las demás
/// muestran el calendario común y la app lo dice en pantalla, en vez de fingir
/// un dato que no tengo.
///
/// Los identificadores de cada vacuna son estables entre comunidades
/// (`g2-hexa` es el mismo en todas), así que cambiar de comunidad no borra lo
/// que ya estaba marcado como puesto.
enum CalendarioVacunal {

    // MARK: Vocabulario de vacunas

    typealias V = (cod: String, nombre: String, detalle: String)

    private static let vrs: V       = ("vrs", "Anticuerpo frente al VRS", "Nirsevimab, en su primera temporada de virus respiratorio sincitial.")
    private static let hbNacer: V   = ("hb", "Hepatitis B al nacer", "Solo si la madre es portadora o no se le hizo el cribado.")
    private static let hexa: V      = ("hexa", "Hexavalente", "Difteria, tétanos, tosferina, polio, Hib y hepatitis B.")
    private static let vnc: V       = ("vnc", "Neumococo", "Vacuna conjugada.")
    private static let vnc20: V     = ("vnc", "Neumococo (VNC20)", "Vacuna conjugada de 20 serotipos.")
    private static let menb: V      = ("menb", "Meningococo B", "")
    private static let menc: V      = ("menc", "Meningococo C", "")
    private static let menacwy: V   = ("menacwy", "Meningococo ACWY", "")
    private static let rota: V      = ("rota", "Rotavirus", "Se administra por boca.")
    private static let tv: V        = ("tv", "Triple vírica", "Sarampión, rubéola y parotiditis.")
    private static let varicela: V  = ("var", "Varicela", "")
    private static let tetra: V     = ("srpv", "Tetravírica", "Triple vírica y varicela en una sola vacuna.")
    private static let dtpaVpi: V   = ("dtpavpi", "Refuerzo DTPa-VPI", "Difteria, tétanos, tosferina y polio.")
    private static let dtpa: V      = ("dtpa", "Refuerzo difteria-tétanos-tosferina", "")
    private static let vpi: V       = ("vpi", "Polio", "")
    private static let tdpa: V      = ("tdpa", "dTpa", "Refuerzo de difteria, tétanos y tosferina.")
    private static let td: V        = ("td", "Tétanos y difteria", "")
    private static let vph: V       = ("vph", "Virus del papiloma humano", "Una dosis, en niñas y niños.")
    private static let gripe: V     = ("gripe", "Gripe", "Campaña estacional.")
    private static let hepA: V      = ("hepa", "Hepatitis A", "")

    /// Añade el número de dosis al nombre sin cambiar el identificador.
    private static func d(_ v: V, _ n: Int) -> V {
        (v.cod, "\(v.nombre) (\(n)ª)", v.detalle)
    }

    private static func nota(_ v: V, _ texto: String) -> V {
        (v.cod, v.nombre, texto)
    }

    private static func gr(
        _ gid: String,
        _ etiqueta: String,
        _ meses: Double,
        _ vs: [V]
    ) -> GrupoVacunal {
        GrupoVacunal(
            id: gid,
            etiqueta: etiqueta,
            meses: meses,
            items: vs.map {
                ItemVacuna(
                    id: "\(gid)-\($0.cod)",
                    nombre: $0.nombre,
                    detalle: $0.detalle
                )
            }
        )
    }

    // MARK: Calendario común del SNS (2026)

    private static let comun: [GrupoVacunal] = [
        gr("g0", "Al nacer", 0, [vrs, hbNacer]),
        gr("g2", "2 meses", 2, [d(hexa, 1), d(vnc, 1), d(menb, 1), d(rota, 1)]),
        gr("g4", "4 meses", 4, [d(hexa, 2), d(vnc, 2), d(menb, 2), d(rota, 2), menc]),
        gr("g6", "6 meses", 6, [nota(gripe, "Una dosis por temporada, de 6 a 59 meses.")]),
        gr("g11", "11 meses", 11, [d(hexa, 3), d(vnc, 3)]),
        gr("g12", "12 meses", 12, [d(tv, 1), d(menb, 3), nota(menc, "Segunda dosis de meningococo C.")]),
        gr("g15", "15 meses", 15, [d(varicela, 1)]),
        gr("g42", "3 – 4 años", 42, [d(tv, 2), d(varicela, 2)]),
        gr("g72", "6 años", 72, [dtpaVpi]),
        gr("g144", "12 años", 144, [vph, menacwy]),
        gr("g168", "14 años", 168, [td])
    ]

    // MARK: Comunidad de Madrid

    private static let madrid: [GrupoVacunal] = [
        gr("g0", "Al nacer", 0, [vrs, hbNacer]),
        gr("g2", "2 meses", 2, [d(hexa, 1), d(vnc, 1), d(menb, 1), d(rota, 1)]),
        gr("g4", "4 meses", 4, [d(hexa, 2), d(vnc, 2), d(menb, 2), d(rota, 2), menc]),
        gr("g6", "6 meses", 6, [nota(gripe, "Una dosis por temporada, de 6 a 59 meses.")]),
        gr("g11", "11 meses", 11, [d(hexa, 3), d(vnc, 3)]),
        gr("g12", "12 meses", 12, [
            d(tv, 1),
            d(menb, 3),
            nota(menacwy, "Desde el 1 de enero de 2026 sustituye a la dosis de MenC.")
        ]),
        gr("g15", "15 meses", 15, [d(varicela, 1)]),
        gr("g36", "3 años", 36, [
            nota(tetra, "Segunda dosis de triple vírica y varicela juntas.")
        ]),
        gr("g72", "6 años", 72, [
            nota(dtpaVpi, "Los vacunados con pauta 3+1 reciben dTpa de baja carga.")
        ]),
        gr("g144", "12 años", 144, [menacwy, vph]),
        gr("g168", "14 años", 168, [tdpa])
    ]

    // MARK: Andalucía

    private static let andalucia: [GrupoVacunal] = [
        gr("g0", "Al nacer", 0, [vrs, hbNacer]),
        gr("g2", "2 meses", 2, [
            d(hexa, 1),
            d(vnc20, 1),
            d(menb, 1),
            nota(rota, "Dos dosis por boca, a los 2 y 4 meses.")
        ]),
        gr("g4", "4 meses", 4, [d(hexa, 2), d(vnc20, 2), d(menb, 2), d(rota, 2), d(menacwy, 1)]),
        gr("g6", "6 meses", 6, [
            d(vnc20, 3),
            nota(gripe, "Una dosis por temporada, de 6 a 59 meses.")
        ]),
        gr("g11", "11 meses", 11, [d(hexa, 3), d(vnc20, 4)]),
        gr("g12", "12 meses", 12, [d(tv, 1), d(menacwy, 2)]),
        gr("g15", "15 meses", 15, [d(varicela, 1), d(menb, 3)]),
        gr("g24", "2 – 3 años", 30, [
            nota(tv, "Segunda dosis, durante 2026 a los 2 y 3 años."),
            nota(varicela, "Segunda dosis, durante 2026 a los 2 y 3 años.")
        ]),
        gr("g72", "6 años", 72, [
            nota(dtpaVpi, "Los vacunados con pauta 3+1 reciben Tdpa sin polio.")
        ]),
        gr("g144", "12 años", 144, [menacwy, vph]),
        gr("g168", "14 años", 168, [
            nota(tdpa, "A quienes no hayan recibido Tdpa a partir de los 10 años.")
        ])
    ]

    // MARK: País Vasco

    private static let paisVasco: [GrupoVacunal] = [
        gr("g2", "2 meses", 2, [
            d(hexa, 1),
            d(vnc, 1),
            d(menb, 1),
            nota(rota, "Pauta entre los 2 y los 6 meses.")
        ]),
        gr("g4", "4 meses", 4, [d(hexa, 2), d(vnc, 2), d(menb, 2), d(rota, 2), d(menacwy, 1)]),
        gr("g6", "6 meses", 6, [
            nota(gripe, "Una dosis por temporada, de 6 a 59 meses.")
        ]),
        gr("g11", "11 meses", 11, [d(hexa, 3), d(vnc, 3)]),
        gr("g12", "12 meses", 12, [d(tv, 1), d(menb, 3), d(menacwy, 2)]),
        gr("g15", "15 meses", 15, [d(varicela, 1)]),
        gr("g48", "4 años", 48, [d(tv, 2), d(varicela, 2)]),
        gr("g72", "6 años", 72, [dtpaVpi]),
        gr("g144", "12 años", 144, [vph, menacwy]),
        gr("g192", "16 años", 192, [td, tdpa])
    ]

    // MARK: Catalunya

    private static let cataluna: [GrupoVacunal] = [
        gr("g0", "Al nacer", 0, [
            nota(vrs, "A todos los menores de 12 meses en su primera temporada.")
        ]),
        gr("g2", "2 meses", 2, [d(hexa, 1), d(vnc, 1), d(menb, 1), d(rota, 1)]),
        gr("g4", "4 meses", 4, [d(hexa, 2), d(vnc, 2), d(menb, 2), d(rota, 2), menc]),
        gr("g6", "6 meses", 6, [
            nota(rota, "Tercera dosis, según la vacuna utilizada."),
            nota(gripe, "Una dosis por temporada, de 6 a 59 meses.")
        ]),
        gr("g11", "11 meses", 11, [d(hexa, 3), d(vnc, 3)]),
        gr("g12", "12 meses", 12, [d(tv, 1), d(menacwy, 1), d(menb, 3)]),
        gr("g15", "15 meses", 15, [d(varicela, 1), d(hepA, 1)]),
        gr("g36", "3 años", 36, [d(tv, 2), d(varicela, 2)]),
        gr("g72", "6 años", 72, [dtpaVpi, d(hepA, 2)]),
        gr("g132", "11 – 12 años", 138, [
            tdpa,
            d(menacwy, 2),
            vph,
            nota(varicela, "Solo a quienes no estén inmunizados."),
            nota(hepA, "Solo a quienes no estén inmunizados.")
        ])
    ]

    // MARK: Galicia

    private static let galicia: [GrupoVacunal] = [
        gr("g0", "Al nacer", 0, [vrs, hbNacer]),
        gr("g2", "2 meses", 2, [
            d(hexa, 1),
            d(vnc20, 1),
            d(menb, 1),
            nota(rota, "Dos dosis, a los 2 y 4 meses, en nacidos desde agosto de 2023.")
        ]),
        gr("g4", "4 meses", 4, [d(hexa, 2), d(vnc20, 2), d(menb, 2), d(rota, 2), d(menacwy, 1)]),
        gr("g6", "6 meses", 6, [
            d(vnc20, 3),
            nota(gripe, "Una dosis por temporada, de 6 a 59 meses.")
        ]),
        gr("g11", "11 meses", 11, [d(hexa, 3), d(vnc20, 4)]),
        gr("g12", "12 meses", 12, [d(tv, 1), d(menb, 3), d(menacwy, 2)]),
        gr("g15", "15 meses", 15, [d(varicela, 1)]),
        gr("g36", "3 años", 36, [
            nota(tetra, "Segunda dosis de triple vírica y varicela juntas.")
        ]),
        gr("g72", "6 años", 72, [
            nota(dtpaVpi, "Los vacunados con pauta 2, 4, 6 y 18 meses reciben dTpa.")
        ]),
        gr("g144", "12 años", 144, [
            menacwy,
            vph,
            nota(varicela, "A quienes no la hayan pasado ni tengan las dos dosis.")
        ]),
        gr("g168", "14 años", 168, [td])
    ]

    // MARK: Comunitat Valenciana

    private static let valencia: [GrupoVacunal] = [
        gr("g0", "Al nacer", 0, [vrs, hbNacer]),
        gr("g2", "2 meses", 2, [d(hexa, 1), d(vnc20, 1), d(menb, 1), d(rota, 1)]),
        gr("g4", "4 meses", 4, [d(hexa, 2), d(vnc20, 2), d(rota, 2), d(menacwy, 1)]),
        gr("g6", "6 meses", 6, [
            d(vnc20, 3),
            nota(rota, "Tercera dosis, según la vacuna utilizada."),
            nota(gripe, "Una dosis por temporada, de 6 a 71 meses.")
        ]),
        gr("g11", "11 meses", 11, [d(hexa, 3), d(vnc20, 4)]),
        gr("g12", "12 meses", 12, [d(tv, 1), d(menacwy, 2)]),
        gr("g15", "15 meses", 15, [d(varicela, 1)]),
        gr("g24", "2 – 4 años", 36, [
            nota(tetra, "Segunda dosis de triple vírica y varicela juntas.")
        ]),
        gr("g60", "5 – 6 años", 66, [dtpaVpi]),
        gr("g144", "12 años", 144, [vph, menacwy]),
        gr("g168", "14 años", 168, [td])
    ]

    // MARK: Castilla y León

    private static let castillaYLeon: [GrupoVacunal] = [
        gr("g0", "Al nacer", 0, [vrs, hbNacer]),
        gr("g2", "2 meses", 2, [d(hexa, 1), d(vnc20, 1), d(menb, 1), d(rota, 1)]),
        gr("g3", "3 meses", 3, [
            nota(rota, "Segunda dosis, según la vacuna utilizada.")
        ]),
        gr("g4", "4 meses", 4, [d(hexa, 2), d(vnc20, 2), d(menb, 2), d(rota, 3), d(menacwy, 1)]),
        gr("g6", "6 meses", 6, [
            d(vnc20, 3),
            nota(gripe, "Anual en campaña: de 6 a 23 meses inyectable, de 2 a 11 años intranasal.")
        ]),
        gr("g11", "11 meses", 11, [d(hexa, 3), d(vnc20, 4)]),
        gr("g12", "12 meses", 12, [d(tv, 1), d(menacwy, 2)]),
        gr("g15", "15 meses", 15, [d(varicela, 1)]),
        gr("g36", "3 años", 36, [d(tv, 2), d(varicela, 2)]),
        gr("g72", "6 años", 72, [dtpa, vpi]),
        gr("g144", "12 años", 144, [
            menacwy,
            nota(vph, "VPH9, una dosis, en niñas y niños."),
            nota(varicela, "Solo a quienes no la hayan pasado ni estén vacunados.")
        ]),
        gr("g168", "14 años", 168, [td])
    ]

    // MARK: Castilla-La Mancha

    private static let castillaLaMancha: [GrupoVacunal] = [
        gr("g0", "Al nacer", 0, [vrs, hbNacer]),
        gr("g2", "2 meses", 2, [d(hexa, 1), d(vnc, 1), d(menb, 1), d(rota, 1)]),
        gr("g4", "4 meses", 4, [d(hexa, 2), d(vnc, 2), d(rota, 2), d(menacwy, 1)]),
        gr("g6", "6 meses", 6, [
            d(vnc, 3),
            d(rota, 3),
            nota(gripe, "Anual, desde los 5 meses hasta los 5 años.")
        ]),
        gr("g11", "11 meses", 11, [d(hexa, 3), d(vnc, 4)]),
        gr("g12", "12 meses", 12, [d(tv, 1), d(menacwy, 2)]),
        gr("g15", "15 meses", 15, [d(varicela, 1)]),
        gr("g48", "4 años", 48, [d(tv, 2), d(varicela, 2)]),
        gr("g72", "6 años", 72, [dtpa, vpi]),
        gr("g144", "12 años", 144, [
            menacwy,
            vph,
            nota(varicela, "Solo a quienes no estén inmunizados.")
        ]),
        gr("g168", "14 años", 168, [td])
    ]

    // MARK: Asturias

    private static let asturias: [GrupoVacunal] = [
        gr("g2", "2 meses", 2, [
            d(hexa, 1),
            d(vnc, 1),
            nota(menb, "Meningococo B, en nacidos desde el 1 de noviembre de 2022."),
            d(rota, 1)
        ]),
        gr("g4", "4 meses", 4, [d(hexa, 2), d(vnc, 2), d(menb, 2), d(rota, 2), d(menacwy, 1)]),
        gr("g6", "6 meses", 6, [
            d(vnc, 3),
            nota(rota, "Tercera dosis, según la vacuna utilizada."),
            nota(gripe, "Una dosis por temporada, de 6 a 59 meses.")
        ]),
        gr("g11", "11 meses", 11, [d(hexa, 3), d(vnc, 4)]),
        gr("g12", "12 meses", 12, [d(tv, 1), d(menb, 3), d(menacwy, 2)]),
        gr("g15", "15 meses", 15, [d(varicela, 1)]),
        gr("g36", "3 años", 36, [d(tv, 2), d(varicela, 2)]),
        gr("g72", "6 años", 72, [dtpaVpi]),
        gr("g120", "10 años", 120, [
            nota(vph, "Una dosis, en niñas y niños."),
            nota(varicela, "Solo a quienes no la hayan pasado ni estén vacunados.")
        ]),
        gr("g156", "13 años", 156, [tdpa, menacwy])
    ]

    // MARK: Aragón

    private static let aragon: [GrupoVacunal] = [
        gr("g0", "Al nacer", 0, [vrs, hbNacer]),
        gr("g2", "2 meses", 2, [
            d(hexa, 1),
            d(vnc, 1),
            d(menb, 1),
            nota(rota, "En nacidos desde el 1 de agosto de 2024.")
        ]),
        gr("g4", "4 meses", 4, [d(hexa, 2), d(vnc, 2), d(menb, 2), d(rota, 2), d(menacwy, 1)]),
        gr("g6", "6 meses", 6, [
            d(vnc, 3),
            nota(rota, "Tercera dosis, según la vacuna utilizada."),
            nota(gripe, "Una dosis por campaña, de 6 a 59 meses.")
        ]),
        gr("g11", "11 meses", 11, [d(hexa, 3), d(vnc, 4)]),
        gr("g12", "12 meses", 12, [
            d(tv, 1),
            d(menacwy, 2),
            nota(menb, "Tercera dosis, en nacidos desde el 1 de enero de 2023.")
        ]),
        gr("g15", "15 meses", 15, [d(varicela, 1)]),
        gr("g36", "3 años", 36, [d(tv, 2), d(varicela, 2)]),
        gr("g72", "6 años", 72, [
            nota(dtpaVpi, "Los vacunados con pauta 3+1 reciben dTpa sin polio.")
        ]),
        gr("g144", "12 años", 144, [
            menacwy,
            vph,
            nota(varicela, "Solo a quienes no la hayan pasado ni estén vacunados.")
        ]),
        gr("g168", "14 años", 168, [td])
    ]

    // MARK: Índice

    private static let porComunidad: [Comunidad: [GrupoVacunal]] = [
        .madrid:           madrid,
        .andalucia:        andalucia,
        .paisVasco:        paisVasco,
        .cataluna:         cataluna,
        .galicia:          galicia,
        .valencia:         valencia,
        .castillaYLeon:    castillaYLeon,
        .castillaLaMancha: castillaLaMancha,
        .asturias:         asturias,
        .aragon:           aragon
    ]

    /// Comunidades con calendario propio ya verificado.
    static var comunidadesCargadas: Set<Comunidad> {
        Set(porComunidad.keys)
    }

    // MARK: API

    static func grupos(para comunidad: Comunidad) -> [GrupoVacunal] {
        if comunidad == .otros {
            return []
        }

        return porComunidad[comunidad] ?? comun
    }

    static func totalItems(para comunidad: Comunidad) -> Int {
        grupos(para: comunidad).reduce(0) { $0 + $1.items.count }
    }

    static func grupoActual(
        mesesDelBebe: Double,
        comunidad: Comunidad
    ) -> GrupoVacunal? {
        grupos(para: comunidad).last { $0.meses <= mesesDelBebe + 0.5 }
    }

    static func siguienteGrupo(
        mesesDelBebe: Double,
        comunidad: Comunidad
    ) -> GrupoVacunal? {
        grupos(para: comunidad).first { $0.meses > mesesDelBebe + 0.5 }
    }

    /// Aviso que acompaña al listado y que explica de dónde sale.
    static func aviso(para comunidad: Comunidad) -> String {
        if comunidad == .otros {
            return "Cada país tiene su propio calendario de vacunación. Usa la sección «Añadidas por ti» para guardar las vacunas de tu bebé."
        }

        if comunidad == .comun {
            return "Calendario común del Sistema Nacional de Salud para 2026. Tu comunidad puede adelantar o añadir vacunas: elígela arriba."
        }

        if comunidadesCargadas.contains(comunidad) {
            return "Calendario de \(comunidad.nombre) para 2026. Contrástalo con la cartilla: las pautas dependen a menudo de la fecha de nacimiento."
        }

        return "Todavía no tengo cargado el calendario propio de \(comunidad.nombre), así que se muestra el común. Añade abajo lo que falte."
    }

    static let avisoGeneral = """
    El calendario es orientativo y se actualiza cada año. La referencia válida \
    es siempre la cartilla de tu bebé y tu enfermera de pediatría.
    """
}

// MARK: - Catálogo para el buscador

/// Nombres habituales para el buscador de "añadir vacuna". No es una lista
/// cerrada: siempre se puede escribir uno a mano.
enum CatalogoVacunas {

    static let nombres: [String] = [
        "Hexavalente (DTPa-VPI-Hib-HB)",
        "Pentavalente (DTPa-VPI-Hib)",
        "Difteria, tétanos y tosferina (DTPa)",
        "dTpa (refuerzo)",
        "Tétanos y difteria (Td)",
        "Polio (VPI)",
        "Haemophilus influenzae b (Hib)",
        "Hepatitis A",
        "Hepatitis B",
        "Neumococo conjugada (VNC13)",
        "Neumococo conjugada (VNC20)",
        "Meningococo B",
        "Meningococo C",
        "Meningococo ACWY",
        "Rotavirus",
        "Triple vírica (sarampión, rubéola, paperas)",
        "Tetravírica (triple vírica y varicela)",
        "Varicela",
        "Gripe",
        "COVID-19",
        "Virus del papiloma humano (VPH)",
        "Anticuerpo frente al VRS (nirsevimab)",
        "BCG (tuberculosis)",
        "Fiebre tifoidea",
        "Fiebre amarilla",
        "Rabia",
        "Encefalitis japonesa",
        "Encefalitis centroeuropea",
        "Cólera"
    ]

    static func buscar(_ texto: String) -> [String] {
        let q = texto
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces)

        guard !q.isEmpty else { return nombres }

        return nombres.filter {
            $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(q)
        }
    }
}