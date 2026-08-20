import SwiftUI

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

    private var decorativeFan: some View {
        let angle = FanSpinner.shared(for: "background-fan").advance(
            to: 0.2,   // slow, calm rotation (revolutions/s)
            at: Date()
        )
        return Image(systemName: "fanblades.fill")
            .font(.system(size: 400))
            .foregroundColor(.white)
            .opacity(0.10)
            .blur(radius: 24)
            .rotationEffect(.degrees(angle))
    }
}
