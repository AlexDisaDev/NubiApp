import Foundation
import AVFoundation
import SwiftUI
import ActivityKit // 1. Añadido el import necesario

@MainActor
final class ReproductorRuido: ObservableObject {
    static let compartido = ReproductorRuido()
    
    enum TipoRuido: String, CaseIterable, Identifiable {
        case blanco, rosa, marron
        var id: String { rawValue }
        var titulo: String {
            switch self {
            case .blanco: return "Ruido blanco"
            case .rosa:   return "Ruido rosa"
            case .marron: return "Ruido marrón"
            }
        }
        var subtitulo: String {
            switch self {
            case .blanco: return "Enmascara ruidos bruscos"
            case .rosa:   return "Suave, ideal para dormir"
            case .marron: return "Grave, como un ventilador"
            }
        }
        var color: Color {
            switch self {
            case .blanco: return Theme.indigo
            case .rosa:   return Theme.rosa
            case .marron: return Theme.melocoton
            }
        }
    }
    
    enum Duracion: String, CaseIterable, Identifiable {
        case media, unaHora, infinito
        var id: String { rawValue }
        var titulo: String {
            switch self {
            case .media:    return "30 min"
            case .unaHora:  return "1 h"
            case .infinito: return "Infinito"
            }
        }
        var segundos: TimeInterval? {
            switch self {
            case .media:    return 30 * 60
            case .unaHora:  return 60 * 60
            case .infinito: return nil
            }
        }
    }
    
    @Published private(set) var reproduciendo: Bool = false
    @Published var tipoSeleccionado: TipoRuido = .blanco
    @Published var duracionSeleccionada: Duracion = .infinito
    @Published private(set) var tiempoRestante: TimeInterval? = nil
    
    private var engine: AVAudioEngine?
    private var renderer: AudioRenderer?
    private var timerTask: Task<Void, Never>?
    
    private init() {
        configurarAudioSession()
    }
    
    private func configurarAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Error configurando AudioSession: \(error)")
        }
        #endif
    }
    
    func toggle() {
        if reproduciendo { detener() } else { iniciar() }
    }
    
    func iniciar() {
        if reproduciendo { detener() }
        configurarAudioSession()
        
        let engine = AVAudioEngine()
        let format = engine.outputNode.inputFormat(forBus: 0)
        
        let renderer = AudioRenderer(tipo: tipoSeleccionado)
        self.renderer = renderer
        
        let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            renderer.render(frameCount: Int(frameCount), audioBufferList: audioBufferList)
            return noErr
        }
        
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
            self.engine = engine
            reproduciendo = true
            
            if let segundos = duracionSeleccionada.segundos {
                tiempoRestante = segundos
                iniciarTimer()
            } else {
                tiempoRestante = nil
            }
            
            iniciarLiveActivity()
        } catch {
            print("No se pudo iniciar el motor de audio: \(error)")
        }
    }

    // 2. Eliminado el método duplicado. Solo dejamos este que llama a terminarLiveActivity()
    func detener() {
        engine?.stop()
        engine = nil
        renderer = nil
        timerTask?.cancel()
        timerTask = nil
        reproduciendo = false
        tiempoRestante = nil
        
        terminarLiveActivity()
    }
    
    private func iniciarTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, let restante = self.tiempoRestante else { break }
                if restante <= 1 {
                    await MainActor.run { self.detener() }
                    break
                } else {
                    await MainActor.run { 
                        self.tiempoRestante = restante - 1
                        self.actualizarLiveActivity()
                    }
                }
            }
        }
    }
    
    func cambiarTipo(_ tipo: TipoRuido) {
        tipoSeleccionado = tipo
        if reproduciendo { iniciar() }
    }
    
    func cambiarDuracion(_ duracion: Duracion) {
        duracionSeleccionada = duracion
        if reproduciendo {
            if let segundos = duracion.segundos {
                tiempoRestante = segundos
                iniciarTimer()
            } else {
                timerTask?.cancel()
                tiempoRestante = nil
            }
        }
    }

    // MARK: - Live Activity

    private var actividadActual: Activity<RuidoActivityAttributes>?

    private func iniciarLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if actividadActual != nil { terminarLiveActivity() }

        let attrs = RuidoActivityAttributes(titulo: "Sonidos para dormir")
        let state = RuidoActivityAttributes.ContentState(
            tipoNombre: tipoSeleccionado.titulo,
            inicio: .now,
            fechaFin: duracionSeleccionada.segundos.map { Date().addingTimeInterval($0) }
        )
        do {
            actividadActual = try Activity.request(
                attributes: attrs,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("No se pudo iniciar la Live Activity de ruido: \(error)")
        }
    }

    private func actualizarLiveActivity() {
        guard let actividad = actividadActual else { return }
        // 3. Corregido: 'activityState' no existe, la ruta correcta es 'content.state'
        let inicioOriginal = actividad.content.state.inicio 
        let state = RuidoActivityAttributes.ContentState(
            tipoNombre: tipoSeleccionado.titulo,
            inicio: inicioOriginal,
            fechaFin: duracionSeleccionada.segundos.map { Date().addingTimeInterval($0) }
        )
        Task {
            await actividad.update(.init(state: state, staleDate: nil))
        }
    }

    private func terminarLiveActivity() {
        guard let actividad = actividadActual else { return }
        actividadActual = nil
        Task {
            await actividad.end(nil, dismissalPolicy: .immediate)
        }
    }
}

// Clase auxiliar para generar el audio en el hilo de tiempo real sin bloqueos
final class AudioRenderer {
    var tipo: ReproductorRuido.TipoRuido
    var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
    var lastWhite: Float = 0
    
    init(tipo: ReproductorRuido.TipoRuido) { self.tipo = tipo }
    
    func render(frameCount: Int, audioBufferList: UnsafeMutablePointer<AudioBufferList>) {
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        
        for frame in 0..<frameCount {
            var value: Float = 0
            let white = Float.random(in: -1...1)
            
            switch tipo {
            case .blanco:
                value = white
                
            case .rosa: // Algoritmo de Paul Kellet
                b0 = 0.99886 * b0 + white * 0.0555179
                b1 = 0.99332 * b1 + white * 0.0750759
                b2 = 0.96900 * b2 + white * 0.1538520
                b3 = 0.86650 * b3 + white * 0.3104856
                b4 = 0.55000 * b4 + white * 0.5329522
                b5 = -0.7616 * b5 - white * 0.0168980
                let pink = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11
                b6 = white * 0.115926
                value = pink
                
            case .marron: // Integración de ruido blanco
                let brown = (lastWhite + (0.02 * white)) / 1.02
                lastWhite = brown
                value = brown * 3.5
            }
            
            for buffer in ablPointer {
                let ptr = buffer.mData?.assumingMemoryBound(to: Float.self)
                ptr?[frame] = value
            }
        }
    }
}

