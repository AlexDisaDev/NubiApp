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
    
    private let latido = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    private var diasLibres: Int { suscripcion.tieneAcceso ? 400 : 2 }
    
    /// Registros del día, INCLUYENDO sueños que empezaron el día anterior
    /// pero terminan en este, para poder editarlos o borrarlos.
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
                        ahora: ahora
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
        }
    }
    
    // MARK: - Barra compacta de sueño
    
    @ViewBuilder
    private var bloqueSueñoHoy: some View {
        if Calendar.current.isDateInToday(dia),
           let bebe = almacen.bebe,
           !almacen.registros.isEmpty {
            
            let balance = MotorSueño.balance(bebe: bebe, registros: almacen.registros)
            let tiempoEnCurso = almacen.sueñoEnCurso.map { ahora.timeIntervalSince($0.inicio) / 3600 } ?? 0
            let horasTotales = balance.horas + tiempoEnCurso
            
            Tarjeta(relleno: 14) {
                BarraSueño24h(horas: horasTotales, rango: balance.rango)
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
                    
                    Rectangle()
                        .fill(Theme.separador)
                        .frame(width: 1, height: 28)
                        .padding(.horizontal, 2)
                    
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
        let total = intervalos.reduce(0.0) {
            $0 + almacen.duracionEnDia($1, dia: dia, ahora: ahora)
        }
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

// MARK: - Hoja para elegir la hora de un registro nuevo

struct HojaHora: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    
    let dia: Date
    let tipo: TipoRegistro
    let lado: LadoPecho?
    
    @State private var fecha: Date = .now
    
    private var titulo: String {
        lado?.titulo ?? tipo.titulo
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
            .onAppear { fecha = horaInicial }
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
        
        almacen.registrarEvento(tipo, lado: lado, en: final)
        cerrar()
    }
}

// MARK: - Hoja para registrar un sueño nuevo con hora y duración

struct HojaSueño: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    
    let dia: Date
    let tipo: TipoRegistro
    
    @State private var fecha: Date = .now
    @State private var horas: Int = 1
    @State private var minutos: Int = 30
    
    private var titulo: String { tipo == .siesta ? "Siesta" : "Sueño nocturno" }
    private var simbolo: Ilus.Simbolo { tipo == .siesta ? .nube : .luna }
    private var color: Color { tipo == .siesta ? Theme.menta : Theme.lila }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(spacing: 12) {
                            Insignia(simbolo: simbolo, fondo: color, diametro: 54)
                            
                            Text(titulo)
                                .font(Theme.display(22))
                                .foregroundStyle(Theme.tinta)
                            
                            Text("¿Cuándo empezó y cuánto duró?")
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
                            
                            Rectangle()
                                .fill(Theme.separador)
                                .frame(height: 1)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "Duración")
                                
                                HStack(spacing: 16) {
                                    controlCantidad(
                                        valor: horas,
                                        texto: "\(horas)",
                                        unidad: horas == 1 ? "hora" : "horas",
                                        mas: { if horas < 16 { horas += 1 } },
                                        menos: { if horas > 0 { horas -= 1 } }
                                    )
                                    
                                    controlCantidad(
                                        valor: minutos,
                                        texto: String(format: "%02d", minutos),
                                        unidad: "min",
                                        mas: { if minutos <= 45 { minutos += 15 } },
                                        menos: { minutos = minutos >= 15 ? minutos - 15 : 0 }
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
                            
                            Text("\(Fmt.hora(fecha)) · \(Fmt.duracion(Double(horas * 3600 + minutos * 60)))")
                                .font(Theme.cuerpo(14, .semibold))
                                .foregroundStyle(Theme.tinta)
                                .monospacedDigit()
                        }
                    }
                    
                    Boton(titulo: "Guardar", color: color) { guardar() }
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
                if tipo == .siesta { horas = 1; minutos = 30 }
                else { horas = 8; minutos = 0 }
            }
        }
    }
    
    private func controlCantidad(
        valor: Int,
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
            of: dia
        ) ?? fecha
        
        if inicio > .now { inicio = .now }
        
        let duracion = Double(horas * 3600 + minutos * 60)
        
        almacen.registrarSueño(tipo, inicio: inicio, duracion: duracion)
        cerrar()
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
    
    private var esIntervalo: Bool { registro.tipo.esIntervalo }
    private var enCurso: Bool { registro.fin == nil }
    
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
                            
                            if esIntervalo && !enCurso {
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
                                            mas: { if minutos < 55 { minutos += 5 } },
                                            menos: { minutos = max(0, minutos - 5) }
                                        )
                                    }
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
    
    private func cargarDatos() {
        fecha = registro.inicio
        
        if let d = registro.duracion {
            let totalMin = Int((d / 60).rounded())
            horas = totalMin / 60
            minutos = (totalMin % 60 / 5) * 5
        }
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
        
        if esIntervalo {
            if enCurso {
                copia.fin = nil
            } else {
                let duracion = Double(horas * 3600 + minutos * 60)
                copia.fin = nuevoInicio.addingTimeInterval(max(duracion, 60))
            }
        } else {
            copia.fin = enCurso ? nil : nuevoInicio
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
                
                Text(detalle(r))
                    .font(Theme.cuerpo(12))
                    .foregroundStyle(Theme.tintaSuave)
                    .monospacedDigit()
                
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
        guard actual.tipo.esIntervalo, siguiente.tipo.esIntervalo, let fin = actual.fin else { return nil }
        
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
        
        return Fmt.hora(r.inicio)
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