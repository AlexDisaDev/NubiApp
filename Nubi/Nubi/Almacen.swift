import Foundation
import Combine

@MainActor
final class Almacen: ObservableObject {
    @Published private(set) var bebe: Bebe?
    @Published private(set) var registros: [Registro] = []
    @Published private(set) var medidas: [Medida] = []
    @Published private(set) var citas: [Cita] = []
    @Published private(set) var diario: [EntradaDiario] = []
    @Published private(set) var vacunas: [String: EstadoVacuna] = [:]
    @Published private(set) var gruposPropios: [GrupoPropio] = []
    @Published private(set) var comunidad: Comunidad = .comun
    @Published private(set) var extracciones: [ExtraccionLeche] = []
    @Published private(set) var usosLeche: [UsoLeche] = []
    @Published private(set) var comidas: [ComidaComplementaria] = []
    @Published private(set) var medicinas: [Medicina] = []
    @Published var hojaFinSueñoPendiente: String? = nil
    @Published private(set) var despertarManual: Date? = nil
    @Published private(set) var enfermedades: [Enfermedad] = []
    
    private var cargando = false
    private var ultimaModificacion: Date = .distantPast
    private var ultimoJSON: Data?
    
    init() {
        cargar()
        Recordatorios.reprogramar(citas)
        GestorLiveActivity.shared.recuperarActividadesActivas()

        Sincronizador.compartido.onParticipanteCambio = { esParticipante in
            guard !esParticipante else { return }
            UserDefaults.standard.set(false, forKey: "nubi.viendoCompartido")
        }

        Task {
            await Sincronizador.compartido.refrescarRol()
            await sincronizarAhora()
        }
        Task {
            _ = await NotificadorVentanas.pedirPermiso()
        }
        Task { await bucleSyncPeriodico() }
    }

    
    // MARK: - Bebé
    
    func guardarBebe(_ nuevo: Bebe) {
        bebe = nuevo
        guardar()
    }

    func registrarDespertarManual(_ fecha: Date) {
        despertarManual = fecha
        guardar()
    }
    
    // MARK: - Sueño y cuidados
    
    func empezarSueño(_ tipo: TipoRegistro, en fecha: Date = .now) {
        cerrarSueñosAbiertos(en: fecha)
        cerrarTomasAbiertas(en: fecha)
        registros.append(Registro(tipo: tipo, inicio: fecha))
        guardar()
        
        if let bebe {
            let modo: SueñoActivityAttributes.ContentState.Modo = (tipo == .siesta) ? .siesta : .noche
            GestorLiveActivity.shared.iniciar(modo: modo, inicio: fecha, nombreBebe: bebe.nombre)
        }
    }

    
    func terminarSueño(en fecha: Date = .now) {
        for idx in registros.indices
        where registros[idx].tipo.restaSueño && registros[idx].fin == nil {
            registros[idx].fin = max(fecha, registros[idx].inicio.addingTimeInterval(60))
        }
        
        guard let idx = registros.lastIndex(where: { $0.tipo.esSueño && $0.fin == nil }) else {
            guardar()
            GestorLiveActivity.shared.terminar()
            // ← NUEVO: reprogramar notificación de ventana
            if let bebe {
                NotificadorVentanas.programarProximaVentana(
                    bebe: bebe,
                    registros: registros,
                    tieneAcceso: true  // se verifica dentro
                )
            }
            return
        }
        
        registros[idx].fin = max(fecha, registros[idx].inicio.addingTimeInterval(60))
        guardar()
        GestorLiveActivity.shared.terminar()
        
        // ← NUEVO: reprogramar notificación de ventana
        if let bebe {
            NotificadorVentanas.programarProximaVentana(
                bebe: bebe,
                registros: registros,
                tieneAcceso: true
            )
        }
    }
    
    func registrarEvento(_ tipo: TipoRegistro, lado: LadoPecho? = nil, en fecha: Date = .now, nota: String = "") {
        registros.append(Registro(tipo: tipo, inicio: fecha, fin: fecha, nota: nota, lado: lado))
        guardar()
    }
    
    func registrarPanal(en fecha: Date = .now, pis: Bool, caca: Bool) {
        let pisFinal = (!pis && !caca) ? true : pis
        var r = Registro(tipo: .panal, inicio: fecha, fin: fecha)
        r.panalPis = pisFinal
        r.panalCaca = caca
        registros.append(r)
        guardar()
    }
    
