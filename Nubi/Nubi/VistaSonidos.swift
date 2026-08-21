import SwiftUI

struct VistaSonidos: View {
    @StateObject private var reproductor = ReproductorRuido.compartido
    //@EnvironmentObject private var l10n: L10n
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Cabecera(titulo: "Sonidos", subtitulo: "Generados matemáticamente. Sin descargas ni anuncios.") { EmptyView() }
                
                // Selector de tipo de ruido
                VStack(alignment: .leading, spacing: 12) {
                    EtiquetaSeccion(texto: "Tipo de sonido")
                    HStack(spacing: 12) {
                        ForEach(ReproductorRuido.TipoRuido.allCases) { tipo in
                            botonTipo(tipo)
                        }
                    }
                }
                
                // Selector de duración
                VStack(alignment: .leading, spacing: 12) {
                    EtiquetaSeccion(texto: "Temporizador")
                    SelectorNubi(
                        opciones: ReproductorRuido.Duracion.allCases.map { OpcionSelector(valor: $0, titulo: $0.titulo) },
                        seleccion: Binding(
                            get: { reproductor.duracionSeleccionada },
                            set: { reproductor.cambiarDuracion($0) }
                        )
                    )
                }
                
                // Botón de Play/Pausa grande
                botonPlay()
                
                // Tiempo restante
                if let restante = reproductor.tiempoRestante {
                    Tarjeta(relleno: 14) {
                        HStack {
                            Ilus(.reloj, 16, color: Theme.tintaSuave)
                            Text("Se detendrá en \(Fmt.duracion(restante))")
                                .font(Theme.cuerpo(14, .medium))
                                .foregroundStyle(Theme.tinta)
                                .monospacedDigit()
                            Spacer()
                        }
                    }
                }
                
                // Explicación de cada color de ruido
                Tarjeta(relleno: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Insignia(simbolo: .ondas, fondo: Theme.cielo, diametro: 28)
                            Text("¿Cuál elegir?")
                                .font(Theme.cuerpo(14, .semibold))
                                .foregroundStyle(Theme.tinta)
                        }
                        Text("**Blanco:** enmascara ruidos bruscos (portazos, perros, hermanos mayores).")
                            .font(Theme.cuerpo(12))
                            .foregroundStyle(Theme.tintaSuave)
                        Text("**Rosa:** más suave y con menos agudos, ideal para mantener el sueño profundo.")
                            .font(Theme.cuerpo(12))
                            .foregroundStyle(Theme.tintaSuave)
                        Text("**Marrón:** muy grave y envolvente, como un ventilador lejano o un trueno suave.")
                            .font(Theme.cuerpo(12))
                            .foregroundStyle(Theme.tintaSuave)
                    }
                }
            }
            .padding(Theme.margen)
            .padding(.bottom, 30)
        }
        .background(Theme.lienzo.ignoresSafeArea())
    }
    
    private func botonTipo(_ tipo: ReproductorRuido.TipoRuido) -> some View {
        let activo = reproductor.tipoSeleccionado == tipo
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                reproductor.cambiarTipo(tipo)
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(activo ? tipo.color.opacity(0.25) : Theme.lienzoAlto)
                        .frame(width: 64, height: 64)
                    
                    Ilus(.ondas, 28, color: activo ? tipo.color : Theme.tintaTenue)
                }
                
                Text(tipo.titulo)
                    .font(Theme.cuerpo(12, activo ? .semibold : .regular))
                    .foregroundStyle(activo ? Theme.tinta : Theme.tintaSuave)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(activo ? tipo.color.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(activo ? tipo.color.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func botonPlay() -> some View {
        Button {
            reproductor.toggle()
        } label: {
            ZStack {
                Circle()
                    .fill(reproductor.reproduciendo ? reproductor.tipoSeleccionado.color : Theme.indigo)
                    .frame(width: 110, height: 110)
                    .shadow(color: Theme.sombra, radius: 12, y: 6)
                
                Image(systemName: reproductor.reproduciendo ? "pause.fill" : "play.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    //.offset(x: reproductor.reproduciendo ? 0 : 4)
            }
        }
        .buttonStyle(BotonPresionable())
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}