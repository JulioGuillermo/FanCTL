import SwiftUI

/// Decorative animated background of the main window.
///
/// Soft colored blobs drift slowly behind the translucent panels and a large
/// blurred fan spins continuously in the center, giving the window a subtle
/// "liquid glass" motion. Pure decoration: it never intercepts interaction.
struct AnimatedBackground: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    let w = geo.size.width
                    let h = geo.size.height

                    blob(
                        color: Color.blue.opacity(0.45),
                        size: min(w, h) * 0.55,
                        x: w * 0.25 + 90 * sin(t * 0.15),
                        y: h * 0.22 + 70 * cos(t * 0.12)
                    )
                    blob(
                        color: Color.purple.opacity(0.40),
                        size: min(w, h) * 0.62,
                        x: w * 0.78 + 110 * cos(t * 0.10),
                        y: h * 0.40 + 80 * sin(t * 0.16)
                    )
                    blob(
                        color: Color.teal.opacity(0.35),
                        size: min(w, h) * 0.48,
                        x: w * 0.52 + 100 * sin(t * 0.09 + 1.7),
                        y: h * 0.78 + 70 * cos(t * 0.13 + 0.9)
                    )

                    decorativeFan
                        .position(x: w * 0.5, y: h * 0.45)
                }
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
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
            .opacity(0.09)
            .blur(radius: 24)
            .rotationEffect(.degrees(angle))
    }
}
