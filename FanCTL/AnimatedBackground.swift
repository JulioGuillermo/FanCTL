import SwiftUI

/// Decorative animated background of the main window.
///
/// A rich, dark, energy backdrop: colored blobs drift slowly, a blurred fan
/// spins in the center, and soft smoke-like particles rise like wind. This
/// moving, varied content is what the Liquid Glass surfaces above refract,
/// making the glass effect actually visible. Pure decoration: it never
/// intercepts interaction.
struct AnimatedBackground: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    baseGradient

                    let w = geo.size.width
                    let h = geo.size.height

                    blob(
                        color: Color.blue.opacity(0.60),
                        size: min(w, h) * 0.60,
                        x: w * 0.22 + 110 * sin(t * 0.15),
                        y: h * 0.20 + 80 * cos(t * 0.12)
                    )
                    blob(
                        color: Color.purple.opacity(0.55),
                        size: min(w, h) * 0.68,
                        x: w * 0.80 + 120 * cos(t * 0.10),
                        y: h * 0.38 + 90 * sin(t * 0.16)
                    )
                    blob(
                        color: Color.teal.opacity(0.45),
                        size: min(w, h) * 0.52,
                        x: w * 0.50 + 110 * sin(t * 0.09 + 1.7),
                        y: h * 0.80 + 80 * cos(t * 0.13 + 0.9)
                    )

                    decorativeFan
                        .position(x: w * 0.5, y: h * 0.42)

                    SmokeParticles()
                        .frame(width: w, height: h)

                    // Soft vignette keeps text legible without flattening the
                    // refraction content underneath.
                    RadialGradient(
                        colors: [.black.opacity(0.0), .black.opacity(0.30)],
                        center: .center,
                        startRadius: 10,
                        endRadius: max(w, h) * 0.75
                    )
                }
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }

    private var baseGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.08, blue: 0.15),
                Color(red: 0.10, green: 0.12, blue: 0.22),
                Color(red: 0.05, green: 0.06, blue: 0.13)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func blob(color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 90)
            .position(x: x, y: y)
    }

    /// Big blurred fan that spins continuously with the shared accumulated
    /// angle (same continuity model as the small menu bar icon).
    private var decorativeFan: some View {
        let angle = FanSpinner.shared(for: "background-fan").advance(
            to: 0.2,   // slow, calm rotation (revolutions/s)
            at: Date()
        )
        return Image(systemName: "fanblades.fill")
            .font(.system(size: 280))
            .foregroundColor(.white)
            .opacity(0.10)
            .blur(radius: 24)
            .rotationEffect(.degrees(angle))
    }
}

/// Soft smoke/wind particles that rise from the bottom with a gentle sway,
/// giving the glass above moving content to refract.
private struct SmokeParticles: View {
    private let particleCount = 60
    private let palette: [Color] = [
        .white,
        Color(red: 0.45, green: 0.75, blue: 1.0),
        Color(red: 0.75, green: 0.55, blue: 1.0),
        Color(red: 0.45, green: 1.0, blue: 0.95)
    ]

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.addFilter(.blur(radius: 6))
                let w = size.width
                let h = size.height

                for i in 0..<particleCount {
                    let seed = Double(i) * 0.618033988749895
                    let lane = (seed * 7.0).truncatingRemainder(dividingBy: 1.0)
                    let speed = 0.015 + 0.025 * lane
                    let duration = 9.0 + 5.0 * ((seed * 13.0).truncatingRemainder(dividingBy: 1.0))
                    let progress = ((time * speed) + seed).truncatingRemainder(dividingBy: 1.0)

                    let xBase = ((seed * 31.7).truncatingRemainder(dividingBy: 1.0)) * w
                    let sway = sin(time * 0.5 + seed * 40.0) * w * 0.07
                    let x = xBase + sway

                    let y = h * (1 - progress) + duration * 0
                    let radius = 16.0 + 30.0 * ((seed * 9.0).truncatingRemainder(dividingBy: 1.0))

                    // Soft fade in at the bottom, fade out at the top.
                    let fade = sin(progress * .pi)
                    let color = palette[i % palette.count].opacity(0.10 * fade)

                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }
}
