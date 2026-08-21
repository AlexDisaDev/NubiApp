import SwiftUI
import CloudKit

/// Tarjeta de Ajustes para compartir los datos del bebé con la pareja.
struct TarjetaCompartir: View {
    @EnvironmentObject private var almacen: Almacen
    @ObservedObject private var sync = Sincronizador.compartido

    @State private var share: CKShare?
    @State private var mostrarHoja = false

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Insignia(simbolo: .corazon, fondo: Theme.rosa, diametro: 34)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Compartir con tu pareja")
                            .font(Theme.cuerpo(15, .semibold))
                            .foregroundStyle(Theme.tinta)

                        Text(subtitulo)
                            .font(Theme.cuerpo(12))
                            .foregroundStyle(Theme.tintaSuave)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    if sync.sincronizando { ProgressView() }
                }

                if sync.esParticipante {
                    Boton(titulo: "Dejar de ver datos compartidos", color: Theme.melocoton, compacto: true) {
                        Task {
                            await sync.dejarShare()
                            await almacen.sincronizarAhora()
                        }
                    }
                } else {
                    Boton(titulo: "Invitar por email", simbolo: .chevronDer, color: Theme.rosa, compacto: true) {
                        Task {
                            await almacen.sincronizarAhora()
                            let titulo = "Nubi · \(almacen.bebe?.nombre ?? "tu bebé")"
                            if let s = try? await sync.prepararShare(titulo: titulo) {
                                share = s
                                mostrarHoja = true
                            }
                        }
                    }

                    if sync.personasInvitadas > 0 {
                        Text("\(sync.personasInvitadas) \(sync.personasInvitadas == 1 ? "persona invitada" : "personas invitadas")")
                            .font(Theme.cuerpo(11))
                            .foregroundStyle(Theme.tintaTenue)
                    }
                }
            }
        }
        .sheet(isPresented: $mostrarHoja) {
            if let share { HojaCompartirNubi(share: share) }
        }
        .task { await sync.refrescarRol() }
    }

    private var subtitulo: String {
        if sync.esParticipante {
            return "Estás viendo y anotando los datos compartidos de \(almacen.bebe?.nombre ?? "tu bebé")."
        }
        if !sync.disponible {
            return "Necesitas iCloud activado para compartir los datos del bebé."
        }
        return "Invita a tu pareja por email: verá y anotará lo mismo que tú, desde su iPhone."
    }
}