    func borrar(_ registro: Registro) {
        registros.removeAll { $0.id == registro.id }
        guardar()
    }
    
    func actualizar(_ registro: Registro) {
        guard let idx = registros.firstIndex(where: { $0.id == registro.id }) else { return }
        registros[idx] = registro
        guardar()
        
        // ← NUEVO: si es un registro en curso, actualizar también la Live Activity
        if registro.tipo.esSueño && registro.fin == nil {
            let modo: SueñoActivityAttributes.ContentState.Modo = (registro.tipo == .siesta) ? .siesta : .noche
            GestorLiveActivity.shared.actualizar(modo: modo, inicio: registro.inicio)
        } else if registro.tipo == .pecho && registro.fin == nil {
            let ladoLA: SueñoActivityAttributes.ContentState.LadoPechoLA? = registro.lado.map { lado in
                lado == .izquierda ? .izquierda : .derecha
            }
            GestorLiveActivity.shared.actualizar(modo: .pecho, inicio: registro.inicio, ladoPecho: ladoLA)
        } else if registro.tipo == .despertar && registro.fin == nil {
            GestorLiveActivity.shared.actualizar(modo: .despertar, inicio: registro.inicio)
        }
    }
        
    private func cerrarSueñosAbiertos(en fecha: Date) {
        for idx in registros.indices
        where (registros[idx].tipo.esSueño || registros[idx].tipo.restaSueño) && registros[idx].fin == nil {
            registros[idx].fin = max(fecha, registros[idx].inicio.addingTimeInterval(60))
        }
    }

     // ← NUEVO: cierra solo siestas, mantiene sueño nocturno activo
    private func cerrarSoloSiestas(en fecha: Date) {
        for idx in registros.indices
        where registros[idx].tipo == .siesta && registros[idx].fin == nil {
            registros[idx].fin = max(fecha, registros[idx].inicio.addingTimeInterval(60))
        }
    }
    
    func registrarTomaPasada(en fecha: Date, duracionMinutos: Int, lado: LadoPecho?) {
        let fin = fecha.addingTimeInterval(TimeInterval(max(1, duracionMinutos) * 60))
        let r = Registro(tipo: .pecho, inicio: fecha, fin: fin, lado: lado)
        registros.append(r)
        registros.sort { $0.inicio < $1.inicio }
        guardar()
    }

    // MARK: - Banco de Leche

    var lecheDisponible: Double {
        let total = extracciones.reduce(0.0) { $0 + $1.cantidadMl }
        let usado = usosLeche.reduce(0.0) { $0 + $1.cantidadMl }
        return max(0, total - usado)
    }

    func registrarExtraccion(_ e: ExtraccionLeche) {
        extracciones.append(e)
        extracciones.sort { $0.fecha > $1.fecha }
        guardar()
    }

    func borrarExtraccion(_ e: ExtraccionLeche) {
        extracciones.removeAll { $0.id == e.id }
        guardar()
    }

    func registrarUsoLeche(_ u: UsoLeche) {
        usosLeche.append(u)
        usosLeche.sort { $0.fecha > $1.fecha }
        guardar()
    }

    func borrarUsoLeche(_ u: UsoLeche) {
        usosLeche.removeAll { $0.id == u.id }
        guardar()
    }

    // MARK: - Alimentación Complementaria

    func guardarComida(_ c: ComidaComplementaria) {
        if let idx = comidas.firstIndex(where: { $0.id == c.id }) {
            comidas[idx] = c
        } else {
            comidas.append(c)
        }
        comidas.sort { $0.fecha > $1.fecha }
        guardar()
    }

    func borrarComida(_ c: ComidaComplementaria) {
        comidas.removeAll { $0.id == c.id }
        guardar()
    }

    // MARK: - Medicina

    func registrarMedicina(_ m: Medicina) {
        medicinas.append(m)
        medicinas.sort { $0.fechaToma > $1.fechaToma }
        guardar()
    }

    func borrarMedicina(_ m: Medicina) {
        medicinas.removeAll { $0.id == m.id }
        NotificadorMedicinas.cancelar(id: m.id)
        guardar()
    }
    
