import SwiftUI
import CloudKit
import UserNotifications
import Intents

// MARK: - AppDelegate para notificaciones push silenciosas de CloudKit
class NubiAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // ← CORREGIDO: UNNotification (no UNUserNotificationCenter)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task {
            await Sincronizador.compartido.manejarNotificacionSilenciosa()
            completionHandler(.newData)
        }
    }
}

// MARK: - App principal
@main
@MainActor
struct NubiApp: App {
    @StateObject private var almacen = Almacen()
    @StateObject private var suscripcion = Suscripcion()
    
    init() {
        // Solo cosas que NO dependen de almacen (evita warnings de StateObject)
        AlmacenCompartido.iniciarRuido = { tipoRaw in
            let tipo = ReproductorRuido.TipoRuido(rawValue: tipoRaw) ?? .blanco
            Task { @MainActor in
                let r = ReproductorRuido.compartido
                r.cambiarTipo(tipo)
                if !r.reproduciendo { r.iniciar() }
            }
        }
        AlmacenCompartido.pararRuido = {
            Task { @MainActor in
                ReproductorRuido.compartido.detener()
            }
        }
        
        NubiShortcuts.updateAppShortcutParameters()
    }
    
    var body: some Scene {
        WindowGroup {
            RaizVista()
                .environmentObject(almacen)
                .environmentObject(suscripcion)
                .tint(Theme.indigo)
                .onAppear {
                    // --- Closures que dependen de almacen (Siri + Live Activity) ---
                    
                    // Alimentación
                    AlmacenCompartido.empezarPecho = { [weak almacen] ladoRaw in
                        let lado: LadoPecho = (ladoRaw == "derecha") ? .derecha : .izquierda
                        almacen?.empezarToma(lado)
                    }
                    AlmacenCompartido.registrarBiberon = { [weak almacen] tipoRaw, cantidad, unidadRaw in
                        let tipo: TipoLeche = (tipoRaw == "formula") ? .formula : .materna
                        let unidad: UnidadBiberon = (unidadRaw == "oz") ? .oz : .ml
                        almacen?.registrarBiberon(cantidad: cantidad, unidad: unidad, tipoLeche: tipo)
                    }
                    AlmacenCompartido.registrarPanal = { [weak almacen] pis, caca in
                        almacen?.registrarPanal(pis: pis, caca: caca)
                    }
                    AlmacenCompartido.registrarDespertar = { [weak almacen] minutos in
                        _ = almacen?.registrarDespertar(inicio: .now, duracion: TimeInterval(minutos * 60))
                    }
                    AlmacenCompartido.empezarSiesta = { [weak almacen] in
                        almacen?.empezarSueño(.siesta)
                    }
                    AlmacenCompartido.empezarSueñoNoche = { [weak almacen] in
                        almacen?.empezarSueño(.noche)
                    }
                    
                    // Live Activity
                    AlmacenCompartido.empezarDespertar = { [weak almacen] in
                        _ = almacen?.empezarDespertar()
                    }
                    AlmacenCompartido.volverADormir = { [weak almacen] in
                        _ = almacen?.volverADormir()
                    }
                    AlmacenCompartido.terminarDespertar = { [weak almacen] in
                        almacen?.terminarDespertar()
                    }
                    AlmacenCompartido.terminarSueño = { [weak almacen] in
                        almacen?.terminarSueño()
                    }
                    AlmacenCompartido.hayDespertarEnCurso = { [weak almacen] in
                        almacen?.despertarEnCurso != nil
                    }
                    AlmacenCompartido.haySueñoEnCurso = { [weak almacen] in
                        almacen?.sueñoEnCurso != nil
                    }
                    AlmacenCompartido.cambiarPecho = { [weak almacen] in
                        _ = almacen?.cambiarPecho()
                    }
                    AlmacenCompartido.terminarPecho = { [weak almacen] in
                        almacen?.terminarToma()
                    }
                    
                }
        }
    }
}

// MARK: - Pestañas inferiores
enum Pestana: String, CaseIterable, Identifiable {
    case hoy, linea, crecimiento, salud, diario
    
    var id: String { rawValue }
    
