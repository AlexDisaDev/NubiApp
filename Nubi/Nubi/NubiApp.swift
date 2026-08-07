import SwiftUI

@main
@MainActor
struct NubiApp: App {

    @StateObject private var almacen = Almacen()
    @StateObject private var suscripcion = Suscripcion()

    var body: some Scene {
        WindowGroup {
            RaizVista()
                .environmentObject(almacen)
                .environmentObject(suscripcion)
                .tint(Theme.indigo)
                //.preferredColorScheme(.light)
        }
    }
}

// MARK: - Pestañas

enum Pestana: String, CaseIterable, Identifiable {
    case hoy, linea, crecimiento, salud, diario

    var id: String { rawValue }

        var titulo: String {
        switch self {
        case .hoy:
            return L10n.t("Hoy")

        case .linea:
            return L10n.t("Día")

        case .crecimiento:
            return L10n.t("Crece")

        case .salud:
            return L10n.t("Salud")

        case .diario:
            return L10n.t("Diario")
        }
    }

    var simbolo: Ilus.Simbolo {
        switch self {
        case .hoy:         return .nube
        case .linea:       return .reloj
        case .crecimiento: return .regla
        case .salud:       return .botiquin
        case .diario:      return .cuaderno
        }
    }
}

// MARK: - Raíz

struct RaizVista: View {
    @EnvironmentObject private var almacen: Almacen
    @EnvironmentObject private var suscripcion: Suscripcion
    @AppStorage("paywall.mostradoTrasAlta") private var yaMostrado = false
    @AppStorage("modoOscuro") private var modoOscuro = false  // ← AÑADIR
    @State private var pestana: Pestana = .hoy
    @State private var mostrarPaywall = false
    
    var body: some View {
        Group {
            if almacen.bebe == nil {
                VistaAlta()
            } else {
                contenido
                    .safeAreaInset(edge: .bottom) {
                        BarraPestanas(seleccion: $pestana)
                    }
                    .task {
                        guard !yaMostrado, !suscripcion.cargando, !suscripcion.tieneAcceso else { return }
                        yaMostrado = true
                        mostrarPaywall = true
                    }
            }
        }
        .preferredColorScheme(modoOscuro ? .dark : .light)  // ← CAMBIAR ESTA LÍNEA
        .sheet(isPresented: $mostrarPaywall) { Paywall() }
    }

    @ViewBuilder
    private var contenido: some View {
        switch pestana {
        case .hoy:
            VistaInicio()

        case .linea:
            VistaLinea()

        case .crecimiento:
            VistaCrecimiento()

        case .salud:
            VistaSalud()

        case .diario:
            VistaDiario()
        }
    }
}

// MARK: - Barra de pestañas propia

/// La barra del sistema obliga a usar SF Symbols y un fondo gris translúcido.
/// Como toda la iconografía es dibujada, la barra también es nuestra.
struct BarraPestanas: View {

    @Binding var seleccion: Pestana

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Pestana.allCases) { p in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        seleccion = p
                    }
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            if seleccion == p {
                                Capsule()
                                    .fill(Theme.lila.opacity(0.35))
                                    .frame(width: 44, height: 30)
                            }

                            Ilus(
                                p.simbolo,
                                22,
                                color: seleccion == p ? Theme.indigo : Theme.tintaTenue
                            )
                        }

                        Text(p.titulo)
                            .font(Theme.cuerpo(10, seleccion == p ? .semibold : .regular))
                            .foregroundStyle(
                                seleccion == p
                                    ? Theme.indigo
                                    : Theme.tintaTenue
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 9)
        .padding(.bottom, 3)
        .background {
            Rectangle()
                .fill(Theme.superficie.opacity(0.96))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.separador)
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Alta del bebé

struct VistaAlta: View {

    @EnvironmentObject private var almacen: Almacen

    @State private var nombre = ""
    @State private var nacimiento = Date()
    @State private var prematuro = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: -10) {
                        Ilus(.nube, 46, color: Theme.lila)
                        Ilus(.luna, 30, color: Theme.mantequilla)
                            .offset(y: -10)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nubi")
                            .font(Theme.display(46))
                            .foregroundStyle(Theme.tinta)

                        Text("El sueño de tu bebé, sin adivinar.")
                            .font(Theme.cuerpo(15))
                            .foregroundStyle(Theme.tintaSuave)
                    }
                }
                .padding(.top, 44)

                Tarjeta {
                    VStack(alignment: .leading, spacing: 18) {
                        campo("Nombre") {
                            TextField("Su nombre", text: $nombre)
                                .font(Theme.cuerpo(17))
                                .textInputAutocapitalization(.words)
                        }

                        Divider()
                            .background(Theme.separador)

                        campo("Fecha de nacimiento") {
                            DatePicker(
                                "",
                                selection: $nacimiento,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                        }

                        Divider()
                            .background(Theme.separador)

                        campo("Semanas de prematuridad") {
                            Stepper("\(prematuro) semanas", value: $prematuro, in: 0...16)
                                .font(Theme.cuerpo(15))

                            Text("Si nació antes de tiempo, Nubi usa la edad corregida para calcular sus ventanas.")
                                .font(Theme.cuerpo(11))
                                .foregroundStyle(Theme.tintaTenue)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Boton(titulo: "Empezar", color: Theme.lila) {
                    almacen.guardarBebe(
                        Bebe(
                            nombre: nombre.trimmingCharacters(in: .whitespaces).isEmpty
                                ? "Mi bebé"
                                : nombre,
                            fechaNacimiento: nacimiento,
                            semanasPrematuro: prematuro
                        )
                    )
                }

                Text("Los datos se guardan solo en tu iPhone. No hay cuenta ni servidor.")
                    .font(Theme.cuerpo(11))
                    .foregroundStyle(Theme.tintaTenue)
            }
            .padding(Theme.margen)
        }
        .background(Theme.lienzo.ignoresSafeArea())
    }

    @ViewBuilder
    private func campo<C: View>(
        _ titulo: String,
        @ViewBuilder _ contenido: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            EtiquetaSeccion(texto: titulo)
            contenido()
        }
    }
}