    // MARK: - Toma de pecho
    
    var tomaEnCurso: Registro? {
        registros.first { $0.tipo == .pecho && $0.fin == nil }
    }
    
    func empezarToma(_ lado: LadoPecho, en fecha: Date = .now) {
        // ← MODIFICADO: solo cerrar siestas, NO sueño nocturno
        cerrarSoloSiestas(en: fecha)
        cerrarTomasAbiertas(en: fecha)
        registros.append(Registro(tipo: .pecho, inicio: fecha, fin: nil, lado: lado))
        guardar()
        
        if let bebe {
            let ladoLA: SueñoActivityAttributes.ContentState.LadoPechoLA =
                (lado == .izquierda) ? .izquierda : .derecha
            GestorLiveActivity.shared.iniciar(
                modo: .pecho,
                inicio: fecha,
                nombreBebe: bebe.nombre,
                ladoPecho: ladoLA
            )
        }
    }
        
    func terminarToma(en fecha: Date = .now) {
        guard let idx = registros.lastIndex(where: { $0.tipo == .pecho && $0.fin == nil }) else { return }
        registros[idx].fin = max(fecha, registros[idx].inicio.addingTimeInterval(60))
        guardar()
        
        // ← NUEVO: verificar si hay un sueño todavía activo
        if let sueñoActivo = registros.first(where: { $0.tipo.esSueño && $0.fin == nil }) {
            // Hay un sueño activo → volver a mostrarlo en la Live Activity
            let modo: SueñoActivityAttributes.ContentState.Modo = (sueñoActivo.tipo == .siesta) ? .siesta : .noche
            GestorLiveActivity.shared.actualizar(modo: modo, inicio: sueñoActivo.inicio)
        } else {
            // No hay sueño activo → terminar la Live Activity
            GestorLiveActivity.shared.terminar()
        }
    }
    
    @discardableResult
    func cambiarPecho(en fecha: Date = .now) -> Bool {
        guard let actual = tomaEnCurso, let ladoActual = actual.lado else { return false }
        let nuevoLado: LadoPecho = (ladoActual == .izquierda) ? .derecha : .izquierda
        
        if let idx = registros.lastIndex(where: { $0.id == actual.id }) {
            registros[idx].fin = max(fecha, registros[idx].inicio.addingTimeInterval(60))
        }
        
        registros.append(Registro(tipo: .pecho, inicio: fecha, fin: nil, lado: nuevoLado))
        registros.sort { $0.inicio < $1.inicio }
        guardar()
        
        let ladoLA: SueñoActivityAttributes.ContentState.LadoPechoLA =
            (nuevoLado == .izquierda) ? .izquierda : .derecha
        GestorLiveActivity.shared.actualizarPecho(inicio: fecha, ladoPecho: ladoLA)
        
        return true
    }
    
    private func cerrarTomasAbiertas(en fecha: Date) {
        for idx in registros.indices where registros[idx].tipo == .pecho && registros[idx].fin == nil {
            registros[idx].fin = max(fecha, registros[idx].inicio.addingTimeInterval(60))
        }
    }
    
    // MARK: - Consultas de sueño
    
    var sueñoEnCurso: Registro? { registros.first { $0.tipo.esSueño && $0.fin == nil } }
    
    var despertarEnCurso: Registro? {
        registros.first { $0.tipo == .despertar && $0.fin == nil }
    }
    
    @discardableResult
    func empezarDespertar(en fecha: Date = .now) -> Bool {
        guard let noche = sueñoEnCurso, noche.tipo == .noche else { return false }
        guard despertarEnCurso == nil else { return false }
        
        if let idx = registros.lastIndex(where: { $0.id == noche.id }) {
            registros[idx].fin = max(fecha, registros[idx].inicio.addingTimeInterval(60))
        }
        
        registros.append(Registro(tipo: .despertar, inicio: fecha, fin: nil))
        registros.sort { $0.inicio < $1.inicio }
        guardar()
        
        GestorLiveActivity.shared.actualizar(modo: .despertar, inicio: fecha)
        return true
    }
    
    func terminarDespertar(en fecha: Date = .now) {
        guard let idx = registros.lastIndex(where: { $0.tipo == .despertar && $0.fin == nil }) else { return }
        registros[idx].fin = max(fecha, registros[idx].inicio.addingTimeInterval(60))
        guardar()
        
        GestorLiveActivity.shared.terminar()
    }
    
