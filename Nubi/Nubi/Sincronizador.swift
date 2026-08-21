import Foundation
import CloudKit

/// Sincroniza Nubi con el iCloud privado del usuario y gestiona el
/// compartido (CKShare) para que varios iPhones vean los mismos datos.
///
/// REGLAS DE ORO (para que NUNCA se pierdan datos):
/// 1. Un móvil que "deja de ver" un compartido queda TOTALMENTE desvinculado:
///    nunca vuelve a escribir en la zona ajena.
/// 2. El dueño que "deja de compartir" revoca el acceso de TODOS los invitados.
/// 3. Un móvil sin vínculo claro SOLO escribe en su zona privada.
@MainActor
final class Sincronizador: ObservableObject {
    static let compartido = Sincronizador()

    @Published private(set) var disponible = false
    @Published private(set) var sincronizando = false
    @Published private(set) var ultimaSync: Date?
    @Published private(set) var ultimoError: String?
    @Published private(set) var estadoCuenta = "Comprobando iCloud…"
    var onParticipanteCambio: (@MainActor (Bool) -> Void)?

    // Compartir
    @Published private(set) var esParticipante = false
    @Published private(set) var sharePropio: CKShare?

    private let container = NubiCloud.contenedor
    private let zona = CKRecordZone(zoneName: "NubiZone")
    private var zonaRemotaID: CKRecordZone.ID?

    private var tareaSubida: Task<Void, Never>?

    /// Candado: el usuario decidió salir del compartido. Mientras esté activo,
    /// este móvil NUNCA se considera participante ni escribe en zona ajena.
    private var ignorarCompartido: Bool {
        get { UserDefaults.standard.bool(forKey: "nubi.ignorarCompartido") }
        set { UserDefaults.standard.set(newValue, forKey: "nubi.ignorarCompartido") }
    }

    private init() {}

    // MARK: - Base de datos y zona según el rol

    private var dbActiva: CKDatabase {
        esParticipante ? container.sharedCloudDatabase : container.privateCloudDatabase
    }

    private var zonaActivaID: CKRecordZone.ID {
        esParticipante ? (zonaRemotaID ?? zona.zoneID) : zona.zoneID
    }

    private var idRegistro: CKRecord.ID {
        CKRecord.ID(recordName: "nubi-datos", zoneID: zonaActivaID)
    }

    // MARK: - Estado

    func refrescarEstado() async {
        let estado = (try? await container.accountStatus()) ?? .couldNotDetermine
        disponible = (estado == .available)
        estadoCuenta = Self.textoEstado(estado)
    }

    private static func textoEstado(_ estado: CKAccountStatus) -> String {
        switch estado {
        case .available:              return "iCloud disponible."
        case .noAccount:              return "Inicia sesión con tu Apple ID en los Ajustes del iPhone."
        case .restricted:             return "El acceso a iCloud está restringido en este dispositivo."
        case .couldNotDetermine:      return "No se pudo comprobar el estado de iCloud."
        case .temporarilyUnavailable: return "iCloud no disponible temporalmente. Prueba en unos minutos."
        @unknown default:             return "Estado de iCloud desconocido."
        }
    }

    // MARK: - Rol (dueño / participante / nada)

    func refrescarRol() async {
        await refrescarEstado()
        guard disponible else { return }

        // ← CLAVE: si el usuario salió del compartido, NUNCA volvemos a ser
        // participantes, aunque iCloud todavía muestre la zona un tiempo.
        if ignorarCompartido {
            let huboCambio = esParticipante
            esParticipante = false
            zonaRemotaID = nil
            sharePropio = await shareExistente()
            if huboCambio { onParticipanteCambio?(false) }
            return
        }

        // Si la consulta falla por red/iCloud, NO cambiamos el rol
        let zonas: [CKRecordZone]
        do {
            zonas = try await container.sharedCloudDatabase.allRecordZones()
        } catch {
            return
        }

        let compartida = zonas.first(where: { $0.zoneID.zoneName == "NubiZone" })
        let nuevo = compartida != nil
        let huboCambio = (nuevo != esParticipante)
        esParticipante = nuevo
        zonaRemotaID = nuevo ? compartida?.zoneID : nil
        sharePropio = nuevo ? nil : await shareExistente()
        if huboCambio {
            onParticipanteCambio?(nuevo)
        }
    }

