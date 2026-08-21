import SwiftUI

struct VistaBancoLeche: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    //@EnvironmentObject private var l10n: L10n
    @State private var mostrarHojaExtraccion = false
    @State private var mostrarHojaUso = false
    @State private var extraccionEditando: ExtraccionLeche? = nil
    @State private var usoEditando: UsoLeche? = nil
    @State private var confirmarBorradoExtraccion: ExtraccionLeche? = nil
    @State private var confirmarBorradoUso: UsoLeche? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Contador principal
                    Tarjeta {
                        VStack(spacing: 8) {
                            Text("\(Int(almacen.lecheDisponible)) ml")
                                .font(Theme.display(42))
                                .foregroundStyle(Theme.tinta)
                                .monospacedDigit()
                            Text("disponibles en el banco")
                                .font(Theme.cuerpo(13))
                                .foregroundStyle(Theme.tintaSuave)
                            
                            HStack(spacing: 16) {
                                Text("\(almacen.extracciones.count) extracciones")
                                    .font(Theme.cuerpo(11))
                                    .foregroundStyle(Theme.tintaTenue)
                                Text("\(almacen.usosLeche.count) usos")
                                    .font(Theme.cuerpo(11))
                                    .foregroundStyle(Theme.tintaTenue)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    HStack(spacing: 10) {
                        Boton(titulo: "Registrar extracción", simbolo: .mas, color: Theme.cielo) {
                            mostrarHojaExtraccion = true
                        }
                        Boton(titulo: "Usar leche", simbolo: .biberon, color: Theme.mantequilla) {
                            mostrarHojaUso = true
                        }
                    }
                    
                    if let caducando = extraccionesCaducando {
                        Tarjeta(relleno: 14) {
                            HStack(spacing: 10) {
                                Insignia(simbolo: .reloj, fondo: Theme.melocoton, diametro: 32)
                                Text(caducando)
                                    .font(Theme.cuerpo(12, .medium))
                                    .foregroundStyle(Theme.tinta)
                            }
                        }
                    }
                    
                    if !almacen.extracciones.isEmpty || !almacen.usosLeche.isEmpty {
                        Tarjeta {
                            VStack(alignment: .leading, spacing: 14) {
                                EtiquetaSeccion(texto: "Historial")
                                
                                ForEach(eventosOrdenados, id: \.id) { evento in
                                    filaEvento(evento)
                                    
                                    if evento.id != eventosOrdenados.last?.id {
                                        Rectangle().fill(Theme.separador).frame(height: 1)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle("Banco de leche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Listo") { cerrar() }
                        .font(Theme.cuerpo(15, .semibold))
                }
            }
            // Hojas nuevas
            .sheet(isPresented: $mostrarHojaExtraccion) {
                HojaExtraccion(extraccion: nil)
            }
            .sheet(isPresented: $mostrarHojaUso) {
                HojaUsoLeche(uso: nil)
            }
            // Hojas de edición (al tocar la fila)
            .sheet(item: $extraccionEditando) { ext in
                HojaExtraccion(extraccion: ext)
            }
            .sheet(item: $usoEditando) { uso in
                HojaUsoLeche(uso: uso)
            }
            // Alertas de borrado
            .alert("¿Eliminar esta extracción?",
                   isPresented: Binding(
                       get: { confirmarBorradoExtraccion != nil },
                       set: { if !$0 { confirmarBorradoExtraccion = nil } }
                   ),
                   presenting: confirmarBorradoExtraccion) { ext in
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    almacen.borrarExtraccion(ext)
                }
            } message: { _ in
                Text("Esta acción no se puede deshacer.")
            }
            .alert("¿Eliminar este uso?",
                   isPresented: Binding(
                       get: { confirmarBorradoUso != nil },
                       set: { if !$0 { confirmarBorradoUso = nil } }
                   ),
                   presenting: confirmarBorradoUso) { uso in
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    almacen.borrarUsoLeche(uso)
                }
            } message: { _ in
                Text("Esta acción no se puede deshacer.")
            }
        }
    }
    
    // MARK: - Helpers
    
    private var extraccionesCaducando: String? {
        let cal = Calendar.current
        let limite = cal.date(byAdding: .day, value: 3, to: .now) ?? .now
        let caducando = almacen.extracciones.filter { $0.caducidad <= limite }
        guard !caducando.isEmpty else { return nil }
        return "⚠️ \(caducando.count) \(caducando.count == 1 ? "extracción caduca" : "extracciones caducan") en los próximos 3 días. Úsalas primero."
    }
    
    private struct EventoLeche: Identifiable {
        let id: UUID
        let fecha: Date
        let texto: String
        let esExtraccion: Bool
        let cantidad: Double
    }
    
    private var eventosOrdenados: [EventoLeche] {
        let ext = almacen.extracciones.map {
            EventoLeche(id: $0.id, fecha: $0.fecha, texto: "+\(Int($0.cantidadMl)) ml · \($0.almacenamiento.rawValue)", esExtraccion: true, cantidad: $0.cantidadMl)
        }
        let usos = almacen.usosLeche.map {
            EventoLeche(id: $0.id, fecha: $0.fecha, texto: "-\(Int($0.cantidadMl)) ml · Uso", esExtraccion: false, cantidad: $0.cantidadMl)
        }
        return (ext + usos).sorted { $0.fecha > $1.fecha }
    }
    
    // ← MODIFICADO: ahora con X a la derecha y tappable para editar
    private func filaEvento(_ e: EventoLeche) -> some View {
        HStack(spacing: 12) {
            // Parte izq: tocar abre edición
            Button {
                if e.esExtraccion, let ext = almacen.extracciones.first(where: { $0.id == e.id }) {
                    extraccionEditando = ext
                } else if !e.esExtraccion, let uso = almacen.usosLeche.first(where: { $0.id == e.id }) {
                    usoEditando = uso
                }
            } label: {
                HStack(spacing: 12) {
                    Insignia(
                        simbolo: e.esExtraccion ? .mas : .biberon,
                        fondo: e.esExtraccion ? Theme.cielo : Theme.mantequilla,
                        diametro: 32
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.texto)
                            .font(Theme.cuerpo(14, .medium))
                            .foregroundStyle(Theme.tinta)
                            .monospacedDigit()
                        Text(Fmt.fechaCorta(e.fecha) + " · " + Fmt.hora(e.fecha))
                            .font(Theme.cuerpo(11))
                            .foregroundStyle(Theme.tintaTenue)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // ← NUEVO: botón X directa para eliminar
            Button {
                if e.esExtraccion, let ext = almacen.extracciones.first(where: { $0.id == e.id }) {
                    confirmarBorradoExtraccion = ext
                } else if !e.esExtraccion, let uso = almacen.usosLeche.first(where: { $0.id == e.id }) {
                    confirmarBorradoUso = uso
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.coral)
            }
            .buttonStyle(.plain)
        }
    }
}

// Reemplaza HojaExtraccion completa
struct HojaExtraccion: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    
    let extraccion: ExtraccionLeche?
    @State private var fecha: Date
    @State private var cantidad: Double
    @State private var almacenamiento: AlmacenamientoLeche
    
    init(extraccion: ExtraccionLeche? = nil) {
        self.extraccion = extraccion
        _fecha = State(initialValue: extraccion?.fecha ?? .now)
        _cantidad = State(initialValue: extraccion?.cantidadMl ?? 120)
        _almacenamiento = State(initialValue: extraccion?.almacenamiento ?? .congelador)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(spacing: 12) {
                            Insignia(simbolo: .biberon, fondo: Theme.cielo, diametro: 54)
                            Text(extraccion == nil ? "Nueva extracción" : "Editar extracción")
                                .font(Theme.display(22))
                                .foregroundStyle(Theme.tinta)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "Fecha y hora")
                                DatePicker("", selection: $fecha, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                            }
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "Cantidad (ml)")
                                HStack(spacing: 20) {
                                    Button { cantidad = max(10, cantidad - 10) } label: {
                                        Image(systemName: "minus.circle.fill").font(.title2).foregroundStyle(Theme.indigo)
                                    }
                                    Text("\(Int(cantidad)) ml")
                                        .font(Theme.display(28))
                                        .foregroundStyle(Theme.tinta)
                                        .monospacedDigit()
                                        .frame(maxWidth: .infinity)
                                    Button { cantidad = min(500, cantidad + 10) } label: {
                                        Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Theme.indigo)
                                    }
                                }
                            }
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "Almacenamiento")
                                Picker("Almacenamiento", selection: $almacenamiento) {
                                    ForEach(AlmacenamientoLeche.allCases) { a in
                                        Text(a.rawValue).tag(a)
                                    }
                                }
                                .pickerStyle(.segmented)
                                Text(almacenamiento == .frigo
                                     ? "Dura hasta 4 días en el frigorífico"
                                     : "Dura hasta 6 meses en el congelador")
                                    .font(Theme.cuerpo(11))
                                    .foregroundStyle(Theme.tintaTenue)
                            }
                        }
                    }
                    
                    Boton(titulo: "Guardar", color: Theme.cielo) {
                        if var e = extraccion {
                            almacen.borrarExtraccion(e)
                            e.fecha = fecha
                            e.cantidadMl = cantidad
                            e.almacenamiento = almacenamiento
                            almacen.registrarExtraccion(e)
                        } else {
                            almacen.registrarExtraccion(
                                ExtraccionLeche(fecha: fecha, cantidadMl: cantidad, almacenamiento: almacenamiento)
                            )
                        }
                        cerrar()
                    }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle(extraccion == nil ? "Extracción" : "Editar extracción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }.font(Theme.cuerpo(15))
                }
            }
        }
    }
}

