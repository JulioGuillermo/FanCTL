import SwiftUI

struct SelectorLiquidGlass: View {
    @Binding var mode: FanMode
    var onChange: (FanMode) -> Void = { _ in }
    @Namespace private var liquidAnimation

    var body: some View {
            HStack(spacing: 4) {
                ForEach(FanMode.allCases, id: \.self) { candidate in
                    let isActive = mode == candidate
                    
                    Button {
                        withAnimation(
                            .spring(
                                response: 0.35,
                                dampingFraction: 0.7,
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
                        }
                        .font(
                            .system(
                                size: 13,
                                weight: isActive ? .semibold : .regular
                            )
                        )
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background {
                        Group {
                            if isActive {
                                Capsule()
                                    .fill(.blue.opacity(0.85))
                                    .matchedGeometryEffect(
                                        id: "flowBG",
                                        in: liquidAnimation
                                    )
                            }
                        }
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }
}
