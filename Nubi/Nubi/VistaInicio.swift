import SwiftUI

struct VistaInicio: View {
    @EnvironmentObject private var almacen: Almacen
    @EnvironmentObject private var suscripcion: Suscripcion
    @AppStorage("modoOscuro") private var modoOscuro = false
    
    @State private var ahora: Date = .now
    @State private var mostrarPaywall = false
    @State private var mostrarAjustes = false
    @State private var mostrarMenuPecho = false
    
    private let latido = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                cabecera
                
                if suscripcion.debeAvisar, let d = suscripcion.diasRestantes {
                    AvisoPrueba(dias: d, mostrarPaywall: $mostrarPaywall)
                }
                
                tarjetaSueño
                
                if let ventana = almacen.proximaVentana {
                    tarjetaPrediccion(ventana)
                }
                
                HStack(spacing: 12) {
                    tarjetaAlimentacion
                    tarjetaPanal
                }
                
                //tarjetaBalance
                
                //aviso
            }
            .padding(Theme.margen)
            .padding(.bottom, 8)
        }
        .background(Theme.lienzo.ignoresSafeArea())
        .onReceive(latido) { ahora = $0 }
        .sheet(isPresented: $mostrarPaywall) { Paywall() }
        .sheet(isPresented: $mostrarAjustes) { VistaAjustes() }
    }
    
    // MARK: Cabecera
    
    private var cabecera: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(saludo)
                    .font(Theme.cuerpo(14))
                    .foregroundStyle(Theme.tintaSuave)
                
                if let bebe = almacen.bebe {
                    Text(bebe.nombre)
                        .font(Theme.display(34))
                        .foregroundStyle(Theme.tinta)
                    
                    Text(bebe.edadLegible)
                        .font(Theme.cuerpo(13))
                        .foregroundStyle(Theme.tintaTenue)
                }
            }
            
            Spacer()
            
            // Botón de modo oscuro/claro
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    modoOscuro.toggle()
                }
            } label: {
                Image(systemName: modoOscuro ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(modoOscuro ? Theme.mantequilla : Theme.indigo)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(modoOscuro ? Theme.tinta.opacity(0.15) : Theme.lila.opacity(0.25))
                    )
            }
            .buttonStyle(.plain)
            
            BotonIcono(simbolo: .ajustes, color: Theme.lila.opacity(0.35), diametro: 42) {
                mostrarAjustes = true
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
    
    private var saludo: String {
        switch Calendar.current.component(.hour, from: ahora) {
        case 5..<12:  return L10n.t("Buenos días")
        case 12..<20: return L10n.t("Buenas tardes")
        default:      return L10n.t("Buenas noches")
        }
    }
    
    // MARK: Sueño
    
    @ViewBuilder
    private var tarjetaSueño: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                if let sueño = almacen.sueñoEnCurso {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            EtiquetaSeccion(texto: sueño.tipo.titulo)
                            
                            Text(Fmt.duracion(ahora.timeIntervalSince(sueño.inicio)))
                                .font(Theme.display(42))
                                .foregroundStyle(Theme.tinta)
                                .monospacedDigit()
                            
                            Text(L10n.t("Dormido desde") + " \(Fmt.hora(sueño.inicio))")
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                        }
                        
                        Spacer()
                        
                        Insignia(
                            simbolo: sueño.tipo.simbolo,
                            fondo: sueño.tipo.color,
                            diametro: 54
                        )
                    }
                    
                    Boton(titulo: L10n.t("Se ha despertado"), simbolo: .sol, color: Theme.melocoton) {
                        withAnimation {
                            almacen.terminarSueño(en: .now)
                        }
                    }
                } else {
                    EtiquetaSeccion(texto: L10n.t("Sueño"))
                    
                    Text(textoDespierto)
                        .font(Theme.cuerpo(14))
                        .foregroundStyle(Theme.tintaSuave)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 10) {
                        Boton(titulo: L10n.t("Siesta"), simbolo: .nube, color: Theme.menta) {
                            withAnimation { almacen.empezarSueño(.siesta) }
                        }
                        
                        Boton(titulo: L10n.t("Noche"), simbolo: .luna, color: Theme.lila) {
                            withAnimation { almacen.empezarSueño(.noche) }
                        }
                    }
                }
            }
        }
    }
    
    private var textoDespierto: String {
        guard let ultimo = MotorSueño.ultimoFinDeSueño(almacen.registros, antesDe: ahora) else {
            return L10n.t("Aún no hay ningún sueño registrado. Empieza por el primero.")
        }
        
        return L10n.t("Despierto desde") + " \(Fmt.hora(ultimo)) · \(Fmt.duracion(ahora.timeIntervalSince(ultimo)))"
    }
    
    // MARK: Predicción
    
    private func tarjetaPrediccion(_ v: Sugerencia) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    EtiquetaSeccion(
                        texto: v.numeroDeSiesta == 1
                        ? "Próxima siesta"
                        : "Siesta \(v.numeroDeSiesta)"
                    )
                    
                    Spacer()
                    
                    if suscripcion.tieneAcceso && v.ajustadaPorHistorial {
                        Pastilla(texto: "A su ritmo", color: Theme.menta)
                    }
                }
                
                if suscripcion.tieneAcceso {
                    Text("\(Fmt.hora(v.desde)) – \(Fmt.hora(v.hasta))")
                        .font(Theme.display(32))
                        .foregroundStyle(Theme.tinta)
                        .monospacedDigit()
                    
                    Text(mensajePrediccion(v))
                        .font(Theme.cuerpo(13))
                        .foregroundStyle(Theme.tintaSuave)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 10) {
                        Text("--:-- – --:--")
                            .font(Theme.display(32))
                            .foregroundStyle(Theme.tintaTenue)
                            .monospacedDigit()
                        
                        Insignia(simbolo: .candado, fondo: Theme.lila, diametro: 30)
                    }
                    
                    Text("Nubi ya ha calculado la ventana con los datos de \(almacen.bebe?.nombre ?? "tu bebé"). Desbloquéala para verla.")
                        .font(Theme.cuerpo(13))
                        .foregroundStyle(Theme.tintaSuave)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Boton(titulo: suscripcion.textoLlamada, color: Theme.lila) {
                        mostrarPaywall = true
                    }
                }
            }
        }
    }
    
    private func mensajePrediccion(_ v: Sugerencia) -> String {
        let base: String
        
        if v.yaEnVentana {
            base = "Está en su mejor momento para dormir."
        } else if v.pasada {
            base = "La ventana ya ha pasado."
        } else {
            base = "Dentro de \(Fmt.duracion(v.desde.timeIntervalSince(ahora)))."
        }
        
        return v.ajustadaPorHistorial ? base : base + " Estimado por su edad."
    }
    
    // MARK: Alimentación
    
    private var tarjetaAlimentacion: some View {
        Tarjeta(relleno: 16) {
            VStack(alignment: .leading, spacing: 12) {
                EtiquetaSeccion(texto: L10n.t("Toma"))
                
                if let toma = almacen.tomaEnCurso {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(toma.tituloVisible)
                            .font(Theme.display(19))
                            .foregroundStyle(Theme.tinta)
                        
                        Text(Fmt.duracion(ahora.timeIntervalSince(toma.inicio)))
                            .font(Theme.display(24))
                            .foregroundStyle(Theme.tinta)
                            .monospacedDigit()
                        
                        Text(L10n.t("Empezó a las") + " \(Fmt.hora(toma.inicio))")
                            .font(Theme.cuerpo(11))
                            .foregroundStyle(Theme.tintaTenue)
                    }
                    
                    Boton(
                        titulo: L10n.t("Terminar toma"),
                        simbolo: .check,
                        color: Theme.melocoton,
                        compacto: true
                    ) {
                        withAnimation {
                            almacen.terminarToma()
                        }
                    }
                } else {
                    if let ultima = almacen.ultimaAlimentacion {
                        Text(Fmt.tiempoDesde(ultima.inicio, hasta: ahora))
                            .font(Theme.display(19))
                            .foregroundStyle(Theme.tinta)
                        
                        Text(textoUltimaAlimentacion(ultima))
                            .font(Theme.cuerpo(11))
                            .foregroundStyle(Theme.tintaTenue)
                            .lineLimit(2)
                    } else {
                        Text(L10n.t("Sin registrar"))
                            .font(Theme.display(19))
                            .foregroundStyle(Theme.tintaTenue)
                        
                        Text(L10n.t("Toca para anotar la primera"))
                            .font(Theme.cuerpo(11))
                            .foregroundStyle(Theme.tintaTenue)
                    }
                    
                    HStack(spacing: 8) {
                        BotonIcono(
                            simbolo: .biberon,
                            color: Theme.mantequilla,
                            diametro: 38
                        ) {
                            almacen.registrarEvento(.biberon)
                        }
                        .accessibilityLabel(L10n.t("Biberón"))
                        
                        // Botón de pecho con menú
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                mostrarMenuPecho.toggle()
                            }
                        } label: {
                            Insignia(
                                simbolo: .corazon,
                                fondo: Theme.melocoton,
                                diametro: 38
                            )
                        }
                        .buttonStyle(BotonPresionable())
                        .popover(isPresented: $mostrarMenuPecho, arrowEdge: .top) {
                            MenuPecho { lado in
                                accionPecho(lado)
                                withAnimation { mostrarMenuPecho = false }
                            }
                            .frame(width: 220)
                            .presentationCompactAdaptation(.popover)
                        }
                        .accessibilityLabel(L10n.t("Pecho"))
                        
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
    
    private func accionPecho(_ lado: LadoPecho) {
        if let actual = almacen.tomaEnCurso, actual.lado == lado {
            withAnimation {
                almacen.terminarToma()
            }
        } else {
            withAnimation {
                almacen.empezarToma(lado)
            }
        }
    }
    
    private func textoUltimaAlimentacion(_ r: Registro) -> String {
        var partes: [String] = []
        
        partes.append(r.tituloVisible)
        
        if let d = r.duracion, d >= 60 {
            partes.append(Fmt.duracion(d))
        }
        
        partes.append(Fmt.hora(r.inicio))
        
        return partes.joined(separator: " · ")
    }
    
    // MARK: Pañal
    
    private var tarjetaPanal: some View {
        Tarjeta(relleno: 16) {
            VStack(alignment: .leading, spacing: 12) {
                EtiquetaSeccion(texto: L10n.t("Pañal"))
                
                if let ultimo = almacen.ultimoPanal {
                    Text(Fmt.tiempoDesde(ultimo.inicio, hasta: ahora))
                        .font(Theme.display(19))
                        .foregroundStyle(Theme.tinta)
                    
                    Text(L10n.t("Último a las") + " \(Fmt.hora(ultimo.inicio))")
                        .font(Theme.cuerpo(11))
                        .foregroundStyle(Theme.tintaTenue)
                } else {
                    Text(L10n.t("Sin registrar"))
                        .font(Theme.display(19))
                        .foregroundStyle(Theme.tintaTenue)
                    
                    Text(L10n.t("Toca para anotar el primero"))
                        .font(Theme.cuerpo(11))
                        .foregroundStyle(Theme.tintaTenue)
                }
                
                HStack {
                    BotonIcono(simbolo: .hoja, color: Theme.cielo, diametro: 40) {
                        almacen.registrarEvento(.panal)
                    }
                    
                    Spacer(minLength: 0)
                }
            }
        }
    }
    
    // MARK: Balance
    
    /*@ViewBuilder
    private var tarjetaBalance: some View {
        if let bebe = almacen.bebe, !almacen.registros.isEmpty {
            let b = MotorSueño.balance(bebe: bebe, registros: almacen.registros)
            let horasFormateadas = String(format: "%.1f", b.horas)
            
            Tarjeta {
                VStack(alignment: .leading, spacing: 12) {
                    EtiquetaSeccion(texto: L10n.t("Últimas 24 horas"))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(horasFormateadas) h")
                            .font(Theme.display(34))
                            .foregroundStyle(Theme.tinta)
                            .monospacedDigit()
                        
                        Text(b.dentro ? L10n.t("dentro de lo habitual") : L10n.t("fuera del rango típico"))
                            .font(Theme.cuerpo(12))
                            .foregroundStyle(b.dentro ? Theme.tintaSuave : Theme.indigo)
                    }
                    
                    BarraRango(valor: b.horas, rango: b.rango)
                    
                    HStack {
                        Text("\(Fmt.numero(b.rango.lowerBound, 0))h")
                            .font(Theme.cuerpo(10))
                            .foregroundStyle(Theme.tintaTenue)
                        
                        Spacer()
                        
                        Text("\(Fmt.numero(b.rango.upperBound, 0))h")
                            .font(Theme.cuerpo(10))
                            .foregroundStyle(Theme.tintaTenue)
                    }
                    
                    Text(L10n.sueleDormir(Fmt.numero(b.rango.lowerBound, 0), Fmt.numero(b.rango.upperBound, 0)))
                        .font(Theme.cuerpo(12))
                        .foregroundStyle(Theme.tintaTenue)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    private var aviso: some View {
        Text("Nubi ofrece orientación basada en patrones. No es consejo médico ni sustituye a tu pediatra.")
            .font(Theme.cuerpo(11))
            .foregroundStyle(Theme.tintaTenue)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }
}*/

/// Barra que sitúa un valor dentro de un rango esperado.
struct BarraRango: View {
    let valor: Double
    let rango: ClosedRange<Double>
    
    var body: some View {
        GeometryReader { geo in
            let ancho = geo.size.width
            
            let lo = max(0, rango.lowerBound - 2)
            let hi = rango.upperBound + 2
            let rangoTotal = hi - lo
            
            let valorClampado = min(max(valor, lo), hi)
            let pos = CGFloat((valorClampado - lo) / rangoTotal) * ancho
            
            let x0 = CGFloat((rango.lowerBound - lo) / rangoTotal) * ancho
            let x1 = CGFloat((rango.upperBound - lo) / rangoTotal) * ancho
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.tintaTenue.opacity(0.3))
                    .frame(height: 10)
                
                Capsule()
                    .fill(Theme.menta)
                    .frame(width: max(4, x1 - x0), height: 10)
                    .offset(x: x0)
                
                ZStack {
                    Circle()
                        .fill(Theme.superficie)
                        .overlay(Circle().strokeBorder(Theme.indigo, lineWidth: 3))
                        .frame(width: 18, height: 18)
                        .shadow(color: Theme.indigo.opacity(0.3), radius: 4, y: 2)
                }
                .offset(x: min(max(pos - 9, 0), ancho - 18))
            }
        }
        .frame(height: 18)
        .padding(.vertical, 4)
    }
}
}