    @discardableResult
    func volverADormir(en fecha: Date = .now) -> Bool {
        guard despertarEnCurso != nil else { return false }
        
        terminarDespertar(en: fecha)
        registros.append(Registro(tipo: .noche, inicio: fecha, fin: nil))
        registros.sort { $0.inicio < $1.inicio }
        guardar()
        
        if let bebe {
            GestorLiveActivity.shared.iniciar(modo: .noche, inicio: fecha, nombreBebe: bebe.nombre)
        }
        return true
    }
    
    func registros(deDia dia: Date) -> [Registro] {
        registros.filter { Calendar.current.isDate($0.inicio, inSameDayAs: dia) }.sorted { $0.inicio < $1.inicio }
    }
    
    func intervalosQueTocan(_ dia: Date) -> [Registro] {
        let cal = Calendar.current
        let ini = cal.startOfDay(for: dia)
        guard let fin = cal.date(byAdding: .day, value: 1, to: ini) else { return [] }
        return registros.filter { r in
            guard r.tipo.esIntervalo else { return false }
            return r.inicio < fin && (r.fin ?? .now) > ini
        }.sorted { $0.inicio < $1.inicio }
    }
    
    func duracionEnDia(_ r: Registro, dia: Date, ahora: Date = .now) -> TimeInterval {
        let cal = Calendar.current
        let inicioDia = cal.startOfDay(for: dia)
        guard let finDia = cal.date(byAdding: .day, value: 1, to: inicioDia) else { return 0 }
        let inicio = max(r.inicio, inicioDia)
        let fin = min(r.fin ?? ahora, finDia)
        return max(0, fin.timeIntervalSince(inicio))
    }
    
    var proximaVentana: Sugerencia? {
        guard let bebe, sueñoEnCurso == nil else { return nil }
        return MotorSueño.proximaVentana(bebe: bebe, registros: registros)
    }

    var prediccionDelDia: PrediccionDia? {
        guard let bebe else { return nil }
        return MotorSueño.prediccionDelDia(bebe: bebe, registros: registros, despertarManual: despertarManual)
    }
    
    var ultimaAlimentacion: Registro? {
        registros.filter { $0.tipo.esAlimentacion }.max { $0.inicio < $1.inicio }
    }
    
    var ultimoPanal: Registro? {
        registros.filter { $0.tipo == .panal }.max { $0.inicio < $1.inicio }
    }
    
    // MARK: - Medidas
    
    func guardarMedida(_ m: Medida) {
        if let idx = medidas.firstIndex(where: { $0.id == m.id }) { medidas[idx] = m } else { medidas.append(m) }
        medidas.sort { $0.fecha > $1.fecha }
        guardar()
    }
    
    func borrarMedida(_ m: Medida) {
        medidas.removeAll { $0.id == m.id }
        guardar()
    }
    
    var ultimoPeso: (valor: Double, fecha: Date)? {
        medidas.compactMap { m -> (valor: Double, fecha: Date)? in
            guard let v = m.pesoKg else { return nil }
            return (valor: v, fecha: m.fecha)
        }.max { $0.fecha < $1.fecha }
    }
    
    var ultimaAltura: (valor: Double, fecha: Date)? {
        medidas.compactMap { m -> (valor: Double, fecha: Date)? in
            guard let v = m.alturaCm else { return nil }
            return (valor: v, fecha: m.fecha)
        }.max { $0.fecha < $1.fecha }
    }
    
    var ultimoPerimetro: (valor: Double, fecha: Date)? {
        medidas.compactMap { m -> (valor: Double, fecha: Date)? in
            guard let v = m.perimetroCm else { return nil }
            return (valor: v, fecha: m.fecha)
        }.max { $0.fecha < $1.fecha }
    }
    
    // MARK: - Citas
    
    func guardarCita(_ c: Cita) {
        if let idx = citas.firstIndex(where: { $0.id == c.id }) { citas[idx] = c } else { citas.append(c) }
        citas.sort { $0.fecha < $1.fecha }
        guardar()
        Recordatorios.reprogramar(citas)
    }
    
    func borrarCita(_ c: Cita) {
        citas.removeAll { $0.id == c.id }
        guardar()
        Recordatorios.reprogramar(citas)
    }
    
