import SwiftUI

/// El día como un reloj de 24 horas: medianoche arriba, mediodía abajo.
/// El anillo representa el cielo: noche negra con estrellas arriba,
/// día azul con nubes abajo.
struct RelojDelDia: View {
    let intervalos: [Registro]
    let eventos: [Registro]
    let dia: Date
    var ventana: Sugerencia?
    var ahora: Date = .now
    var alTocarEvento: ((Registro) -> Void)? = nil
    
    private let grosor: CGFloat = 30
    
    var body: some View {
        GeometryReader { geo in
            let lado = min(geo.size.width, geo.size.height)
            
            let rExterior = lado / 2 - 20
            let rAnillo = rExterior - grosor / 2
            let rEventos = rAnillo - grosor / 2 - 18
            
            ZStack {
                anilloCielo(rAnillo, lado: lado)
                marcasHorarias(rAnillo)
                arcosDeSueño(rAnillo)
                
                if let ventana {
                    arcoVentana(ventana, radio: rExterior + 7)
                }
                
                puntosDeEventos(rEventos, lado: lado)
                
                if esHoy {
                    aguja(rExterior)
                }
                
                etiquetasHorarias(rExterior + 13, lado: lado)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var esHoy: Bool {
        Calendar.current.isDateInToday(dia)
    }
    
    // MARK: - Anillo (cielo día/noche con estrellas, nubes y bordes)
    
    private func anilloCielo(_ r: CGFloat, lado: CGFloat) -> some View {
        ZStack {
            // El cielo: noche negra arriba, día TODO azul abajo
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(hex: 0x14122B), location: 0.00), // 00h noche
                            .init(color: Color(hex: 0x14122B), location: 0.21), // ~05h noche
                            .init(color: Theme.melocoton,      location: 0.28), // amanecer
                            .init(color: Theme.cielo,          location: 0.35), // mañana
                            .init(color: Theme.cielo,          location: 0.65), // tarde
                            .init(color: Theme.melocoton,      location: 0.72), // atardecer
                            .init(color: Color(hex: 0x14122B), location: 0.80), // ~19h noche
                            .init(color: Color(hex: 0x14122B), location: 1.00), // 24h noche
                        ]),
                        center: .center,
                        angle: .degrees(-90)
                    ),
                    lineWidth: grosor
                )
                .frame(width: r * 2, height: r * 2)
            
            // Estrellas en la zona nocturna
            estrellas(r, lado: lado)
            
            // Nubes en la zona diurna
            nubes(r, lado: lado)
            
            // Borde exterior e interior del anillo
            Circle()
                .stroke(Theme.lila.opacity(0.8), lineWidth: 1.5)
                .frame(width: (r + grosor / 2) * 2, height: (r + grosor / 2) * 2)
            