// Reemplaza HojaUsoLeche completa
struct HojaUsoLeche: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    
    let uso: UsoLeche?
    @State private var cantidad: Double
    
    init(uso: UsoLeche? = nil) {
        self.uso = uso
        _cantidad = State(initialValue: uso?.cantidadMl ?? 120)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(spacing: 12) {
                            Insignia(simbolo: .biberon, fondo: Theme.mantequilla, diametro: 54)
                            Text(uso == nil ? "Usar leche del banco" : "Editar uso")
                                .font(Theme.display(22))
                                .foregroundStyle(Theme.tinta)
                            Text("Se restará del total disponible")
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 16) {
                            EtiquetaSeccion(texto: "Cantidad a usar (ml)")
                            HStack(spacing: 20) {
                                Button { cantidad = max(10, cantidad - 10) } label: {
                                    Image(systemName: "minus.circle.fill").font(.title2).foregroundStyle(Theme.indigo)
                                }
                                Text("\(Int(cantidad)) ml")
                                    .font(Theme.display(28))
                                    .foregroundStyle(Theme.tinta)
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity)
                                Button { cantidad = min(500, cantidad + 10) } label: {
                                    Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Theme.indigo)
                                }
                            }
                            Text("Disponible: \(Int(almacen.lecheDisponible)) ml")
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaTenue)
                        }
                    }
                    
                    Boton(titulo: uso == nil ? "Confirmar uso" : "Guardar", color: Theme.mantequilla) {
                        if var u = uso {
                            almacen.borrarUsoLeche(u)
                            u.cantidadMl = cantidad
                            almacen.registrarUsoLeche(u)
                        } else {
                            almacen.registrarUsoLeche(UsoLeche(cantidadMl: cantidad))
                        }
                        cerrar()
                    }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle(uso == nil ? "Usar leche" : "Editar uso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }.font(Theme.cuerpo(15))
                }
            }
        }
    }
}