    var personasInvitadas: Int { sharePropio?.participants.count ?? 0 }

    /// Busca el share real de la zona (por su referencia, no por un nombre fijo).
    private func shareExistente() async -> CKShare? {
        let db = container.privateCloudDatabase
        guard let zonaActual = try? await db.recordZone(for: zona.zoneID),
              let refShare = zonaActual.share,
              let record = try? await db.record(for: refShare.recordID),
              let share = record as? CKShare
        else { return nil }
        return share
    }

    // MARK: - Subida

    func programarSubida(json: Data, modificado: Date) {
        guard disponible else { return }

        tareaSubida?.cancel()
        tareaSubida = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.subir(json: json, modificado: modificado)
        }
    }

    func subir(json: Data, modificado: Date) async {
        await refrescarEstado()
        guard disponible else { return }

        // Seguridad doble: si salimos del compartido, jamás escribimos en zona ajena
        if esParticipante && ignorarCompartido { return }

        sincronizando = true
        defer { sincronizando = false }

        do {
            let db = dbActiva
            if !esParticipante { try await asegurarZona(db) }

            let record: CKRecord
            if let existente = try? await db.record(for: idRegistro) {
                record = existente
            } else {
                record = CKRecord(recordType: "NubiBackup", recordID: idRegistro)
            }

            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("nubi-sync-\(UUID().uuidString).json")
            try json.write(to: tmp)

            record["datos"] = CKAsset(fileURL: tmp)
            record["modificado"] = modificado as CKRecordValue

            _ = try await db.save(record)
            try? FileManager.default.removeItem(at: tmp)

            ultimaSync = .now
            ultimoError = nil
        } catch {
            ultimoError = error.localizedDescription
        }
    }

    // MARK: - Bajada

    func descargar() async -> (json: Data, modificado: Date)? {
        await refrescarEstado()
        guard disponible else { return nil }

        do {
            let record = try await dbActiva.record(for: idRegistro)

            guard let asset = record["datos"] as? CKAsset,
                  let url = asset.fileURL,
                  let json = try? Data(contentsOf: url),
                  let modificado = record["modificado"] as? Date
            else { return nil }

            return (json, modificado)
        } catch {
            return nil
        }
    }

    // MARK: - Compartir (propietario)

    func prepararShare(titulo: String) async throws -> CKShare {
        let db = container.privateCloudDatabase
        try await asegurarZona(db)

        // Si la zona YA tiene un share, lo reutilizamos.
        if let existente = await shareExistente() {
            if existente.publicPermission != .readWrite {
                existente.publicPermission = .readWrite
                _ = try await db.save(existente)
            }
            sharePropio = existente
            return existente
        }

        // No hay share: creamos uno público y limpio.
        let share = CKShare(recordZoneID: zona.zoneID)
        share[CKShare.SystemFieldKey.title] = titulo
        share.publicPermission = .readWrite
        _ = try await db.save(share)
        sharePropio = share
        return share
    }

    func urlInvitacion(titulo: String) async -> URL? {
        guard let share = await prepararShareSeguro(titulo: titulo) else { return nil }
        if let url = share.url { return url }
        return await shareExistente()?.url
    }

    /// Igual que prepararShare pero captura el error para no romper la UI.
    func prepararShareSeguro(titulo: String) async -> CKShare? {
        await refrescarEstado()
        guard disponible else {
            ultimoError = estadoCuenta
            return nil
        }
        do {
            return try await prepararShare(titulo: titulo)
        } catch {
            ultimoError = error.localizedDescription
            return nil
        }
    }

    /// El DUEÑO deja de compartir: revoca el acceso de TODOS los invitados.
    /// Al borrar el CKShare, los móviles invitados pierden el acceso y sus apps
    /// se desasocian solas (detectan que la zona desaparece y recuperan lo suyo).
    func detenerCompartir() async {
        let db = container.privateCloudDatabase
        if let zonaActual = try? await db.recordZone(for: zona.zoneID),
           let refShare = zonaActual.share {
            _ = try? await db.deleteRecord(withID: refShare.recordID)
        }
        sharePropio = nil
        UserDefaults.standard.removeObject(forKey: "nubi.inv.shareURL")
        UserDefaults.standard.removeObject(forKey: "nubi.inv.de")
        UserDefaults.standard.removeObject(forKey: "nubi.inv.bebe")
        await refrescarRol()
    }

    /// Borra la zona de compartir (con su share y su copia) para empezar de cero.
    /// Úsalo UNA sola vez si el share quedó en mal estado.
    func resetZonaCompartir() async {
        let db = container.privateCloudDatabase
        _ = try? await db.deleteRecordZone(withID: zona.zoneID)
        sharePropio = nil
        esParticipante = false
        zonaRemotaID = nil
        ignorarCompartido = false
    }

    // MARK: - Compartir (participante)

    func aceptarInvitacion(url: URL) async -> Bool {
        do {
            let metadata = try await metadatosDelShare(url: url)
            _ = try await container.accept(metadata)
            // El usuario ha elegido entrar: quitamos el candado de salida
            ignorarCompartido = false
            await refrescarRol()
            return true
        } catch {
            return false
        }
    }

    /// Envuelve el callback antiguo de fetchShareMetadata en async/await,
    /// porque ese método concreto no tiene versión async nativa.
    private func metadatosDelShare(url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            container.fetchShareMetadata(with: url) { metadata, error in
                if let metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: error ?? CKError(.internalError))
                }
            }
        }
    }

    /// El INVITADO deja de ver el compartido: se desvincula por completo.
    /// Después de esto, aunque cree un bebé nuevo, SOLO irá a su iCloud privado.
    func dejarShare() async {
        // 1) Dejamos de recibir avisos del compartido
        await cancelarSuscripcionCompartida()
        // 2) Quitamos este dispositivo del compartido (no toca los datos del dueño)
        await eliminarParticipacionPendiente()
        // 3) Candado: aunque iCloud tarde en limpiar, nunca volveremos a esa zona
        ignorarCompartido = true
        zonaRemotaID = nil
        await refrescarRol()
    }

    private func eliminarParticipacionPendiente() async {
        guard let zonas = try? await container.sharedCloudDatabase.allRecordZones() else { return }
        for compartida in zonas where compartida.zoneID.zoneName == "NubiZone" {
            _ = try? await container.sharedCloudDatabase.deleteRecordZone(withID: compartida.zoneID)
        }
    }

    // MARK: - Zona

    private func asegurarZona(_ db: CKDatabase) async throws {
        do {
            _ = try await db.recordZone(for: zona.zoneID)
        } catch {
            _ = try await db.save(zona)
        }
    }

    // MARK: - Invitaciones con enlace propio (marca Nubi)

    func crearInvitacion(de: String, bebe: String) async throws -> InvitacionNubi {
        await refrescarEstado()
        guard disponible else {
            throw NSError(domain: "NubiInvitacion", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: estadoCuenta])
        }
        let share = try await prepararShare(titulo: "Nubi · \(bebe)")
        guard let shareURL = share.url else {
            throw NSError(domain: "NubiInvitacion", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "No se pudo crear el enlace de iCloud."])
        }
        let inv = InvitacionNubi(shareURL: shareURL, de: de, bebe: bebe)
        UserDefaults.standard.set(shareURL.absoluteString, forKey: "nubi.inv.shareURL")
        UserDefaults.standard.set(de, forKey: "nubi.inv.de")
        UserDefaults.standard.set(bebe, forKey: "nubi.inv.bebe")
        return inv
    }

    /// Enlace bonito con la marca Nubi.
    func enlaceInvitacion(_ inv: InvitacionNubi) -> URL {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "appnubi.netlify.app"
        comps.path = "/"
        var items = [
            URLQueryItem(name: "bebe", value: inv.bebe),
            URLQueryItem(name: "u", value: inv.shareURL.absoluteString)
        ]
        if !inv.de.isEmpty { items.append(URLQueryItem(name: "de", value: inv.de)) }
        comps.queryItems = items
        return comps.url ?? URL(string: "https://appnubi.netlify.app/")!
    }

    func invitacionGuardada() -> InvitacionNubi? {
        guard let s = UserDefaults.standard.string(forKey: "nubi.inv.shareURL"),
              let url = URL(string: s) else { return nil }
        return InvitacionNubi(
            shareURL: url,
            de: UserDefaults.standard.string(forKey: "nubi.inv.de") ?? "",
            bebe: UserDefaults.standard.string(forKey: "nubi.inv.bebe") ?? ""
        )
    }

    /// Extrae el enlace de iCloud si el URL viene de la web de Nubi (?u=...)
    static func shareURLDesdeEnlace(_ url: URL) -> URL? {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let u = comps.queryItems?.first(where: { $0.name == "u" })?.value,
              let share = URL(string: u) else { return nil }
        return share
    }

    /// Acepta una invitación venga de donde venga (nubi://, https con ?u=, o enlace directo de iCloud)
    func aceptarInvitacionNubi(url: URL) async -> Bool {
        let share = Self.shareURLDesdeEnlace(url) ?? url
        return await aceptarInvitacion(url: share)
    }

    // MARK: - Suscripción a cambios en la zona compartida

    func suscribirseACambiosCompartidos() async {
        let db = container.sharedCloudDatabase
        let subID = "nubi-cambios-compartidos"

        do {
            let existentes = try await db.allSubscriptions()
            if existentes.contains(where: { $0.subscriptionID == subID }) { return }
        } catch {}

        let subscription = CKDatabaseSubscription(subscriptionID: subID)
        subscription.recordType = "NubiBackup"

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await db.save(subscription)
        } catch {
            print("No se pudo suscribir a cambios: \(error)")
        }
    }

    func manejarNotificacionSilenciosa() async {
        guard disponible, esParticipante, !ignorarCompartido else { return }
        await refrescarRol()
        NotificationCenter.default.post(
            name: .nubiDatosCompartidosCambiados,
            object: nil
        )
    }

    func cancelarSuscripcionCompartida() async {
        let db = container.sharedCloudDatabase
        do {
            _ = try await db.deleteSubscription(withID: "nubi-cambios-compartidos")
        } catch {}
    }

    // MARK: - Recuperación (sube/baja SIN comparar fechas)

    func forzarSubida(json: Data) async {
        await refrescarEstado()
        guard disponible else { return }
        let db = dbActiva
        if !esParticipante { try? await asegurarZona(db) }
        let record: CKRecord
        if let existente = try? await db.record(for: idRegistro) { record = existente }
        else { record = CKRecord(recordType: "NubiBackup", recordID: idRegistro) }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("nubi-sync-\(UUID().uuidString).json")
        try? json.write(to: tmp)
        record["datos"] = CKAsset(fileURL: tmp)
        record["modificado"] = Date() as CKRecordValue
        _ = try? await db.save(record)
        try? FileManager.default.removeItem(at: tmp)
        ultimaSync = .now
    }

    func forzarBajada() async -> Data? {
        await refrescarEstado()
        guard disponible else { return nil }
        guard let record = try? await dbActiva.record(for: idRegistro),
              let asset = record["datos"] as? CKAsset,
              let urlAsset = asset.fileURL else { return nil }
        return try? Data(contentsOf: urlAsset)
    }
}

struct InvitacionNubi {
    let shareURL: URL
    let de: String
    let bebe: String
}

extension Notification.Name {
    static let nubiDatosCompartidosCambiados = Notification.Name("nubi.datos.compartidos.cambiados")
}