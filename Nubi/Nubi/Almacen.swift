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

    private var cargando = false

    init() {
        cargar()
        Recordatorios.reprogramar(citas)
    }

    // MARK: - Bebé
    func guardarBebe(_ nuevo: Bebe) {
        bebe = nuevo
        guardar()
    }

    // MARK: - Sueño y cuidados
    func empezarSueño(_ tipo: TipoRegistro, en fecha: Date = .now) {
        cerrarSueñosAbiertos(en: fecha)
        cerrarTomasAbiertas(en: fecha)
        registros.append(Registro(tipo: tipo, inicio: fecha))
        guardar()
    }

    func terminarSueño(en fecha: Date = .now) {
        guard let idx = registros.lastIndex(where: { $0.tipo.esIntervalo && $0.fin == nil }) else { return }
        registros[idx].fin = max(fecha, registros[idx].inicio.addingTimeInterval(60))
        guardar()
    }

    func registrarEvento(_ tipo: TipoRegistro, lado: LadoPecho? = nil, en fecha: Date = .now, nota: String = "") {
        registros.append(Registro(tipo: tipo, inicio: fecha, fin: fecha, nota: nota, lado: lado))
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
    }

    private func cerrarSueñosAbiertos(en fecha: Date) {
        for idx in registros.indices where registros[idx].tipo.esIntervalo && registros[idx].fin == nil {
            registros[idx].fin = max(fecha, registros[idx].inicio.addingTimeInterval(60))
        }
    }

    // MARK: - Toma de pecho
    var tomaEnCurso: Registro? {
        registros.first { $0.tipo == .pecho && $0.fin == nil }
    }

    func empezarToma(_ lado: LadoPecho, en fecha: Date = .now) {
        cerrarSueñosAbiertos(en: fecha)
        cerrarTomasAbiertas(en: fecha)
        registros.append(Registro(tipo: .pecho, inicio: fecha, fin: nil, lado: lado))
        guardar()
    }

    func terminarToma(en fecha: Date = .now) {
        guard let idx = registros.lastIndex(where: { $0.tipo == .pecho && $0.fin == nil }) else { return }
        registros[idx].fin = max(fecha, registros[idx].inicio.addingTimeInterval(60))
        guardar()
    }

    private func cerrarTomasAbiertas(en fecha: Date) {
        for idx in registros.indices where registros[idx].tipo == .pecho && registros[idx].fin == nil {
            registros[idx].fin = max(fecha, registros[idx].inicio.addingTimeInterval(60))
        }
    }

    // MARK: - Consultas de sueño
    var sueñoEnCurso: Registro? { registros.first { $0.tipo.esIntervalo && $0.fin == nil } }

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
    }

    private var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("nubi.json")
    }

    private func guardar() {
        guard !cargando else { return }
        let datos = Disco(version: 4, bebe: bebe, registros: registros, medidas: medidas,
                          citas: citas, diario: diario, vacunas: vacunas,
                          gruposPropios: gruposPropios, comunidad: comunidad)
        guard let json = try? JSONEncoder().encode(datos) else { return }
        try? json.write(to: url, options: .atomic)
    }

    private func cargar() {
        cargando = true
        defer { cargando = false }
        guard let json = try? Data(contentsOf: url),
              let datos = try? JSONDecoder().decode(Disco.self, from: json) else { return }
        bebe      = datos.bebe
        registros = datos.registros ?? []
        medidas   = (datos.medidas ?? []).sorted { $0.fecha > $1.fecha }
        citas     = (datos.citas ?? []).sorted { $0.fecha < $1.fecha }
        diario    = (datos.diario ?? []).sorted { $0.fecha > $1.fecha }
        vacunas   = datos.vacunas ?? [:]
        gruposPropios = (datos.gruposPropios ?? []).sorted { $0.meses < $1.meses }
        comunidad = datos.comunidad ?? .comun
    }

    // MARK: - Exportar
    func exportarCSV() -> String {
        var filas = ["tipo;inicio;fin;duracion_min;nota;lado"]
        let f = ISO8601DateFormatter()
        for r in registros.sorted(by: { $0.inicio < $1.inicio }) {
            let dur = r.duracion.map { String(Int($0 / 60)) } ?? ""
            let fin = r.fin.map { f.string(from: $0) } ?? ""
            let lado = r.lado?.rawValue ?? ""
            let fila = [r.tipo.rawValue, f.string(from: r.inicio), fin, dur, escaparCSV(r.nota), lado].joined(separator: ";")
            filas.append(fila)
        }
        return filas.joined(separator: "\n")
    }
    
    private func escaparCSV(_ texto: String) -> String {
        if texto.contains(";") || texto.contains("\"") || texto.contains("\n") {
            return "\"" + texto.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return texto
    }

    func borrarTodo() {
        bebe = nil; registros = []; medidas = []; citas = []; diario = []
        vacunas = [:]; gruposPropios = []; comunidad = .comun
        try? FileManager.default.removeItem(at: url)
        Recordatorios.cancelarTodo()
    }

    /// Registra un sueño completo (con inicio y fin) en una hora específica.

    func registrarSueño(_ tipo: TipoRegistro, inicio: Date, duracion: TimeInterval) {
        let fin = inicio.addingTimeInterval(max(duracion, 60))
        registros.append(Registro(tipo: tipo, inicio: inicio, fin: fin))
        registros.sort { $0.inicio < $1.inicio }
        guardar()
    }
}