    var titulo: String {
        switch self {
        case .hoy:         return L10n.t("Hoy")
        case .linea:       return L10n.t("Día")
        case .crecimiento: return L10n.t("Crece")
        case .salud:       return L10n.t("Salud")
        case .diario:      return L10n.t("Diario")
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

// MARK: - Barra superior premium
enum VistaSuperior: String, CaseIterable, Identifiable {
    case banco, alimentacion, sonidos
    
    var id: String { rawValue }
    
    var titulo: String {
        switch self {
        case .banco:        return L10n.t("Banco")
        case .alimentacion: return L10n.t("Alimentación")
        case .sonidos:      return L10n.t("Sonidos")
        }
    }
    
    var simbolo: Ilus.Simbolo {
        switch self {
        case .banco:        return .biberon
        case .alimentacion: return .plato
        case .sonidos:      return .ondas
        }
    }
}

// MARK: - Vista raíz
struct RaizVista: View {
    @EnvironmentObject private var almacen: Almacen
    @EnvironmentObject private var suscripcion: Suscripcion
    
    @AppStorage("paywall.mostradoTrasAlta") private var yaMostrado = false
    @AppStorage("modoOscuro") private var modoOscuro = false
    @AppStorage("idioma.nubi") private var idiomaRaw: String = IdiomaNubi.sistema.rawValue
    
    @State private var pestana: Pestana = .hoy
    @State private var vistaSuperior: VistaSuperior? = nil
    @State private var mostrarPaywall = false
    @State private var urlInvitacion: URL?
    
    private var nombreInvitador: String? {
        guard let url = urlInvitacion,
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let de = comps.queryItems?.first(where: { $0.name == "de" })?.value,
              !de.isEmpty else { return nil }
        return de
    }
    
    var body: some View {
        Group {
            if almacen.bebe == nil {
                VistaAlta()
            } else {
                contenido
                    .task {
                        guard !yaMostrado, !suscripcion.cargando, !suscripcion.tieneAcceso else { return }
                        yaMostrado = true
                        mostrarPaywall = true
                    }
            }
        }
        .preferredColorScheme(modoOscuro ? .dark : .light)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                await Sincronizador.compartido.refrescarRol()
                await almacen.sincronizarAhora()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nubiDatosCompartidosCambiados)) { _ in
            Task { await almacen.sincronizarAhora() }
        }
        .onOpenURL { url in
            guard let scheme = url.scheme else { return }
            
            if scheme == "nubi-share" || url.host == "share" {
                urlInvitacion = url
                return
            }
            
            guard scheme == "nubi" else { return }
            switch url.host {
            case "fin-siesta":    almacen.hojaFinSueñoPendiente = "siesta"
            case "fin-noche":     almacen.hojaFinSueñoPendiente = "noche"
            case "fin-despertar": almacen.hojaFinSueñoPendiente = "despertar"
            case "unirme":        urlInvitacion = url
            default: break
            }
        }
        .alert(
            nombreInvitador.map { "\($0) te invita a Nubi" } ?? "¿Unirte a Nubi compartido?",
            isPresented: Binding(
                get: { urlInvitacion != nil },
                set: { if !$0 { urlInvitacion = nil } }
            )
        ) {
            Button("Aceptar") {
                guard let url = urlInvitacion else { return }
                Task {
                    let share = HojaCompartirNubi.shareURLDesdeEnlace(url) ?? url
                    let ok = await Sincronizador.compartido.aceptarInvitacion(url: share)
                    urlInvitacion = nil
                    if ok { await almacen.adoptarCompartido() }
                }
            }
            Button("Cancelar", role: .cancel) { urlInvitacion = nil }
        } message: {
            Text(
                nombreInvitador.map { "\($0) te invita a compartir el sueño y los cuidados de su bebé en tiempo real." }
                ?? "Podrás ver y anotar los datos del bebé compartido en este iPhone."
            )
        }
        .sheet(isPresented: $mostrarPaywall) { Paywall() }
    }
    
    @ViewBuilder
    private var contenido: some View {
        Group {
            if let superior = vistaSuperior {
                switch superior {
                case .banco:
                    if suscripcion.tieneAcceso || Sincronizador.compartido.esParticipante {
                        ContenidoBancoLeche()
                    } else {
                        BloqueoPremiumVista(
                            titulo: "Banco de leche",
                            texto: "Controla tus extracciones, los usos y las caducidades de la leche materna.",
                            simbolo: .biberon,
                            color: Theme.cielo,
                            mostrarPaywall: $mostrarPaywall
                        )
                    }
                case .alimentacion:
                    if suscripcion.tieneAcceso || Sincronizador.compartido.esParticipante {
                        ContenidoAlimentacion()
                    } else {
                        BloqueoPremiumVista(
                            titulo: "Alimentación complementaria",
                            texto: "Registra cada comida nueva con fotos y marca si le gustó o no.",
                            simbolo: .plato,
                            color: Theme.menta,
                            mostrarPaywall: $mostrarPaywall
                        )
                    }
                case .sonidos:
                    VistaSonidos()
                }
            } else {
                switch pestana {
                case .hoy:         VistaInicio()
                case .linea:       VistaLinea()
                case .crecimiento: VistaCrecimiento()
                case .salud:       VistaSalud()
                case .diario:      VistaDiario()
                }
            }
        }
        .safeAreaInset(edge: .top) {
            BarraSuperior(seleccion: $vistaSuperior)
        }
        .safeAreaInset(edge: .bottom) {
            BarraPestanas(seleccion: $pestana, vistaSuperior: $vistaSuperior)
        }
    }
}

// MARK: - Bloqueo premium para la barra superior
struct BloqueoPremiumVista: View {
    let titulo: String
    let texto: String
    let simbolo: Ilus.Simbolo
    let color: Color
    @Binding var mostrarPaywall: Bool
    @EnvironmentObject private var suscripcion: Suscripcion
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Tarjeta {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Insignia(simbolo: .candado, fondo: Theme.lila, diametro: 26)
                            EtiquetaSeccion(texto: L10n.t("Nubi completo"))
                        }
                        HStack(spacing: 12) {
                            Insignia(simbolo: simbolo, fondo: color, diametro: 42)
                            Text(titulo)
                                .font(Theme.display(22))
                                .foregroundStyle(Theme.tinta)
                        }
                        Text(texto)
                            .font(Theme.cuerpo(13))
                            .foregroundStyle(Theme.tintaSuave)
                            .fixedSize(horizontal: false, vertical: true)
                        Boton(titulo: suscripcion.textoLlamada, color: Theme.lila) {
                            mostrarPaywall = true
                        }
                    }
                }
            }
            .padding(Theme.margen)
        }
        .background(Theme.lienzo.ignoresSafeArea())
    }
}

