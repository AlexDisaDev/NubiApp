import SwiftUI

enum Magnitud: String, CaseIterable, Identifiable {
    case peso, altura, perimetro

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .peso:      return "Peso"
        case .altura:    return "Estatura"
        case .perimetro: return "Cabeza"
        }
    }

    var unidad: String {
        switch self {
        case .peso: return "kg"
        default:    return "cm"
        }
    }

    var simbolo: Ilus.Simbolo {
        switch self {
        case .peso:      return .bascula
        case .altura:    return .regla
        case .perimetro: return .ondas
        }
    }

    var color: Color {
        switch self {
        case .peso:      return Theme.menta
        case .altura:    return Theme.cielo
        case .perimetro: return Theme.rosa
        }
    }

    var decimales: Int { self == .peso ? 3 : 1 }

    func valor(_ m: Medida) -> Double? {
        switch self {
        case .peso:      return m.pesoKg
        case .altura:    return m.alturaCm
        case .perimetro: return m.perimetroCm
        }
    }
}

struct VistaCrecimiento: View {
    @EnvironmentObject private var almacen: Almacen
    @EnvironmentObject private var suscripcion: Suscripcion
    //@EnvironmentObject private var l10n: L10n
    @State private var magnitud: Magnitud = .peso
    @State private var editando: Medida?
    @State private var mostrarPaywall = false

