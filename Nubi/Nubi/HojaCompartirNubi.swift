import SwiftUI
import CloudKit

// MARK: - Tarjeta de Ajustes para invitar

struct TarjetaCompartir: View {
    @EnvironmentObject private var almacen: Almacen
    @ObservedObject private var sync = Sincronizador.compartido
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
                            await almacen.salirDeCompartido() // ← ANTES DECÍA sincronizarAhora()
                        }
                    }
                } else {
                    Boton(titulo: "Invitar a mi pareja", simbolo: .chevronDer, color: Theme.rosa, compacto: true) {
                        mostrarHoja = true
                    }
                    if sync.personasInvitadas > 0 {
                        Text("\(sync.personasInvitadas) \(sync.personasInvitadas == 1 ? "persona invitada" : "personas invitadas")")
                            .font(Theme.cuerpo(11))
                            .foregroundStyle(Theme.tintaTenue)
                    }
                }
            }
        }
        .sheet(isPresented: $mostrarHoja) { HojaCompartirNubi() }
        .task { await sync.refrescarRol() }
    }

    private var subtitulo: String {
        if sync.esParticipante {
            return "Estás viendo y anotando los datos compartidos de \(almacen.bebe?.nombre ?? "tu bebé")."
        }
        if !sync.disponible {
            return "Necesitas iCloud activado para compartir los datos del bebé."
        }
        return "Crea un enlace con la marca Nubi y compártelo por WhatsApp, Mail o donde quieras."
    }
}

// MARK: - Hoja de invitación

struct HojaCompartirNubi: View {
    @EnvironmentObject private var almacen: Almacen
    @ObservedObject private var sync = Sincronizador.compartido
    @Environment(\.dismiss) private var cerrar

    @State private var nombre = ""
    @State private var invitacion: InvitacionNubi?
    @State private var creando = false
    @State private var errorTexto: String?
    @State private var mostrarShare = false
    @State private var copiado = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(spacing: 12) {
                            Insignia(simbolo: .corazon, fondo: Theme.rosa, diametro: 54)
                            Text("Invitar a tu pareja")
                                .font(Theme.display(22))
                                .foregroundStyle(Theme.tinta)
                            Text("Crea un enlace con la marca Nubi y compártelo por WhatsApp, Mail, Messages… por donde quieras.")
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if let invitacion {
                        tarjetaEnlace(invitacion)
                    } else {
                        tarjetaCrear
                    }

                    if let errorTexto {
                        Text(errorTexto)
                            .font(Theme.cuerpo(12, .medium))
                            .foregroundStyle(Theme.coral)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    if sync.personasInvitadas > 0 {
                        Text("\(sync.personasInvitadas) \(sync.personasInvitadas == 1 ? "persona tiene acceso" : "personas tienen acceso") a estos datos.")
                            .font(Theme.cuerpo(11))
                            .foregroundStyle(Theme.tintaTenue)
                    }

                    Button {
                        Task {
                            await sync.detenerCompartir()
                            invitacion = nil
                            cerrar()
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Ilus(.papelera, 14, color: Theme.indigo)
                            Text("Dejar de compartir")
                                .font(Theme.cuerpo(14, .medium))
                                .foregroundStyle(Theme.indigo)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle("Invitar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Listo") { cerrar() }
                        .font(Theme.cuerpo(15, .semibold))
                }
            }
            .sheet(isPresented: $mostrarShare) {
                if let invitacion {
                    ActivityView(items: [textoCompartir(invitacion), sync.enlaceInvitacion(invitacion)])
                }
            }
            .onAppear {
                if invitacion == nil {
                    invitacion = sync.invitacionGuardada()
                }
            }
        }
    }

    private var tarjetaCrear: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                EtiquetaSeccion(texto: "Tu nombre (opcional)")
                TextField("Por ejemplo, Lucía", text: $nombre)
                    .font(Theme.cuerpo(16))
                    .textInputAutocapitalization(.words)
                Boton(titulo: creando ? "Creando…" : "Crear enlace de invitación", simbolo: .mas, color: Theme.rosa) {
                    Task { await crear() }
                }
                .disabled(creando)
            }
        }
    }

    private func tarjetaEnlace(_ inv: InvitacionNubi) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                EtiquetaSeccion(texto: "Tu enlace de invitación")
                Text(sync.enlaceInvitacion(inv).absoluteString)
                    .font(Theme.cuerpo(12))
                    .foregroundStyle(Theme.tintaSuave)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    Boton(titulo: "Compartir enlace", simbolo: .chevronDer, color: Theme.rosa) {
                        mostrarShare = true
                    }
                    BotonSecundario(titulo: copiado ? "Copiado ✓" : "Copiar", simbolo: .cuaderno) {
                        UIPasteboard.general.string = sync.enlaceInvitacion(inv).absoluteString
                        withAnimation { copiado = true }
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            withAnimation { copiado = false }
                        }
                    }
                }
                Text("Al tocarlo, tu pareja verá una página de Nubi con tu nombre. Si tiene la app, se abrirá y podrá unirse.")
                    .font(Theme.cuerpo(11))
                    .foregroundStyle(Theme.tintaTenue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func crear() async {
        creando = true
        errorTexto = nil
        defer { creando = false }
        do {
            invitacion = try await sync.crearInvitacion(
                de: nombre.trimmingCharacters(in: .whitespaces),
                bebe: almacen.bebe?.nombre ?? "tu bebé"
            )
        } catch {
            errorTexto = error.localizedDescription
        }
    }

    private func textoCompartir(_ inv: InvitacionNubi) -> String {
        let quien = inv.de.isEmpty ? "Alguien especial" : inv.de
        return "🌙 \(quien) te invita a Nubi para compartir el sueño y los cuidados de \(inv.bebe). Toca el enlace para unirte: \(sync.enlaceInvitacion(inv).absoluteString)"
    }

    /// Extrae el enlace de iCloud si el URL viene de la web de Nubi (?u=...)
    static func shareURLDesdeEnlace(_ url: URL) -> URL? {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let u = comps.queryItems?.first(where: { $0.name == "u" })?.value,
              let share = URL(string: u) else { return nil }
        return share
    }
}