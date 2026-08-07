import SwiftUI

// MARK: - Formas base

struct FormaCorazon: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height

        var p = Path()

        p.move(to: CGPoint(x: w * 0.5, y: h * 0.98))

        p.addCurve(
            to: CGPoint(x: 0, y: h * 0.30),
            control1: CGPoint(x: w * 0.12, y: h * 0.80),
            control2: CGPoint(x: 0, y: h * 0.58)
        )

        p.addArc(
            center: CGPoint(x: w * 0.25, y: h * 0.30),
            radius: w * 0.25,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )

        p.addArc(
            center: CGPoint(x: w * 0.75, y: h * 0.30),
            radius: w * 0.25,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )

        p.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.98),
            control1: CGPoint(x: w, y: h * 0.58),
            control2: CGPoint(x: w * 0.88, y: h * 0.80)
        )

        p.closeSubpath()

        return p
    }
}

struct FormaHoja: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height

        var p = Path()

        p.move(to: CGPoint(x: w * 0.5, y: h * 0.03))
        p.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.97),
            control: CGPoint(x: w * 1.08, y: h * 0.40)
        )
        p.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.03),
            control: CGPoint(x: -w * 0.08, y: h * 0.60)
        )

        p.closeSubpath()

        return p
    }
}

struct FormaChevron: Shape {
    var derecha = true

    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height

        var p = Path()

        if derecha {
            p.move(to: CGPoint(x: w * 0.34, y: h * 0.16))
            p.addLine(to: CGPoint(x: w * 0.68, y: h * 0.50))
            p.addLine(to: CGPoint(x: w * 0.34, y: h * 0.84))
        } else {
            p.move(to: CGPoint(x: w * 0.66, y: h * 0.16))
            p.addLine(to: CGPoint(x: w * 0.32, y: h * 0.50))
            p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.84))
        }

        return p
    }
}

struct FormaCheck: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height

        var p = Path()

        p.move(to: CGPoint(x: w * 0.20, y: h * 0.53))
        p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.74))
        p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.28))

        return p
    }
}

struct FormaEstrella: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let rE = min(r.width, r.height) / 2
        let rI = rE * 0.44

        var p = Path()

        for i in 0..<10 {
            let radio = i.isMultiple(of: 2) ? rE : rI
            let ang: Double = Double(i) * Double.pi / 5 - Double.pi / 2

            let pt = CGPoint(
                x: c.x + radio * CGFloat(cos(ang)),
                y: c.y + radio * CGFloat(sin(ang))
            )

            if i == 0 {
                p.move(to: pt)
            } else {
                p.addLine(to: pt)
            }
        }

        p.closeSubpath()

        return p
    }
}

struct FormaTriangulo: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()

        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))

        p.closeSubpath()

        return p
    }
}

// MARK: - Set de iconos de Nubi

/// Iconografía propia de la app. Todo se dibuja sobre un lienzo de 24×24 y se
/// escala, así que un mismo símbolo funciona igual en la barra de pestañas,
/// dentro de una insignia o a 64 pt en una pantalla vacía.
///
/// No se usa ningún SF Symbol a propósito: el icono forma parte de la marca y,
/// además, así la app no se parece a las mil que usan `moon.stars.fill`.
struct Ilus: View {

    enum Simbolo {
        case nube, luna, sol, biberon, corazon, hoja
        case bascula, regla, jeringa, botiquin, calendario, cuaderno
        case candado, reloj, ondas, ajustes, estrella, lapiz, papelera
        case mas, cerrar, check, chevronDer, chevronIzq
    }

    let simbolo: Simbolo
    var tamano: CGFloat
    var color: Color

    init(
        _ simbolo: Simbolo,
        _ tamano: CGFloat = 24,
        color: Color = Theme.tinta
    ) {
        self.simbolo = simbolo
        self.tamano = tamano
        self.color = color
    }

    private let base: CGFloat = 24
    private var t: CGFloat { 1.9 }   // grosor de trazo en el lienzo base

    var body: some View {
        ZStack { dibujo }
            .frame(width: base, height: base)
            .foregroundStyle(color)
            .scaleEffect(tamano / base)
            .frame(width: tamano, height: tamano)
    }

