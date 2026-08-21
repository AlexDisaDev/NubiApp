import SwiftUI

struct VistaInicio: View {
    @EnvironmentObject private var almacen: Almacen
    @EnvironmentObject private var suscripcion: Suscripcion
    //@EnvironmentObject private var l10n: L10n
    @AppStorage("modoOscuro") private var modoOscuro = false
    @State private var ahora: Date = .now
    @State private var mostrarPaywall = false
    @State private var mostrarAjustes = false
    @State private var mostrarMenuPecho = false
    @State private var mostrarHojaDespertar = false
    @State private var mostrarHojaBiberon = false
    @State private var mostrarPopoverPanal = false
    @State private var panalPis = true
    @State private var panalCaca = false
    @State private var configFinSueño: ConfigFinSueño? = nil
    private let latido = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                cabecera
                if suscripcion.debeAvisar, let d = suscripcion.diasRestantes {
                    AvisoPrueba(dias: d, mostrarPaywall: $mostrarPaywall)
                }
                tarjetaSueño
                if let prediccion = almacen.prediccionDelDia {
                    if suscripcion.tieneAcceso || Sincronizador.compartido.esParticipante {
                        tarjetaPrediccion(prediccion)
                    } else {
                        BloqueoPremium(
                            titulo: L10n.t("Predicción de ventanas"),
                            texto: L10n.t("Nubi calcula cuándo le tocará la próxima siesta según el ritmo real de tu bebé. Con Nubi completo lo ves aquí y en el reloj del día."),
                            mostrarPaywall: $mostrarPaywall
                        )
                    }
                }
                tarjetaAlimentacion
                tarjetaPanal
            }
            .padding(Theme.margen)
            .padding(.bottom, 8)
        }
        .background(Theme.lienzo.ignoresSafeArea())
        .onReceive(latido) { ahora = $0 }
        .onChange(of: almacen.hojaFinSueñoPendiente) { _, nuevo in
            guard let tipo = nuevo else { return }
            almacen.hojaFinSueñoPendiente = nil
            switch tipo {
            case "siesta":
                if let sueño = almacen.sueñoEnCurso, sueño.tipo == .siesta {
                    configFinSueño = ConfigFinSueño(tipo: .siesta, inicio: sueño.inicio, titulo: L10n.t("ha despertado"))
                }
            case "noche":
                if let sueño = almacen.sueñoEnCurso, sueño.tipo == .noche {
                    configFinSueño = ConfigFinSueño(tipo: .noche, inicio: sueño.inicio, titulo: L10n.t("Fin de la noche"))
                }
            case "despertar":
                if let despertar = almacen.despertarEnCurso {
                    configFinSueño = ConfigFinSueño(tipo: .despertar, inicio: despertar.inicio, titulo: L10n.t("Fin del despertar"))
                }
            default:
                break
            }
        }
        .sheet(isPresented: $mostrarPaywall) { Paywall() }
        .sheet(isPresented: $mostrarAjustes) { VistaAjustes() }
        .sheet(isPresented: $mostrarHojaDespertar) { HojaDespertar(dia: .now) }
        .sheet(isPresented: $mostrarHojaBiberon) { HojaBiberon() }
        .sheet(item: $configFinSueño) { config in HojaFinSueño(config: config) }
    }

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
                    Text(Fmt.edadCompletaEnFecha(ahora, nacimiento: bebe.fechaNacimiento, semanasPrematuro: bebe.semanasPrematuro))
                        .font(Theme.cuerpo(13))
                        .foregroundStyle(Theme.tintaTenue)
                }
            }
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { modoOscuro.toggle() }
            } label: {
                Image(systemName: modoOscuro ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(modoOscuro ? Theme.mantequilla : Theme.indigo)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(modoOscuro ? Theme.tinta.opacity(0.15) : Theme.lila.opacity(0.25)))
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

    @ViewBuilder
    private var tarjetaSueño: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                if let despertar = almacen.despertarEnCurso {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            EtiquetaSeccion(texto: L10n.t("Despertar nocturno"))
                            Text(Fmt.duracion(ahora.timeIntervalSince(despertar.inicio)))
                                .font(Theme.display(42))
                                .foregroundStyle(Theme.coral)
                                .monospacedDigit()
                            Text(L10n.t("Despierto desde") + " \(Fmt.hora(despertar.inicio))")
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                        }
                        Spacer()
                        Insignia(simbolo: .lunaOjoAbierto, fondo: Theme.coral, diametro: 54)
                    }
                    HStack(spacing: 10) {
                        Boton(titulo: L10n.t("Volvió a dormir"), simbolo: .luna, color: Theme.lila) {
                            withAnimation { _ = almacen.volverADormir() }
                        }
                        Boton(titulo: L10n.t("Fin de la noche"), simbolo: .sol, color: Theme.melocoton) {
                            configFinSueño = ConfigFinSueño(tipo: .despertar, inicio: despertar.inicio, titulo: L10n.t("Fin del despertar"))
                        }
                    }
                } else if let sueño = almacen.sueñoEnCurso {
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
                        Insignia(simbolo: sueño.tipo.simbolo, fondo: sueño.tipo.color, diametro: 54)
                    }
                    if sueño.tipo == .noche {
                        HStack(spacing: 10) {
                            Boton(titulo: L10n.t("Despertar nocturno"), simbolo: .lunaOjoAbierto, color: Theme.coral) {
                                withAnimation { _ = almacen.empezarDespertar() }
                            }
                            Boton(titulo: L10n.t("ha despertado"), simbolo: .sol, color: Theme.melocoton) {
                                configFinSueño = ConfigFinSueño(tipo: .noche, inicio: sueño.inicio, titulo: L10n.t("Fin de la noche"))
                            }
                        }
                    } else {
                        Boton(titulo: L10n.t("ha despertado"), simbolo: .sol, color: Theme.melocoton) {
                            configFinSueño = ConfigFinSueño(tipo: .siesta, inicio: sueño.inicio, titulo: L10n.t("ha despertado"))
                        }
                    }
                } else {
                    EtiquetaSeccion(texto: L10n.t("Sueño"))
                    Text(textoDespierto)
                        .font(Theme.cuerpo(14))
                        .foregroundStyle(Theme.tintaSuave)
                    HStack(spacing: 10) {
                        Boton(titulo: L10n.t("Siesta"), simbolo: .nube, color: Theme.menta) {
                            withAnimation { almacen.empezarSueño(.siesta) }
                        }
                        Boton(titulo: L10n.t("Sueño nocturno"), simbolo: .luna, color: Theme.lila) {
                            withAnimation { almacen.empezarSueño(.noche) }
                        }
                    }
                }
            }
        }
    }

    private var textoDespierto: String {
        guard let ultimoDespertar = MotorSueño.ultimoFinDeSueño(almacen.registros, antesDe: ahora) else {
            return L10n.t("Aún no hay ningún sueño registrado. Empieza por el primero.")
        }
        return L10n.t("Despierto desde") + " \(Fmt.hora(ultimoDespertar)) · \(Fmt.duracion(ahora.timeIntervalSince(ultimoDespertar)))"
    }

    private func tarjetaPrediccion(_ p: PrediccionDia) -> some View {
        Tarjeta(relleno: 14) {
            HStack(spacing: 12) {
                Insignia(
                    simbolo: p.tipo == .noche ? .luna : .reloj,
                    fondo: p.tipo == .noche ? Theme.lila.opacity(0.25) : Theme.indigo.opacity(0.15),
                    diametro: 40,
                    tinta: p.tipo == .noche ? Theme.lila : Theme.indigo
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(textoPrediccion(p))
                        .font(Theme.cuerpo(13, .semibold))
                        .foregroundStyle(Theme.tinta)
                    Text(subtituloPrediccion(p))
                        .font(Theme.cuerpo(11))
                        .foregroundStyle(Theme.tintaTenue)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func textoPrediccion(_ p: PrediccionDia) -> String {
        switch p.tipo {
        case .siesta:
            if p.yaEnVentana {
                return L10n.t("Buena ventana ahora") + " · " + L10n.t("hasta") + " " + Fmt.hora(p.hasta)
            }
            if p.pasada {
                return L10n.t("Se ha pasado la ventana ideal")
            }
            return L10n.t("Próxima siesta") + " · " + Fmt.hora(p.desde) + " – " + Fmt.hora(p.hasta)
        case .noche:
            if p.yaEnVentana || p.pasada {
                return L10n.t("Es hora de dormir 🌙")
            }
            return L10n.t("Sueño nocturno") + " · " + Fmt.hora(p.desde)
        }
    }

    private func subtituloPrediccion(_ p: PrediccionDia) -> String {
        switch p.tipo {
        case .siesta:
            return p.ajustadaPorHistorial ? L10n.t("Ajustado a su ritmo real") : L10n.t("Basado en su edad")
        case .noche:
            if p.yaEnVentana || p.pasada {
                return L10n.t("Última ventana del día")
            }
            let restante = p.desde.timeIntervalSince(ahora)
            if restante > 0 {
                return L10n.t("En") + " " + Fmt.duracion(restante) + " " + L10n.t("· última siesta hecha")
            }
            return L10n.t("Última ventana del día")
        }
    }

    @ViewBuilder
    private var tarjetaAlimentacion: some View {
        Tarjeta(relleno: 14) {
            if let toma = almacen.tomaEnCurso {
                filaTomaEnCurso(toma)
            } else {
                filaUltimaToma
            }
        }
    }

    private func filaTomaEnCurso(_ toma: Registro) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(toma.tituloVisible + " · " + L10n.t("en curso"))
                    .font(Theme.cuerpo(13, .semibold))
                    .foregroundStyle(Theme.tinta)
                    .lineLimit(1)
                Text(Fmt.duracion(ahora.timeIntervalSince(toma.inicio)) + " · " + L10n.t("desde") + " " + Fmt.hora(toma.inicio))
                    .font(Theme.cuerpo(11))
                    .foregroundStyle(Theme.tintaTenue)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if toma.tipo == .pecho {
                bloqueCambioPecho(actual: toma.lado)
            }
            Button {
                withAnimation { almacen.terminarToma() }
            } label: {
                Ilus(.check, 18, color: Theme.tinta)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Theme.menta))
            }
            .buttonStyle(BotonPresionable())
            .accessibilityLabel(L10n.t("Terminar toma"))
        }
        .frame(minHeight: 56)
    }

    private func bloqueCambioPecho(actual: LadoPecho?) -> some View {
        Button {
            withAnimation { _ = almacen.cambiarPecho() }
        } label: {
            HStack(spacing: 6) {
                Ilus(.corazon, 14, color: colorCorazon(.izquierda, actual: actual))
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.tinta.opacity(0.6))
                Ilus(.corazon, 14, color: colorCorazon(.derecha, actual: actual))
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Theme.melocoton.opacity(0.55), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.tinta.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(BotonPresionable())
        .accessibilityLabel(L10n.t("Cambiar de pecho"))
    }

    private func colorCorazon(_ lado: LadoPecho, actual: LadoPecho?) -> Color {
        actual == lado ? Theme.tinta : Theme.tinta.opacity(0.25)
    }

    private var filaUltimaToma: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let ultima = almacen.ultimaAlimentacion {
                    Text(L10n.t("Última toma") + " · " + Fmt.tiempoDesde(ultima.inicio, hasta: ahora))
                        .font(Theme.cuerpo(13, .semibold))
                        .foregroundStyle(Theme.tinta)
                        .lineLimit(1)
                    Text(textoUltimaAlimentacion(ultima))
                        .font(Theme.cuerpo(11))
                        .foregroundStyle(Theme.tintaTenue)
                        .lineLimit(1)
                } else {
                    Text(L10n.t("Alimentación"))
                        .font(Theme.cuerpo(13, .semibold))
                        .foregroundStyle(Theme.tinta)
                    Text(L10n.t("Sin registrar todavía"))
                        .font(Theme.cuerpo(11))
                        .foregroundStyle(Theme.tintaTenue)
                }
            }
            Spacer(minLength: 8)
            BotonIcono(simbolo: .biberon, color: Theme.mantequilla, diametro: 42) {
                mostrarHojaBiberon = true
            }
            .accessibilityLabel(L10n.t("Biberón"))
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { mostrarMenuPecho.toggle() }
            } label: {
                Insignia(simbolo: .corazon, fondo: Theme.melocoton, diametro: 42)
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
        }
        .frame(minHeight: 56)
    }

    private func accionPecho(_ lado: LadoPecho) {
        if let actual = almacen.tomaEnCurso, actual.lado == lado {
            withAnimation { almacen.terminarToma() }
        } else {
            withAnimation { almacen.empezarToma(lado) }
        }
    }

    private func textoUltimaAlimentacion(_ r: Registro) -> String {
        var partes: [String] = []
        partes.append(r.tituloVisible)
        if let d = r.duracion, d >= 60 { partes.append(Fmt.duracion(d)) }
        partes.append(Fmt.hora(r.inicio))
        return partes.joined(separator: " · ")
    }

    private var tarjetaPanal: some View {
        Tarjeta(relleno: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    if let ultimo = almacen.ultimoPanal {
                        Text(L10n.t("Pañal") + " · " + Fmt.tiempoDesde(ultimo.inicio, hasta: ahora))
                            .font(Theme.cuerpo(13, .semibold))
                            .foregroundStyle(Theme.tinta)
                            .lineLimit(1)
                        Text(L10n.t("Último a las") + " " + Fmt.hora(ultimo.inicio))
                            .font(Theme.cuerpo(11))
                            .foregroundStyle(Theme.tintaTenue)
                            .lineLimit(1)
                    } else {
                        Text(L10n.t("Pañal"))
                            .font(Theme.cuerpo(13, .semibold))
                            .foregroundStyle(Theme.tinta)
                        Text(L10n.t("Sin registrar todavía"))
                            .font(Theme.cuerpo(11))
                            .foregroundStyle(Theme.tintaTenue)
                    }
                }
                Spacer(minLength: 8)
                Button {
                    panalPis = true
                    panalCaca = false
                    withAnimation { mostrarPopoverPanal = true }
                } label: {
                    Insignia(simbolo: .hoja, fondo: Theme.cielo, diametro: 42)
                }
                .buttonStyle(BotonPresionable())
                .popover(isPresented: $mostrarPopoverPanal, arrowEdge: .top) {
                    PopoverPanal(pis: $panalPis, caca: $panalCaca) {
                        almacen.registrarPanal(pis: panalPis, caca: panalCaca)
                        withAnimation { mostrarPopoverPanal = false }
                    }
                    .frame(width: 240)
                    .presentationCompactAdaptation(.popover)
                }
                .accessibilityLabel(L10n.t("Pañal"))
            }
            .frame(minHeight: 56)
        }
    }
}

