import Foundation

/// Guía de sueño por edad. Valores basados en Taking Cara Babies, Cleveland Clinic,
/// The Bump y Baby Sleep Site (2025-2026). No es consejo médico.
struct GuiaEdad {
    let mesesHasta: Double
    let ventanaMin: TimeInterval
    let ventanaMax: TimeInterval
    let siestasTipicas: ClosedRange<Int>
    let sueñoTotalHoras: ClosedRange<Double>
    let duracionSiestaTipica: TimeInterval
    let bedtimeIdeal: Int
    
    static let tabla: [GuiaEdad] = [
        .init(mesesHasta:  1, ventanaMin:  30*60, ventanaMax:  60*60, siestasTipicas: 5...7, sueñoTotalHoras: 14...17, duracionSiestaTipica: 45*60, bedtimeIdeal: 20),
        .init(mesesHasta:  3, ventanaMin:  60*60, ventanaMax:  90*60, siestasTipicas: 4...6, sueñoTotalHoras: 14...17, duracionSiestaTipica: 60*60, bedtimeIdeal: 20),
        .init(mesesHasta:  4, ventanaMin:  75*60, ventanaMax: 120*60, siestasTipicas: 4...5, sueñoTotalHoras: 13...16, duracionSiestaTipica: 60*60, bedtimeIdeal: 19),
        .init(mesesHasta:  5, ventanaMin:  75*60, ventanaMax: 120*60, siestasTipicas: 4...5, sueñoTotalHoras: 12...16, duracionSiestaTipica: 60*60, bedtimeIdeal: 19),
        .init(mesesHasta:  7, ventanaMin: 120*60, ventanaMax: 180*60, siestasTipicas: 3...4, sueñoTotalHoras: 12...16, duracionSiestaTipica: 90*60, bedtimeIdeal: 19),
        .init(mesesHasta: 10, ventanaMin: 150*60, ventanaMax: 210*60, siestasTipicas: 2...3, sueñoTotalHoras: 12...15, duracionSiestaTipica: 90*60, bedtimeIdeal: 19),
        .init(mesesHasta: 14, ventanaMin: 180*60, ventanaMax: 240*60, siestasTipicas: 2...2, sueñoTotalHoras: 11...15, duracionSiestaTipica: 105*60, bedtimeIdeal: 19),
        .init(mesesHasta: 18, ventanaMin: 210*60, ventanaMax: 270*60, siestasTipicas: 1...2, sueñoTotalHoras: 11...14, duracionSiestaTipica: 120*60, bedtimeIdeal: 19),
        .init(mesesHasta: 24, ventanaMin: 240*60, ventanaMax: 300*60, siestasTipicas: 1...1, sueñoTotalHoras: 11...14, duracionSiestaTipica: 120*60, bedtimeIdeal: 20),
        .init(mesesHasta: 99, ventanaMin: 300*60, ventanaMax: 360*60, siestasTipicas: 0...1, sueñoTotalHoras: 10...13, duracionSiestaTipica: 90*60, bedtimeIdeal: 20),
    ]
    
    static func para(meses: Double) -> GuiaEdad {
        tabla.first { meses < $0.mesesHasta } ?? tabla[tabla.count - 1]
    }
}

struct Sugerencia {
    let desde: Date
    let hasta: Date
    let numeroDeSiesta: Int
    let ajustadaPorHistorial: Bool
    
    var yaEnVentana: Bool { Date() >= desde && Date() <= hasta }
    var pasada: Bool { Date() > hasta }
}

enum TipoPrediccion {
    case siesta
    case noche
}

struct PrediccionDia {
    let tipo: TipoPrediccion
    let desde: Date
    let hasta: Date
    let numero: Int
    let ajustadaPorHistorial: Bool
    
    var yaEnVentana: Bool { Date() >= desde && Date() <= hasta }
    var pasada: Bool { Date() > hasta }
}

struct VentanaIdeal: Identifiable {
    let id = UUID()
    let numero: Int
    let rangoInicioDesde: Date
    let rangoInicioHasta: Date
    let duracionTipica: TimeInterval
    let inicioReal: Date?
    let finReal: Date?
    var esNocturna: Bool = false
    var ajustadaPorHistorial: Bool = false
    