    /// Se devuelve `AnyView` a propósito. Un `switch` de 24 casos dentro de un
    /// `@ViewBuilder` genera un árbol de condicionales anidados que dispara el
    /// tiempo de compilación; con `AnyView` el coste en tiempo de ejecución es
    /// irrelevante para un icono y el proyecto compila en segundos.
    private var dibujo: AnyView {
        switch simbolo {
        case .nube:
            return AnyView(nube)

        case .luna:
            return AnyView(luna)

        case .sol:
            return AnyView(sol)

        case .biberon:
            return AnyView(biberon)

        case .corazon:
            return AnyView(FormaCorazon().frame(width: 20, height: 18))

        case .hoja:
            return AnyView(hoja)

        case .bascula:
            return AnyView(bascula)

        case .regla:
            return AnyView(regla)

        case .jeringa:
            return AnyView(jeringa)

        case .botiquin:
            return AnyView(botiquin)

        case .calendario:
            return AnyView(calendario)

        case .cuaderno:
            return AnyView(cuaderno)

        case .candado:
            return AnyView(candado)

        case .reloj:
            return AnyView(reloj)

        case .ondas:
            return AnyView(ondas)

        case .ajustes:
            return AnyView(ajustes)

        case .estrella:
            return AnyView(FormaEstrella().frame(width: 21, height: 21))

        case .lapiz:
            return AnyView(lapiz)

        case .papelera:
            return AnyView(papelera)

        case .mas:
            return AnyView(mas)

        case .cerrar:
            return AnyView(cerrar)

        case .check:
            return AnyView(
                FormaCheck()
                    .stroke(
                        style: StrokeStyle(
                            lineWidth: t + 0.4,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .frame(width: 20, height: 20)
            )

        case .chevronDer:
            return AnyView(
                FormaChevron(derecha: true)
                    .stroke(
                        style: StrokeStyle(
                            lineWidth: t,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .frame(width: 16, height: 16)
            )

        case .chevronIzq:
            return AnyView(
                FormaChevron(derecha: false)
                    .stroke(
                        style: StrokeStyle(
                            lineWidth: t,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .frame(width: 16, height: 16)
            )
        }
    }

    // MARK: Sueño y ritmo del día

    private var nube: some View {
        ZStack {
            Circle().frame(width: 11, height: 11).offset(x: -5, y: 1)
            Circle().frame(width: 14, height: 14).offset(x: 1, y: -1.5)
            Circle().frame(width: 10, height: 10).offset(x: 6.5, y: 1)
            Capsule().frame(width: 21, height: 9).offset(x: 0.5, y: 3.5)
        }
        .compositingGroup()
    }

    private var luna: some View {
        Circle()
            .frame(width: 19, height: 19)
            .overlay(
                Circle()
                    .frame(width: 16, height: 16)
                    .offset(x: 6, y: -4.5)
                    .blendMode(.destinationOut)
            )
            .compositingGroup()
            .rotationEffect(.degrees(-12))
    }

    private var sol: some View {
        ZStack {
            Circle().frame(width: 11, height: 11)

            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .frame(width: 2.2, height: 4)
                    .offset(y: -9.5)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
    }

    // MARK: Cuidados

    private var biberon: some View {
        ZStack {
            Capsule().frame(width: 4.4, height: 4.5).offset(y: -9.3)
            RoundedRectangle(cornerRadius: 1.4, style: .continuous).frame(width: 9.5, height: 3).offset(y: -6.2)
            RoundedRectangle(cornerRadius: 4.5, style: .continuous).frame(width: 12.5, height: 15).offset(y: 3)
            Capsule().frame(width: 4.5, height: 1.5).offset(x: -1.2, y: 0).blendMode(.destinationOut)
            Capsule().frame(width: 4.5, height: 1.5).offset(x: -1.2, y: 3.6).blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    private var hoja: some View {
        ZStack {
            FormaHoja().frame(width: 18, height: 21)
            Capsule().frame(width: 1.4, height: 14).offset(y: 0.5).blendMode(.destinationOut)
        }
        .compositingGroup()
        .rotationEffect(.degrees(-10))
    }

    // MARK: Crecimiento

    private var bascula: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                .strokeBorder(lineWidth: t)
                .frame(width: 19, height: 19)

            Circle()
                .strokeBorder(lineWidth: t)
                .frame(width: 9.5, height: 9.5)
                .offset(y: 1.5)

            Capsule()
                .frame(width: 1.7, height: 5)
                .offset(y: -1)
                .rotationEffect(.degrees(32))
        }
    }

    private var regla: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .strokeBorder(lineWidth: t)
                .frame(width: 10, height: 21)

            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .frame(width: i.isMultiple(of: 2) ? 5.5 : 3, height: 1.6)
                    .offset(x: i.isMultiple(of: 2) ? -2 : -3.2, y: -6.5 + CGFloat(i) * 4.3)
            }
        }
    }

    private var ondas: some View {
        HStack(alignment: .bottom, spacing: 3.4) {
            Capsule().frame(width: 4.2, height: 9)
            Capsule().frame(width: 4.2, height: 18)
            Capsule().frame(width: 4.2, height: 13)
        }
    }

    // MARK: Salud

    private var jeringa: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2, style: .continuous).frame(width: 8, height: 12.5).offset(y: 1)
            Capsule().frame(width: 11.5, height: 2.4).offset(y: -4.2)
            Capsule().frame(width: 2.6, height: 4).offset(y: -7.4)
            Capsule().frame(width: 2, height: 6).offset(y: 9.5)
            Capsule().frame(width: 5, height: 1.3).offset(x: 0, y: -0.5).blendMode(.destinationOut)
        }
        .compositingGroup()
        .rotationEffect(.degrees(-38))
    }

    private var botiquin: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous).frame(width: 21, height: 15).offset(y: 2.5)

            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .strokeBorder(lineWidth: t)
                .frame(width: 9.5, height: 6)
                .offset(y: -7)

