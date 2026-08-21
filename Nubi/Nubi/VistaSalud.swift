import SwiftUI

enum SeccionSalud: String, CaseIterable {
    case vacunas, citas, enfermedades
}

struct VistaSalud: View {
    @EnvironmentObject private var almacen: Almacen
    @State private var seccion: SeccionSalud = .vacunas
    @State private var editandoCita: Cita?
    @State private var editandoEnfermedad: Enfermedad?
    @State private var eligiendoComunidad = false
    @State private var creandoGrupo = false
    @State private var añadiendoAGrupo: GrupoPropio?
    
    private var gruposCalendario: [GrupoVacunal] {
        CalendarioVacunal.grupos(para: almacen.comunidad)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Cabecera(titulo: L10n.t("Salud"), subtitulo: subtitulo) {
                    botonCabecera
                }
                
                SelectorNubi(
                    opciones: [
                        OpcionSelector(valor: SeccionSalud.vacunas, titulo: L10n.t("Vacunas")),
                        OpcionSelector(valor: SeccionSalud.citas, titulo: L10n.t("Citas")),
                        OpcionSelector(valor: SeccionSalud.enfermedades, titulo: L10n.t("Enfermedades"))
                    ],
                    seleccion: $seccion
                )
                
                if seccion == .vacunas {
                    bloqueVacunas
                } else if seccion == .citas {
                    bloqueCitas
                } else {
                    bloqueEnfermedades
                }
            }
            .padding(Theme.margen)
            .padding(.bottom, 8)
        }
        .background(Theme.lienzo.ignoresSafeArea())
        .sheet(item: $editandoCita) { c in HojaCita(cita: c) }
        .sheet(item: $editandoEnfermedad) { e in HojaEnfermedad(enfermedad: e) }
        .sheet(isPresented: $eligiendoComunidad) { HojaComunidad() }
        .sheet(isPresented: $creandoGrupo) { HojaNuevaEdad() }
        .sheet(item: $añadiendoAGrupo) { g in HojaAñadirVacuna(grupo: g) }
    }
    
    // MARK: - Botón dinámico de la cabecera según la pestaña
    @ViewBuilder
    private var botonCabecera: some View {
        switch seccion {
        case .citas:
            BotonIcono(simbolo: .mas, color: Theme.lila, diametro: 42) {
                editandoCita = Cita()
            }
        case .enfermedades:
            BotonIcono(simbolo: .mas, color: Theme.lila, diametro: 42) {
                editandoEnfermedad = Enfermedad()
            }
        case .vacunas:
            EmptyView()
        }
    }
    
    private var subtitulo: String {
        switch seccion {
        case .vacunas:
            let totalCalendario = CalendarioVacunal.totalItems(para: almacen.comunidad)
            let totalPropias = almacen.gruposPropios.reduce(0) { $0 + $1.vacunas.count }
            let total = totalCalendario + totalPropias
            if total == 0 { return L10n.t("Sin vacunas añadidas") }
            return "\(almacen.totalVacunasPuestas) de \(total) marcadas"
        case .citas:
            let n = almacen.citasProximas.count
            return n == 0
                ? L10n.t("Sin citas pendientes")
                : "\(n) \(n == 1 ? L10n.t("cita pendiente") : L10n.t("citas pendientes"))"
        case .enfermedades:
            let activas = almacen.enfermedadesActivas.count
            let total = almacen.enfermedades.count
            if total == 0 { return L10n.t("Sin enfermedades registradas") }
            if activas == 0 {
                return "\(total) \(total == 1 ? L10n.t("enfermedad pasada") : L10n.t("enfermedades pasadas"))"
            }
            return "\(activas) \(L10n.t("en curso")) · \(total) \(L10n.t("en total"))"
        }
    }
    
    // MARK: - Enfermedades (NUEVO)
    @ViewBuilder
    private var bloqueEnfermedades: some View {
        if almacen.enfermedades.isEmpty {
            Tarjeta {
                EstadoVacio(
                    simbolo: .botiquin,
                    titulo: L10n.t("Ninguna enfermedad registrada"),
                    texto: L10n.t("Anota resfriados, gripes, alergias o cualquier proceso de salud que quieras recordar."),
                    color: Theme.coral
                )
            }
            Boton(titulo: L10n.t("Registra una enfermedad"), simbolo: .mas, color: Theme.lila) {
                editandoEnfermedad = Enfermedad()
            }
        } else {
            if !almacen.enfermedadesActivas.isEmpty {
                Tarjeta {
                    VStack(alignment: .leading, spacing: 14) {
                        EtiquetaSeccion(texto: L10n.t("En curso"))
                        ForEach(almacen.enfermedadesActivas) { e in
                            filaEnfermedad(e)
                            if e.id != almacen.enfermedadesActivas.last?.id {
                                Rectangle().fill(Theme.separador).frame(height: 1)
                            }
                        }
                    }
                }
            }
            if !almacen.enfermedadesPasadas.isEmpty {
                Tarjeta {
                    VStack(alignment: .leading, spacing: 14) {
                        EtiquetaSeccion(texto: L10n.t("Pasadas"))
                        ForEach(almacen.enfermedadesPasadas.prefix(20)) { e in
                            filaEnfermedad(e)
                            if e.id != almacen.enfermedadesPasadas.prefix(20).last?.id {
                                Rectangle().fill(Theme.separador).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func filaEnfermedad(_ e: Enfermedad) -> some View {
        Button {
            editandoEnfermedad = e
        } label: {
            HStack(spacing: 12) {
                Insignia(
                    simbolo: .botiquin,
                    fondo: e.activa ? Theme.coral : Theme.lila.opacity(0.25),
                    diametro: 38
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.nombre.isEmpty ? L10n.t("Sin nombre") : e.nombre)
                        .font(Theme.cuerpo(14, .semibold))
                        .foregroundStyle(e.activa ? Theme.tinta : Theme.tintaSuave)
                        .multilineTextAlignment(.leading)
                    Text(e.textoDuracion)
                        .font(Theme.cuerpo(12))
                        .foregroundStyle(Theme.tintaSuave)
                        .monospacedDigit()
                    if !e.medicacion.isEmpty {
                        Text("💊 " + e.medicacion)
                            .font(Theme.cuerpo(11))
                            .foregroundStyle(Theme.tintaTenue)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if e.activa {
                    Pastilla(texto: L10n.t("En curso"), color: Theme.coral)
                }
                Ilus(.chevronDer, 13, color: Theme.tintaTenue)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Vacunas
    @ViewBuilder
    private var bloqueVacunas: some View {
        if let bebe = almacen.bebe {
            let meses = bebe.edadEnMeses
            selectorComunidad
            if almacen.comunidad == .otros {
                Tarjeta {
                    VStack(alignment: .leading, spacing: 8) {
                        EtiquetaSeccion(texto: L10n.t("Otros países"))
                        Text(L10n.t("Cada país tiene su propio calendario oficial"))
                            .font(Theme.cuerpo(15, .semibold))
                            .foregroundStyle(Theme.tinta)
                        Text(L10n.t("Para no mostrar un calendario que no corresponda a tu país, aquí puedes anotar manualmente las vacunas que le pongan."))
                            .font(Theme.cuerpo(12))
                            .foregroundStyle(Theme.tintaSuave)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                if let siguiente = CalendarioVacunal.siguienteGrupo(
                    mesesDelBebe: meses,
                    comunidad: almacen.comunidad
                ) {
                    Tarjeta {
                        HStack(spacing: 12) {
                            Insignia(simbolo: .jeringa, fondo: Theme.cielo, diametro: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                EtiquetaSeccion(texto: L10n.t("Siguiente tanda"))
                                Text(siguiente.etiqueta)
                                    .font(Theme.display(21))
                                    .foregroundStyle(Theme.tinta)
                                Text(siguiente.items.map(\.nombre).joined(separator: " · "))
                                    .font(Theme.cuerpo(11))
                                    .foregroundStyle(Theme.tintaSuave)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                ForEach(gruposCalendario) { grupo in
                    Tarjeta {
                        Desplegable(
                            titulo: grupo.etiqueta,
                            subtitulo: estadoGrupo(grupo),
                            insignia: (.jeringa, colorGrupo(grupo, mesesDelBebe: meses)),
                            abiertoInicial: grupo.id == CalendarioVacunal.grupoActual(
                                mesesDelBebe: meses,
                                comunidad: almacen.comunidad
                            )?.id
                        ) {
                            ForEach(grupo.items) { item in
                                filaVacuna(item)
                            }
                        }
                    }
                }
            }
            bloquePropio
            if almacen.comunidad != .otros {
                Text(CalendarioVacunal.avisoGeneral)
                    .font(Theme.cuerpo(11))
                    .foregroundStyle(Theme.tintaTenue)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }
    
    private var selectorComunidad: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    eligiendoComunidad = true
                } label: {
                    HStack(spacing: 12) {
                        Insignia(simbolo: .botiquin, fondo: Theme.menta, diametro: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            EtiquetaSeccion(texto: L10n.t("Calendario de"))
                            Text(almacen.comunidad.nombre)
                                .font(Theme.cuerpo(15, .semibold))
                                .foregroundStyle(Theme.tinta)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Ilus(.chevronDer, 14, color: Theme.tintaTenue)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Text(CalendarioVacunal.aviso(para: almacen.comunidad))
                    .font(Theme.cuerpo(11))
                    .foregroundStyle(Theme.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private func filaVacuna(_ item: ItemVacuna) -> some View {
        let estado = almacen.estadoVacuna(item.id)
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                almacen.marcarVacuna(item.id, puesta: !estado.puesta)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                casilla(estado.puesta)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.nombre)
                        .font(Theme.cuerpo(14, .medium))
                        .foregroundStyle(estado.puesta ? Theme.tintaSuave : Theme.tinta)
                        .strikethrough(estado.puesta, color: Theme.tintaTenue)
                        .multilineTextAlignment(.leading)
                    if !item.detalle.isEmpty {
                        Text(item.detalle)
                            .font(Theme.cuerpo(11))
                            .foregroundStyle(Theme.tintaTenue)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    if estado.puesta, let f = estado.fecha {
                        Text(L10n.t("Puesta el") + " " + Fmt.fechaCorta(f))
                            .font(Theme.cuerpo(11, .medium))
                            .foregroundStyle(Theme.indigo)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func casilla(_ puesta: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(puesta ? Color.clear : Theme.tintaTenue, lineWidth: 1.8)
                .background(Circle().fill(puesta ? Theme.menta : Color.clear))
                .frame(width: 26, height: 26)
            if puesta {
                Ilus(.check, 15, color: Theme.tinta)
            }
        }
    }
    
    private func estadoGrupo(_ g: GrupoVacunal) -> String {
        let puestas = almacen.vacunasPuestas(en: g)
        if puestas == 0 {
            return "\(g.items.count) \(g.items.count == 1 ? L10n.t("vacuna") : L10n.t("vacunas"))"
        }
        if puestas == g.items.count {
            return L10n.t("Todas puestas")
        }
        return "\(puestas) de \(g.items.count) \(L10n.t("puestas"))"
    }
    
    private func colorGrupo(_ g: GrupoVacunal, mesesDelBebe: Double) -> Color {
        let puestas = almacen.vacunasPuestas(en: g)
        if puestas == g.items.count {
            return Theme.menta
        }
        if g.meses <= mesesDelBebe {
            return Theme.melocoton
        }
        return Theme.lila.opacity(0.5)
    }
    
    @ViewBuilder
    private var bloquePropio: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EtiquetaSeccion(texto: L10n.t("Añadidas por ti"))
                Spacer()
                BotonSecundario(titulo: L10n.t("Añadir edad"), simbolo: .mas) {
                    creandoGrupo = true
                }
            }
            if almacen.gruposPropios.isEmpty {
                Tarjeta {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("Tu propio bloque"))
                            .font(Theme.cuerpo(15, .semibold))
                            .foregroundStyle(Theme.tinta)
                        if almacen.comunidad == .otros {
                            Text(L10n.t("Crea una edad (\u{201C}5 meses\u{201D}, \u{201C}antes del viaje\u{201D}) y añade dentro las vacunas que le hayan puesto."))
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(L10n.t("Crea una edad (\u{201C}5 meses\u{201D}, \u{201C}antes del viaje\u{201D}) y añade dentro las vacunas que le hayan puesto y no estén en el calendario de arriba."))
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                ForEach(almacen.gruposPropios) { grupo in
                    Tarjeta {
                        Desplegable(
                            titulo: grupo.etiqueta,
                            subtitulo: resumenPropio(grupo),
                            insignia: (.jeringa, Theme.mantequilla),
                            abiertoInicial: true
                        ) {
                            ForEach(grupo.vacunas) { v in
                                filaVacunaPropia(grupo: grupo, vacuna: v)
                            }
                            HStack(spacing: 10) {
                                BotonSecundario(titulo: L10n.t("Añadir vacuna"), simbolo: .mas) {
                                    añadiendoAGrupo = grupo
                                }
                                Spacer()
                                Button {
                                    withAnimation { almacen.borrarGrupoPropio(grupo.id) }
                                } label: {
                                    Ilus(.papelera, 15, color: Theme.tintaTenue)
                                        .frame(width: 34, height: 34)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 2)
                        }
                    }
                }
            }
        }
    }
    
    private func filaVacunaPropia(grupo: GrupoPropio, vacuna: VacunaPropia) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    almacen.marcarVacunaPropia(
                        grupo: grupo.id,
                        vacuna: vacuna.id,
                        puesta: !vacuna.puesta
                    )
                }
            } label: {
                casilla(vacuna.puesta)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(vacuna.nombre)
                    .font(Theme.cuerpo(14, .medium))
                    .foregroundStyle(vacuna.puesta ? Theme.tintaSuave : Theme.tinta)
                    .strikethrough(vacuna.puesta, color: Theme.tintaTenue)
                    .multilineTextAlignment(.leading)
                if vacuna.puesta, let f = vacuna.fecha {
                    Text(L10n.t("Puesta el") + " " + Fmt.fechaCorta(f))
                        .font(Theme.cuerpo(11, .medium))
                        .foregroundStyle(Theme.indigo)
                }
            }
            Spacer(minLength: 0)
            Button {
                withAnimation { almacen.borrarVacunaPropia(grupo: grupo.id, vacuna: vacuna.id) }
            } label: {
                Ilus(.cerrar, 12, color: Theme.tintaTenue)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private func resumenPropio(_ g: GrupoPropio) -> String {
        if g.vacunas.isEmpty {
            return L10n.t("Sin vacunas todavía")
        }
        let puestas = g.vacunas.filter(\.puesta).count
        return puestas == g.vacunas.count
            ? L10n.t("Todas puestas")
            : "\(puestas) de \(g.vacunas.count) \(L10n.t("puestas"))"
    }
    
    // MARK: - Citas
    @ViewBuilder
    private var bloqueCitas: some View {
        if almacen.citas.isEmpty {
            Tarjeta {
                EstadoVacio(
                    simbolo: .calendario,
                    titulo: L10n.t("Ninguna cita apuntada"),
                    texto: L10n.t("Anota la próxima revisión y Nubi te avisa la tarde de antes."),
                    color: Theme.menta
                )
            }
            Boton(titulo: L10n.t("Apuntar una cita"), simbolo: .mas, color: Theme.lila) {
                editandoCita = Cita()
            }
        } else {
            if !almacen.citasProximas.isEmpty {
                Tarjeta {
                    VStack(alignment: .leading, spacing: 14) {
                        EtiquetaSeccion(texto: L10n.t("Pendientes"))
                        ForEach(almacen.citasProximas) { c in
                            filaCita(c, destacada: c.id == almacen.proximaCita?.id)
                            if c.id != almacen.citasProximas.last?.id {
                                Rectangle().fill(Theme.separador).frame(height: 1)
                            }
                        }
                    }
                }
            }
            if !almacen.citasPasadas.isEmpty {
                Tarjeta {
                    VStack(alignment: .leading, spacing: 14) {
                        EtiquetaSeccion(texto: L10n.t("Ya pasadas"))
                        ForEach(almacen.citasPasadas.prefix(10)) { c in
                            filaCita(c, destacada: false)
                            if c.id != almacen.citasPasadas.prefix(10).last?.id {
                                Rectangle().fill(Theme.separador).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func filaCita(_ c: Cita, destacada: Bool) -> some View {
        Button {
            editandoCita = c
        } label: {
            HStack(spacing: 12) {
                Insignia(
                    simbolo: c.tipo.simbolo,
                    fondo: c.pasada ? Theme.lila.opacity(0.25) : c.tipo.color,
                    diametro: 38
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.tituloVisible)
                        .font(Theme.cuerpo(14, .semibold))
                        .foregroundStyle(c.pasada ? Theme.tintaSuave : Theme.tinta)
                        .multilineTextAlignment(.leading)
                    Text(
                        c.pasada
                            ? Fmt.fechaCorta(c.fecha)
                            : Fmt.cuandoFalta(c.fecha) + (c.lugar.isEmpty ? "" : " · \(c.lugar)")
                    )
                    .font(Theme.cuerpo(12))
                    .foregroundStyle(Theme.tintaSuave)
                    .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if destacada {
                    Pastilla(texto: L10n.t("Próxima"), color: Theme.menta)
                }
                Ilus(.chevronDer, 13, color: Theme.tintaTenue)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hoja de enfermedad (NUEVO)
struct HojaEnfermedad: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    @State var enfermedad: Enfermedad
    @State private var enCurso: Bool = true
    
    private var esNueva: Bool {
        !almacen.enfermedades.contains { $0.id == enfermedad.id }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(spacing: 12) {
                            Insignia(simbolo: .botiquin, fondo: Theme.coral, diametro: 54)
                            Text(esNueva ? L10n.t("Nueva enfermedad") : L10n.t("Editar enfermedad"))
                                .font(Theme.display(22))
                                .foregroundStyle(Theme.tinta)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: L10n.t("Enfermedad"))
                                TextField(L10n.t("Resfriado, gripe, otitis…"), text: $enfermedad.nombre)
                                    .font(Theme.cuerpo(16))
                            }
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: L10n.t("Fecha de inicio"))
                                DatePicker("", selection: $enfermedad.fechaInicio, in: ...Date(), displayedComponents: .date)
                                    .labelsHidden()
                            }
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            Toggle(isOn: $enCurso) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.t("Todavía en curso"))
                                        .font(Theme.cuerpo(15))
                                        .foregroundStyle(Theme.tinta)
                                    Text(L10n.t("Desactívalo para marcar la fecha de fin"))
                                        .font(Theme.cuerpo(11))
                                        .foregroundStyle(Theme.tintaTenue)
                                }
                            }
                            .tint(Theme.indigo)
                            .onChange(of: enCurso) { _, nueva in
                                if nueva {
                                    enfermedad.fechaFin = nil
                                } else if enfermedad.fechaFin == nil {
                                    enfermedad.fechaFin = Date()
                                }
                            }
                            if !enCurso {
                                Rectangle().fill(Theme.separador).frame(height: 1)
                                VStack(alignment: .leading, spacing: 6) {
                                    EtiquetaSeccion(texto: L10n.t("Fecha de fin"))
                                    DatePicker("", selection: Binding(
                                        get: { enfermedad.fechaFin ?? Date() },
                                        set: { enfermedad.fechaFin = $0 }
                                    ), in: enfermedad.fechaInicio...Date(), displayedComponents: .date)
                                    .labelsHidden()
                                }
                            }
                        }
                    }
                    
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 6) {
                            EtiquetaSeccion(texto: L10n.t("Medicación"))
                            TextField(L10n.t("Apiretal cada 8h, Augmentine…"), text: $enfermedad.medicacion, axis: .vertical)
                                .font(Theme.cuerpo(15))
                                .lineLimit(2...4)
                        }
                    }
                    
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 6) {
                            EtiquetaSeccion(texto: L10n.t("Notas"))
                            TextField(L10n.t("Síntomas, evolución, visitas al médico…"), text: $enfermedad.notas, axis: .vertical)
                                .font(Theme.cuerpo(15))
                                .lineLimit(3...8)
                        }
                    }
                    
                    Boton(titulo: L10n.t("Guardar"), color: Theme.lila) {
                        if enCurso { enfermedad.fechaFin = nil }
                        almacen.guardarEnfermedad(enfermedad)
                        cerrar()
                    }
                    
                    if !esNueva {
                        Button {
                            almacen.borrarEnfermedad(enfermedad)
                            cerrar()
                        } label: {
                            HStack(spacing: 7) {
                                Ilus(.papelera, 14, color: Theme.indigo)
                                Text(L10n.t("Borrar esta enfermedad"))
                                    .font(Theme.cuerpo(14, .medium))
                                    .foregroundStyle(Theme.indigo)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle(esNueva ? L10n.t("Nueva enfermedad") : L10n.t("Enfermedad"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancelar")) { cerrar() }
                        .font(Theme.cuerpo(15))
                }
            }
            .onAppear {
                enCurso = enfermedad.activa
            }
        }
    }
}

// MARK: - Elegir comunidad
struct HojaComunidad: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("Elige el calendario oficial que quieres ver. Si no estás en España, selecciona Otros países y añade manualmente las vacunas."))
                        .font(Theme.cuerpo(13))
                        .foregroundStyle(Theme.tintaSuave)
                        .fixedSize(horizontal: false, vertical: true)
                    Tarjeta(relleno: 14) {
                        VStack(spacing: 0) {
                            ForEach(Comunidad.allCases) { c in
                                Button {
                                    almacen.fijarComunidad(c)
                                    cerrar()
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(c.nombre)
                                            .font(Theme.cuerpo(15, almacen.comunidad == c ? .semibold : .regular))
                                            .foregroundStyle(Theme.tinta)
                                            .multilineTextAlignment(.leading)
                                        Spacer(minLength: 0)
                                        if almacen.comunidad == c {
                                            Ilus(.check, 16, color: Theme.indigo)
                                        }
                                    }
                                    .padding(.vertical, 11)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if c != Comunidad.allCases.last {
                                    Rectangle()
                                        .fill(Theme.separador)
                                        .frame(height: 1)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle(L10n.t("Calendario"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancelar")) {
                        cerrar()
                    }
                    .font(Theme.cuerpo(15))
                }
            }
        }
    }
}

// MARK: - Nueva edad
struct HojaNuevaEdad: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    @State private var meses = 5
    @State private var etiqueta = ""
    @State private var usarTexto = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 14) {
                            SelectorNubi(
                                opciones: [
                                    OpcionSelector(valor: false, titulo: L10n.t("Por meses")),
                                    OpcionSelector(valor: true, titulo: L10n.t("Texto libre"))
                                ],
                                seleccion: $usarTexto
                            )
                            if usarTexto {
                                VStack(alignment: .leading, spacing: 6) {
                                    EtiquetaSeccion(texto: L10n.t("Nombre del bloque"))
                                    TextField(L10n.t("Antes del viaje"), text: $etiqueta)
                                        .font(Theme.cuerpo(16))
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    EtiquetaSeccion(texto: L10n.t("Edad"))
                                    Stepper(
                                        "\(meses) \(meses == 1 ? L10n.t("mes") : L10n.t("meses"))",
                                        value: $meses,
                                        in: 0...216
                                    )
                                    .font(Theme.cuerpo(16))
                                }
                            }
                        }
                    }
                    Boton(titulo: L10n.t("Crear bloque"), color: Theme.lila) {
                        let nombre = usarTexto
                            ? etiqueta.trimmingCharacters(in: .whitespaces)
                            : "\(meses) \(meses == 1 ? L10n.t("mes") : L10n.t("meses"))"
                        guard !nombre.isEmpty else { return }
                        almacen.añadirGrupoPropio(
                            etiqueta: nombre,
                            meses: usarTexto ? 999 : Double(meses)
                        )
                        cerrar()
                    }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle(L10n.t("Nueva edad"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancelar")) {
                        cerrar()
                    }
                    .font(Theme.cuerpo(15))
                }
            }
        }
    }
}

// MARK: - Añadir vacuna (buscador o manual)
struct HojaAñadirVacuna: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    let grupo: GrupoPropio
    @State private var busqueda = ""
    @State private var yaPuesta = true
    @State private var fecha = Date()
    
    private var resultados: [String] {
        CatalogoVacunas.buscar(busqueda)
    }
    
    private var textoLimpio: String {
        busqueda.trimmingCharacters(in: .whitespaces)
    }
    
    private var esNombreNuevo: Bool {
        !textoLimpio.isEmpty && !resultados.contains {
            $0.caseInsensitiveCompare(textoLimpio) == .orderedSame
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 6) {
                            EtiquetaSeccion(texto: L10n.t("Buscar o escribir"))
                            TextField(L10n.t("Nombre de la vacuna"), text: $busqueda)
                                .font(Theme.cuerpo(16))
                                .textInputAutocapitalization(.sentences)
                                .autocorrectionDisabled()
                        }
                    }
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $yaPuesta) {
                                Text(L10n.t("Ya se la han puesto"))
                                    .font(Theme.cuerpo(15))
                                    .foregroundStyle(Theme.tinta)
                            }
                            .tint(Theme.indigo)
                            if yaPuesta {
                                Rectangle()
                                    .fill(Theme.separador)
                                    .frame(height: 1)
                                HStack {
                                    EtiquetaSeccion(texto: L10n.t("Fecha"))
                                    Spacer()
                                    DatePicker(
                                        "",
                                        selection: $fecha,
                                        in: ...Date(),
                                        displayedComponents: .date
                                    )
                                    .labelsHidden()
                                }
                            }
                        }
                    }
                    if esNombreNuevo {
                        Boton(
                            titulo: L10n.t("Añadir") + " \u{201C}\(textoLimpio)\u{201D}",
                            simbolo: .mas,
                            color: Theme.mantequilla
                        ) {
                            añadir(textoLimpio)
                        }
                    }
                    if !resultados.isEmpty {
                        Tarjeta(relleno: 14) {
                            VStack(spacing: 0) {
                                ForEach(resultados, id: \.self) { nombre in
                                    Button {
                                        añadir(nombre)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Insignia(
                                                simbolo: .jeringa,
                                                fondo: Theme.cielo,
                                                diametro: 30
                                            )
                                            Text(nombre)
                                                .font(Theme.cuerpo(14))
                                                .foregroundStyle(Theme.tinta)
                                                .multilineTextAlignment(.leading)
                                            Spacer(minLength: 0)
                                            Ilus(.mas, 13, color: Theme.tintaTenue)
                                        }
                                        .padding(.vertical, 9)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if nombre != resultados.last {
                                        Rectangle()
                                            .fill(Theme.separador)
                                            .frame(height: 1)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle(grupo.etiqueta)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancelar")) {
                        cerrar()
                    }
                    .font(Theme.cuerpo(15))
                }
            }
        }
    }
    
    private func añadir(_ nombre: String) {
        almacen.añadirVacunaPropia(
            nombre,
            aGrupo: grupo.id,
            puesta: yaPuesta,
            fecha: fecha
        )
        cerrar()
    }
}

// MARK: - Hoja de cita
struct HojaCita: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    @State var cita: Cita
    
    private var esNueva: Bool {
        !almacen.citas.contains { $0.id == cita.id }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 12) {
                            EtiquetaSeccion(texto: L10n.t("Con quién"))
                            SelectorNubi(
                                opciones: TipoCita.allCases.map {
                                    OpcionSelector(valor: $0, titulo: $0.titulo)
                                },
                                seleccion: $cita.tipo
                            )
                        }
                    }
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: L10n.t("Motivo"))
                                TextField(L10n.t("Revisión de los 4 meses"), text: $cita.titulo)
                                    .font(Theme.cuerpo(16))
                            }
                            Rectangle()
                                .fill(Theme.separador)
                                .frame(height: 1)
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: L10n.t("Cuándo"))
                                DatePicker("", selection: $cita.fecha)
                                    .labelsHidden()
                            }
                            Rectangle()
                                .fill(Theme.separador)
                                .frame(height: 1)
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: L10n.t("Dónde"))
                                TextField(L10n.t("Centro de salud"), text: $cita.lugar)
                                    .font(Theme.cuerpo(16))
                            }
                        }
                    }
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $cita.recordar) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.t("Avisarme la tarde de antes"))
                                        .font(Theme.cuerpo(15))
                                        .foregroundStyle(Theme.tinta)
                                    Text(L10n.t("Aviso local en este iPhone"))
                                        .font(Theme.cuerpo(11))
                                        .foregroundStyle(Theme.tintaTenue)
                                }
                            }
                            .tint(Theme.indigo)
                            Rectangle()
                                .fill(Theme.separador)
                                .frame(height: 1)
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: L10n.t("Notas"))
                                TextField(
                                    L10n.t("Preguntas que quieres hacer…"),
                                    text: $cita.nota,
                                    axis: .vertical
                                )
                                .font(Theme.cuerpo(15))
                                .lineLimit(2...6)
                            }
                        }
                    }
                    Boton(titulo: L10n.t("Guardar cita"), color: Theme.lila) {
                        Task {
                            let concedido = await Recordatorios.permisoConcedido()
                            if cita.recordar, !concedido {
                                _ = await Recordatorios.pedirPermiso()
                            }
                            almacen.guardarCita(cita)
                            cerrar()
                        }
                    }
                    if !esNueva {
                        Button {
                            almacen.borrarCita(cita)
                            cerrar()
                        } label: {
                            HStack(spacing: 7) {
                                Ilus(.papelera, 14, color: Theme.indigo)
                                Text(L10n.t("Borrar esta cita"))
                                    .font(Theme.cuerpo(14, .medium))
                                    .foregroundStyle(Theme.indigo)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle(esNueva ? L10n.t("Nueva cita") : L10n.t("Cita"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancelar")) {
                        cerrar()
                    }
                    .font(Theme.cuerpo(15))
                }
            }
        }
    }
}