// MARK: - Contenido para la barra superior (sin NavigationStack)
struct ContenidoBancoLeche: View {
    @EnvironmentObject private var almacen: Almacen
    @State private var mostrarHojaExtraccion = false
    @State private var mostrarHojaUso = false
    @State private var extraccionEditando: ExtraccionLeche? = nil
    @State private var usoEditando: UsoLeche? = nil
    @State private var confirmarBorradoExtraccion: ExtraccionLeche? = nil
    @State private var confirmarBorradoUso: UsoLeche? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Cabecera(titulo: "Banco de leche") { EmptyView() }
                
                Tarjeta {
                    VStack(spacing: 8) {
                        Text("\(Int(almacen.lecheDisponible)) ml")
                            .font(Theme.display(42))
                            .foregroundStyle(Theme.tinta)
                            .monospacedDigit()
                        Text("disponibles en el banco")
                            .font(Theme.cuerpo(13))
                            .foregroundStyle(Theme.tintaSuave)
                        
                        HStack(spacing: 16) {
                            Text("\(almacen.extracciones.count) extracciones")
                                .font(Theme.cuerpo(11))
                                .foregroundStyle(Theme.tintaTenue)
                            Text("\(almacen.usosLeche.count) usos")
                                .font(Theme.cuerpo(11))
                                .foregroundStyle(Theme.tintaTenue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                HStack(spacing: 10) {
                    Boton(titulo: "Extracción", simbolo: .mas, color: Theme.cielo) {
                        mostrarHojaExtraccion = true
                    }
                    Boton(titulo: "Usar leche", simbolo: .biberon, color: Theme.mantequilla) {
                        mostrarHojaUso = true
                    }
                }
                
                if let caducando = extraccionesCaducando {
                    Tarjeta(relleno: 14) {
                        HStack(spacing: 10) {
                            Insignia(simbolo: .reloj, fondo: Theme.melocoton, diametro: 32)
                            Text(caducando)
                                .font(Theme.cuerpo(12, .medium))
                                .foregroundStyle(Theme.tinta)
                        }
                    }
                }
                
                if !almacen.extracciones.isEmpty || !almacen.usosLeche.isEmpty {
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 14) {
                            EtiquetaSeccion(texto: "Historial")
                            
                            ForEach(eventosOrdenados, id: \.id) { evento in
                                HStack(spacing: 12) {
                                    Button {
                                        if evento.esExtraccion,
                                           let ext = almacen.extracciones.first(where: { $0.id == evento.id }) {
                                            extraccionEditando = ext
                                        } else if !evento.esExtraccion,
                                                  let uso = almacen.usosLeche.first(where: { $0.id == evento.id }) {
                                            usoEditando = uso
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Insignia(
                                                simbolo: evento.esExtraccion ? .mas : .biberon,
                                                fondo: evento.esExtraccion ? Theme.cielo : Theme.mantequilla,
                                                diametro: 32
                                            )
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(evento.texto)
                                                    .font(Theme.cuerpo(14, .medium))
                                                    .foregroundStyle(Theme.tinta)
                                                    .monospacedDigit()
                                                Text(Fmt.fechaCorta(evento.fecha) + " · " + Fmt.hora(evento.fecha))
                                                    .font(Theme.cuerpo(11))
                                                    .foregroundStyle(Theme.tintaTenue)
                                            }
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button {
                                        if evento.esExtraccion,
                                           let ext = almacen.extracciones.first(where: { $0.id == evento.id }) {
                                            confirmarBorradoExtraccion = ext
                                        } else if !evento.esExtraccion,
                                                  let uso = almacen.usosLeche.first(where: { $0.id == evento.id }) {
                                            confirmarBorradoUso = uso
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(Theme.coral)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if evento.id != eventosOrdenados.last?.id {
                                    Rectangle().fill(Theme.separador).frame(height: 1)
                                }
                            }
                        }
                    }
                }
            }
            .padding(Theme.margen)
            .padding(.bottom, 8)
        }
        .background(Theme.lienzo.ignoresSafeArea())
        .sheet(isPresented: $mostrarHojaExtraccion) { HojaExtraccion() }
        .sheet(isPresented: $mostrarHojaUso) { HojaUsoLeche() }
        .sheet(item: $extraccionEditando) { ext in HojaExtraccion(extraccion: ext) }
        .sheet(item: $usoEditando) { uso in HojaUsoLeche(uso: uso) }
        .alert("¿Eliminar esta extracción?",
               isPresented: Binding(
                   get: { confirmarBorradoExtraccion != nil },
                   set: { if !$0 { confirmarBorradoExtraccion = nil } }
               ),
               presenting: confirmarBorradoExtraccion) { ext in
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                almacen.borrarExtraccion(ext)
            }
        } message: { _ in
            Text("Esta acción no se puede deshacer.")
        }
        .alert("¿Eliminar este uso?",
               isPresented: Binding(
                   get: { confirmarBorradoUso != nil },
                   set: { if !$0 { confirmarBorradoUso = nil } }
               ),
               presenting: confirmarBorradoUso) { uso in
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                almacen.borrarUsoLeche(uso)
            }
        } message: { _ in
            Text("Esta acción no se puede deshacer.")
        }
    }
    
    private var extraccionesCaducando: String? {
        let cal = Calendar.current
        let limite = cal.date(byAdding: .day, value: 3, to: .now) ?? .now
        let caducando = almacen.extracciones.filter { $0.caducidad <= limite }
        guard !caducando.isEmpty else { return nil }
        return "⚠️ \(caducando.count) \(caducando.count == 1 ? "extracción caduca" : "extracciones caducan") en los próximos 3 días."
    }
    
    private struct EventoLeche: Identifiable {
        let id: UUID
        let fecha: Date
        let texto: String
        let esExtraccion: Bool
    }
    
    private var eventosOrdenados: [EventoLeche] {
        let ext = almacen.extracciones.map {
            EventoLeche(id: $0.id, fecha: $0.fecha,
                        texto: "+\(Int($0.cantidadMl)) ml · \($0.almacenamiento.rawValue)",
                        esExtraccion: true)
        }
        let usos = almacen.usosLeche.map {
            EventoLeche(id: $0.id, fecha: $0.fecha,
                        texto: "-\(Int($0.cantidadMl)) ml · Uso",
                        esExtraccion: false)
        }
        return (ext + usos).sorted { $0.fecha > $1.fecha }
    }
}