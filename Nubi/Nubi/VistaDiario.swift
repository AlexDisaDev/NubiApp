import SwiftUI

struct VistaDiario: View {
    @EnvironmentObject private var almacen: Almacen
    @EnvironmentObject private var suscripcion: Suscripcion

    @State private var editando: EntradaDiario?
    @State private var soloHitos = false
    @State private var mostrarPaywall = false

    /// Sin suscripción se pueden escribir unas cuantas entradas. Lo bastante
    /// para engancharse, no tanto como para no echar de menos el resto.
    private let limiteGratis = 5

    private var entradas: [EntradaDiario] {
        soloHitos ? almacen.diario.filter(\.hito) : almacen.diario
    }

    private var puedeEscribir: Bool {
        suscripcion.tieneAcceso || almacen.diario.count < limiteGratis
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Cabecera(titulo: "Diario", subtitulo: subtitulo) {
                    BotonIcono(simbolo: .lapiz, color: Theme.lila, diametro: 42) {
                        nuevaEntrada()
                    }
                }

                if !almacen.diario.isEmpty {
                    SelectorNubi(
                        opciones: [OpcionSelector(valor: false, titulo: "Todo"),
                                   OpcionSelector(valor: true, titulo: "Solo hitos")],
                        seleccion: $soloHitos
                    )
                }

                if entradas.isEmpty {
                    Tarjeta {
                        EstadoVacio(
                            simbolo: .cuaderno,
                            titulo: soloHitos ? "Ningún hito todavía" : "El cuaderno está en blanco",
                            texto: soloHitos
                                ? "Marca una entrada como hito cuando pase algo por primera vez."
                                : "La primera sonrisa, la noche que durmió del tirón, lo que dijo el pediatra. Dentro de un año no te acordarás si no lo escribes.",
                            color: Theme.mantequilla
                        )
                    }
                    if !soloHitos {
                        Boton(titulo: "Escribir la primera", simbolo: .lapiz, color: Theme.lila) {
                            nuevaEntrada()
                        }
                    }
                } else {
                    ForEach(entradas) { e in
                        tarjetaEntrada(e)
                    }
                }

                if !puedeEscribir {
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Insignia(simbolo: .candado, fondo: Theme.lila, diametro: 26)
                                EtiquetaSeccion(texto: "Nubi completo")
                            }
                            Text("Diario sin límite")
                                .font(Theme.display(21))
                                .foregroundStyle(Theme.tinta)
                            Text("Llevas \(almacen.diario.count) entradas, que son las que caben en la versión gratuita. Con Nubi completo escribes todas las que quieras.")
                                .font(Theme.cuerpo(13))
                                .foregroundStyle(Theme.tintaSuave)
                                .fixedSize(horizontal: false, vertical: true)
                            Boton(titulo: suscripcion.textoLlamada, color: Theme.lila) { mostrarPaywall = true }
                        }
                    }
                }
            }
            .padding(Theme.margen)
            .padding(.bottom, 8)
        }
        .background(Theme.lienzo.ignoresSafeArea())
        .sheet(item: $editando) { e in HojaDiario(entrada: e) }
        .sheet(isPresented: $mostrarPaywall) { Paywall() }
    }

    private var subtitulo: String {
        let n = almacen.diario.count
        if n == 0 { return "Sin entradas" }
        let hitos = almacen.diario.filter(\.hito).count
        return hitos > 0 ? "\(n) entradas · \(hitos) hitos" : "\(n) \(n == 1 ? "entrada" : "entradas")"
    }

    private func nuevaEntrada() {
        if puedeEscribir { editando = EntradaDiario() } else { mostrarPaywall = true }
    }

    private func tarjetaEntrada(_ e: EntradaDiario) -> some View {
        Button { editando = e } label: {
            Tarjeta {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(Fmt.fechaLarga(e.fecha).capitalizedPrimera)
                            .font(Theme.cuerpo(11, .semibold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.tintaSuave)
                        if let bebe = almacen.bebe {
                            Text("· " + Fmt.edadEnFecha(e.fecha, nacimiento: bebe.fechaNacimiento))
                                .font(Theme.cuerpo(11))
                                .foregroundStyle(Theme.tintaTenue)
                        }
                        Spacer()
                        if e.hito { Ilus(.estrella, 16, color: Theme.mantequilla) }
                    }

                    Text(e.tituloVisible)
                        .font(Theme.display(20))
                        .foregroundStyle(Theme.tinta)
                        .multilineTextAlignment(.leading)

                    if !e.texto.isEmpty {
                        Text(e.texto)
                            .font(Theme.cuerpo(13))
                            .foregroundStyle(Theme.tintaSuave)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .buttonStyle(BotonPresionable())
    }
}

// MARK: - Hoja de escritura

struct HojaDiario: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar

    @State var entrada: EntradaDiario
    @FocusState private var enfocado: Bool

    private var esNueva: Bool { !almacen.diario.contains { $0.id == entrada.id } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                EtiquetaSeccion(texto: "Fecha")
                                Spacer()
                                DatePicker("", selection: $entrada.fecha, in: ...Date(), displayedComponents: .date)
                                    .labelsHidden()
                            }
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            Toggle(isOn: $entrada.hito) {
                                HStack(spacing: 8) {
                                    Ilus(.estrella, 16, color: Theme.mantequilla)
                                    Text("Marcar como hito")
                                        .font(Theme.cuerpo(15))
                                        .foregroundStyle(Theme.tinta)
                                }
                            }
                            .tint(Theme.indigo)
                        }
                    }

                    Tarjeta {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Título", text: $entrada.titulo)
                                .font(Theme.display(22))
                                .foregroundStyle(Theme.tinta)
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            TextField("Hoy ha pasado que…", text: $entrada.texto, axis: .vertical)
                                .font(Theme.cuerpo(16))
                                .foregroundStyle(Theme.tinta)
                                .lineLimit(6...20)
                                .focused($enfocado)
                        }
                    }

                    Boton(titulo: "Guardar", color: Theme.lila) {
                        guard !(entrada.titulo.isEmpty && entrada.texto.isEmpty) else { cerrar(); return }
                        almacen.guardarEntrada(entrada)
                        cerrar()
                    }

                    if !esNueva {
                        Button {
                            almacen.borrarEntrada(entrada)
                            cerrar()
                        } label: {
                            HStack(spacing: 7) {
                                Ilus(.papelera, 14, color: Theme.indigo)
                                Text("Borrar esta entrada").font(Theme.cuerpo(14, .medium)).foregroundStyle(Theme.indigo)
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
            .navigationTitle(esNueva ? "Nueva entrada" : "Entrada")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }.font(Theme.cuerpo(15))
                }
            }
        }
    }
}