    var citasProximas: [Cita] { citas.filter { !$0.pasada }.sorted { $0.fecha < $1.fecha } }
    var citasPasadas: [Cita]  { citas.filter { $0.pasada }.sorted { $0.fecha > $1.fecha } }
    var proximaCita: Cita?    { citasProximas.first }
    
    // MARK: - Vacunas
    
    func estadoVacuna(_ id: String) -> EstadoVacuna { vacunas[id] ?? EstadoVacuna() }
    
    func marcarVacuna(_ id: String, puesta: Bool, fecha: Date? = nil) {
        var e = estadoVacuna(id)
        e.puesta = puesta
        e.fecha = puesta ? (fecha ?? e.fecha ?? .now) : nil
        vacunas[id] = e
        guardar()
    }
    
    func vacunasPuestas(en grupo: GrupoVacunal) -> Int {
        grupo.items.filter { estadoVacuna($0.id).puesta }.count
    }
    
    var totalVacunasPuestas: Int {
        let oficiales = CalendarioVacunal.grupos(para: comunidad).reduce(0) { $0 + vacunasPuestas(en: $1) }
        let propios = gruposPropios.reduce(0) { $0 + $1.vacunas.filter(\.puesta).count }
        return oficiales + propios
    }
    
    func fijarComunidad(_ c: Comunidad) { comunidad = c; guardar() }
    
    func añadirGrupoPropio(etiqueta: String, meses: Double) {
        gruposPropios.append(GrupoPropio(etiqueta: etiqueta, meses: meses))
        gruposPropios.sort { $0.meses < $1.meses }
        guardar()
    }
    
    func borrarGrupoPropio(_ id: UUID) { gruposPropios.removeAll { $0.id == id }; guardar() }
    
    func añadirVacunaPropia(_ nombre: String, aGrupo grupoID: UUID, puesta: Bool = false, fecha: Date? = nil) {
        guard let idx = gruposPropios.firstIndex(where: { $0.id == grupoID }) else { return }
        gruposPropios[idx].vacunas.append(VacunaPropia(nombre: nombre, puesta: puesta, fecha: puesta ? (fecha ?? .now) : nil))
        guardar()
    }
    
    func marcarVacunaPropia(grupo grupoID: UUID, vacuna vacunaID: UUID, puesta: Bool) {
        guard let g = gruposPropios.firstIndex(where: { $0.id == grupoID }),
              let v = gruposPropios[g].vacunas.firstIndex(where: { $0.id == vacunaID }) else { return }
        gruposPropios[g].vacunas[v].puesta = puesta
        gruposPropios[g].vacunas[v].fecha = puesta ? (gruposPropios[g].vacunas[v].fecha ?? .now) : nil
        guardar()
    }
    
    func borrarVacunaPropia(grupo grupoID: UUID, vacuna vacunaID: UUID) {
        guard let g = gruposPropios.firstIndex(where: { $0.id == grupoID }) else { return }
        gruposPropios[g].vacunas.removeAll { $0.id == vacunaID }
        guardar()
    }
    
    // MARK: - Diario
    
    func guardarEntrada(_ e: EntradaDiario) {
        if let idx = diario.firstIndex(where: { $0.id == e.id }) { diario[idx] = e } else { diario.append(e) }
        diario.sort { $0.fecha > $1.fecha }
        guardar()
    }
    
    func borrarEntrada(_ e: EntradaDiario) { diario.removeAll { $0.id == e.id }; guardar() }
    
    // MARK: - Sincronización iCloud
    
    func sincronizarAhora() async {
        guard let remoto = await Sincronizador.compartido.descargar() else {
            if let json = ultimoJSON, ultimaModificacion > .distantPast {
                await Sincronizador.compartido.subir(json: json, modificado: ultimaModificacion)
            }
            return
        }
        
        if remoto.modificado > ultimaModificacion {
            aplicarRemoto(remoto.json)
        } else if ultimaModificacion > remoto.modificado, let json = ultimoJSON {
            await Sincronizador.compartido.subir(json: json, modificado: ultimaModificacion)
        }
    }
    
