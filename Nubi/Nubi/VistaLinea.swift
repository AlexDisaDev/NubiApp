import SwiftUI

struct VistaLinea: View {
    @EnvironmentObject private var almacen: Almacen
    @EnvironmentObject private var suscripcion: Suscripcion
    
    @State private var dia: Date = .now
    @State private var mostrarPaywall = false
    @State private var ahora: Date = .now
    @State private var registroDestacado: UUID?
    @State private var hojaHora: ConfigHora?
    @State private var hojaSueño: ConfigSueño?
    @State private var registroEditando: Registro?
    @State private var mostrarMenuPecho = false
    @State private var mostrarHojaDespertar = false
    @State private var mostrarHojaMedicina = false
    
    private let latido = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    private var diasLibres: Int { suscripcion.tieneAcceso ? 400 : 2 }
    
    private var registrosDelDia: [Registro] {
        var todos = almacen.registros(deDia: dia)
        
        for intervalo in almacen.intervalosQueTocan(dia)
        where !todos.contains(where: { $0.id == intervalo.id }) {
            todos.append(intervalo)
        }
        
        return todos.sorted { $0.inicio < $1.inicio }
    }
    
    private var intervalos: [Registro] { almacen.intervalosQueTocan(dia) }
    private var eventos: [Registro] { registrosDelDia.filter { !$0.tipo.esIntervalo } }
    
    private var ventanasIdeales: [VentanaIdeal] {
        let sync = Sincronizador.compartido
        guard suscripcion.tieneAcceso || sync.esParticipante else { return [] }
        guard let bebe = almacen.bebe else { return [] }
        return MotorSueño.ventanasIdealesDelDia(
            bebe: bebe,
            registros: almacen.registros,
            dia: dia,
            ahora: ahora
        )
    }

    private var despertarDelDia: Date? {
        MotorSueño.despertarDelDia(
            registros: almacen.registros,
            dia: dia,
            manual: almacen.despertarManual
        )
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Cabecera("Su día", subtitulo: resumenDelDia)
                    
                    selectorDeDia
                    
                    RelojDelDia(
                        intervalos: intervalos,
                        eventos: eventos,
                        dia: dia,
                        ventana: Calendar.current.isDateInToday(dia) ? almacen.proximaVentana : nil,
                        ventanasIdeales: ventanasIdeales,
                        ahora: ahora,
                        despertar: despertarDelDia
                    ) { reg in
                        registroDestacado = reg.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                proxy.scrollTo(reg.id, anchor: .top)
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            if registroDestacado == reg.id {
                                withAnimation { registroDestacado = nil }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    bloqueSueñoHoy
                    
                    botoneraRegistro
                    
                    if registrosDelDia.isEmpty {
                        Tarjeta {
                            EstadoVacio(
                                simbolo: .reloj,
                                titulo: "Nada anotado este día",
                                texto: "Cada siesta, toma o cambio que registres en Hoy aparecerá en el reloj y aquí debajo, en orden."
                            )
                        }
                    } else {
                        Tarjeta {
                            VStack(alignment: .leading, spacing: 0) {
                                VStack(alignment: .leading, spacing: 4) {
                                    EtiquetaSeccion(texto: "Todo lo del día")
                                    
                                    Text("Toca un registro para editarlo · ✕ para borrarlo")
                                        .font(Theme.cuerpo(10))
                                        .foregroundStyle(Theme.tintaTenue)
                                }
                                .padding(.bottom, 16)
                                
                                LineaVertical(
                                    registros: registrosDelDia,
                                    ahora: ahora,
                                    dia: dia,
                                    registroDestacado: $registroDestacado,
                                    alEditar: { r in registroEditando = r },
                                    alBorrar: { r in withAnimation { almacen.borrar(r) } }
                                )
                            }
                        }
                    }
                }
                .padding(Theme.margen)
                .padding(.bottom, 8)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .onReceive(latido) { ahora = $0 }
            .sheet(isPresented: $mostrarPaywall) { Paywall() }
            .sheet(item: $hojaHora) { c in
                HojaHora(dia: dia, tipo: c.tipo, lado: c.lado)
            }
            .sheet(item: $hojaSueño) { c in
                HojaSueño(dia: dia, tipo: c.tipo)
            }
            .sheet(item: $registroEditando) { r in
                HojaEditarRegistro(registro: r)
            }
            .sheet(isPresented: $mostrarHojaDespertar) {
                HojaDespertar(dia: dia)
            }
            .sheet(isPresented: $mostrarHojaMedicina) {
                HojaMedicina()
            }
        }
    }
    
    // MARK: - Barra compacta de sueño
    
    @ViewBuilder
    private var bloqueSueñoHoy: some View {
        if Calendar.current.isDateInToday(dia),
           let bebe = almacen.bebe,
           !almacen.registros.isEmpty {
            
            let balance = MotorSueño.balanceDelDia(
                bebe: bebe,
                registros: almacen.registros,
                dia: dia,
                ahora: ahora
            )
            
            Tarjeta(relleno: 14) {
                BarraSueño24h(horas: balance.horas, rango: balance.rango)
            }
        }
    }
    
    // MARK: - Botonera de registro rápido con hora
    
    private func botonRapido(_ tipo: TipoRegistro, _ lado: LadoPecho?) -> some View {
        Button {
            hojaHora = ConfigHora(tipo: tipo, lado: lado)
        } label: {
            Insignia(simbolo: tipo.simbolo, fondo: tipo.color, diametro: 40)
        }
        .buttonStyle(BotonPresionable())
    }
    
