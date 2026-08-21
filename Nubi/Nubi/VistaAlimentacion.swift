import SwiftUI
import PhotosUI

// MARK: - Contenido Alimentación (para la barra superior)

struct ContenidoAlimentacion: View {
    @EnvironmentObject private var almacen: Almacen
    @State private var editandoComida: ComidaComplementaria?
    @State private var confirmarBorradoComida: ComidaComplementaria? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Cabecera(titulo: "Alimentación") { EmptyView() }
                
                Tarjeta {
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("\(almacen.comidas.count)")
                                .font(Theme.display(32))
                                .foregroundStyle(Theme.tinta)
                            Text("comidas")
                                .font(Theme.cuerpo(11))
                                .foregroundStyle(Theme.tintaSuave)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 4) {
                            Text("\(comidasGustadas)")
                                .font(Theme.display(32))
                                .foregroundStyle(Theme.menta)
                            HStack(spacing: 4) {
                                Image(systemName: "hand.thumbsup.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.menta)
                                Text("gustaron")
                                    .font(Theme.cuerpo(11))
                                    .foregroundStyle(Theme.tintaSuave)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 4) {
                            Text("\(comidasNoGustadas)")
                                .font(Theme.display(32))
                                .foregroundStyle(Theme.coral)
                            HStack(spacing: 4) {
                                Image(systemName: "hand.thumbsdown.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.coral)
                                Text("no gustaron")
                                    .font(Theme.cuerpo(11))
                                    .foregroundStyle(Theme.tintaSuave)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                Boton(titulo: "Registrar comida", simbolo: .mas, color: Theme.menta) {
                    editandoComida = ComidaComplementaria()
                }
                
                if almacen.comidas.isEmpty {
                    Tarjeta {
                        EstadoVacio(
                            simbolo: .plato,
                            titulo: "Aún no hay comidas",
                            texto: "Registra la primera papilla, fruta o cereal de tu bebé.",
                            color: Theme.menta
                        )
                    }
                } else {
                    ForEach(almacen.comidas) { comida in
                        HStack(spacing: 8) {
                            Button {
                                editandoComida = comida
                            } label: {
                                Tarjeta {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(spacing: 8) {
                                            Text(Fmt.fechaCorta(comida.fecha) + " · " + Fmt.hora(comida.fecha))
                                                .font(Theme.cuerpo(11, .semibold))
                                                .foregroundStyle(Theme.tintaSuave)
                                            Pastilla(texto: comida.categoria.rawValue, color: comida.categoria.color)
                                            Spacer()
                                            if let gusto = comida.gusto {
                                                Image(systemName: gusto == .leGusto ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                                                    .font(.system(size: 18))
                                                    .foregroundStyle(gusto == .leGusto ? Theme.menta : Theme.coral)
                                            }
                                        }
                                        
                                        if !comida.nombre.isEmpty {
                                            Text(comida.nombre)
                                                .font(Theme.display(18))
                                                .foregroundStyle(Theme.tinta)
                                        }
                                        
                                        if !comida.fotos.isEmpty {
                                            HStack(spacing: 8) {
                                                ForEach(Array(comida.fotos.enumerated()), id: \.offset) { _, fotoData in
                                                    if let uiImage = UIImage(data: fotoData) {
                                                        Image(uiImage: uiImage)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(width: 70, height: 70)
                                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    }
                                                }
                                            }
                                        }
                                        
                                        if !comida.nota.isEmpty {
                                            Text(comida.nota)
                                                .font(Theme.cuerpo(12))
                                                .foregroundStyle(Theme.tintaSuave)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                confirmarBorradoComida = comida
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Theme.coral)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(Theme.margen)
            .padding(.bottom, 8)
        }
        .background(Theme.lienzo.ignoresSafeArea())
        .sheet(item: $editandoComida) { comida in
            HojaComida(comida: comida)
        }
        .alert("¿Eliminar esta comida?",
               isPresented: Binding(
                   get: { confirmarBorradoComida != nil },
                   set: { if !$0 { confirmarBorradoComida = nil } }
               ),
               presenting: confirmarBorradoComida) { comida in
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                almacen.borrarComida(comida)
            }
        } message: { _ in
            Text("Esta acción no se puede deshacer.")
        }
    }
    
    private var comidasGustadas: Int {
        almacen.comidas.filter { $0.gusto == .leGusto }.count
    }
    
    private var comidasNoGustadas: Int {
        almacen.comidas.filter { $0.gusto == .noLeGusto }.count
    }
}

// MARK: - Hoja de comida

struct HojaComida: View {
    @EnvironmentObject private var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    @State var comida: ComidaComplementaria
    @State private var fotosSeleccionadas: [PhotosPickerItem] = []
    @State private var imagenes: [Data] = []
    @State private var confirmarBorrado = false
    @State private var mostrarCamara = false
    @State private var fotoCamara: UIImage? = nil
    
    private var esNueva: Bool { !almacen.comidas.contains { $0.id == comida.id } }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "Fecha y hora")
                                DatePicker("", selection: $comida.fecha, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                            }
                            
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "¿Qué comió?")
                                TextField("Puré de calabaza", text: $comida.nombre)
                                    .font(Theme.cuerpo(16))
                            }
                            
                            Rectangle().fill(Theme.separador).frame(height: 1)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                EtiquetaSeccion(texto: "Categoría")
                                Picker("Categoría", selection: $comida.categoria) {
                                    ForEach(CategoriaAlimento.allCases) { c in
                                        Text(c.rawValue).tag(c)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                    
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 12) {
                            EtiquetaSeccion(texto: "Fotos (máx 2)")
                            
                            if imagenes.count < 2 {
                                HStack(spacing: 10) {
                                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                        Button {
                                            mostrarCamara = true
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 14, weight: .semibold))
                                                Text("Hacer foto")
                                                    .font(Theme.cuerpo(14, .medium))
                                            }
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Theme.indigo, in: Capsule())
                                        }
                                        .buttonStyle(BotonPresionable())
                                    }
                                    
                                    PhotosPicker(
                                        selection: $fotosSeleccionadas,
                                        maxSelectionCount: 2,
                                        matching: .images
                                    ) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "photo.on.rectangle")
                                                .font(.system(size: 14, weight: .semibold))
                                            Text("Elegir foto")
                                                .font(Theme.cuerpo(14, .medium))
                                        }
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(Theme.indigo, in: Capsule())
                                    }
                                    .buttonStyle(BotonPresionable())
                                }
                            } else {
                                Text("Máximo 2 fotos alcanzado")
                                    .font(Theme.cuerpo(12))
                                    .foregroundStyle(Theme.tintaTenue)
                            }
                            
                            if !imagenes.isEmpty {
                                HStack(spacing: 8) {
                                    ForEach(Array(imagenes.enumerated()), id: \.offset) { idx, data in
                                        if let uiImage = UIImage(data: data) {
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                
                                                Button {
                                                    imagenes.remove(at: idx)
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundStyle(Theme.tinta)
                                                        .font(.system(size: 20))
                                                }
                                                .offset(x: 6, y: -6)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 12) {
                            EtiquetaSeccion(texto: "¿Le gustó?")
                            HStack(spacing: 12) {
                                botonGusto(.leGusto, texto: "Le gustó")
                                botonGusto(.noLeGusto, texto: "No le gustó")
                            }
                        }
                    }
                    
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 10) {
                            EtiquetaSeccion(texto: "Nota")
                            TextField("Cantidad, reacción, cómo se lo tomó…", text: $comida.nota, axis: .vertical)
                                .font(Theme.cuerpo(15))
                                .lineLimit(2...5)
                        }
                    }
                    
                    Boton(titulo: "Guardar", color: Theme.menta) {
                        guardar()
                    }
                    
                    if !esNueva {
                        Button {
                            confirmarBorrado = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Theme.coral)
                                Text("Eliminar esta comida")
                                    .font(Theme.cuerpo(15, .medium))
                                    .foregroundStyle(Theme.coral)
                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Theme.coral.opacity(0.12))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Theme.margen)
            }
            .background(Theme.lienzo.ignoresSafeArea())
            .navigationTitle(esNueva ? "Nueva comida" : "Editar comida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        cerrar()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.tintaTenue)
                    }
                }
            }
            .onAppear {
                imagenes = comida.fotos
            }
            .onChange(of: fotosSeleccionadas) { _, nuevos in
                guard !nuevos.isEmpty else { return }
                Task {
                    for item in nuevos {
                        if imagenes.count >= 2 { break }
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            let resized = uiImage.resized(maxDimension: 800)
                            if let jpeg = resized.jpegData(compressionQuality: 0.6) {
                                imagenes.append(jpeg)
                            }
                        }
                    }
                    fotosSeleccionadas = []
                }
            }
            .onChange(of: fotoCamara) { _, nueva in
                guard let uiImage = nueva else { return }
                if imagenes.count < 2 {
                    let resized = uiImage.resized(maxDimension: 800)
                    if let jpeg = resized.jpegData(compressionQuality: 0.6) {
                        imagenes.append(jpeg)
                    }
                }
                fotoCamara = nil
            }
            .fullScreenCover(isPresented: $mostrarCamara) {
                SelectorCamara(imagen: $fotoCamara)
                    .ignoresSafeArea()
            }
            .alert("¿Eliminar esta comida?", isPresented: $confirmarBorrado) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    almacen.borrarComida(comida)
                    cerrar()
                }
            } message: {
                Text("Esta acción no se puede deshacer.")
            }
        }
    }
    
    // ← REDISEÑO ESTÉTICO con SF Symbols
    private func botonGusto(_ gusto: GustoComida, texto: String) -> some View {
        let activo = comida.gusto == gusto
        let color: Color = gusto == .leGusto ? Theme.menta : Theme.coral
        let simbolo = gusto == .leGusto ? "hand.thumbsup.fill" : "hand.thumbsdown.fill"
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                comida.gusto = activo ? nil : gusto
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(activo ? color.opacity(0.25) : Theme.lienzoAlto)
                        .frame(width: 56, height: 56)
                    Image(systemName: simbolo)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(activo ? color : Theme.tintaTenue)
                }
                
                Text(texto)
                    .font(Theme.cuerpo(12, activo ? .semibold : .regular))
                    .foregroundStyle(activo ? Theme.tinta : Theme.tintaTenue)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(activo ? color.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func guardar() {
        comida.fotos = imagenes
        almacen.guardarComida(comida)
        cerrar()
    }
}

// MARK: - Selector de cámara

struct SelectorCamara: UIViewControllerRepresentable {
    @Binding var imagen: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SelectorCamara
        
        init(_ parent: SelectorCamara) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.imagen = uiImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Extensión para redimensionar imágenes

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}