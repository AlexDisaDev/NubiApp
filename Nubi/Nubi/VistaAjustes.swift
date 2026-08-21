import SwiftUI
import CloudKit

struct VistaAjustes: View {
    @EnvironmentObject private var almacen: Almacen
    @EnvironmentObject private var suscripcion: Suscripcion
    @Environment(\.dismiss) private var cerrar
    

    @AppStorage("paywall.mostradoTrasAlta") private var yaMostrado = false
    @AppStorage("idioma.nubi") private var idiomaRaw: String = IdiomaNubi.sistema.rawValue

    @State private var mostrarPaywall = false
    @State private var editarBebe = false
    @State private var confirmarBorrado = false

    private var idiomaActual: IdiomaNubi {
        IdiomaNubi(rawValue: idiomaRaw) ?? .sistema
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    tarjetaSuscripcion
                    tarjetaIdioma
                    
                    // iCloud y compartir
                    TarjetaICloud()
                    TarjetaCompartir()

                    if let bebe = almacen.bebe {
                        Tarjeta {
                            VStack(alignment: .leading, spacing: 14) {
                                EtiquetaSeccion(texto: "Bebé")

                                fila("Nombre", bebe.nombre)

                                Rectangle()
                                    .fill(Theme.separador)
                                    .frame(height: 1)

                                fila("Nacimiento", Fmt.fechaCorta(bebe.fechaNacimiento))

                                Rectangle()
                                    .fill(Theme.separador)
                                    .frame(height: 1)

                                fila("Edad", bebe.edadLegible)

                                if bebe.semanasPrematuro > 0 {
                                    Rectangle()
                                        .fill(Theme.separador)
                                        .frame(height: 1)

                                    fila("Prematuridad", "\(bebe.semanasPrematuro) semanas")
                                }

                                BotonSecundario(titulo: "Editar datos", simbolo: .lapiz) {
                                    editarBebe = true
                                }
                            }
                        }
                    }

                    Tarjeta {
                        VStack(alignment: .leading, spacing: 14) {
                            EtiquetaSeccion(texto: "Nubi")

                            NavigationLink {
                                VistaSueñoSeguro()
                            } label: {
                                filaEnlace(.nube, "Sueño seguro", Theme.menta)
                            }
                            .buttonStyle(.plain)

                            Rectangle()
                                .fill(Theme.separador)
                                .frame(height: 1)

                            NavigationLink {
                                VistaAtajosSiri()
                            } label: {
                                filaEnlace(.ondas, "Atajos de Siri", Theme.lila)
                            }
                            .buttonStyle(.plain)

                            Rectangle()
                                .fill(Theme.separador)
                                .frame(height: 1)

                            Link(destination: URL(string: "https://appnubi.netlify.app/privacidad")!) {
                                filaEnlace(.candado, "Política de privacidad", Theme.lila)
                            }
                            .buttonStyle(.plain)

                            Rectangle()
                                .fill(Theme.separador)
                                .frame(height: 1)

                            Link(destination: URL(string: "https://appnubi.netlify.app/terminos")!) {
                                filaEnlace(.calendario, "Términos de uso", Theme.cielo)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Tarjeta {
                        VStack(alignment: .leading, spacing: 10) {
                            EtiquetaSeccion(texto: "Datos")

                            Text("Tus datos viven en tu iPhone y en tu iCloud privado. Si borras la app, puedes recuperarlos al volver a instalarla con el mismo Apple ID.")
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                confirmarBorrado = true
                            } label: {
                                HStack(spacing: 7) {
                                    Ilus(.papelera, 14, color: Theme.indigo)

                                    Text("Borrar todos los datos")
                                        .font(Theme.cuerpo(14, .medium))
                                        .foregroundStyle(Theme.indigo)
                                }
                                .padding(.top, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Nubi no sustituye el criterio de un profesional sanitario.")
                        .font(Theme.cuerpo(11))
                        .foregroundStyle(Theme.tintaTenue)
                        .padding(.horizontal, 4)
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Listo") {
                        cerrar()
                    }
                    .font(Theme.cuerpo(15, .semibold))
                }
            }
            .sheet(isPresented: $mostrarPaywall) {
                Paywall()
            }
            .sheet(isPresented: $editarBebe) {
                if let bebe = almacen.bebe {
                    HojaBebe(bebe: bebe)
                }
            }
            /*
            BotonSecundario(titulo: "RECUPERACIÓN: subir mis datos al compartido", simbolo: .mas) {
                Task { await almacen.forzarSubidaDeRecuperacion() }
            }
            BotonSecundario(titulo: "RECUPERACIÓN: bajar datos del compartido", simbolo: .nube) {
                Task { await almacen.forzarBajadaDeRecuperacion() }
            }
            */
            .alert("¿Borrar todo?", isPresented: $confirmarBorrado) {
                Button("Cancelar", role: .cancel) {}

                Button("Borrar", role: .destructive) {
                    yaMostrado = false
                    almacen.borrarTodo()
                    cerrar()
                }
            } message: {
                Text("Se borran los registros, las medidas, las citas y el diario. No se puede deshacer.")
            }
        }
    }

    // MARK: Suscripción

    private var tarjetaSuscripcion: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Insignia(
                        simbolo: suscripcion.tieneAcceso ? .estrella : .candado,
                        fondo: suscripcion.tieneAcceso ? Theme.mantequilla : Theme.lila,
                        diametro: 34
                    )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(suscripcion.tieneAcceso ? "Nubi completo activo" : "Nubi gratis")
                            .font(Theme.cuerpo(15, .semibold))
                            .foregroundStyle(Theme.tinta)

                        Text(descripcionEstado)
                            .font(Theme.cuerpo(12))
                            .foregroundStyle(Theme.tintaSuave)
                    }

                    Spacer(minLength: 0)
                }