    private var botoneraRegistro: some View {
        Tarjeta(relleno: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        hojaSueño = ConfigSueño(tipo: .siesta)
                    } label: {
                        Insignia(simbolo: .nube, fondo: Theme.menta, diametro: 38)
                    }
                    .buttonStyle(BotonPresionable())
                    
                    Button {
                        hojaSueño = ConfigSueño(tipo: .noche)
                    } label: {
                        Insignia(simbolo: .luna, fondo: Theme.lila, diametro: 38)
                    }
                    .buttonStyle(BotonPresionable())
                    
                    botonRapido(.biberon, nil)
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            mostrarMenuPecho.toggle()
                        }
                    } label: {
                        Insignia(simbolo: .corazon, fondo: Theme.melocoton, diametro: 38)
                    }
                    .buttonStyle(BotonPresionable())
                    .popover(isPresented: $mostrarMenuPecho, arrowEdge: .top) {
                        MenuPechoHora { lado in
                            hojaHora = ConfigHora(tipo: .pecho, lado: lado)
                            withAnimation { mostrarMenuPecho = false }
                        }
                        .frame(width: 220)
                        .presentationCompactAdaptation(.popover)
                    }
                    
                    botonRapido(.panal, nil)
                    
                    Button {
                        mostrarHojaDespertar = true
                    } label: {
                        Insignia(
                            simbolo: .lunaOjoAbierto,
                            fondo: Theme.coral,
                            diametro: 38
                        )
                    }
                    .buttonStyle(BotonPresionable())
                    
                    Button {
                        mostrarHojaMedicina = true
                    } label: {
                        Insignia(
                            simbolo: .jeringa,
                            fondo: .white,
                            diametro: 38,
                            tinta: .black
                        )
                    }
                    .buttonStyle(BotonPresionable())
                    
                    Spacer(minLength: 0)
                }
                Text("¿Se te olvidó? Toca y elige la hora")
                    .font(Theme.cuerpo(10))
                    .foregroundStyle(Theme.tintaTenue)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    // MARK: Selector de día
    
    private var selectorDeDia: some View {
        HStack(spacing: 12) {
            Button {
                cambiarDia(-1)
            } label: {
                Insignia(simbolo: .chevronIzq, fondo: Theme.superficie, diametro: 38, tinta: puedeRetroceder ? Theme.indigo : Theme.tintaTenue)
                    .shadow(color: Theme.sombra, radius: 6, y: 2)
            }
            .buttonStyle(BotonPresionable())
            
            VStack(spacing: 1) {
                Text(etiquetaDia)
                    .font(Theme.cuerpo(15, .semibold))
                    .foregroundStyle(Theme.tinta)
                
                if let bebe = almacen.bebe {
                    Text(Fmt.edadEnFecha(dia, nacimiento: bebe.fechaNacimiento) + " de vida")
                        .font(Theme.cuerpo(11))
                        .foregroundStyle(Theme.tintaTenue)
                }
            }
            .frame(maxWidth: .infinity)
            
            Button {
                cambiarDia(1)
            } label: {
                Insignia(simbolo: .chevronDer, fondo: Theme.superficie, diametro: 38, tinta: puedeAvanzar ? Theme.indigo : Theme.tintaTenue)
                    .shadow(color: Theme.sombra, radius: 6, y: 2)
            }
            .buttonStyle(BotonPresionable())
            .disabled(!puedeAvanzar)
        }
    }
    
    private var etiquetaDia: String {
        let cal = Calendar.current
        
        if cal.isDateInToday(dia) { return "Hoy" }
        if cal.isDateInYesterday(dia) { return "Ayer" }
        
        return Fmt.fechaLarga(dia).capitalizedPrimera
    }
    
    private var diasAtras: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: dia), to: cal.startOfDay(for: .now)).day ?? 0
    }
    
    private var puedeAvanzar: Bool { diasAtras > 0 }
    private var puedeRetroceder: Bool { diasAtras + 1 < diasLibres || suscripcion.tieneAcceso }
    
    private func cambiarDia(_ delta: Int) {
        if delta < 0 && !puedeRetroceder {
            mostrarPaywall = true
            return
        }
        
        guard let nuevo = Calendar.current.date(byAdding: .day, value: delta, to: dia) else { return }
        if delta > 0 && nuevo > .now { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { dia = nuevo }
    }
    
    // MARK: Resumen
    
    private var resumenDelDia: String {
        let sueños = intervalos.filter { $0.tipo.esSueño }
        
        let sueño = sueños.reduce(0.0) {
            $0 + almacen.duracionEnDia($1, dia: dia, ahora: ahora)
        }
        
        let despertares = intervalos
            .filter { d in
                guard d.tipo.restaSueño else { return false }
                let finDespertar = d.fin ?? ahora
                return sueños.contains { s in
                    let finSueño = s.fin ?? ahora
                    return d.inicio >= s.inicio && finDespertar <= finSueño
                }
            }
            .reduce(0.0) { $0 + almacen.duracionEnDia($1, dia: dia, ahora: ahora) }
        
        let total = max(0, sueño - despertares)
        let tomas = eventos.filter { $0.tipo.esAlimentacion }.count
        
        if total == 0 && tomas == 0 { return "Sin registros" }
        
        var partes: [String] = []
        if total > 0 { partes.append("\(Fmt.duracion(total)) de sueño") }
        if tomas > 0 { partes.append("\(tomas) \(tomas == 1 ? "toma" : "tomas")") }
        
        return partes.joined(separator: " · ")
    }
}

extension String {
    var capitalizedPrimera: String {
        guard let p = first else { return self }
        return p.uppercased() + dropFirst()
    }
}

// MARK: - Configuración para las hojas

struct ConfigHora: Identifiable {
    let id = UUID()
    let tipo: TipoRegistro
    let lado: LadoPecho?
}

struct ConfigSueño: Identifiable {
    let id = UUID()
    let tipo: TipoRegistro
}

// MARK: - Hoja para registrar un sueño nuevo con hora y duración