            Capsule().frame(width: 7.5, height: 2.5).offset(y: 2.5).blendMode(.destinationOut)
            Capsule().frame(width: 2.5, height: 7.5).offset(y: 2.5).blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    private var calendario: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(lineWidth: t)
                .frame(width: 19, height: 18)
                .offset(y: 2)

            Capsule().frame(width: 19, height: t).offset(y: -2.6)
            Capsule().frame(width: 2.2, height: 5.5).offset(x: -5, y: -8.6)
            Capsule().frame(width: 2.2, height: 5.5).offset(x: 5, y: -8.6)

            HStack(spacing: 3.2) {
                Circle().frame(width: 2.7, height: 2.7)
                Circle().frame(width: 2.7, height: 2.7)
                Circle().frame(width: 2.7, height: 2.7)
            }
            .offset(y: 4.5)
        }
    }

    // MARK: Diario y utilidades

    private var cuaderno: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(lineWidth: t)
                .frame(width: 16.5, height: 20)
                .offset(x: 2)

            Capsule().frame(width: 3, height: 20).offset(x: -7.5)
            Capsule().frame(width: 8.5, height: 1.8).offset(x: 1.5, y: -4)
            Capsule().frame(width: 8.5, height: 1.8).offset(x: 1.5, y: 0)
            Capsule().frame(width: 5.5, height: 1.8).offset(x: 0, y: 4)
        }
    }

    private var candado: some View {
        ZStack {
            Circle()
                .trim(from: 0.5, to: 1.0)
                .stroke(style: StrokeStyle(lineWidth: t, lineCap: .round))
                .frame(width: 11, height: 11)
                .offset(y: -5)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .frame(width: 17, height: 13)
                .offset(y: 4)
        }
    }

    private var reloj: some View {
        ZStack {
            Circle()
                .strokeBorder(lineWidth: t)
                .frame(width: 19, height: 19)

            Capsule().frame(width: t, height: 6).offset(y: -3)

            Capsule()
                .frame(width: t, height: 4.6)
                .offset(y: -2.3)
                .rotationEffect(.degrees(115))
        }
    }

    private var ajustes: some View {
        ZStack {
            Group {
                Capsule().frame(width: 19, height: t).offset(y: -6)
                Capsule().frame(width: 19, height: t).offset(y: 0)
                Capsule().frame(width: 19, height: t).offset(y: 6)
            }

            Circle().frame(width: 6.5, height: 6.5).offset(x: -3.5, y: -6)
            Circle().frame(width: 6.5, height: 6.5).offset(x: 4, y: 0)
            Circle().frame(width: 6.5, height: 6.5).offset(x: -1, y: 6)

            Group {
                Circle().frame(width: 2.6, height: 2.6).offset(x: -3.5, y: -6)
                Circle().frame(width: 2.6, height: 2.6).offset(x: 4, y: 0)
                Circle().frame(width: 2.6, height: 2.6).offset(x: -1, y: 6)
            }
            .blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    private var lapiz: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .frame(width: 6, height: 14)
                .offset(y: -2)

            FormaTriangulo()
                .frame(width: 6, height: 5)
                .rotationEffect(.degrees(180))
                .offset(y: 7.5)

            Capsule()
                .frame(width: 6, height: 1.4)
                .offset(y: 4.6)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .rotationEffect(.degrees(45))
    }

    private var papelera: some View {
        ZStack {
            Capsule().frame(width: 17, height: t).offset(y: -7)
            Capsule().frame(width: 7, height: t).offset(y: -9.5)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(lineWidth: t)
                .frame(width: 13, height: 15)
                .offset(y: 2.5)
        }
    }

    private var mas: some View {
        ZStack {
            Capsule().frame(width: 15, height: t + 0.3)
            Capsule().frame(width: t + 0.3, height: 15)
        }
    }

    private var cerrar: some View {
        ZStack {
            Capsule().frame(width: 15, height: t).rotationEffect(.degrees(45))
            Capsule().frame(width: 15, height: t).rotationEffect(.degrees(-45))
        }
    }
}