    func adoptarCompartido() async {
        // ← COPIA DE SEGURIDAD: Guarda tus datos locales antes de machacarlos con los compartidos
        if (bebe != nil || !registros.isEmpty),
        let actual = try? Data(contentsOf: url) {
            try? actual.write(to: urlPersonal, options: .atomic)
        }
        UserDefaults.standard.set(true, forKey: "nubi.viendoCompartido")
        guard let remoto = await Sincronizador.compartido.descargar() else { return }
        aplicarRemoto(remoto.json)
        Task { await Sincronizador.compartido.suscribirseACambiosCompartidos() }
    }

    // MARK: - Datos personales vs. compartidos

    private var urlPersonal: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("nubi-personal.json")
    }

    /// Mientras la app está abierta y hay compartido activo, sincroniza cada 30 s
    private func bucleSyncPeriodico() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            let sync = Sincronizador.compartido
            guard sync.esParticipante || sync.sharePropio != nil else { continue }
            await sync.refrescarRol()   // detecta si el share sigue existiendo
            await sincronizarAhora()    // descarga los cambios de tu pareja
        }
    }

    private func aplicarRemoto(_ json: Data) {
        guard let datos = try? JSONDecoder().decode(Disco.self, from: json) else { return }
        
        try? json.write(to: url, options: .atomic)
        ultimoJSON = json
        ultimaModificacion = datos.modificado ?? .now
        
        cargando = true
        asignar(datos)
        cargando = false
        
        Recordatorios.reprogramar(citas)
        
        if let bebe {
            NotificadorVentanas.programarProximaVentana(
                bebe: bebe,
                registros: registros,
                tieneAcceso: true
            )
        }
    }  

    /// Vuelve a tu Nubi personal: restaura tu copia o empieza de cero, y lo sube a TU iCloud
    func salirDeCompartido() async {
        UserDefaults.standard.set(false, forKey: "nubi.viendoCompartido")
        // ← NUEVO: respaldo de seguridad del estado actual antes de tocar nada
        if let actual = try? Data(contentsOf: url) {
            let respaldo = url.appendingPathExtension("respaldo")
            try? actual.write(to: respaldo, options: .atomic)
        }
        if let json = try? Data(contentsOf: urlPersonal) {
            try? FileManager.default.removeItem(at: urlPersonal)
            aplicarRemoto(json)
        } else {
            bebe = nil
            registros = []; medidas = []; citas = []; diario = []
            vacunas = [:]; gruposPropios = []; comunidad = .comun
            extracciones = []; usosLeche = []; comidas = []; medicinas = []
            ultimoJSON = nil
            ultimaModificacion = .distantPast
        }
        guardar()
        await sincronizarAhora()
    }
    /* 
    func forzarSubidaDeRecuperacion() async {
        guard let json = ultimoJSON ?? try? Data(contentsOf: url) else { return }
        await Sincronizador.compartido.forzarSubida(json: json)
    }

    func forzarBajadaDeRecuperacion() async {
        guard let json = await Sincronizador.compartido.forzarBajada() else { return }
        aplicarRemoto(json)
        guardar()
    }
    */

    
    // MARK: - Persistencia
    
    private struct Disco: Codable {
        var version: Int?
        var bebe: Bebe?
        var registros: [Registro]?
        var medidas: [Medida]?
        var citas: [Cita]?
        var diario: [EntradaDiario]?
        var vacunas: [String: EstadoVacuna]?
        var gruposPropios: [GrupoPropio]?
        var comunidad: Comunidad?
        var modificado: Date?
        // ← NUEVOS CAMPOS
        var extracciones: [ExtraccionLeche]?
        var usosLeche: [UsoLeche]?
        var comidas: [ComidaComplementaria]?
        var medicinas: [Medicina]?
        var despertarManual: Date? 
        var enfermedades: [Enfermedad]?
    }
    
    private var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("nubi.json")
    }
    
    private func guardar() {
        guard !cargando else { return }
        
        ultimaModificacion = .now
        
        let datos = Disco(version: 5, bebe: bebe, registros: registros, medidas: medidas,
                          citas: citas, diario: diario, vacunas: vacunas,
                          gruposPropios: gruposPropios, comunidad: comunidad,
                          modificado: ultimaModificacion,extracciones: extracciones,
                          usosLeche: usosLeche, comidas: comidas, medicinas: medicinas, despertarManual: despertarManual, 
                          enfermedades: enfermedades)
        
        guard let json = try? JSONEncoder().encode(datos) else { return }
        
        ultimoJSON = json
        try? json.write(to: url, options: .atomic)
        
        Sincronizador.compartido.programarSubida(json: json, modificado: ultimaModificacion)
    }
    
    private func cargar() {
        cargando = true
        defer { cargando = false }
        
        guard let json = try? Data(contentsOf: url),
              let datos = try? JSONDecoder().decode(Disco.self, from: json) else { return }
        
        ultimoJSON = json
        ultimaModificacion = datos.modificado ?? .distantPast
        asignar(datos)
    }
    
    private func asignar(_ datos: Disco) {
        bebe          = datos.bebe
        registros     = datos.registros ?? []
        medidas       = (datos.medidas ?? []).sorted { $0.fecha > $1.fecha }
        citas         = (datos.citas ?? []).sorted { $0.fecha < $1.fecha }
        diario        = (datos.diario ?? []).sorted { $0.fecha > $1.fecha }
        vacunas       = datos.vacunas ?? [:]
        gruposPropios = (datos.gruposPropios ?? []).sorted { $0.meses < $1.meses }
        comunidad     = datos.comunidad ?? .comun
        extracciones = (datos.extracciones ?? []).sorted { $0.fecha > $1.fecha }
        usosLeche    = (datos.usosLeche ?? []).sorted { $0.fecha > $1.fecha }
        comidas      = (datos.comidas ?? []).sorted { $0.fecha > $1.fecha }
        medicinas = (datos.medicinas ?? []).sorted { $0.fechaToma > $1.fechaToma }
        despertarManual = datos.despertarManual
        enfermedades = (datos.enfermedades ?? []).sorted { $0.fechaInicio > $1.fechaInicio }
    }
    
    func borrarTodo() {
        bebe = nil; registros = []; medidas = []; citas = []; diario = []
        vacunas = [:]; gruposPropios = []; comunidad = .comun
        extracciones = []; usosLeche = []; comidas = []; despertarManual = nil; enfermedades = []
        Recordatorios.cancelarTodo()
        NotificadorVentanas.cancelarTodo() 
        NotificadorMedicinas.cancelarTodo() // ← AQUÍ, justo antes de guardar()
        guardar()
    }

    // MARK: - Enfermedades
    func guardarEnfermedad(_ e: Enfermedad) {
        if let idx = enfermedades.firstIndex(where: { $0.id == e.id }) {
            enfermedades[idx] = e
        } else {
            enfermedades.append(e)
        }
        enfermedades.sort { $0.fechaInicio > $1.fechaInicio }
        guardar()
    }

    func borrarEnfermedad(_ e: Enfermedad) {
        enfermedades.removeAll { $0.id == e.id }
        guardar()
    }

    var enfermedadesActivas: [Enfermedad] { enfermedades.filter(\.activa) }
    var enfermedadesPasadas: [Enfermedad] { enfermedades.filter { !$0.activa } }
    
    func registrarSueño(_ tipo: TipoRegistro, inicio: Date, duracion: TimeInterval) {
        let fin = inicio.addingTimeInterval(max(duracion, 60))
        registros.append(Registro(tipo: tipo, inicio: inicio, fin: fin))
        registros.sort { $0.inicio < $1.inicio }
        guardar()
    }
    
    @discardableResult
    func registrarDespertar(inicio: Date, duracion: TimeInterval, ahora: Date = .now) -> Bool {
        guard inicio <= ahora else { return false }
        
        let duracionValida = max(60, duracion)
        let fin = min(inicio.addingTimeInterval(duracionValida), ahora)
        
        registros.append(Registro(tipo: .despertar, inicio: inicio, fin: fin))
        registros.sort { $0.inicio < $1.inicio }
        guardar()
        return true
    }
    
    func registrarBiberon(en fecha: Date = .now, cantidad: Double?, unidad: UnidadBiberon?, tipoLeche: TipoLeche? = nil, nota: String = "") {
        var r = Registro(tipo: .biberon, inicio: fecha, fin: fecha, nota: nota)
        r.cantidadBiberon = cantidad
        r.unidadBiberon = unidad
        r.tipoLeche = tipoLeche
        registros.append(r)
        guardar()
    }
}
