import SwiftUI

/// Sorting modes available for the sensor lists.
enum SensorSortMode: String, CaseIterable, Identifiable {
    case alphabetical
    case byType
    case hottest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .alphabetical: return "Alphabetical"
        case .byType: return "Type"
        case .hottest: return "Hottest"
        }
    }

    var iconName: String {
        switch self {
        case .alphabetical: return "textformat.abc"
        case .byType: return "square.grid.2x2"
        case .hottest: return "flame"
        }
    }
}

/// Applies a sort mode to a sensor list.
func sortedSensors(_ sensors: [SensorInfo], by mode: SensorSortMode) -> [SensorInfo] {
    switch mode {
    case .alphabetical:
        return sensors.sorted {
            $0.rawKey.localizedCaseInsensitiveCompare($1.rawKey) == .orderedAscending
        }
    case .byType:
        return sensors.sorted {
            if $0.category == $1.category {
                return $0.rawKey.localizedCaseInsensitiveCompare($1.rawKey) == .orderedAscending
            }
            return $0.category.rawValue < $1.category.rawValue
        }
    case .hottest:
        return sensors.sorted {
            if $0.value == $1.value {
                return $0.rawKey.localizedCaseInsensitiveCompare($1.rawKey) == .orderedAscending
            }
            return $0.value > $1.value
        }
    }
}

/// Compact menu to pick the sort order of a sensor list.
struct SensorSortMenu: View {
    @Binding var sortMode: SensorSortMode

    var body: some View {
        Picker("Sort", selection: $sortMode) {
            ForEach(SensorSortMode.allCases) { mode in
                Label(mode.label, systemImage: mode.iconName)
                    .tag(mode)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
        .help("Sort order")
    }
}

/// Row with checkbox + category icon for selecting sensors from a list.
struct SensorCheckRow: View {
    let sensor: SensorInfo
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: sensor.category.iconName)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 22)

            Text(sensor.rawKey)
                .font(.system(.body, design: .monospaced))
                .bold()
                .strikethrough(!isSelected, color: .secondary)

            Text(SensorDescriptions.shortName(for: sensor.rawKey))
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            Text(sensor.displayValue)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .help(sensor.descriptionText)
        .padding(.vertical, 2)
    }
}
