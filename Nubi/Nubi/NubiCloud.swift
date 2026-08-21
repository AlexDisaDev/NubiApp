import CloudKit

enum NubiCloud {
    /// Único lugar donde se define el contenedor de iCloud.
    /// Debe coincidir EXACTAMENTE con el que está tildado en
    /// Signing & Capabilities → iCloud → Containers.
    static let contenedorID = "iCloud.disa.nubi"
    static let contenedor = CKContainer(identifier: contenedorID)
}