    var realizada: Bool { inicioReal != nil }
    var arcoDesde: Date { inicioReal ?? rangoInicioDesde }
    var arcoHasta: Date {
        if let fReal = finReal { return fReal }
        return rangoInicioHasta.addingTimeInterval(duracionTipica)
    }
    var horaAmostrar: Date { inicioReal ?? rangoInicioDesde }
    var horaCalculada: Date { rangoInicioDesde }
    func perdida(ahora: Date) -> Bool {
        !realizada && ahora > rangoInicioHasta.addingTimeInterval(30 * 60)
    }
}

enum MotorSueño {
    
    // MARK: - Próxima ventana (pestaña Hoy)
    
    static func proximaVentana(bebe: Bebe, registros: [Registro], ahora: Date = .now) -> Sugerencia? {
        guard let ultimoDespertar = ultimoFinDeSueño(registros, antesDe: ahora) else { return nil }
        let siestasHoy = siestasCompletadasHoy(registros, ahora: ahora)
        let guia = GuiaEdad.para(meses: bebe.edadEnMeses)
        let N = numeroDeSiestas(guia)
        
        return calcularVentana(
            desdeDespertar: ultimoDespertar,
            indiceSiesta: siestasHoy,
            totalSiestas: N,
            bebe: bebe,
            registros: registros
        )
    }

    static func despertarDelDia(registros: [Registro], dia: Date, manual: Date?) -> Date? {
        let cal = Calendar.current
        
        // 1) Fin real de un sueño nocturno que terminó ese día
        let finesReales = registros
            .filter { r in
                guard r.tipo == .noche, let fin = r.fin else { return false }
                return cal.isDate(fin, inSameDayAs: dia)
            }
            .compactMap { $0.fin }
        
        if let real = finesReales.max() { return real }
        
        // 2) Despertar manual escrito al entrar en la app
        if let manual, cal.isDate(manual, inSameDayAs: dia) { return manual }
        
        return nil
    }
    
    /// Predicción rica para la tarjeta de Hoy: si ya se hicieron todas las siestas
    /// previstas, predice la NOCHE en vez de otra siesta.
    static func prediccionDelDia(bebe: Bebe, registros: [Registro], ahora: Date = .now, despertarManual: Date? = nil) -> PrediccionDia? {
        if registros.contains(where: { $0.tipo.esSueño && $0.fin == nil }) { return nil }
        let ventanas = ventanasIdealesDelDia(
            bebe: bebe,
            registros: registros,
            dia: ahora,
            ahora: ahora,
            despertarManual: despertarManual
        )
        
        if let proxima = ventanas.first(where: { !$0.realizada }) {
            if proxima.esNocturna {
                return PrediccionDia(
                    tipo: .noche,
                    desde: proxima.rangoInicioDesde,
                    hasta: proxima.rangoInicioHasta,
                    numero: proxima.numero,
                    ajustadaPorHistorial: horaMediaInicioNoche(registros, hoy: ahora) != nil
                )
            }
            return PrediccionDia(
                tipo: .siesta,
                desde: proxima.rangoInicioDesde,
                hasta: proxima.rangoInicioHasta,
                numero: proxima.numero,
                ajustadaPorHistorial: proxima.ajustadaPorHistorial
            )
        }
        
        return nil
    }
    
    // MARK: - Núcleo del cálculo
    
    private static func calcularVentana(
        desdeDespertar despertar: Date,
        indiceSiesta: Int,
        totalSiestas: Int,
        bebe: Bebe,
        registros: [Registro]
    ) -> Sugerencia {
        let guia = GuiaEdad.para(meses: bebe.edadEnMeses)
        
        let factor: Double = totalSiestas > 1
            ? min(1.0, Double(indiceSiesta) / Double(totalSiestas - 1))
            : 0.5
        
        var base = guia.ventanaMin + (guia.ventanaMax - guia.ventanaMin) * factor
        var amplitud = (guia.ventanaMax - guia.ventanaMin) * 0.15
        var ajustada = false
        
        let observadas = ventanasObservadas(registros, ultimas: 12)
        if observadas.count >= 7 {
            let media = observadas.reduce(0, +) / Double(observadas.count)
            base = base * 0.4 + media * 0.6
            ajustada = true
        }
        
        amplitud = max(35 * 60, amplitud)
        
        return Sugerencia(
            desde: despertar.addingTimeInterval(base - amplitud / 2),
            hasta: despertar.addingTimeInterval(base + amplitud / 2),
            numeroDeSiesta: indiceSiesta + 1,
            ajustadaPorHistorial: ajustada
        )
    }
    
