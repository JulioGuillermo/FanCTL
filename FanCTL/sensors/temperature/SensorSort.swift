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

/// List of sensors with checkboxes. In "Type" mode the sensors are grouped by
/// category in collapsible sections (expanded by default) whose header has a
/// checkbox to select/deselect the whole group. Other modes keep a flat list.
struct SensorSelectionList: View {
    let sensors: [SensorInfo]
    @Binding var sortMode: SensorSortMode
    let isSelected: (SensorInfo) -> Bool
    let onToggle: (SensorInfo) -> Void
    let onSetSelected: ([SensorInfo], Bool) -> Void

    @State private var expandedCategories: Set<String>

    init(sensors: [SensorInfo], sortMode: Binding<SensorSortMode>,
         isSelected: @escaping (SensorInfo) -> Bool,
         onToggle: @escaping (SensorInfo) -> Void,
         onSetSelected: @escaping ([SensorInfo], Bool) -> Void) {
        self.sensors = sensors
        self._sortMode = sortMode
        self.isSelected = isSelected
        self.onToggle = onToggle
        self.onSetSelected = onSetSelected
        _expandedCategories = State(initialValue: Set(sensors.map(\.category.rawValue)))
    }

    private var groups: [(category: SensorCategory, sensors: [SensorInfo])] {
        var result: [(SensorCategory, [SensorInfo])] = []
        for category in SensorCategory.allCases {
            let members = sensors.filter { $0.category == category }
            if !members.isEmpty {
                result.append((category, members))
            }
        }
        return result
    }

    var body: some View {
        if sortMode == .byType {
            groupedList
        } else {
            flatList
        }
    }

    private var flatList: some View {
        List(sortedSensors(sensors, by: sortMode), id: \.id) { sensor in
            SensorCheckRow(
                sensor: sensor,
                isSelected: isSelected(sensor),
                onToggle: { onToggle(sensor) }
            )
        }
        .listStyle(.plain)
    }

    private var groupedList: some View {
        List {
            ForEach(groups, id: \.category.rawValue) { group in
                Section {
                    if expandedCategories.contains(group.category.rawValue) {
                        ForEach(group.sensors) { sensor in
                            SensorCheckRow(
                                sensor: sensor,
                                isSelected: isSelected(sensor),
                                onToggle: { onToggle(sensor) }
                            )
                        }
                    }
                } header: {
                    GroupHeaderView(
                        category: group.category,
                        selectedCount: group.sensors.filter { isSelected($0) }.count,
                        totalCount: group.sensors.count,
                        isExpanded: expandedCategories.contains(group.category.rawValue),
                        onToggleExpansion: {
                            toggleExpansion(group.category.rawValue)
                        },
                        onToggleSelection: {
                            onSetSelected(group.sensors, group.sensors.filter { isSelected($0) }.count != group.sensors.count)
                        }
                    )
                }
            }
        }
        .listStyle(.plain)
    }

    private func toggleExpansion(_ category: String) {
        if expandedCategories.contains(category) {
            expandedCategories.remove(category)
        } else {
            expandedCategories.insert(category)
        }
    }
}

/// Header of a collapsible sensor group: chevron, group checkbox, icon and
/// a selection counter.
private struct GroupHeaderView: View {
    let category: SensorCategory
    let selectedCount: Int
    let totalCount: Int
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onToggleSelection: () -> Void

    private var isFullySelected: Bool { selectedCount == totalCount }
    private var isPartiallySelected: Bool { selectedCount > 0 && selectedCount < totalCount }

    private var selectionIcon: String {
        if isFullySelected { return "checkmark.square.fill" }
        if isPartiallySelected { return "minus.square.fill" }
        return "square"
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggleExpansion) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Button(action: onToggleSelection) {
                Image(systemName: selectionIcon)
                    .font(.title3)
                    .foregroundColor(isFullySelected ? .blue : (isPartiallySelected ? .blue : .secondary))
            }
            .buttonStyle(.plain)

            Image(systemName: category.iconName)
                .font(.body)
                .foregroundColor(.blue)

            Text(category.rawValue)
                .font(.caption)
                .bold()

            Spacer()

            Text("\(selectedCount)/\(totalCount)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { onToggleExpansion() }
        .padding(.vertical, 2)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
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
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
        .help(sensor.descriptionText)
        .padding(.vertical, 2)
    }
}
