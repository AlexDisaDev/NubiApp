import SwiftUI

enum Theme {
    // MARK: Fondos (adaptativos light/dark)
    static let lienzo     = Color(light: 0xF7F4FB, dark: 0x161423)
    static let lienzoAlto = Color(light: 0xFBF9FE, dark: 0x1C1A2B)
    static let superficie = Color(light: 0xFFFFFF, dark: 0x252236)
    
    // MARK: Tintas de texto (adaptativas)
    static let tinta      = Color(light: 0x3D3450, dark: 0xF0E8FF)
    static let tintaSuave = Color(light: 0x6B6282, dark: 0xC8BEE0)
    static let tintaTenue = Color(light: 0xA49BB5, dark: 0x7A7190)
    static let separador  = Color(light: 0xE8E3F0, dark: 0x3A3550)
    
    // MARK: Colores de acento (adaptativos)
    static let lila        = Color(light: 0xC9B8E8, dark: 0xA895D4)
    static let menta       = Color(light: 0xA8DCCB, dark: 0x7BC4A8)
    static let melocoton   = Color(light: 0xF7C9B5, dark: 0xE5A88E)
    static let mantequilla = Color(light: 0xF5E1A4, dark: 0xE5CB7A)
    static let cielo       = Color(light: 0xB7D4EF, dark: 0x8BB8DE)
    static let rosa        = Color(light: 0xEFC0D4, dark: 0xD99CB5)
    static let indigo      = Color(light: 0x6E63A6, dark: 0x9B8FD4)
    static let coral       = Color(light: 0xE88B7B, dark: 0xD46B5A)   // ← NUEVO: rojo pastel para despertares
    
    // MARK: Sombras (adaptativas)
    static let sombra       = Color(light: 0x000000, dark: 0x000000, lightOpacity: 0.08, darkOpacity: 0.40)
    static let sombraFuerte = Color(light: 0x000000, dark: 0x000000, lightOpacity: 0.15, darkOpacity: 0.60)
    
    // MARK: Tipografía
    static func display(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    
    static func cuerpo(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    
    static let etiqueta = Font.system(size: 11, weight: .semibold, design: .rounded)
    
    // MARK: Geometría
    static let radio: CGFloat = 22
    static let radioChico: CGFloat = 14
    static let margen: CGFloat = 20
    static let huecoBarra: CGFloat = 12
}

extension Color {
    /// Crea un color a partir de un valor hexadecimal.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: 1
        )
    }
    
    /// Crea un color adaptativo light/dark a partir de dos hex.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(Color(hex: dark))
            default:
                return UIColor(Color(hex: light))
            }
        })
    }
    
    /// Crea un color adaptativo light/dark con opacidades diferentes.
    init(light: UInt32, dark: UInt32, lightOpacity: Double, darkOpacity: Double) {
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(Color(hex: dark)).withAlphaComponent(CGFloat(darkOpacity))
            default:
                return UIColor(Color(hex: light)).withAlphaComponent(CGFloat(lightOpacity))
            }
        })
    }
}