    private var serie: [PuntoGrafica] {
        almacen.medidas
            .compactMap { m -> PuntoGrafica? in
                guard let v = magnitud.valor(m) else { return nil }
                return PuntoGrafica(fecha: m.fecha, valor: v)
            }
            .sorted { $0.fecha < $1.fecha }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Cabecera(titulo: "Cómo crece", subtitulo: subtitulo) {
                    BotonIcono(simbolo: .mas, color: Theme.lila, diametro: 42) {
                        editando = Medida()
                    }
                }

                resumen

                SelectorNubi(
                    opciones: Magnitud.allCases.map { OpcionSelector(valor: $0, titulo: $0.titulo) },
                    seleccion: $magnitud
                )

                if serie.isEmpty {
                    Tarjeta {
                        EstadoVacio(
                            simbolo: magnitud.simbolo,
                            titulo: "Aún no hay \(magnitud.titulo.lowercased())",
                            texto: "Apunta lo que te digan en la revisión y verás cómo evoluciona entre visita y visita.",
                            color: magnitud.color
                        )
                    }
                } else {
                    tarjetaEvolucion
                }

                listaDeMedidas
                avisoPercentiles
            }
            .padding(Theme.margen)
            .padding(.bottom, 8)
        }
        .background(Theme.lienzo.ignoresSafeArea())
        .sheet(item: $editando) { m in HojaMedida(medida: m) }
        .sheet(isPresented: $mostrarPaywall) { Paywall() }
    }

    private var subtitulo: String {
        almacen.medidas.isEmpty
            ? "Sin medidas todavía"
            : "\(almacen.medidas.count) \(almacen.medidas.count == 1 ? "medida" : "medidas") anotadas"
    }

    // MARK: Resumen de las tres cifras

    private var resumen: some View {
        HStack(spacing: 10) {
            celda(.peso, almacen.ultimoPeso)
            celda(.altura, almacen.ultimaAltura)
            celda(.perimetro, almacen.ultimoPerimetro)
        }
    }

    private func celda(_ m: Magnitud, _ dato: (valor: Double, fecha: Date)?) -> some View {
        Tarjeta(relleno: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Insignia(simbolo: m.simbolo, fondo: m.color, diametro: 30)
                if let dato {
                    Text(Fmt.numero(dato.valor, m == .peso ? 2 : 1))
                        .font(Theme.display(21))
                        .foregroundStyle(Theme.tinta)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(m.unidad + " · " + Fmt.fechaCorta(dato.fecha))
                        .font(Theme.cuerpo(10))
                        .foregroundStyle(Theme.tintaTenue)
                        .lineLimit(1)
                } else {
                    Text("—")
                        .font(Theme.display(21))
                        .foregroundStyle(Theme.tintaTenue)
                    Text(m.titulo)
                        .font(Theme.cuerpo(10))
                        .foregroundStyle(Theme.tintaTenue)
                }
            }
        }
    }

    // MARK: Evolución

    private var tarjetaEvolucion: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    EtiquetaSeccion(texto: "Evolución de \(magnitud.titulo.lowercased())")
                    Spacer()
                    if let cambio = cambioTotal {
                        Pastilla(texto: cambio, color: magnitud.color)
                    }
                }

                if suscripcion.tieneAcceso || serie.count < 3 {
                    GraficaLinea(puntos: serie, color: Theme.indigo)
                    HStack {
                        Text(Fmt.fechaCorta(serie[0].fecha))
                        Spacer()
                        Text(Fmt.fechaCorta(serie[serie.count - 1].fecha))
                    }
                    .font(Theme.cuerpo(10))
                    .foregroundStyle(Theme.tintaTenue)
                } else {
                    ZStack {
                        GraficaLinea(puntos: serie, color: Theme.indigo)
                            .blur(radius: 7)
                            .opacity(0.5)
                        VStack(spacing: 10) {
                            Insignia(simbolo: .candado, fondo: Theme.lila, diametro: 40)
                            Text("La curva completa está en Nubi completo")
                                .font(Theme.cuerpo(13, .medium))
                                .foregroundStyle(Theme.tinta)
                                .multilineTextAlignment(.center)
                        }
                    }
                    Boton(titulo: suscripcion.textoLlamada, color: Theme.lila) { mostrarPaywall = true }
                }
            }
        }
    }

    private var cambioTotal: String? {
        guard let primera = serie.first, let ultima = serie.last, serie.count >= 2 else { return nil }
        let d = ultima.valor - primera.valor
        let signo = d >= 0 ? "+" : ""
        return signo + Fmt.numero(d, magnitud == .peso ? 2 : 1) + " " + magnitud.unidad
    }

    // MARK: Lista

    @ViewBuilder
    private var listaDeMedidas: some View {
        if !almacen.medidas.isEmpty {
            Tarjeta {
                VStack(alignment: .leading, spacing: 14) {
                    EtiquetaSeccion(texto: "Historial")
                    ForEach(almacen.medidas) { m in
                        Button { editando = m } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Fmt.fechaLarga(m.fecha).capitalizedPrimera)
                                        .font(Theme.cuerpo(14, .medium))
                                        .foregroundStyle(Theme.tinta)
                                    Text(resumenMedida(m))
                                        .font(Theme.cuerpo(12))
                                        .foregroundStyle(Theme.tintaSuave)
                                        .monospacedDigit()
                                }
                                Spacer()
                                Ilus(.chevronDer, 13, color: Theme.tintaTenue)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if m.id != almacen.medidas.last?.id {
                            Rectangle().fill(Theme.separador).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func resumenMedida(_ m: Medida) -> String {
        var partes: [String] = []
        if let p = m.pesoKg { partes.append(Fmt.numero(p, 2) + " kg") }
        if let a = m.alturaCm { partes.append(Fmt.numero(a) + " cm") }
        if let c = m.perimetroCm { partes.append("cabeza " + Fmt.numero(c) + " cm") }
        return partes.isEmpty ? "Sin datos" : partes.joined(separator: " · ")
    }

    private var avisoPercentiles: some View {
        Text("Nubi guarda tus medidas y te enseña la tendencia. Los percentiles y su interpretación corresponden a tu pediatra.")
            .font(Theme.cuerpo(11))
            .foregroundStyle(Theme.tintaTenue)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }
}

// MARK: - Hoja de alta / edición de medida

struct HojaMedida: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar

    @State var medida: Medida
    @State private var peso = ""
    @State private var altura = ""
    @State private var perimetro = ""
    @State private var cargado = false

    private var esNueva: Bool { !almacen.medidas.contains { $0.id == medida.id } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 16) {
                            EtiquetaSeccion(texto: "Fecha")
                            DatePicker("", selection: $medida.fecha, in: ...Date(), displayedComponents: .date)
                                .labelsHidden()
                        }
                    }

                    Tarjeta {
                        VStack(alignment: .leading, spacing: 16) {
                            campoNumero("Peso", unidad: "kg", texto: $peso, simbolo: .bascula, color: Theme.menta)
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            campoNumero("Estatura", unidad: "cm", texto: $altura, simbolo: .regla, color: Theme.cielo)
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            campoNumero("Perímetro craneal", unidad: "cm", texto: $perimetro, simbolo: .ondas, color: Theme.rosa)
                        }
                    }

                    Tarjeta {
                        VStack(alignment: .leading, spacing: 10) {
                            EtiquetaSeccion(texto: "Nota")
                            TextField("Lo que te dijeron en la consulta…", text: $medida.nota, axis: .vertical)
                                .font(Theme.cuerpo(15))
                                .lineLimit(2...5)
                        }
                    }

                    Boton(titulo: "Guardar", color: Theme.lila) { guardar() }

                    if !esNueva {
                        Button {
                            almacen.borrarMedida(medida)
                            cerrar()
                        } label: {
                            HStack(spacing: 7) {
                                Ilus(.papelera, 14, color: Theme.indigo)
                                Text("Borrar esta medida").font(Theme.cuerpo(14, .medium)).foregroundStyle(Theme.indigo)
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
            .navigationTitle(esNueva ? "Nueva medida" : "Medida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }.font(Theme.cuerpo(15))
                }
            }
        }
        .onAppear {
            guard !cargado else { return }
            cargado = true
            peso = medida.pesoKg.map { Fmt.numero($0, 3) } ?? ""
            altura = medida.alturaCm.map { Fmt.numero($0) } ?? ""
            perimetro = medida.perimetroCm.map { Fmt.numero($0) } ?? ""
        }
    }

    private func campoNumero(_ titulo: String, unidad: String, texto: Binding<String>,
                             simbolo: Ilus.Simbolo, color: Color) -> some View {
        HStack(spacing: 12) {
            Insignia(simbolo: simbolo, fondo: color, diametro: 34)
            Text(titulo)
                .font(Theme.cuerpo(15))
                .foregroundStyle(Theme.tinta)
            Spacer()
            TextField("—", text: texto)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(Theme.display(19))
                .foregroundStyle(Theme.tinta)
                .frame(width: 78)
            Text(unidad)
                .font(Theme.cuerpo(13))
                .foregroundStyle(Theme.tintaTenue)
                .frame(width: 22, alignment: .leading)
        }
    }

    private func guardar() {
        medida.pesoKg = Self.numero(peso)
        medida.alturaCm = Self.numero(altura)
        medida.perimetroCm = Self.numero(perimetro)
        guard !medida.vacia else { cerrar(); return }
        almacen.guardarMedida(medida)
        cerrar()
    }

    /// Acepta tanto "7,4" como "7.4": en España la gente escribe con coma.
    static func numero(_ s: String) -> Double? {
        let limpio = s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard !limpio.isEmpty, let v = Double(limpio), v > 0 else { return nil }
        return v
    }
}
