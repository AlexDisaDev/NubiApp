import SwiftUI

struct VistaAtajosSiri: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Cabecera
                VStack(alignment: .leading, spacing: 10) {
                    Insignia(simbolo: .ondas, fondo: Theme.lila, diametro: 56)
                    Text("Atajos de Siri")
                        .font(Theme.display(28))
                        .foregroundStyle(Theme.tinta)
                    Text("Registra la rutina de tu bebé sin abrir la app. Di «Oye Siri…» seguido de cualquiera de estas frases.")
                        .font(Theme.cuerpo(14))
                        .foregroundStyle(Theme.tintaSuave)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Sueño
                seccion(titulo: "Sueño", color: Theme.lila) {
                    atajo("Empieza la noche en Nubi", "Inicia el sueño nocturno.")
                    atajo("Buenos días en Nubi", "Termina la noche.")
                    atajo("Empieza la siesta en Nubi", "Inicia una siesta.")
                    atajo("Termina la siesta en Nubi", "Cierra la siesta en curso.")
                    atajo("Registra despertar nocturno en Nubi", "Anota un despertar durante la noche.")
                }
                
                // Alimentación
                seccion(titulo: "Alimentación", color: Theme.melocoton) {
                    atajo("Empieza pecho izquierdo en Nubi", "Inicia una toma. También «derecho».")
                    atajo("Cambia de pecho en Nubi", "Alterna al otro pecho durante la toma.")
                    atajo("Termina el pecho en Nubi", "Cierra la toma en curso.")
                    atajo("Registra biberón de materna en Nubi", "Nubi te preguntará la cantidad y la unidad. También «fórmula».")
                }
                
                // Cuidados
                seccion(titulo: "Cuidados", color: Theme.menta) {
                    atajo("Registra pañal con pis y caca en Nubi", "También «con pis» o «con caca».")
                }
                
                // Consejo final
                Tarjeta(relleno: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Insignia(simbolo: .estrella, fondo: Theme.mantequilla, diametro: 34)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("¿Quieres frases más cortas?")
                                .font(Theme.cuerpo(14, .semibold))
                                .foregroundStyle(Theme.tinta)
                            Text("Abre la app Atajos de Apple, busca Nubi y graba tu propia frase para cada acción (por ejemplo «a dormir»). Así no tendrás que decir «en Nubi».")
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(Theme.margen)
        }
        .background(Theme.lienzo.ignoresSafeArea())
        .navigationTitle("Atajos de Siri")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func seccion<C: View>(
        titulo: String,
        color: Color,
        @ViewBuilder _ contenido: () -> C
    ) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Circle().fill(color).frame(width: 10, height: 10)
                    EtiquetaSeccion(texto: titulo)
                }
                contenido()
            }
        }
    }
    
    private func atajo(_ frase: String, _ descripcion: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("«\(frase)»")
                .font(Theme.cuerpo(14, .semibold))
                .foregroundStyle(Theme.tinta)
            Text(descripcion)
                .font(Theme.cuerpo(12))
                .foregroundStyle(Theme.tintaSuave)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}