    private static func numeroDeSiestas(_ guia: GuiaEdad) -> Int {
        let suma = guia.siestasTipicas.lowerBound + guia.siestasTipicas.upperBound
        return (suma + 1) / 2
    }
    
    private static func horaInicioNoche(bebe: Bebe, registros: [Registro], dia: Date) -> Date {
        if let media = horaMediaInicioNoche(registros, hoy: dia) {
            return media
        }
        let guia = GuiaEdad.para(meses: bebe.edadEnMeses)
        let cal = Calendar.current
        return cal.date(bySettingHour: guia.bedtimeIdeal, minute: 0, second: 0, of: dia) ?? dia
    }
    
    static func ultimoFinDeSueño(_ registros: [Registro], antesDe fecha: Date) -> Date? {
        registros
            .filter { $0.tipo.esSueño }
            .compactMap(\.fin)
            .filter { $0 <= fecha }
            .max()
    }
    
    static func siestasCompletadasHoy(_ registros: [Registro], ahora: Date) -> Int {
        registros.filter {
            $0.tipo == .siesta && $0.fin != nil && Calendar.current.isDate($0.inicio, inSameDayAs: ahora)
        }.count
    }
    
    private static func ventanasObservadas(_ registros: [Registro], ultimas n: Int) -> [TimeInterval] {
        let sueños = registros
            .filter { $0.tipo.esSueño && $0.fin != nil }
            .sorted { $0.inicio < $1.inicio }
        var huecos: [TimeInterval] = []
        for i in 1..<max(1, sueños.count) {
            guard let finAnterior = sueños[i - 1].fin else { continue }
            let hueco = sueños[i].inicio.timeIntervalSince(finAnterior)
            if hueco > 15 * 60 && hueco < 8 * 3600 { huecos.append(hueco) }
        }
        return Array(huecos.suffix(n))
    }
    
    // MARK: - Sueño acumulado
    
    static func sueñoUltimas24h(_ registros: [Registro], ahora: Date = .now) -> TimeInterval {
        let corte = ahora.addingTimeInterval(-24 * 3600)
        func duracionEnVentana(_ r: Registro) -> TimeInterval {
            let inicio = max(r.inicio, corte)
            let fin = min(r.fin ?? ahora, ahora)
            guard fin > corte, inicio < ahora else { return 0 }
            return max(0, fin.timeIntervalSince(inicio))
        }
        let sueños = registros.filter { $0.tipo.esSueño }
        func caeDentroDeSueño(_ d: Registro) -> Bool {
            let finDespertar = d.fin ?? ahora
            for s in sueños {
                let finSueño = s.fin ?? ahora
                if d.inicio >= s.inicio && finDespertar <= finSueño { return true }
            }
            return false
        }
        let sumaSueño = sueños.reduce(0.0) { $0 + duracionEnVentana($1) }
        let sumaDespertares = registros
            .filter { $0.tipo.restaSueño && caeDentroDeSueño($0) }
            .reduce(0.0) { $0 + duracionEnVentana($1) }
        return max(0, sumaSueño - sumaDespertares)
    }
    
    static func sueñoDelDia(_ registros: [Registro], dia: Date, ahora: Date = .now) -> TimeInterval {
        let cal = Calendar.current
        let inicioDia = cal.startOfDay(for: dia)
        guard let finDia = cal.date(byAdding: .day, value: 1, to: inicioDia) else { return 0 }
        let tope = min(finDia, ahora)
        func duracionEnDia(_ r: Registro) -> TimeInterval {
            let inicio = max(r.inicio, inicioDia)
            let fin = min(r.fin ?? ahora, tope)
            guard fin > inicioDia, inicio < tope else { return 0 }
            return max(0, fin.timeIntervalSince(inicio))
        }
        let sueños = registros.filter { $0.tipo.esSueño }
        func caeDentroDeSueño(_ d: Registro) -> Bool {
            let finDespertar = d.fin ?? ahora
            for s in sueños {
                let finSueño = s.fin ?? ahora
                if d.inicio >= s.inicio && finDespertar <= finSueño { return true }
            }
            return false
        }
        let sumaSueño = sueños.reduce(0.0) { $0 + duracionEnDia($1) }
        let sumaDespertares = registros
            .filter { $0.tipo.restaSueño && caeDentroDeSueño($0) }
            .reduce(0.0) { $0 + duracionEnDia($1) }
        return max(0, sumaSueño - sumaDespertares)
    }
    
