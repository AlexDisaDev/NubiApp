import SwiftUI

enum SeccionPremium: String, CaseIterable, Identifiable {
    case banco = "Banco de leche"
    case alimentacion = "Alimentación"
    var id: String { rawValue }
}

struct VistaPremium: View {
    //@EnvironmentObject private var l10n: L10
    @EnvironmentObject private var suscripcion: Suscripcion
    @State private var seccion: SeccionPremium = .banco
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Picker segmentado arriba
                Picker("Sección", selection: $seccion) {
                    ForEach(SeccionPremium.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                
                // Contenido según la sección (ya están definidos en sus archivos)
                if seccion == .banco {
                    ContenidoBancoLeche()
                } else {
                    ContenidoAlimentacion()
                }
            }
            .padding(Theme.margen)
        }
        .background(Theme.lienzo.ignoresSafeArea())
    }
}