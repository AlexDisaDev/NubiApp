import Foundation
import StoreKit
import Combine

/// Acceso premium vía suscripción nativa de Apple (StoreKit 2).
///
/// Regla que conviene no romper: ningún texto sobre la prueba gratuita se
/// escribe a mano en la interfaz. Todo sale del `Product`. Si algún día cambias
/// la oferta en App Store Connect y la app sigue diciendo "7 días", eso es
/// motivo de rechazo en revisión y de reseñas de una estrella.
@MainActor
final class Suscripcion: ObservableObject {

    enum ID {
        static let anual   = "app.nubi.premium.anual"
        static let mensual = "app.nubi.premium.mensual"
        static let todos   = [anual, mensual]
    }

    @Published private(set) var productos: [Product] = []
    @Published private(set) var suscrito = false
    @Published private(set) var cargando = true
    @Published private(set) var elegibleParaPrueba = true
    @Published private(set) var enPrueba = false
    @Published private(set) var venceEl: Date?

    private var vigilante: Task<Void, Never>?

    init() {
        vigilante = escucharTransacciones()
        Task {
            await cargarProductos()
            await refrescarEstado()
            cargando = false
        }
    }

    deinit { vigilante?.cancel() }

    var tieneAcceso: Bool { suscrito }

    var diasRestantes: Int? {
        guard let venceEl else { return nil }
        let d = Calendar.current.dateComponents([.day], from: .now, to: venceEl).day
        return d.map { max(0, $0 + 1) }
    }

    var debeAvisar: Bool {
        guard enPrueba, let d = diasRestantes else { return false }
        return d <= 3
    }

    /// Texto de todos los botones que llevan al paywall. Sale del producto real.
    var textoLlamada: String {
        let preferido = productos.first { $0.subscription?.subscriptionPeriod.unit == .year } ?? productos.first
        if let p = preferido, let prueba = textoPrueba(p) { return "Probar " + prueba }
        return "Ver Nubi completo"
    }

    // MARK: Catálogo

    private func cargarProductos() async {
        do {
            let items = try await Product.products(for: ID.todos)
            productos = items.sorted { $0.price > $1.price }
            await comprobarElegibilidad()
        } catch {
            productos = []
        }
    }

    private func comprobarElegibilidad() async {
        guard let sub = productos.first?.subscription else { return }
        elegibleParaPrueba = await sub.isEligibleForIntroOffer
    }

    /// "7 días gratis", "1 mes gratis"… o nil si ya se ha usado la prueba.
    func textoPrueba(_ producto: Product) -> String? {
        guard elegibleParaPrueba,
              let oferta = producto.subscription?.introductoryOffer,
              oferta.paymentMode == .freeTrial
        else { return nil }

        let n = oferta.period.value
        switch oferta.period.unit {
        case .day:   return n == 1 ? "1 día gratis"    : "\(n) días gratis"
        case .week:  return n == 1 ? "7 días gratis"   : "\(n * 7) días gratis"
        case .month: return n == 1 ? "1 mes gratis"    : "\(n) meses gratis"
        case .year:  return n == 1 ? "1 año gratis"    : "\(n) años gratis"
        @unknown default: return "Prueba gratuita"
        }
    }

    func precioMensualizado(_ producto: Product) -> String? {
        guard let sub = producto.subscription, sub.subscriptionPeriod.unit == .year else { return nil }
        let meses = Decimal(12 * sub.subscriptionPeriod.value)
        let porMes = producto.price / meses
        return porMes.formatted(producto.priceFormatStyle) + "/mes"
    }

    func ahorroAnual(_ producto: Product) -> Int? {
        guard producto.subscription?.subscriptionPeriod.unit == .year,
              let mensual = productos.first(where: { $0.subscription?.subscriptionPeriod.unit == .month }),
              mensual.price > 0
        else { return nil }

        let coste12Meses = mensual.price * 12
        guard coste12Meses > producto.price else { return nil }

        let ratio = (coste12Meses - producto.price) / coste12Meses * 100
        let pct = Int(NSDecimalNumber(decimal: ratio).doubleValue.rounded())
        return pct >= 10 ? pct : nil
    }

    // MARK: Compra

    @discardableResult
    func comprar(_ producto: Product) async -> Bool {
        do {
            switch try await producto.purchase() {
            case .success(let verificacion):
                guard case .verified(let t) = verificacion else { return false }
                await t.finish()
                await refrescarEstado()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    func restaurar() async {
        try? await AppStore.sync()
        await refrescarEstado()
    }

    // MARK: Estado del derecho

    func refrescarEstado() async {
        var activo = false
        var prueba = false
        var vence: Date?

        for await resultado in Transaction.currentEntitlements {
            guard case .verified(let t) = resultado,
                  ID.todos.contains(t.productID),
                  t.revocationDate == nil
            else { continue }

            activo = true
            vence = t.expirationDate
            if t.offerType == .introductory { prueba = true }
        }

        suscrito = activo
        enPrueba = prueba
        venceEl = vence
        await comprobarElegibilidad()
    }

    private func escucharTransacciones() -> Task<Void, Never> {
        Task { [weak self] in
            for await resultado in Transaction.updates {
                guard case .verified(let t) = resultado else { continue }
                await t.finish()
                await self?.refrescarEstado()
            }
        }
    }
}
