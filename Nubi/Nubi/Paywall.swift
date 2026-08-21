import SwiftUI
import StoreKit

/// Paywall blando: se puede cerrar. Aparece al terminar el alta del bebé y
/// desde cualquier función bloqueada.
struct Paywall: View {

    @EnvironmentObject private var suscripcion: Suscripcion
    @Environment(\.dismiss) private var cerrar

    @State private var seleccionado: Product?
    @State private var comprando = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                cabecera
                ventajas
                planes
                accion
                letraPequeña
            }
            .padding(Theme.margen)
            .padding(.bottom, 30)
        }
        .background(Theme.lienzo.ignoresSafeArea())
        .overlay(alignment: .topTrailing) { botonCerrar }
        .task(id: suscripcion.productos.count) {
            if seleccionado == nil {
                seleccionado = suscripcion.productos.first
            }
        }
    }

    // MARK: Cabecera

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: -12) {
                Ilus(.nube, 44, color: Theme.lila)
                Ilus(.luna, 28, color: Theme.mantequilla).offset(y: -10)
            }

            Text("Nubi completo")
                .font(Theme.display(38))
                .foregroundStyle(Theme.tinta)

            Text("Deja de adivinar cuándo toca la siesta.")
                .font(Theme.cuerpo(16))
                .foregroundStyle(Theme.tintaSuave)
        }
        .padding(.top, 44)
    }

    // MARK: Ventajas

    private var ventajas: some View {
        VStack(alignment: .leading, spacing: 16) {
            ventaja(
                .nube,
                Theme.menta,
                "Ventanas que aprenden de tu bebé",
                "No una tabla por edad: el ritmo real del tuyo, afinado cada día."
            )

            ventaja(
                .reloj,
                Theme.cielo,
                "Historial completo",
                "Todos los días atrás, donde se ven las regresiones y los cambios de siesta."
            )

            ventaja(
                .regla,
                Theme.melocoton,
                "Curvas de peso y estatura",
                "La evolución entre revisión y revisión, no solo el último número."
            )

            ventaja(
                .cuaderno,
                Theme.mantequilla,
                "Diario sin límite",
                "Todas las anécdotas y los hitos que quieras guardar."
            )

            ventaja(
                .candado,
                Theme.lila,
                "Tus datos, solo tuyos",
                "Se guardan en tu iPhone y en tu iCloud privado. Nunca en servidores de terceros. Family Sharing incluido."
            )
        }
    }

    private func ventaja(
        _ simbolo: Ilus.Simbolo,
        _ color: Color,
        _ titulo: String,
        _ texto: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Insignia(simbolo: simbolo, fondo: color, diametro: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(titulo)
                    .font(Theme.cuerpo(15, .semibold))
                    .foregroundStyle(Theme.tinta)

                Text(texto)
                    .font(Theme.cuerpo(13))
                    .foregroundStyle(Theme.tintaSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Planes

    @ViewBuilder
    private var planes: some View {
        if suscripcion.cargando {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
        } else if suscripcion.productos.isEmpty {
            Tarjeta {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No se han podido cargar los planes")
                        .font(Theme.cuerpo(15, .semibold))
                        .foregroundStyle(Theme.tinta)

                    Text("Comprueba la conexión y vuelve a abrir esta pantalla.")
                        .font(Theme.cuerpo(13))
                        .foregroundStyle(Theme.tintaSuave)

                    Text("Si estás probando en el simulador, necesitas tener configurado un archivo StoreKit con los productos de prueba.")
                        .font(Theme.cuerpo(11))
                        .foregroundStyle(Theme.tintaTenue)
                        .padding(.top, 4)
                }
            }
        } else {
            VStack(spacing: 10) {
                ForEach(suscripcion.productos, id: \.id) { producto in
                    tarjetaPlan(producto)
                }
            }
        }
    }

    private func tarjetaPlan(_ producto: Product) -> some View {
        let activo = seleccionado?.id == producto.id
        // ← NUEVO: detecta el nombre del plan automáticamente
        let nombrePlan: String = {
            guard let sub = producto.subscription else { return "Nubi" }
            switch sub.subscriptionPeriod.unit {
            case .year:
                return "Anual"
            case .month:
                return sub.subscriptionPeriod.value == 3 ? "Trimestral" : "Mensual"
            case .week:
                return "Semanal"
            default:
                return "Nubi"
            }
        }()

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                seleccionado = producto
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            activo ? Theme.indigo : Theme.tintaTenue,
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)

                    if activo {
                        Circle()
                            .fill(Theme.indigo)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(nombrePlan)  // ← CAMBIADO: antes era `anual ? "Anual" : "Mensual"`
                        .font(Theme.cuerpo(16, .semibold))
                        .foregroundStyle(Theme.tinta)

                    if let mensual = suscripcion.precioMensualizado(producto) {
                        Text("Sale a \(mensual)")
                            .font(Theme.cuerpo(12))
                            .foregroundStyle(Theme.tintaSuave)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(producto.displayPrice)
                        .font(Theme.display(19))
                        .foregroundStyle(Theme.tinta)

                    if let ahorro = suscripcion.ahorroAnual(producto) ?? suscripcion.ahorroTrimestral(producto) {
                        Text("AHORRAS \(ahorro) %")
                            .font(Theme.etiqueta)
                            .tracking(1.2)
                            .foregroundStyle(Theme.tinta)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Theme.mantequilla, in: Capsule())
                    }
                }
            }
            .padding(Theme.margen)
            .background(
                Theme.superficie,
                in: RoundedRectangle(cornerRadius: Theme.radio, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radio, style: .continuous)
                    .strokeBorder(activo ? Theme.indigo : .clear, lineWidth: 2)
            )
            .shadow(color: Theme.sombra, radius: activo ? 12 : 5, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: Acción

    @ViewBuilder
    private var accion: some View {
        if let producto = seleccionado {
            VStack(spacing: 12) {
                Button {
                    Task {
                        comprando = true
                        let ok = await suscripcion.comprar(producto)
                        comprando = false

                        if ok {
                            cerrar()
                        }
                    }
                } label: {
                    Group {
                        if comprando {
                            ProgressView()
                                .tint(Theme.tinta)
                        } else {
                            Text(textoBoton(producto))
                                .font(Theme.cuerpo(16, .semibold))
                        }
                    }
                    .foregroundStyle(Theme.tinta)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Theme.lila, in: Capsule())
                }
                .buttonStyle(BotonPresionable())
                .disabled(comprando)

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

    private func textoBoton(_ producto: Product) -> String {
        suscripcion.textoPrueba(producto) != nil
            ? "Empezar prueba gratis"
            : "Suscribirme"
    }

    // MARK: Letra pequeña

    @ViewBuilder
    private var letraPequeña: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let producto = seleccionado,
               let prueba = suscripcion.textoPrueba(producto) {
                Text("\(prueba), después \(producto.displayPrice). Se renueva automáticamente. Puedes cancelar cuando quieras desde los Ajustes de tu iPhone; si cancelas antes de que acabe la prueba, no se te cobra nada.")
            } else {
                Text("Se renueva automáticamente. Puedes cancelar cuando quieras desde los Ajustes de tu iPhone.")
            }

            HStack(spacing: 16) {
               Link("Términos", destination: URL(string: "https://appnubi.netlify.app/terminos")!)
               Link("Privacidad", destination: URL(string: "https://appnubi.netlify.app/privacidad")!)
            }
            .font(Theme.cuerpo(12, .medium))
            .foregroundStyle(Theme.tintaSuave)
        }
        .font(Theme.cuerpo(11))
        .foregroundStyle(Theme.tintaTenue)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var botonCerrar: some View {
        Button {
            cerrar()
        } label: {
            Ilus(.cerrar, 12, color: Theme.tintaSuave)
                .frame(width: 32, height: 32)
                .background(Theme.superficie, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(Theme.margen)
    }
}

// MARK: - Bloqueo

/// Sustituye a una función premium cuando no hay acceso.
/// No oculta la función: enseña qué se está perdiendo, que convierte mejor.
struct BloqueoPremium: View {

    let titulo: String
    let texto: String

    @Binding var mostrarPaywall: Bool

    @EnvironmentObject private var suscripcion: Suscripcion

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Insignia(simbolo: .candado, fondo: Theme.lila, diametro: 26)
                    EtiquetaSeccion(texto: "Nubi completo")
                }

                Text(titulo)
                    .font(Theme.display(22))
                    .foregroundStyle(Theme.tinta)

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
}

/// Aviso discreto en los últimos días de prueba.
struct AvisoPrueba: View {

    let dias: Int

    @Binding var mostrarPaywall: Bool

    var body: some View {
        Button {
            mostrarPaywall = true
        } label: {
            HStack(spacing: 10) {
                Ilus(.reloj, 15, color: Theme.tinta)

                Text(dias == 1 ? "Último día de prueba" : "Quedan \(dias) días de prueba")
                    .font(Theme.cuerpo(13, .medium))
                    .foregroundStyle(Theme.tinta)

                Spacer()

                Ilus(.chevronDer, 12, color: Theme.tintaSuave)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.mantequilla, in: Capsule())
        }
        .buttonStyle(BotonPresionable())
    }
}