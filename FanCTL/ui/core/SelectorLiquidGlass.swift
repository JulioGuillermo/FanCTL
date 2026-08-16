import SwiftUI

/// Floating glass pill selector for the fan control mode.
///
/// The fan modes are laid out side by side (like a segmented control) inside a
/// capsule of standard material that floats over the background. The active
/// segment is a blue capsule that slides between segments with a spring
/// animation (matched geometry effect), mimicking the fluid motion of Liquid
/// Glass.
struct SelectorLiquidGlass: View {
    @Binding var mode: FanMode
    var onChange: (FanMode) -> Void = { _ in }

    // Namespace for the fluid sliding animation between segments
    @Namespace private var animacionLiquid

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FanMode.allCases, id: \.self) { candidate in
                let isActive = mode == candidate

                Button {
                    withAnimation(
                        .spring(
                            response: 0.35,
                            dampingFraction: 0.65,
                            blendDuration: 0
                        )
                    ) {
                        if !isActive {
                            onChange(candidate)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: candidate.iconName)
                        Text(candidate.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(
                        isActive ? .white : .white.opacity(0.6)
                    )
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .frame(minWidth: 90)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    if isActive {
                        Capsule()
                            .fill(Color.blue.opacity(0.85))
                            .matchedGeometryEffect(
                                id: "fondoFluido",
                                in: animacionLiquid
                            )
                    }
                }
            }
            
        }
        .padding(0)
        .glassEffect(
            .regular,
            in: Capsule()

        )
        .clipShape(Capsule())
    }
}
