import Foundation

/// Guía de ventanas de sueño por edad.
/// Rangos orientativos de literatura pediátrica divulgativa. No es consejo médico.
struct GuiaEdad {
    let mesesHasta: Double
    let ventanaMin: TimeInterval   // segundos despierto antes de la siguiente siesta
    let ventanaMax: TimeInterval
    let siestasTipicas: ClosedRange<Int>
    let sueñoTotalHoras: ClosedRange<Double>

    static let tabla: [GuiaEdad] = [
        .init(mesesHasta:  1, ventanaMin: 45*60,  ventanaMax:  60*60, siestasTipicas: 4...7, sueñoTotalHoras: 14...17),
        .init(mesesHasta:  2, ventanaMin: 60*60,  ventanaMax:  90*60, siestasTipicas: 4...6, sueñoTotalHoras: 14...17),
        .init(mesesHasta:  3, ventanaMin: 75*60,  ventanaMax: 105*60, siestasTipicas: 4...5, sueñoTotalHoras: 14...16),
        .init(mesesHasta:  4, ventanaMin: 90*60,  ventanaMax: 120*60, siestasTipicas: 3...5, sueñoTotalHoras: 13...16),
        .init(mesesHasta:  6, ventanaMin: 120*60, ventanaMax: 150*60, siestasTipicas: 3...4, sueñoTotalHoras: 12...16),
        .init(mesesHasta:  9, ventanaMin: 150*60, ventanaMax: 180*60, siestasTipicas: 2...3, sueñoTotalHoras: 12...15),
        .init(mesesHasta: 12, ventanaMin: 180*60, ventanaMax: 240*60, siestasTipicas: 2...2, sueñoTotalHoras: 12...15),
        .init(mesesHasta: 18, ventanaMin: 240*60, ventanaMax: 300*60, siestasTipicas: 1...2, sueñoTotalHoras: 11...14),
        .init(mesesHasta: 24, ventanaMin: 300*60, ventanaMax: 330*60, siestasTipicas: 1...1, sueñoTotalHoras: 11...14),
        .init(mesesHasta: 99, ventanaMin: 330*60, ventanaMax: 360*60, siestasTipicas: 0...1, sueñoTotalHoras: 10...13),
    ]

    static func para(meses: Double) -> GuiaEdad {
        tabla.first { meses < $0.mesesHasta } ?? tabla[tabla.count - 1]
    }
}

/// Sugerencia de próxima ventana de sueño.
struct Sugerencia {
    let desde: Date
    let hasta: Date
    /// Cuántas siestas lleva hoy — la ventana se alarga a lo largo del día.
    let numeroDeSiesta: Int
    let ajustadaPorHistorial: Bool

    var yaEnVentana: Bool { Date() >= desde && Date() <= hasta }
    var pasada: Bool { Date() > hasta }
}

enum MotorSueño {

    /// Calcula la próxima ventana a partir de la última vez que el bebé se despertó.
    ///
    /// Dos ajustes sobre la tabla base:
    /// 1. La ventana se estira a lo largo del día (la primera del día es la más corta).
    /// 2. Si hay historial, se mezcla la media real del bebé con la guía (70/30).
    static func proximaVentana(bebe: Bebe, registros: [Registro], ahora: Date = .now) -> Sugerencia? {
        guard let ultimoDespertar = ultimoFinDeSueño(registros, antesDe: ahora) else { return nil }

        let guia = GuiaEdad.para(meses: bebe.edadEnMeses)
        let siestasHoy = siestasCompletadasHoy(registros, ahora: ahora)

        // 1. Estiramiento progresivo: +8 % por cada siesta ya hecha, tope +30 %.
        let estiramiento = min(1.30, 1.0 + Double(siestasHoy) * 0.08)

        var minimo = guia.ventanaMin * estiramiento
        var maximo = guia.ventanaMax * estiramiento
        var ajustada = false

        // 2. Mezcla con la media real de las últimas ventanas observadas.
        let observadas = ventanasObservadas(registros, ultimas: 8)
        if observadas.count >= 3 {
            let media = observadas.reduce(0, +) / Double(observadas.count)
            let centroGuia = (minimo + maximo) / 2
            let centro = centroGuia * 0.3 + media * 0.7
            let amplitud = (maximo - minimo) / 2
            minimo = centro - amplitud
            maximo = centro + amplitud
            ajustada = true
        }

        return Sugerencia(
            desde: ultimoDespertar.addingTimeInterval(minimo),
            hasta: ultimoDespertar.addingTimeInterval(maximo),
            numeroDeSiesta: siestasHoy + 1,
            ajustadaPorHistorial: ajustada
        )
    }

    static func ultimoFinDeSueño(_ registros: [Registro], antesDe fecha: Date) -> Date? {
        registros
            .filter { $0.tipo.esIntervalo }
            .compactMap(\.fin)
            .filter { $0 <= fecha }
            .max()
    }

    static func siestasCompletadasHoy(_ registros: [Registro], ahora: Date) -> Int {
        registros.filter {
            $0.tipo == .siesta && $0.fin != nil && Calendar.current.isDate($0.inicio, inSameDayAs: ahora)
        }.count
    }

    /// Duraciones de vigilia entre sueños consecutivos.
    private static func ventanasObservadas(_ registros: [Registro], ultimas n: Int) -> [TimeInterval] {
        let sueños = registros
            .filter { $0.tipo.esIntervalo && $0.fin != nil }
            .sorted { $0.inicio < $1.inicio }

        var huecos: [TimeInterval] = []
        for i in 1..<max(1, sueños.count) {
            guard let finAnterior = sueños[i - 1].fin else { continue }
            let hueco = sueños[i].inicio.timeIntervalSince(finAnterior)
            // Descarta ruido: menos de 15 min o más de 8 h no es una ventana normal.
            if hueco > 15 * 60 && hueco < 8 * 3600 { huecos.append(hueco) }
        }
        return Array(huecos.suffix(n))
    }

    /// Sueño total acumulado en las últimas 24 h.
    static func sueñoUltimas24h(_ registros: [Registro], ahora: Date = .now) -> TimeInterval {
        let corte = ahora.addingTimeInterval(-24 * 3600)
        
        let segundosTotales = registros
            .filter { $0.tipo.esIntervalo }
            .reduce(0.0) { total, r in
                // Solo contar la parte del sueño que está dentro de las últimas 24h
                let inicio = max(r.inicio, corte)
                let fin = min(r.fin ?? ahora, ahora)
                
                // Si el sueño terminó antes del corte, no cuenta
                guard fin > corte else { return total }
                
                // Si el sueño empezó después de ahora, no cuenta
                guard inicio < ahora else { return total }
                
                let duracion = max(0, fin.timeIntervalSince(inicio))
                return total + duracion
            }
        
        return segundosTotales
    }

    /// ¿Está dentro de lo esperado para su edad?
    static func balance(bebe: Bebe, registros: [Registro]) -> (horas: Double, rango: ClosedRange<Double>, dentro: Bool) {
        let guia = GuiaEdad.para(meses: bebe.edadEnMeses)
        let horas = sueñoUltimas24h(registros) / 3600
        return (horas, guia.sueñoTotalHoras, guia.sueñoTotalHoras.contains(horas))
    }
}