struct HojaSueño: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    
    let dia: Date
    let tipo: TipoRegistro
    
    @State private var fecha: Date = .now
    @State private var horas: Int = 0
    @State private var minutos: Int = 30
    @State private var esAyer = false
    @State private var aunDurmiendo = false
    
    private var esHoy: Bool {
        Calendar.current.isDateInToday(dia)
    }
    
    private var puedeCambiarDia: Bool {
        tipo == .noche && esHoy
    }
    
    private var puedeEstarDurmiendo: Bool {
        esHoy
    }
    
    private var diaSeleccionado: Date {
        esAyer ? diaAyer : dia
    }
    
    private var diaAyer: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: dia) ?? dia
    }
    
    private var titulo: String {
        tipo == .siesta ? "Siesta" : "Sueño nocturno"
    }
    
    private var simbolo: Ilus.Simbolo {
        tipo == .siesta ? .nube : .luna
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(spacing: 12) {
                            Insignia(simbolo: simbolo, fondo: tipo.color, diametro: 54)
                            
                            Text(titulo)
                                .font(Theme.display(22))
                                .foregroundStyle(Theme.tinta)
                            
                            Text(aunDurmiendo ? "¿Cuándo empezó?" : "¿Cuándo durmió y cuánto?")
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                            
                            HStack(alignment: .center, spacing: 16) {
                                if puedeCambiarDia {
                                    VStack(spacing: 4) {
                                        Text("Día")
                                            .font(Theme.cuerpo(11, .semibold))
                                            .foregroundStyle(Theme.tintaSuave)
                                        
                                        Picker("Día", selection: $esAyer) {
                                            Text("Hoy").tag(false)
                                            Text("Ayer").tag(true)
                                        }
                                        .pickerStyle(.menu)
                                    }
                                }
                                
                                VStack(spacing: 4) {
                                    Text("Hora")
                                        .font(Theme.cuerpo(11, .semibold))
                                        .foregroundStyle(Theme.tintaSuave)
                                    
                                    DatePicker(
                                        "Hora",
                                        selection: $fecha,
                                        displayedComponents: [.hourAndMinute]
                                    )
                                    .labelsHidden()
                                    .datePickerStyle(.wheel)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    if puedeEstarDurmiendo {
                        Tarjeta {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    aunDurmiendo.toggle()
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .strokeBorder(
                                                aunDurmiendo ? tipo.color : Theme.tintaTenue,
                                                lineWidth: 2
                                            )
                                            .frame(width: 24, height: 24)
                                        if aunDurmiendo {
                                            Circle()
                                                .fill(tipo.color)
                                                .frame(width: 14, height: 14)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Aún está soñando")
                                            .font(Theme.cuerpo(15, .semibold))
                                            .foregroundStyle(Theme.tinta)
                                        Text("Se guarda abierto y aparece en la pantalla de bloqueo")
                                            .font(Theme.cuerpo(11))
                                            .foregroundStyle(Theme.tintaTenue)
                                    }
                                    
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if !aunDurmiendo {
                        Tarjeta {
                            VStack(alignment: .leading, spacing: 16) {
                                EtiquetaSeccion(texto: "Duración")
                                
                                HStack(spacing: 16) {
                                    controlCantidad(
                                        texto: "\(horas)",
                                        unidad: horas == 1 ? "hora" : "horas",
                                        mas: { if horas < 16 { horas += 1 } },
                                        menos: { if horas > 0 { horas -= 1 } }
                                    )
                                    
                                    controlCantidad(
                                        texto: String(format: "%02d", minutos),
                                        unidad: "min",
                                        mas: {
                                            let nuevo = minutos + 5
                                            if nuevo <= 55 { minutos = nuevo }
                                        },
                                        menos: {
                                            minutos = max(0, minutos - 5)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    Boton(titulo: "Guardar", color: tipo.color) {
                        guardar()
                    }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle(Fmt.fechaCorta(dia))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                        .font(Theme.cuerpo(15))
                }
            }
            .onAppear {
                fecha = horaInicial
            }
        }
    }
    
    private var horaInicial: Date {
        if Calendar.current.isDateInToday(dia) { return .now }
        
        let c = Calendar.current.dateComponents([.hour, .minute], from: .now)
        
        return Calendar.current.date(
            bySettingHour: c.hour ?? 12,
            minute: c.minute ?? 0,
            second: 0,
            of: dia
        ) ?? dia
    }
    
    private func guardar() {
        let c = Calendar.current.dateComponents([.hour, .minute], from: fecha)
        
        var inicio = Calendar.current.date(
            bySettingHour: c.hour ?? 12,
            minute: c.minute ?? 0,
            second: 0,
            of: diaSeleccionado
        ) ?? fecha
        
        if inicio > .now { inicio = .now }
        
        if aunDurmiendo {
            almacen.empezarSueño(tipo, en: inicio)
        } else {
            let duracion = Double(horas * 3600 + minutos * 60)
            almacen.registrarSueño(tipo, inicio: inicio, duracion: duracion)
        }
        
        cerrar()
    }
    
    private func controlCantidad(
        texto: String,
        unidad: String,
        mas: @escaping () -> Void,
        menos: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 4) {
            Text(texto)
                .font(Theme.display(28))
                .foregroundStyle(Theme.tinta)
                .monospacedDigit()
            
            Text(unidad)
                .font(Theme.cuerpo(11))
                .foregroundStyle(Theme.tintaSuave)
            
            HStack(spacing: 8) {
                Button(action: menos) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.indigo)
                }
                
                Button(action: mas) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.indigo)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hoja para elegir la hora de un registro nuevo

struct HojaHora: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    
    let dia: Date
    let tipo: TipoRegistro
    let lado: LadoPecho?
    
    @State private var fecha: Date = .now
    @State private var panalPis = true
    @State private var panalCaca = false
    @State private var cantidadBiberon: Double = 120
    @State private var unidadBiberon: UnidadBiberon = .ml
    @State private var pechoMinutos: Int = 10
    
    // ← NUEVOS: tipo de leche y preferencias persistentes
    @State private var tipoLecheBiberon: TipoLeche = .materna
    @AppStorage("unidadBiberonPreferida") private var unidadRaw: String = UnidadBiberon.ml.rawValue
    @AppStorage("tipoLechePreferido") private var tipoLecheRaw: String = TipoLeche.materna.rawValue
    
    private var titulo: String {
        lado?.titulo ?? tipo.titulo
    }
    
    private var pasoBiberon: Double { unidadBiberon == .ml ? 10 : 1 }
    private var maximoBiberon: Double { unidadBiberon == .ml ? 400 : 14 }
    private var minimoBiberon: Double { unidadBiberon == .ml ? 10 : 1 }
    
    private var textoCantidadBiberon: String {
        if unidadBiberon == .ml { return "\(Int(cantidadBiberon))" }
        return cantidadBiberon == cantidadBiberon.rounded()
            ? "\(Int(cantidadBiberon))"
            : String(format: "%.1f", cantidadBiberon)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(spacing: 12) {
                            Insignia(simbolo: tipo.simbolo, fondo: tipo.color, diametro: 54)
                            Text(titulo)
                                .font(Theme.display(22))
                                .foregroundStyle(Theme.tinta)
                            Text("Elige la hora del registro")
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                            DatePicker(
                                "Hora",
                                selection: $fecha,
                                displayedComponents: [.hourAndMinute]
                            )
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    if tipo == .panal {
                        Tarjeta {
                            VStack(alignment: .leading, spacing: 12) {
                                EtiquetaSeccion(texto: "¿Qué hizo?")
                                HStack(spacing: 10) {
                                    miniToggle(icono: .gota, etiqueta: "Pis",
                                               activo: $panalPis, color: Theme.cielo)
                                    miniToggle(icono: .caquita, etiqueta: "Caca",
                                               activo: $panalCaca, color: Theme.mantequilla)
                                }
                            }
                        }
                    }
                    
                    // ← BIBERÓN: orden corregido (tipo → unidad → cantidad)
                    if tipo == .biberon {
                        Tarjeta {
                            VStack(alignment: .leading, spacing: 14) {
                                // 1) Tipo de leche (arriba)
                                VStack(alignment: .leading, spacing: 8) {
                                    EtiquetaSeccion(texto: "Tipo de leche")
                                    Picker("Tipo de leche", selection: $tipoLecheBiberon) {
                                        ForEach(TipoLeche.allCases) { t in
                                            Text(t.corta).tag(t)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .onChange(of: tipoLecheBiberon) { _, nuevo in
                                        tipoLecheRaw = nuevo.rawValue
                                    }
                                }
                                
                                Rectangle().fill(Theme.separador).frame(height: 1)
                                
                                // 2) Unidad ml/oz (en medio, segmentado)
                                VStack(alignment: .leading, spacing: 8) {
                                    EtiquetaSeccion(texto: "Unidad")
                                    Picker("Unidad", selection: $unidadBiberon) {
                                        Text("ml").tag(UnidadBiberon.ml)
                                        Text("oz").tag(UnidadBiberon.oz)
                                    }
                                    .pickerStyle(.segmented)
                                    .onChange(of: unidadBiberon) { _, nueva in
                                        unidadRaw = nueva.rawValue
                                        cantidadBiberon = nueva == .ml ? 120 : 4
                                    }
                                }
                                
                                Rectangle().fill(Theme.separador).frame(height: 1)
                                
                                // 3) Cantidad (abajo)
                                VStack(alignment: .leading, spacing: 8) {
                                    EtiquetaSeccion(texto: "Cantidad")
                                    HStack(spacing: 20) {
                                        Button {
                                            cantidadBiberon = max(minimoBiberon, cantidadBiberon - pasoBiberon)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundStyle(Theme.indigo)
                                        }
                                        
                                        VStack(spacing: 2) {
                                            Text(textoCantidadBiberon)
                                                .font(Theme.display(32))
                                                .foregroundStyle(Theme.tinta)
                                                .monospacedDigit()
                                            Text(unidadBiberon.etiqueta)
                                                .font(Theme.cuerpo(11))
                                                .foregroundStyle(Theme.tintaSuave)
                                        }
                                        .frame(maxWidth: .infinity)
                                        
                                        Button {
                                            cantidadBiberon = min(maximoBiberon, cantidadBiberon + pasoBiberon)
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundStyle(Theme.indigo)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    if tipo == .pecho {
                        Tarjeta {
                            VStack(alignment: .leading, spacing: 12) {
                                EtiquetaSeccion(texto: "Duración de la toma")
                                HStack(spacing: 20) {
                                    Button {
                                        if pechoMinutos > 1 { pechoMinutos -= 1 }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(Theme.indigo)
                                    }
                                    VStack(spacing: 2) {
                                        Text("\(pechoMinutos)")
                                            .font(Theme.display(32))
                                            .foregroundStyle(Theme.tinta)
                                            .monospacedDigit()
                                        Text("min")
                                            .font(Theme.cuerpo(11))
                                            .foregroundStyle(Theme.tintaSuave)
                                    }
                                    .frame(maxWidth: .infinity)
                                    Button {
                                        if pechoMinutos < 90 { pechoMinutos += 1 }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(Theme.indigo)
                                    }
                                }
                            }
                        }
                    }
                    
                    Boton(titulo: "Guardar", color: Theme.lila) {
                        guardar()
                    }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle(Fmt.fechaCorta(dia))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                        .font(Theme.cuerpo(15))
                }
            }
            .onAppear {
                fecha = horaInicial
                unidadBiberon = UnidadBiberon(rawValue: unidadRaw) ?? .ml
                cantidadBiberon = unidadBiberon == .ml ? 120 : 4
                tipoLecheBiberon = TipoLeche(rawValue: tipoLecheRaw) ?? .materna
            }
        }
    }
    
    private var horaInicial: Date {
        if Calendar.current.isDateInToday(dia) { return .now }
        let c = Calendar.current.dateComponents([.hour, .minute], from: .now)
        return Calendar.current.date(
            bySettingHour: c.hour ?? 12,
            minute: c.minute ?? 0,
            second: 0,
            of: dia
        ) ?? dia
    }
    
    private func guardar() {
        let c = Calendar.current.dateComponents([.hour, .minute], from: fecha)
        var final = Calendar.current.date(
            bySettingHour: c.hour ?? 12,
            minute: c.minute ?? 0,
            second: 0,
            of: dia
        ) ?? fecha
        if final > .now { final = .now }
        
        if tipo == .panal {
            almacen.registrarPanal(en: final, pis: panalPis, caca: panalCaca)
        } else if tipo == .biberon {
            // ← CORREGIDO: se pasa tipoLeche
            almacen.registrarBiberon(
                en: final,
                cantidad: cantidadBiberon,
                unidad: unidadBiberon,
                tipoLeche: tipoLecheBiberon
            )
        } else if tipo == .pecho {
            almacen.registrarTomaPasada(en: final, duracionMinutos: pechoMinutos, lado: lado)
        } else {
            almacen.registrarEvento(tipo, lado: lado, en: final)
        }
        cerrar()
    }
    
    private func miniToggle(icono: Ilus.Simbolo,
                            etiqueta: String,
                            activo: Binding<Bool>,
                            color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                activo.wrappedValue.toggle()
            }
        } label: {
            VStack(spacing: 6) {
                Ilus(icono, 24, color: activo.wrappedValue ? Theme.tinta : Theme.tintaTenue)
                Text(etiqueta)
                    .font(Theme.cuerpo(12, .semibold))
                    .foregroundStyle(activo.wrappedValue ? Theme.tinta : Theme.tintaTenue)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(activo.wrappedValue ? color : Theme.lienzoAlto)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hoja para EDITAR un registro existente

struct HojaEditarRegistro: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    
    let registro: Registro
    
    @State private var fecha: Date = .now
    @State private var horas: Int = 0
    @State private var minutos: Int = 0
    
    // ← NUEVO: para editar biberón
    @State private var cantidadBiberon: Double = 120
    @State private var unidadBiberon: UnidadBiberon = .ml
    @State private var tipoLecheBiberon: TipoLeche = .materna   // ← AÑADIDO: faltaba este @State
    
    // ← NUEVO: para editar pañal
    @State private var panalPis: Bool = true
    @State private var panalCaca: Bool = false
    
    private var enCurso: Bool { registro.fin == nil }
    
    private var puedeEditarDuracion: Bool {
        (registro.tipo.esIntervalo || registro.tipo == .pecho) && !enCurso
    }
    
    private var esBiberon: Bool { registro.tipo == .biberon }
    private var esPanal: Bool { registro.tipo == .panal }
    
    private var pasoMinutos: Int {
        registro.tipo.esIntervalo ? 15 : 5
    }
    
    private var maxMinutos: Int {
        registro.tipo.esIntervalo ? 45 : 59
    }
    
    private var pasoIncrementoMinutos: Int {
        5
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(spacing: 12) {
                            Insignia(simbolo: registro.tipo.simbolo, fondo: registro.tipo.color, diametro: 54)
                            
                            Text(registro.tituloVisible)
                                .font(Theme.display(22))
                                .foregroundStyle(Theme.tinta)
                            
                            Text("Corrige la hora sin perder el registro")
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "Hora de inicio")
                                
                                DatePicker(
                                    "Hora",
                                    selection: $fecha,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .labelsHidden()
                                .datePickerStyle(.wheel)
                            }
                            
                            if puedeEditarDuracion {
                                Rectangle()
                                    .fill(Theme.separador)
                                    .frame(height: 1)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    EtiquetaSeccion(texto: "Duración")
                                    
                                    HStack(spacing: 16) {
                                        controlCantidad(
                                            texto: "\(horas)",
                                            unidad: horas == 1 ? "hora" : "horas",
                                            mas: { if horas < 16 { horas += 1 } },
                                            menos: { if horas > 0 { horas -= 1 } }
                                        )
                                        
                                        controlCantidad(
                                            texto: String(format: "%02d", minutos),
                                            unidad: "min",
                                            mas: {
                                                let nuevo = minutos + pasoIncrementoMinutos
                                                if nuevo <= 59 { minutos = nuevo }
                                            },
                                            menos: {
                                                minutos = max(0, minutos - pasoIncrementoMinutos)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    
                    if esBiberon {
                        Tarjeta {
                            VStack(alignment: .leading, spacing: 14) {
                                // 1) Tipo de leche
                                VStack(alignment: .leading, spacing: 8) {
                                    EtiquetaSeccion(texto: "Tipo de leche")
                                    Picker("Tipo de leche", selection: $tipoLecheBiberon) {
                                        ForEach(TipoLeche.allCases) { t in
                                            Text(t.corta).tag(t)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                                
                                Rectangle().fill(Theme.separador).frame(height: 1)
                                
                                // 2) Unidad ml/oz
                                VStack(alignment: .leading, spacing: 8) {
                                    EtiquetaSeccion(texto: "Unidad")
                                    Picker("Unidad", selection: $unidadBiberon) {
                                        Text("ml").tag(UnidadBiberon.ml)
                                        Text("oz").tag(UnidadBiberon.oz)
                                    }
                                    .pickerStyle(.segmented)
                                }
                                
                                Rectangle().fill(Theme.separador).frame(height: 1)
                                
                                // 3) Cantidad
                                VStack(alignment: .leading, spacing: 8) {
                                    EtiquetaSeccion(texto: "Cantidad")
                                    HStack(spacing: 20) {
                                        Button {
                                            cantidadBiberon = max(minimoBiberon, cantidadBiberon - pasoBiberon)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundStyle(Theme.indigo)
                                        }
                                        VStack(spacing: 2) {
                                            Text(textoCantidad)
                                                .font(Theme.display(32))
                                                .foregroundStyle(Theme.tinta)
                                                .monospacedDigit()
                                            Text(unidadBiberon.etiqueta)
                                                .font(Theme.cuerpo(11))
                                                .foregroundStyle(Theme.tintaSuave)
                                        }
                                        .frame(maxWidth: .infinity)
                                        Button {
                                            cantidadBiberon = min(maximoBiberon, cantidadBiberon + pasoBiberon)
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundStyle(Theme.indigo)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    if esPanal {
                        Tarjeta {
                            VStack(alignment: .leading, spacing: 12) {
                                EtiquetaSeccion(texto: "¿Qué hizo?")
                                
                                HStack(spacing: 10) {
                                    miniToggle(icono: .gota, etiqueta: "Pis",
                                               activo: $panalPis, color: Theme.cielo)
                                    miniToggle(icono: .caquita, etiqueta: "Caca",
                                               activo: $panalCaca, color: Theme.mantequilla)
                                }
                            }
                        }
                    }
                    
                    Boton(titulo: "Guardar cambios", color: registro.tipo.color) {
                        guardar()
                    }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle("Editar registro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                        .font(Theme.cuerpo(15))
                }
            }
            .onAppear { cargarDatos() }
        }
    }
    
    private var pasoBiberon: Double { unidadBiberon == .ml ? 10 : 1 }
    private var maximoBiberon: Double { unidadBiberon == .ml ? 400 : 14 }
    private var minimoBiberon: Double { unidadBiberon == .ml ? 10 : 1 }
    
    private var textoCantidad: String {
        if unidadBiberon == .ml { return "\(Int(cantidadBiberon))" }
        return cantidadBiberon == cantidadBiberon.rounded()
            ? "\(Int(cantidadBiberon))"
            : String(format: "%.1f", cantidadBiberon)
    }
    
    private func controlCantidad(
        texto: String,
        unidad: String,
        mas: @escaping () -> Void,
        menos: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 4) {
            Text(texto)
                .font(Theme.display(28))
                .foregroundStyle(Theme.tinta)
                .monospacedDigit()
            
            Text(unidad)
                .font(Theme.cuerpo(11))
                .foregroundStyle(Theme.tintaSuave)
            
            HStack(spacing: 8) {
                Button(action: menos) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.indigo)
                }
                
                Button(action: mas) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.indigo)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func miniToggle(icono: Ilus.Simbolo,
                            etiqueta: String,
                            activo: Binding<Bool>,
                            color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                activo.wrappedValue.toggle()
            }
        } label: {
            VStack(spacing: 6) {
                Ilus(icono, 24, color: activo.wrappedValue ? Theme.tinta : Theme.tintaTenue)
                Text(etiqueta)
                    .font(Theme.cuerpo(12, .semibold))
                    .foregroundStyle(activo.wrappedValue ? Theme.tinta : Theme.tintaTenue)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(activo.wrappedValue ? color : Theme.lienzoAlto)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func cargarDatos() {
        fecha = registro.inicio
        
        if let d = registro.duracion {
            let totalMin = Int((d / 60).rounded())
            horas = totalMin / 60
            minutos = totalMin % 60
        }
        
        // ← NUEVO: precargar tipo de leche
        if let t = registro.tipoLeche { tipoLecheBiberon = t }
        
        if let c = registro.cantidadBiberon {
            cantidadBiberon = c
        }
        if let u = registro.unidadBiberon {
            unidadBiberon = u
        }
        
        panalPis = registro.panalPis ?? true
        panalCaca = registro.panalCaca ?? false
    }
    
    private func guardar() {
        var copia = registro
        
        let c = Calendar.current.dateComponents([.hour, .minute], from: fecha)
        let diaOriginal = Calendar.current.startOfDay(for: registro.inicio)
        
        let nuevoInicio = Calendar.current.date(
            bySettingHour: c.hour ?? 0,
            minute: c.minute ?? 0,
            second: 0,
            of: diaOriginal
        ) ?? registro.inicio
        
        copia.inicio = nuevoInicio
        
        if puedeEditarDuracion {
            let duracion = Double(horas * 3600 + minutos * 60)
            copia.fin = nuevoInicio.addingTimeInterval(max(duracion, 60))
        } else if registro.tipo.esIntervalo || registro.tipo == .pecho {
            copia.fin = nil
        } else {
            copia.fin = enCurso ? nil : nuevoInicio
        }
        
        if esBiberon {
            copia.cantidadBiberon = cantidadBiberon
            copia.unidadBiberon = unidadBiberon
            copia.tipoLeche = tipoLecheBiberon
        }
        
        if esPanal {
            let pisFinal = (!panalPis && !panalCaca) ? true : panalPis
            copia.panalPis = pisFinal
            copia.panalCaca = panalCaca
        }
        
        almacen.actualizar(copia)
        cerrar()
    }
}

// MARK: - Línea de tiempo vertical

struct LineaVertical: View {
    let registros: [Registro]
    let ahora: Date
    let dia: Date
    @Binding var registroDestacado: UUID?
    var alEditar: (Registro) -> Void
    var alBorrar: (Registro) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(registros.enumerated()), id: \.element.id) { idx, r in
                VStack(spacing: 0) {
                    fila(r, esUltimo: idx == registros.count - 1)
                    
                    if let hueco = vigilia(desde: idx) {
                        separadorVigilia(hueco)
                    }
                }
                .id(r.id)
                .padding(.top, registroDestacado == r.id ? 12 : 0)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            registroDestacado == r.id
                            ? Theme.mantequilla.opacity(0.35)
                            : Color.clear
                        )
                )
                .animation(.easeOut(duration: 0.4), value: registroDestacado)
            }
        }
    }
    
    private func fila(_ r: Registro, esUltimo: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Insignia(simbolo: r.tipo.simbolo, fondo: r.tipo.color, diametro: 36)
                
                if !esUltimo {
                    Rectangle()
                        .fill(Theme.separador)
                        .frame(width: 2)
                        .frame(minHeight: 18)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(r.tituloVisible)
                        .font(Theme.cuerpo(15, .semibold))
                        .foregroundStyle(Theme.tinta)
                    
                    if r.enCurso { Pastilla(texto: "en curso", color: Theme.menta) }
                    
                    if !Calendar.current.isDate(r.inicio, inSameDayAs: dia) {
                        Pastilla(texto: "noche anterior", color: Theme.lila)
                    }
                    
                    if r.tipo.esIntervalo {
                        if let duracion = r.duracion ?? (r.enCurso ? ahora.timeIntervalSince(r.inicio) : nil) {
                            Text(Fmt.duracion(duracion))
                                .font(Theme.cuerpo(11, .medium))
                                .foregroundStyle(Theme.indigo)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.indigo.opacity(0.1), in: Capsule())
                        }
                    }
                }
                
                HStack(spacing: 6) {
                    Text(detalle(r))
                        .font(Theme.cuerpo(12))
                        .foregroundStyle(Theme.tintaSuave)
                        .monospacedDigit()
                    
                    if r.tipo == .panal {
                        if r.panalPis == true {
                            Ilus(.gota, 12, color: Theme.cielo)
                        }
                        if r.panalCaca == true {
                            Ilus(.caquita, 14, color: Theme.mantequilla)
                        }
                    }
                    
                    // ← NUEVO: icono de tipo de leche
                    if r.tipo == .biberon, let leche = r.tipoLeche {
                        Text(leche.corta)
                            .font(Theme.cuerpo(10, .medium))
                            .foregroundStyle(Theme.tintaTenue)
                    }
                }
                
                if !r.nota.isEmpty {
                    Text(r.nota)
                        .font(Theme.cuerpo(12))
                        .foregroundStyle(Theme.tintaTenue)
                }
            }
            .padding(.top, 6)
            
            Spacer(minLength: 0)
            
            Button { alBorrar(r) } label: {
                Ilus(.cerrar, 13, color: Theme.tintaTenue)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .onTapGesture { alEditar(r) }
    }
    
    private func separadorVigilia(_ hueco: TimeInterval) -> some View {
        HStack(spacing: 14) {
            Rectangle().fill(Theme.separador).frame(width: 2, height: 26).padding(.leading, 17)
            
            Text("\(Fmt.duracion(hueco)) despierto")
                .font(Theme.cuerpo(11))
                .foregroundStyle(Theme.tintaTenue)
            
            Spacer()
        }
    }
    
    private func vigilia(desde idx: Int) -> TimeInterval? {
        guard idx < registros.count - 1 else { return nil }
        
        let actual = registros[idx], siguiente = registros[idx + 1]
        guard actual.tipo.esSueño, siguiente.tipo.esSueño, let fin = actual.fin else { return nil }
        
        let hueco = siguiente.inicio.timeIntervalSince(fin)
        return hueco > 15 * 60 ? hueco : nil
    }
    
    private func detalle(_ r: Registro) -> String {
        if r.tipo.esIntervalo || r.tipo == .pecho {
            guard let d = r.duracion, let fin = r.fin else {
                return "Desde \(Fmt.hora(r.inicio)) · \(Fmt.duracion(ahora.timeIntervalSince(r.inicio)))"
            }
            return "\(Fmt.hora(r.inicio)) – \(Fmt.hora(fin)) · \(Fmt.duracion(d))"
        }
        
        if r.tipo == .biberon,
           let cantidad = r.cantidadBiberon,
           let unidad = r.unidadBiberon {
            return "\(Fmt.hora(r.inicio)) · \(formatearCantidad(cantidad, unidad: unidad))"
        }
        
        return Fmt.hora(r.inicio)
    }
    
    private func formatearCantidad(_ v: Double, unidad: UnidadBiberon) -> String {
        let entero = v == v.rounded()
        if unidad == .ml {
            return "\(Int(v)) ml"
        }
        return entero ? "\(Int(v)) oz" : String(format: "%.1f oz", v)
    }
}

// MARK: - Barra compacta de sueño (0-24h)

struct BarraSueño24h: View {
    let horas: Double
    let rango: ClosedRange<Double>
    
    private var dentro: Bool { rango.contains(horas) }
    private var colorBorde: Color { dentro ? Theme.menta : Theme.melocoton }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            EtiquetaSeccion(texto: "Sueño de hoy")
                .frame(maxWidth: .infinity, alignment: .center)
            
            GeometryReader { geo in
                let ancho = geo.size.width
                let alto: CGFloat = 34
                
                let posHoras    = CGFloat(min(max(horas, 0), 24) / 24) * ancho
                let posRangoIni = CGFloat(max(rango.lowerBound, 0) / 24) * ancho
                let posRangoFin = CGFloat(min(rango.upperBound, 24) / 24) * ancho
                let anchoRango  = max(4, posRangoFin - posRangoIni)
                
                ZStack(alignment: .leading) {
                    LinearGradient(
                        colors: [
                            Theme.indigo.opacity(0.15),
                            Theme.cielo.opacity(0.20),
                            Theme.cielo.opacity(0.20),
                            Theme.indigo.opacity(0.15)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: alto)
                    
                    Rectangle()
                        .fill(Theme.menta.opacity(0.45))
                        .frame(width: anchoRango, height: alto)
                        .offset(x: posRangoIni)
                    
                    ForEach([6, 12, 18], id: \.self) { h in
                        Rectangle()
                            .fill(Theme.tintaTenue.opacity(0.4))
                            .frame(width: 1, height: alto)
                            .offset(x: CGFloat(h) / 24 * ancho)
                    }
                    
                    ZStack {
                        Circle()
                            .fill(Theme.superficie)
                            .overlay(Circle().strokeBorder(colorBorde, lineWidth: 3))
                            .frame(width: 44, height: 44)
                            .shadow(color: Theme.sombra, radius: 4, y: 2)
                        
                        Text(formatear(horas))
                            .font(Theme.cuerpo(11, .bold))
                            .foregroundStyle(Theme.tinta)
                            .monospacedDigit()
                    }
                    .offset(x: max(22, min(posHoras, ancho - 22)) - 22)
                }
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(colorBorde, lineWidth: 2.5)
                )
            }
            .frame(height: 44)
            
            HStack {
                Text("0h")
                    .font(Theme.cuerpo(9))
                    .foregroundStyle(Theme.tintaTenue)
                
                Spacer()
                
                Text("12h")
                    .font(Theme.cuerpo(9))
                    .foregroundStyle(Theme.tintaTenue)
                
                Spacer()
                
                Text("24h")
                    .font(Theme.cuerpo(9))
                    .foregroundStyle(Theme.tintaTenue)
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func formatear(_ h: Double) -> String {
        let horas = Int(h)
        let minutos = Int((h - Double(horas)) * 60)
        if minutos == 0 { return "\(horas)h" }
        return "\(horas)h\(minutos)"
    }
}

// MARK: - Hoja para registrar un despertar nocturno

struct HojaDespertar: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    
    var dia: Date = .now
    
    @State private var fecha: Date = .now
    @State private var minutos: Int = 15
    @State private var errorTexto: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(spacing: 12) {
                            Insignia(simbolo: .lunaOjoAbierto, fondo: Theme.coral, diametro: 54)
                            
                            Text("Despertar nocturno")
                                .font(Theme.display(22))
                                .foregroundStyle(Theme.tinta)
                            
                            Text("¿A qué hora se despertó y cuánto duró?")
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "Hora del despertar")
                                
                                DatePicker(
                                    "Hora",
                                    selection: $fecha,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .labelsHidden()
                                .datePickerStyle(.wheel)
                            }
                            
                            Rectangle()
                                .fill(Theme.separador)
                                .frame(height: 1)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "Duración del despertar")
                                
                                HStack(spacing: 16) {
                                    controlCantidad(
                                        texto: "\(minutos)",
                                        unidad: "min",
                                        mas: { if minutos < 180 { minutos += 5 } },
                                        menos: { if minutos > 5 { minutos -= 5 } }
                                    )
                                }
                            }
                        }
                    }
                    
                    Tarjeta(relleno: 14) {
                        HStack {
                            Text("Resumen:")
                                .font(Theme.cuerpo(13, .medium))
                                .foregroundStyle(Theme.tintaSuave)
                            
                            Spacer()
                            
                            Text("\(Fmt.hora(fecha)) · \(minutos) min")
                                .font(Theme.cuerpo(14, .semibold))
                                .foregroundStyle(Theme.tinta)
                                .monospacedDigit()
                        }
                    }
                    
                    if let errorTexto {
                        Text(errorTexto)
                            .font(Theme.cuerpo(12, .medium))
                            .foregroundStyle(Theme.coral)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    Boton(titulo: "Guardar", color: Theme.coral) { guardar() }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle(Fmt.fechaCorta(dia))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                        .font(Theme.cuerpo(15))
                }
            }
            .onAppear { preparar() }
        }
    }
    
    private func preparar() {
        errorTexto = nil
        minutos = 15
        
        let ahora = Date()
        
        if Calendar.current.isDateInToday(dia) {
            fecha = ahora.addingTimeInterval(-30 * 60)
        } else {
            fecha = Calendar.current.date(bySettingHour: 3, minute: 0, second: 0, of: dia) ?? dia
        }
    }
    
    private func guardar() {
        let c = Calendar.current.dateComponents([.hour, .minute], from: fecha)
        let diaOriginal = Calendar.current.startOfDay(for: dia)
        
        var inicio = Calendar.current.date(
            bySettingHour: c.hour ?? 3,
            minute: c.minute ?? 0,
            second: 0,
            of: diaOriginal
        ) ?? fecha
        
        if inicio > .now { inicio = .now }
        
        let duracion = TimeInterval(minutos * 60)
        let ok = almacen.registrarDespertar(inicio: inicio, duracion: duracion)
        
        if ok {
            cerrar()
        } else {
            errorTexto = "No se pudo guardar. Comprueba los datos."
        }
    }
    
    private func controlCantidad(
        texto: String,
        unidad: String,
        mas: @escaping () -> Void,
        menos: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 4) {
            Text(texto)
                .font(Theme.display(28))
                .foregroundStyle(Theme.tinta)
                .monospacedDigit()
            
            Text(unidad)
                .font(Theme.cuerpo(11))
                .foregroundStyle(Theme.tintaSuave)
            
            HStack(spacing: 8) {
                Button(action: menos) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.indigo)
                }
                
                Button(action: mas) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.indigo)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hoja para registrar medicina

struct HojaMedicina: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    
    @State private var fechaToma: Date = .now
    @State private var nombre: String = ""
    @State private var nota: String = ""
    @State private var programarSiguiente: Bool = false
    @State private var horaSiguiente: Date = .now
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(spacing: 12) {
                            Insignia(simbolo: .jeringa, fondo: .white, diametro: 54, tinta: .black)
                            Text("Medicina")
                                .font(Theme.display(22))
                                .foregroundStyle(Theme.tinta)
                            Text("Anota la toma y programa un aviso")
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "Nombre de la medicina")
                                TextField("Apiretal, Augmentine…", text: $nombre)
                                    .font(Theme.cuerpo(16))
                            }
                            
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "Hora de la toma")
                                DatePicker("", selection: $fechaToma, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                            }
                            
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            
                            Toggle(isOn: $programarSiguiente) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Avisar de la siguiente toma")
                                        .font(Theme.cuerpo(15))
                                        .foregroundStyle(Theme.tinta)
                                    Text("Te avisamos cuando llegue la hora")
                                        .font(Theme.cuerpo(11))
                                        .foregroundStyle(Theme.tintaTenue)
                                }
                            }
                            .tint(Theme.indigo)
                            
                            if programarSiguiente {
                                DatePicker("Siguiente toma", selection: $horaSiguiente, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                            }
                            
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "Notas")
                                TextField("Dosis, indicaciones, reacciones…", text: $nota, axis: .vertical)
                                    .font(Theme.cuerpo(15))
                                    .lineLimit(2...6)
                            }
                        }
                    }
                    
                    Boton(titulo: "Guardar", color: Theme.cielo) {
                        guardar()
                    }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle("Medicina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }.font(Theme.cuerpo(15))
                }
            }
            .onAppear {
                horaSiguiente = Calendar.current.date(byAdding: .hour, value: 8, to: .now) ?? .now
            }
        }
    }
    
    private func guardar() {
        let medicina = Medicina(
            fechaToma: fechaToma,
            nombre: nombre.trimmingCharacters(in: .whitespaces),
            nota: nota,
            horaSiguiente: programarSiguiente ? horaSiguiente : nil
        )
        almacen.registrarMedicina(medicina)
        
        if programarSiguiente {
            Task {
                _ = await NotificadorMedicinas.pedirPermiso()
                NotificadorMedicinas.programar(medicina)
            }
        }
        
        cerrar()
    }
}