// MARK: - Hoja para registrar un biberón con cantidad
struct HojaBiberon: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    @AppStorage("unidadBiberonPreferida") private var unidadRaw: String = UnidadBiberon.ml.rawValue
    @AppStorage("tipoLechePreferido") private var tipoLecheRaw: String = TipoLeche.materna.rawValue
    
    @State private var unidad: UnidadBiberon = .ml
    @State private var cantidad: Double = 120
    @State private var tipoLeche: TipoLeche = .materna
    
    private var sugerencias: [Double] {
        unidad == .ml
            ? [30, 60, 90, 120, 150, 180, 210, 240]
            : [1, 2, 3, 4, 5, 6, 7, 8]
    }
    private var paso: Double { unidad == .ml ? 10 : 1 }
    private var maximo: Double { unidad == .ml ? 400 : 14 }
    private var minimo: Double { unidad == .ml ? 10 : 1 }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(spacing: 12) {
                            Insignia(simbolo: .biberon, fondo: Theme.mantequilla, diametro: 54)
                            Text("Biberón")
                                .font(Theme.display(22))
                                .foregroundStyle(Theme.tinta)
                            Text("¿Cuánto ha bebido?")
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 18) {
                            // 1) Tipo de leche (botones segmentados, arriba)
                            VStack(alignment: .leading, spacing: 8) {
                                EtiquetaSeccion(texto: "Tipo de leche")
                                Picker("Tipo de leche", selection: $tipoLeche) {
                                    ForEach(TipoLeche.allCases) { t in
                                        Text(t.corta).tag(t)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: tipoLeche) { _, nuevo in
                                    tipoLecheRaw = nuevo.rawValue
                                }
                            }
                            
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            
                            // 2) Unidad ml/oz (botones segmentados)
                            VStack(alignment: .leading, spacing: 8) {
                                EtiquetaSeccion(texto: "Unidad")
                                Picker("Unidad", selection: $unidad) {
                                    Text("ml").tag(UnidadBiberon.ml)
                                    Text("oz").tag(UnidadBiberon.oz)
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: unidad) { _, nueva in
                                    unidadRaw = nueva.rawValue
                                    cantidad = nueva == .ml ? 120 : 4
                                }
                            }
                            
                            // 3) Cantidad con + / −
                            HStack(spacing: 20) {
                                Button {
                                    cantidad = max(minimo, cantidad - paso)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(Theme.indigo)
                                }
                                VStack(spacing: 2) {
                                    Text(textoCantidad)
                                        .font(Theme.display(38))
                                        .foregroundStyle(Theme.tinta)
                                        .monospacedDigit()
                                    Text(unidad.etiqueta)
                                        .font(Theme.cuerpo(12))
                                        .foregroundStyle(Theme.tintaSuave)
                                }
                                .frame(maxWidth: .infinity)
                                Button {
                                    cantidad = min(maximo, cantidad + paso)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(Theme.indigo)
                                }
                            }
                            
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            
                            // 4) Sugerencias rápidas
                            VStack(alignment: .leading, spacing: 8) {
                                EtiquetaSeccion(texto: "Rápido")
                                LazyVGrid(
                                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                                    spacing: 8
                                ) {
                                    ForEach(sugerencias, id: \.self) { valor in
                                        Button {
                                            cantidad = valor
                                        } label: {
                                            Text(textoValor(valor))
                                                .font(Theme.cuerpo(13, .semibold))
                                                .foregroundStyle(cantidad == valor ? Theme.tinta : Theme.tintaSuave)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(cantidad == valor ? Theme.mantequilla : Theme.lienzoAlto)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    VStack(spacing: 8) {
                        Boton(titulo: "Guardar", color: Theme.mantequilla) {
                            guardarConCantidad()
                        }
                        Button {
                            guardarSinCantidad()
                        } label: {
                            Text("Guardar sin cantidad")
                                .font(Theme.cuerpo(13, .medium))
                                .foregroundStyle(Theme.tintaSuave)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle("Ahora")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                        .font(Theme.cuerpo(15))
                }
            }
            .onAppear {
                unidad = UnidadBiberon(rawValue: unidadRaw) ?? .ml
                cantidad = unidad == .ml ? 120 : 4
                tipoLeche = TipoLeche(rawValue: tipoLecheRaw) ?? .materna
            }
        }
    }
    
    private var textoCantidad: String {
        if unidad == .ml { return "\(Int(cantidad))" }
        return cantidad == cantidad.rounded()
            ? "\(Int(cantidad))"
            : String(format: "%.1f", cantidad)
    }
    private func textoValor(_ v: Double) -> String {
        if unidad == .ml { return "\(Int(v))" }
        return v == v.rounded() ? "\(Int(v)) oz" : String(format: "%.1f oz", v)
    }
    private func guardarConCantidad() {
        almacen.registrarBiberon(cantidad: cantidad, unidad: unidad, tipoLeche: tipoLeche)
        cerrar()
    }
    private func guardarSinCantidad() {
        almacen.registrarBiberon(cantidad: nil, unidad: nil, tipoLeche: tipoLeche)
        cerrar()
    }
}

// MARK: - Popover para elegir tipo de pañal
struct PopoverPanal: View {
    @Binding var pis: Bool
    @Binding var caca: Bool
    let alGuardar: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Insignia(simbolo: .hoja, fondo: Theme.cielo, diametro: 32)
                Text(L10n.t("¿Qué hizo?"))
                    .font(Theme.cuerpo(14, .semibold))
                    .foregroundStyle(Theme.tinta)
                Spacer()
            }
            HStack(spacing: 10) {
                toggleTipo(icono: .gota, etiqueta: L10n.t("Pis"), activo: $pis, color: Theme.cielo)
                toggleTipo(icono: .caquita, etiqueta: L10n.t("Caca"), activo: $caca, color: Theme.mantequilla)
            }
            Button { alGuardar() } label: {
                Text(L10n.t("Guardar"))
                    .font(Theme.cuerpo(13, .semibold))
                    .foregroundStyle(Theme.tinta)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.cielo, in: Capsule())
            }
            .buttonStyle(BotonPresionable())
        }
        .padding(16)
    }

    private func toggleTipo(icono: Ilus.Simbolo, etiqueta: String, activo: Binding<Bool>, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { activo.wrappedValue.toggle() }
        } label: {
            VStack(spacing: 6) {
                Ilus(icono, 24, color: activo.wrappedValue ? Theme.tinta : Theme.tintaTenue)
                Text(etiqueta)
                    .font(Theme.cuerpo(12, .semibold))
                    .foregroundStyle(activo.wrappedValue ? Theme.tinta : Theme.tintaTenue)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(activo.wrappedValue ? color : Theme.lienzoAlto))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Configuración para hoja de fin de sueño
struct ConfigFinSueño: Identifiable {
    let id = UUID()
    let tipo: TipoRegistro
    let inicio: Date
    let titulo: String
}

// MARK: - Hoja para confirmar o ajustar la hora de fin de sueño
struct HojaFinSueño: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    let config: ConfigFinSueño
    @State private var fechaFin: Date

    init(config: ConfigFinSueño) {
        self.config = config
        let ahora = Date()
        _fechaFin = State(initialValue: ahora > config.inicio ? ahora : config.inicio.addingTimeInterval(60))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(spacing: 12) {
                            Insignia(simbolo: config.tipo.simbolo, fondo: config.tipo.color, diametro: 54)
                            Text(config.titulo)
                                .font(Theme.display(22))
                                .foregroundStyle(Theme.tinta)
                            Text(L10n.t("¿A qué hora se ha despertado?"))
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: L10n.t("Hora de despertar"))
                                DatePicker("Hora", selection: $fechaFin, in: config.inicio...Date(), displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                                    .datePickerStyle(.wheel)
                            }
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            HStack {
                                Text(L10n.t("Empezó a las"))
                                    .font(Theme.cuerpo(13))
                                    .foregroundStyle(Theme.tintaSuave)
                                Spacer()
                                Text(Fmt.hora(config.inicio))
                                    .font(Theme.cuerpo(14, .semibold))
                                    .foregroundStyle(Theme.tinta)
                                    .monospacedDigit()
                            }
                            HStack {
                                Text(L10n.t("Duración total"))
                                    .font(Theme.cuerpo(13))
                                    .foregroundStyle(Theme.tintaSuave)
                                Spacer()
                                Text(Fmt.duracion(fechaFin.timeIntervalSince(config.inicio)))
                                    .font(Theme.cuerpo(15, .semibold))
                                    .foregroundStyle(Theme.tinta)
                                    .monospacedDigit()
                            }
                            if fechaFin < config.inicio {
                                Text("⚠️ " + L10n.t("La hora debe estar entre el inicio y ahora"))
                                    .font(Theme.cuerpo(11))
                                    .foregroundStyle(Theme.coral)
                            }
                        }
                    }
                    Boton(titulo: L10n.t("Guardar"), color: config.tipo.color) { guardar() }
                        .disabled(fechaFin < config.inicio || fechaFin > .now)
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle(config.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancelar")) { cerrar() }.font(Theme.cuerpo(15))
                }
            }
        }
    }

    private func guardar() {
        var finAjustado = fechaFin
        if finAjustado < config.inicio { finAjustado = config.inicio.addingTimeInterval(60) }
        if finAjustado > .now { finAjustado = .now }
        switch config.tipo {
        case .despertar:
            almacen.terminarDespertar(en: finAjustado)
        default:
            almacen.terminarSueño(en: finAjustado)
        }
        cerrar()
    }
}