// MARK: - Barra superior premium
struct BarraSuperior: View {
    @Binding var seleccion: VistaSuperior?
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(VistaSuperior.allCases) { item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if seleccion == item {
                            seleccion = nil
                        } else {
                            seleccion = item
                        }
                    }
                } label: {
                    VStack(spacing: 5) {
                        Text(item.titulo)
                            .font(Theme.cuerpo(10, seleccion == item ? .semibold : .regular))
                            .foregroundStyle(
                                seleccion == item ? Theme.indigo : Theme.tintaTenue
                            )
                        ZStack {
                            if seleccion == item {
                                Capsule()
                                    .fill(Theme.lila.opacity(0.35))
                                    .frame(width: 44, height: 30)
                            }
                            Ilus(
                                item.simbolo,
                                22,
                                color: seleccion == item ? Theme.indigo : Theme.tintaTenue
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 3)
        .padding(.bottom, 9)
        .background {
            Rectangle()
                .fill(Theme.superficie.opacity(0.96))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Theme.separador)
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - Barra de pestañas inferiores
struct BarraPestanas: View {
    @Binding var seleccion: Pestana
    @Binding var vistaSuperior: VistaSuperior?
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Pestana.allCases) { p in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        seleccion = p
                        vistaSuperior = nil
                    }
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            if seleccion == p && vistaSuperior == nil {
                                Capsule()
                                    .fill(Theme.lila.opacity(0.35))
                                    .frame(width: 44, height: 30)
                            }
                            Ilus(
                                p.simbolo,
                                22,
                                color: (seleccion == p && vistaSuperior == nil) ? Theme.indigo : Theme.tintaTenue
                            )
                        }
                        Text(p.titulo)
                            .font(Theme.cuerpo(10, (seleccion == p && vistaSuperior == nil) ? .semibold : .regular))
                            .foregroundStyle(
                                (seleccion == p && vistaSuperior == nil) ? Theme.indigo : Theme.tintaTenue
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
    @State private var mostrarBienvenida = false
    
    // Despertar manual del primer día
    @State private var conDespertar = false
    @State private var horaDespertar = Date()
    
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
                        Text(L10n.t("El sueño de tu bebé, sin adivinar."))
                            .font(Theme.cuerpo(15))
                            .foregroundStyle(Theme.tintaSuave)
                    }
                }
                .padding(.top, 44)
                
                Tarjeta {
                    VStack(alignment: .leading, spacing: 18) {
                        campo(L10n.t("Nombre")) {
                            TextField(L10n.t("Su nombre"), text: $nombre)
                                .font(Theme.cuerpo(17))
                                .textInputAutocapitalization(.words)
                        }
                        Divider().background(Theme.separador)
                        campo(L10n.t("Fecha de nacimiento")) {
                            DatePicker(
                                "",
                                selection: $nacimiento,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                        }
                        Divider().background(Theme.separador)
                        campo(L10n.t("Semanas de prematuridad")) {
                            Stepper("\(prematuro) " + L10n.t("semanas"), value: $prematuro, in: 0...16)
                                .font(Theme.cuerpo(15))
                            Text(L10n.t("Si nació antes de tiempo, Nubi usa la edad corregida para calcular sus ventanas."))
                                .font(Theme.cuerpo(11))
                                .foregroundStyle(Theme.tintaTenue)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                
                // Pregunta opcional: ¿a qué hora despertó hoy?
                Tarjeta(relleno: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $conDespertar.animation(.spring(response: 0.3, dampingFraction: 0.85))) {
                            HStack(spacing: 10) {
                                Insignia(simbolo: .sol, fondo: Theme.mantequilla, diametro: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.t("¿A qué hora despertó hoy?"))
                                        .font(Theme.cuerpo(14, .semibold))
                                        .foregroundStyle(Theme.tinta)
                                    Text(L10n.t("Con este dato, Nubi coloca el sol en el reloj y calcula las siestas de hoy desde el primer día."))
                                        .font(Theme.cuerpo(11))
                                        .foregroundStyle(Theme.tintaSuave)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .tint(Theme.indigo)
                        
                        if conDespertar {
                            DatePicker(
                                L10n.t("Hora de despertar"),
                                selection: $horaDespertar,
                                displayedComponents: [.hourAndMinute]
                            )
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                        }
                    }
                }
                
                // Aviso del aprendizaje de 7 días
                Tarjeta(relleno: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Insignia(simbolo: .estrella, fondo: Theme.mantequilla, diametro: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.t("Nubi aprende de tu bebé"))
                                .font(Theme.cuerpo(14, .semibold))
                                .foregroundStyle(Theme.tinta)
                            Text(L10n.t("Las primeras predicciones se basan en su edad. Durante los primeros 7 días, Nubi observa el ritmo real de tu bebé y ajusta las ventanas de sueño para que cada vez acierten más."))
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                
                Boton(titulo: L10n.t("Empezar"), color: Theme.lila) {
                    mostrarBienvenida = true
                }
                
                Text(L10n.t("Tus datos se guardan en tu iPhone y en tu iCloud privado. Puedes compartirlos con tu pareja si lo deseas."))
                    .font(Theme.cuerpo(11))
                    .foregroundStyle(Theme.tintaTenue)
            }
            .padding(Theme.margen)
        }
        .background(Theme.lienzo.ignoresSafeArea())
        .alert(L10n.t("¡Bienvenido a Nubi! 🌙"), isPresented: $mostrarBienvenida) {
            Button(L10n.t("Empezar a cuidar su sueño")) {
                crearBebe()
            }
        } message: {
            Text("Durante los próximos 7 días, Nubi irá aprendiendo el ritmo único de \(nombreVisible). Cuanto más registres sus siestas y noches, más precisas serán las predicciones. ¡Vamos a por ello!")
        }
    }
    
    private var nombreVisible: String {
        let limpio = nombre.trimmingCharacters(in: .whitespaces)
        return limpio.isEmpty ? L10n.t("tu bebé") : limpio
    }
    
    private func crearBebe() {
        almacen.guardarBebe(
            Bebe(
                nombre: nombre.trimmingCharacters(in: .whitespaces).isEmpty
                    ? L10n.t("Mi bebé")
                    : nombre,
                fechaNacimiento: nacimiento,
                semanasPrematuro: prematuro
            )
        )
        
        // Si el usuario indicó la hora de despertar de hoy, la guardamos
        if conDespertar {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: horaDespertar)
            if let fecha = Calendar.current.date(
                bySettingHour: comps.hour ?? 7,
                minute: comps.minute ?? 0,
                second: 0,
                of: .now
            ) {
                almacen.registrarDespertarManual(fecha)
            }
        }
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