    static func balanceDelDia(bebe: Bebe, registros: [Registro], dia: Date, ahora: Date = .now) -> (horas: Double, rango: ClosedRange<Double>, dentro: Bool) {
        let guia = GuiaEdad.para(meses: bebe.edadEnMeses)
        let horas = sueñoDelDia(registros, dia: dia, ahora: ahora) / 3600
        return (horas, guia.sueñoTotalHoras, guia.sueñoTotalHoras.contains(horas))
    }
    
    static func balance(bebe: Bebe, registros: [Registro]) -> (horas: Double, rango: ClosedRange<Double>, dentro: Bool) {
        let guia = GuiaEdad.para(meses: bebe.edadEnMeses)
        let horas = sueñoUltimas24h(registros) / 3600
        return (horas, guia.sueñoTotalHoras, guia.sueñoTotalHoras.contains(horas))
    }
    
    // MARK: - Aprendizaje (7 días)
    
    static func horaMediaInicioNoche(_ registros: [Registro], hoy: Date = .now) -> Date? {
        let cal = Calendar.current
        let corte = cal.date(byAdding: .day, value: -30, to: hoy) ?? hoy
        let candidatos = registros
            .filter { $0.tipo == .noche && $0.inicio >= corte && $0.inicio < hoy }
            .filter {
                let h = cal.component(.hour, from: $0.inicio)
                return h >= 17 && h <= 23
            }
        guard candidatos.count >= 7 else { return nil }
        return promedioHoraDelDia(candidatos.map(\.inicio), en: hoy)
    }
    
    static func horaMediaDespertarMañana(_ registros: [Registro], hoy: Date = .now) -> Date? {
        let cal = Calendar.current
        let corte = cal.date(byAdding: .day, value: -30, to: hoy) ?? hoy
        let candidatos = registros
            .compactMap { r -> Date? in
                guard r.tipo == .noche, let fin = r.fin, fin >= corte, fin < hoy else { return nil }
                let h = cal.component(.hour, from: fin)
                return (h >= 4 && h <= 10) ? fin : nil
            }
        guard candidatos.count >= 7 else { return nil }
        return promedioHoraDelDia(candidatos, en: hoy)
    }
    
    private static func promedioHoraDelDia(_ fechas: [Date], en dia: Date) -> Date? {
        guard !fechas.isEmpty else { return nil }
        let cal = Calendar.current
        let segundos = fechas.map { fecha -> Double in
            let comp = cal.dateComponents([.hour, .minute], from: fecha)
            return Double((comp.hour ?? 0) * 3600 + (comp.minute ?? 0) * 60)
        }
        let media = segundos.reduce(0, +) / Double(segundos.count)
        return cal.date(bySettingHour: Int(media) / 3600,
                        minute: (Int(media) % 3600) / 60,
                        second: 0,
                        of: dia)
    }
    
    // MARK: - Ventanas ideales del día (anillo del reloj)