            Circle()
                .stroke(Theme.lila.opacity(0.8), lineWidth: 1.5)
                .frame(width: (r - grosor / 2) * 2, height: (r - grosor / 2) * 2)
        }
    }
    
    /// Puntos de estrella fijos en el tramo nocturno del anillo.
    private func estrellas(_ r: CGFloat, lado: CGFloat) -> some View {
        let datos: [(h: Double, off: CGFloat, s: CGFloat, o: Double)] = [
            (21.2, -7, 2.0, 0.9), (21.9, 5, 1.4, 0.6), (22.6, -2, 2.4, 1.0),
            (23.3, 7, 1.4, 0.6), (23.9, -6, 1.8, 0.8), (0.6, 4, 2.2, 0.9),
            (1.4, -5, 1.4, 0.6), (2.1, 6, 2.0, 0.9), (2.9, -3, 1.4, 0.7),
            (3.7, 5, 2.2, 0.9), (4.4, -6, 1.4, 0.6)
        ]
        
        return ForEach(datos.indices, id: \.self) { i in
            let d = datos[i]
            Circle()
                .fill(.white.opacity(d.o))
                .frame(width: d.s, height: d.s)
                .position(punto(hora: d.h, radio: r + d.off, lado: lado))
        }
    }
    
    /// Nubes pequeñas fijas en el tramo diurno del anillo.
    private func nubes(_ r: CGFloat, lado: CGFloat) -> some View {
        let datos: [(h: Double, off: CGFloat, s: CGFloat, o: Double)] = [
            (8.6, -6, 1.0, 0.75), (10.3, 5, 0.75, 0.55), (12.0, -4, 1.1, 0.8),
            (13.7, 6, 0.75, 0.55), (15.4, -5, 1.0, 0.7), (16.8, 4, 0.7, 0.5)
        ]
        
        return ForEach(datos.indices, id: \.self) { i in
            let d = datos[i]
            nube(size: 12 * d.s)
                .opacity(d.o)
                .position(punto(hora: d.h, radio: r + d.off, lado: lado))
        }
    }
    
    /// Formita de nube: cápsula + dos círculos encima.
    private func nube(size: CGFloat) -> some View {
        ZStack {
            Capsule()
                .frame(width: size, height: size * 0.45)
            
            Circle()
                .frame(width: size * 0.5, height: size * 0.5)
                .offset(x: -size * 0.18, y: -size * 0.22)
            
            Circle()
                .frame(width: size * 0.4, height: size * 0.4)
                .offset(x: size * 0.2, y: -size * 0.15)
        }
        .foregroundStyle(.white)
    }
    
    private func marcasHorarias(_ r: CGFloat) -> some View {
        ForEach(0..<24, id: \.self) { h in
            Capsule()
                .fill(.white.opacity(h % 6 == 0 ? 0.95 : 0.35))
                .frame(width: h % 6 == 0 ? 2 : 1.2, height: h % 6 == 0 ? 11 : 5)
                .offset(y: -r)
                .rotationEffect(.degrees(Double(h) / 24 * 360))
        }
    }
    
    // MARK: - Sueños (con contorno blanco reforzado para que siempre se vean)
    
    private func arcosDeSueño(_ r: CGFloat) -> some View {
        ForEach(intervalos) { reg in
            let tramo = horas(de: reg)
            
            ArcoReloj(desde: tramo.desde, hasta: tramo.hasta, radio: r)
                .stroke(
                    reg.tipo.color,
                    style: StrokeStyle(lineWidth: grosor - 7, lineCap: .round)
                )
                .overlay(
                    ArcoReloj(desde: tramo.desde, hasta: tramo.hasta, radio: r)
                        .stroke(
                            .white.opacity(0.7),
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                        )
                )
        }
    }
    
    private func arcoVentana(_ s: Sugerencia, radio: CGFloat) -> some View {
        let d = hora(s.desde)
        let h = max(hora(s.hasta), d + 0.2)
        
        return ArcoReloj(desde: d, hasta: h, radio: radio)
            .stroke(
                Theme.indigo.opacity(0.75),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 5])
            )
    }
    
    // MARK: - Eventos puntuales
    
    private struct PuntoEvento: Identifiable {
        let id: UUID
        let registro: Registro
        let posicion: CGPoint
    }
    
    private func puntosDeEventos(_ rBase: CGFloat, lado: CGFloat) -> some View {
        let puntos = posicionesEventos(rBase: rBase, lado: lado)
        
        return ForEach(puntos) { p in
            Button {
                alTocarEvento?(p.registro)
            } label: {
                ZStack {
                    Circle()
                        .fill(p.registro.tipo.color)
                        .overlay(Circle().strokeBorder(Theme.superficie, lineWidth: 2))
                    
                    Ilus(p.registro.tipo.simbolo, 13, color: Theme.tinta)
                }
                .frame(width: 26, height: 26)
                .shadow(color: Theme.sombra, radius: 3, y: 1)
            }
            .buttonStyle(BotonPresionable())
            .position(p.posicion)
        }
    }
    
    private func posicionesEventos(rBase: CGFloat, lado: CGFloat) -> [PuntoEvento] {
        var resultado: [PuntoEvento] = []
        
        let ordenados = eventos.sorted {
            if $0.inicio != $1.inicio {
                return $0.inicio < $1.inicio
            }
            return ordenDeTipo($0.tipo) < ordenDeTipo($1.tipo)
        }
        
        for registro in ordenados {
            let h = hora(registro.inicio)
            
            var radio = rBase
            var p = punto(hora: h, radio: radio, lado: lado)
            
            var intentos = 0
            
            while colisiona(p, con: resultado) && intentos < 14 {
                if radio > 50 {
                    radio -= 12
                    p = punto(hora: h, radio: radio, lado: lado)
                } else {
                    let desplazamientos: [Double] = [
                        0.14, -0.14,
                        0.28, -0.28,
                        0.42, -0.42,
                        0.56, -0.56,
                        0.70, -0.70
                    ]
                    
                    let desplazamiento = desplazamientos[intentos % desplazamientos.count]
                    
                    p = punto(
                        hora: horaEnvuelta(h + desplazamiento),
                        radio: radio,
                        lado: lado
                    )
                }
                
                intentos += 1
            }
            
            resultado.append(
                PuntoEvento(id: registro.id, registro: registro, posicion: p)
            )
        }
        
        return resultado
    }
    
    private func colisiona(_ p: CGPoint, con puntos: [PuntoEvento]) -> Bool {
        puntos.contains {
            let dx = $0.posicion.x - p.x
            let dy = $0.posicion.y - p.y
            return dx * dx + dy * dy < 20 * 20
        }
    }
    
    private func ordenDeTipo(_ tipo: TipoRegistro) -> Int {
        switch tipo {
        case .biberon: return 0
        case .pecho:   return 1
        case .panal:   return 2
        default:       return 3
        }
    }
    
    private func horaEnvuelta(_ h: Double) -> Double {
        let r = h.truncatingRemainder(dividingBy: 24)
        return r < 0 ? r + 24 : r
    }
    
    // MARK: - Aguja y etiquetas
    
    private func aguja(_ r: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(Theme.tinta)
                .frame(width: 2.5, height: r)
                .offset(y: -r / 2)
                .rotationEffect(.degrees(hora(ahora) / 24 * 360))
            
            Circle()
                .fill(Theme.tinta)
                .frame(width: 9, height: 9)
        }
    }
    
    private func etiquetasHorarias(_ r: CGFloat, lado: CGFloat) -> some View {
        ForEach([0, 3, 6, 9, 12, 15, 18, 21], id: \.self) { h in
            Text(String(format: "%02d", h))
                .font(Theme.cuerpo(11, h % 6 == 0 ? .semibold : .regular))
                .foregroundStyle(h % 6 == 0 ? Theme.tintaSuave : Theme.tintaTenue)
                .position(punto(hora: Double(h), radio: r, lado: lado))
        }
    }
    
    // MARK: - Geometría
    
    private func hora(_ fecha: Date) -> Double {
        let inicioDia = Calendar.current.startOfDay(for: dia)
        let h = fecha.timeIntervalSince(inicioDia) / 3600
        return min(max(h, 0), 24)
    }
    
    /// Recorta el sueño al día mostrado.
    /// Un sueño de ayer 21:00 a hoy 06:19, en el reloj de HOY se dibuja
    /// de 00:00 a 06:19, y en el de AYER de 21:00 a 24:00.
    private func horas(de r: Registro) -> (desde: Double, hasta: Double) {
        let cal = Calendar.current
        let inicioDia = cal.startOfDay(for: dia)
        
        guard let finDia = cal.date(byAdding: .day, value: 1, to: inicioDia) else {
            return (0, 0.2)
        }
        
        let inicioClampado = max(r.inicio, inicioDia)
        let finClampado = min(r.fin ?? ahora, finDia)
        
        guard inicioClampado < finClampado else {
            return (0, 0.2)
        }
        
        let desde = inicioClampado.timeIntervalSince(inicioDia) / 3600
        let hasta = finClampado.timeIntervalSince(inicioDia) / 3600
        
        return (desde, max(hasta, min(desde + 0.2, 24)))
    }
    
    private func punto(hora: Double, radio: CGFloat, lado: CGFloat) -> CGPoint {
        let ang: Double = hora / 24 * 2 * Double.pi - Double.pi / 2
        
        return CGPoint(
            x: lado / 2 + radio * CGFloat(cos(ang)),
            y: lado / 2 + radio * CGFloat(sin(ang))
        )
    }
}

/// Arco entre dos horas del día sobre una circunferencia de radio fijo.
struct ArcoReloj: Shape {
    let desde: Double
    let hasta: Double
    let radio: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var p = Path()
        
        p.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radio,
            startAngle: .degrees(desde / 24 * 360 - 90),
            endAngle: .degrees(hasta / 24 * 360 - 90),
            clockwise: false
        )
        
        return p
    }
}