                if suscripcion.tieneAcceso {
                    Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                        Text("Gestionar suscripción")
                            .font(Theme.cuerpo(14, .medium))
                            .foregroundStyle(Theme.indigo)
                    }
                } else {
                    Boton(titulo: suscripcion.textoLlamada, color: Theme.lila) {
                        mostrarPaywall = true
                    }

                    Button("Restaurar compras") {
                        Task {
                            await suscripcion.restaurar()
                        }
                    }
                    .font(Theme.cuerpo(13))
                    .foregroundStyle(Theme.tintaSuave)
                }
            }
        }
    }

    private var descripcionEstado: String {
        if suscripcion.enPrueba, let d = suscripcion.diasRestantes {
            return d == 1 ? "Último día de prueba" : "Quedan \(d) días de prueba"
        }

        if suscripcion.tieneAcceso, let v = suscripcion.venceEl {
            return "Se renueva el " + Fmt.fechaCorta(v)
        }

        return "Predicción, historial y curvas bloqueados"
    }

    // MARK: Idioma

    private var tarjetaIdioma: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                EtiquetaSeccion(texto: L10n.t("Idioma"))
                Menu {
                    Picker(L10n.t("Idioma"), selection: Binding(
                        get: { idiomaActual },
                        set: { nuevo in
                            L10n.idioma = nuevo
                            idiomaRaw = nuevo.rawValue
                        }
                    )) {
                        ForEach(IdiomaNubi.allCases) { idioma in
                            Text(idioma.nombre).tag(idioma)
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.indigo)
                            .frame(width: 34, height: 34)
                            .background(Theme.cielo.opacity(0.3), in: Circle())
                        Text(idiomaActual.nombre)
                            .font(Theme.cuerpo(15, .semibold))
                            .foregroundStyle(Theme.tinta)
                        Spacer()
                        Ilus(.chevronDer, 14, color: Theme.tintaTenue)
                            .rotationEffect(.degrees(90))
                    }
                    .contentShape(Rectangle())
                }
                Text(L10n.t("Elige tu idioma"))
                    .font(Theme.cuerpo(11))
                    .foregroundStyle(Theme.tintaTenue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Piezas

    private func fila(_ titulo: String, _ valor: String) -> some View {
        HStack {
            Text(titulo)
                .font(Theme.cuerpo(14))
                .foregroundStyle(Theme.tintaSuave)

            Spacer()

            Text(valor)
                .font(Theme.cuerpo(14, .medium))
                .foregroundStyle(Theme.tinta)
        }
    }

    private func filaEnlace(
        _ simbolo: Ilus.Simbolo,
        _ titulo: String,
        _ color: Color
    ) -> some View {
        HStack(spacing: 12) {
            Insignia(simbolo: simbolo, fondo: color, diametro: 32)

            Text(titulo)
                .font(Theme.cuerpo(15))
                .foregroundStyle(Theme.tinta)

            Spacer()

            Ilus(.chevronDer, 13, color: Theme.tintaTenue)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Editar bebé

struct HojaBebe: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    @State var bebe: Bebe

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "Nombre")

                                TextField("Su nombre", text: $bebe.nombre)
                                    .font(Theme.cuerpo(17))
                                    .textInputAutocapitalization(.words)
                            }

                            Rectangle()
                                .fill(Theme.separador)
                                .frame(height: 1)

                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "Fecha de nacimiento")

                                DatePicker(
                                    "",
                                    selection: $bebe.fechaNacimiento,
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                            }

                            Rectangle()
                                .fill(Theme.separador)
                                .frame(height: 1)

                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "Semanas de prematuridad")

                                Stepper(
                                    "\(bebe.semanasPrematuro) semanas",
                                    value: $bebe.semanasPrematuro,
                                    in: 0...16
                                )
                                .font(Theme.cuerpo(15))
                            }
                        }
                    }

                    Boton(titulo: "Guardar", color: Theme.lila) {
                        almacen.guardarBebe(bebe)
                        cerrar()
                    }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle("Datos del bebé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        cerrar()
                    }
                    .font(Theme.cuerpo(15))
                }
            }
        }
    }
}

