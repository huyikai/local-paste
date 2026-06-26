import SwiftUI

struct ItemRowView: View {
    @EnvironmentObject var appState: AppState
    let item: ClipboardItem

    /// Look up the current item from appState so we always show fresh data.
    private var currentItem: ClipboardItem {
        appState.items.first(where: { $0.id == item.id }) ?? item
    }

    /// White or black based on color brightness, for readable text on color backgrounds.
    private var textColor: Color {
        guard let c = currentItem.displayColor else { return .primary }
        let l = c.redComponent * 0.299 + c.greenComponent * 0.587 + c.blueComponent * 0.114
        return l > 0.55 ? .black : .white
    }

    @State private var showPinPopover = false

    var body: some View {
        let item = currentItem
        let isSelected = appState.selectedItemIDs.contains(item.id)

        HStack(spacing: 10) {
            // App icon
            Group {
                if let icon = item.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 28, height: 28)
                        .cornerRadius(5)
                } else {
                    Image(systemName: item.contentTypeIcon)
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .frame(width: 28)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                if let image = item.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 44)
                        .cornerRadius(4)
                } else if let attr = item.attributedPreview {
                    Text(attr)
                        .lineLimit(2)
                        .font(.system(size: 14))
                } else {
                    Text(item.displayText)
                        .lineLimit(1)
                        .font(.system(size: 15))
                }

                HStack(spacing: 6) {
                    if let app = item.appName {
                        Text(app)
                            .font(.system(size: 11))
                    }
                    Text(item.timestamp, style: .time)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text(item.detailInfo)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    if let group = item.pinGroup {
                        Text(group)
                            .font(.system(size: 9))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                }
            }

            Spacer(minLength: 4)

            Button(action: { showPinPopover = true }) {
                Image(systemName: item.pinGroup != nil ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 13))
                    .foregroundColor(item.pinGroup != nil ? .accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPinPopover, arrowEdge: .trailing) {
                PinGroupPicker(item: item)
                    .environmentObject(appState)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 64)
        .background(
            Group {
                if let swatch = item.displayColor {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: swatch))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 5)
                .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .clear, radius: 3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .foregroundColor(currentItem.displayColor != nil ? textColor : .primary)
        .onTapGesture {
            appState.isSearchFocused = false
            let event = NSApp.currentEvent
            if event?.modifierFlags.contains(.command) == true {
                // Cmd+click: toggle multi-select
                if appState.selectedItemIDs.contains(item.id) {
                    appState.selectedItemIDs.remove(item.id)
                } else {
                    appState.selectedItemIDs.insert(item.id)
                }
            } else {
                // Normal click: single select
                appState.selectedItemID = item.id
                appState.selectedItemIDs = [item.id]
            }
        }
        .onTapGesture(count: 2) { appState.performPaste(item) }
        .contextMenu {
            Button(action: { appState.performPaste(item) }) {
                Label(loc("context.paste"), systemImage: "doc.on.clipboard")
            }
            if item.plainText != nil {
                Button(action: {
                    appState.performPasteAsPlainText(item)
                }) {
                    Label(loc("context.paste.plain"), systemImage: "text.alignleft")
                }
            }
            Button(action: { showPinPopover = true }) {
                Label(item.pinGroup != nil ? loc("context.change.group") : loc("context.pin.group"), systemImage: "bookmark")
            }
            if item.pinGroup != nil {
                Button(action: { appState.setPinGroup(for: item, group: nil) }) {
                    Label(loc("context.unpin"), systemImage: "bookmark.slash")
                }
            }
            Divider()
            Button(role: .destructive, action: { appState.deleteItem(item) }) {
                Label(loc("context.delete"), systemImage: "trash")
            }
        }
    }
}

/// Popover with pin group selection.
struct PinGroupPicker: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let item: ClipboardItem
    @State private var newGroupName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(loc("pin.popover.title"))
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            ForEach(appState.pinGroups, id: \.self) { group in
                HStack {
                    Button(action: {
                        appState.setPinGroup(for: item, group: group)
                        dismiss()
                    }) {
                        HStack {
                            Text(group)
                                .foregroundColor(.primary)
                            Spacer()
                            let current = appState.items.first(where: { $0.id == item.id })
                            if current?.pinGroup == group {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: { appState.deletePinGroup(group) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help(loc("delete.group"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            Divider()

            HStack {
                TextField(loc("pin.new.group"), text: $newGroupName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                Button(loc("pin.add")) {
                    let name = newGroupName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty, !appState.pinGroups.contains(name) else { return }
                    appState.pinGroups.append(name)
                    appState.setPinGroup(for: item, group: name)
                    newGroupName = ""
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .font(.system(size: 12))
                .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(8)
        }
        .frame(width: 200)
        .onAppear { appState.isPopoverOpen = true }
        .onDisappear { appState.isPopoverOpen = false }
    }
}