    static func ventanasIdealesDelDia(bebe: Bebe, registros: [Registro], dia: Date, ahora: Date = .now, despertarManual: Date? = nil) -> [VentanaIdeal] {
        let cal = Calendar.current
        guard cal.isDate(dia, inSameDayAs: ahora) else { return [] }
        // Mientras haya un sueño nocturno EN CURSO (empezara hoy o ayer),
        // ocultamos las siestas del día: solo aparecen al cerrar la noche.
        if registros.contains(where: { $0.tipo == .noche && $0.fin == nil }) { return [] }
        
        let guia = GuiaEdad.para(meses: bebe.edadEnMeses)
        let N = numeroDeSiestas(guia)
        let maxSiestas = max(N, 6) // ← Permitimos evaluar hasta 6 siestas
        guard N > 0 else { return [] }
        
        // Punto de partida: despertar real de la mañana o media o default
        let despertar: Date = {
            let inicioDia = cal.startOfDay(for: dia)
            let mediodia = cal.date(bySettingHour: 12, minute: 0, second: 0, of: dia) ?? dia
            // 1) Despertar real ya ocurrido esta mañana
            if let real = registros
                .filter({ $0.tipo == .noche })
                .compactMap(\.fin)
                .filter({ $0 >= inicioDia && $0 < mediodia })
                .max() {
                return real
            }
            // 2) Sueño nocturno ACTIVO que cruzó la medianoche
            if registros.contains(where: {
                $0.tipo == .noche && $0.fin == nil && !cal.isDate($0.inicio, inSameDayAs: dia)
            }) {
                return ahora
            }
            if let manual = despertarManual,
               cal.isDate(manual, inSameDayAs: dia),
               manual < mediodia {
                return manual
            }
            // 3) Hora media habitual de despertar por la mañana
            if let media = horaMediaDespertarMañana(registros, hoy: dia) { return media }
            return cal.date(bySettingHour: 7, minute: 0, second: 0, of: dia) ?? dia
        }()
        
        let inicioNoche = horaInicioNoche(bebe: bebe, registros: registros, dia: dia)
        let duracionSiesta = guia.duracionSiestaTipica
        let horaCorteNocturna = cal.date(bySettingHour: 20, minute: 30, second: 0, of: dia) ?? dia
        
        var realesRestantes = registros
            .filter { $0.tipo == .siesta && cal.isDate($0.inicio, inSameDayAs: dia) }
            .sorted { $0.inicio < $1.inicio }
        
        var resultado: [VentanaIdeal] = []
        var despertarActual = despertar
        
        // ← BUCLE PRINCIPAL (se abre aquí y se cierra mucho más abajo)
        for i in 0..<maxSiestas {
            let sugerencia = calcularVentana(
                desdeDespertar: despertarActual,
                indiceSiesta: i,
                totalSiestas: N,
                bebe: bebe,
                registros: registros
            )
            
            // Si la ventana cae después de las 20:30, es sueño nocturno
            if sugerencia.desde >= horaCorteNocturna {
                resultado.append(VentanaIdeal(
                    numero: i + 1,
                    rangoInicioDesde: sugerencia.desde,
                    rangoInicioHasta: sugerencia.hasta,
                    duracionTipica: duracionSiesta,
                    inicioReal: nil,
                    finReal: nil,
                    esNocturna: true,
                    ajustadaPorHistorial: sugerencia.ajustadaPorHistorial
                ))
                break
            }
            
            if sugerencia.desde >= inicioNoche.addingTimeInterval(-15 * 60) { break }
            
            let centro = Date(timeIntervalSince1970:
                (sugerencia.desde.timeIntervalSince1970 + sugerencia.hasta.timeIntervalSince1970) / 2)
            
            var inicioReal: Date? = nil
            var finReal: Date? = nil
            if let idx = realesRestantes.firstIndex(where: {
                abs($0.inicio.timeIntervalSince(centro)) <= 90 * 60
            }) {
                let real = realesRestantes.remove(at: idx)
                inicioReal = real.inicio
                finReal = real.fin
            }
            
            resultado.append(VentanaIdeal(
                numero: i + 1,
                rangoInicioDesde: sugerencia.desde,
                rangoInicioHasta: sugerencia.hasta,
                duracionTipica: duracionSiesta,
                inicioReal: inicioReal,
                finReal: finReal,
                ajustadaPorHistorial: sugerencia.ajustadaPorHistorial
            ))
            
            // Para la siguiente: el despertar es el fin (real o simulado)
            if let fReal = finReal {
                despertarActual = fReal
            } else {
                despertarActual = sugerencia.desde.addingTimeInterval(duracionSiesta)
            }
        } // ← CIERRE DEL FOR
        
        // Añadir el sueño nocturno al final
        let ventanaNocturna = guia.ventanaMin + (guia.ventanaMax - guia.ventanaMin) * 1.0
        let horaNocturna = despertarActual.addingTimeInterval(ventanaNocturna)
        let horaMinimaNoche = cal.date(bySettingHour: 17, minute: 0, second: 0, of: dia) ?? dia
        
        let nocheReal = registros.first {
            $0.tipo == .noche && cal.isDate($0.inicio, inSameDayAs: dia)
        }
        
        if horaNocturna >= horaMinimaNoche {
            // Si la última siesta calculada cae después de las 20:30, eliminarla
            if let ultima = resultado.last, ultima.rangoInicioDesde >= horaCorteNocturna {
                resultado.removeLast()
            }
            
            resultado.append(VentanaIdeal(
                numero: resultado.count + 1,
                rangoInicioDesde: horaNocturna,
                rangoInicioHasta: horaNocturna.addingTimeInterval(30 * 60),
                duracionTipica: 10 * 3600,
                inicioReal: nocheReal?.inicio,
                finReal: nocheReal?.fin,
                esNocturna: true,
                ajustadaPorHistorial: horaMediaInicioNoche(registros, hoy: dia) != nil
            ))
        }
        
        return resultado
    }
}