// MARK: - Sueño seguro

struct VistaSueñoSeguro: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Insignia(simbolo: .nube, fondo: Theme.menta, diametro: 60)

                Text("Sueño seguro")
                    .font(Theme.display(28))
                    .foregroundStyle(Theme.tinta)

                Text("""
Las recomendaciones generales de sueño seguro para lactantes incluyen acostar al bebé boca arriba, sobre una superficie firme y plana, sin almohadas, mantas sueltas ni peluches en la cuna, y compartir habitación pero no cama durante los primeros meses.

Evita el sobrecalentamiento y el humo del tabaco en el entorno del bebé.

Consulta siempre las guías de tu pediatra o de la sociedad de pediatría de tu país, que son la referencia válida para tu caso.
""")
                .font(Theme.cuerpo(15))
                .foregroundStyle(Theme.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.margen)
        }
        .background(Theme.lienzo.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Tarjeta de copia de seguridad en iCloud (100% automática)

struct TarjetaICloud: View {
    @ObservedObject private var sync = Sincronizador.compartido

    var body: some View {
        Tarjeta {
            HStack(alignment: .top, spacing: 12) {
                Insignia(simbolo: .nube, fondo: Theme.cielo, diametro: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Copia de seguridad en iCloud")
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
        }
        .task { await sync.refrescarEstado() }
    }

    private var subtitulo: String {
        if let e = sync.ultimoError {
            return " \(e)"
        }
        if !sync.disponible {
            return " \(sync.estadoCuenta)"
        }
        if let ultima = sync.ultimaSync {
            return "Automática: cada cambio se guarda en tu iCloud privado. Última copia: \(Fmt.hora(ultima))."
        }
        return "Automática: cada cambio se guarda en tu iCloud privado. Si cambias de móvil, vuelven solos."
    }
}