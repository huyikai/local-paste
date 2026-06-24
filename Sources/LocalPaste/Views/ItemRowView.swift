import SwiftUI

struct ItemRowView: View {
    @EnvironmentObject var appState: AppState
    let item: ClipboardItem

    var body: some View {
        HStack(spacing: 8) {
            // App icon
            if let icon = item.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .cornerRadius(3)
            } else {
                Image(systemName: item.contentTypeIcon)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
            }

            // Preview
            VStack(alignment: .leading, spacing: 2) {
                if let image = item.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 60)
                        .cornerRadius(4)
                } else if let attr = item.attributedPreview {
                    Text(attr)
                        .lineLimit(3)
                        .font(.body)
                        .foregroundColor(.primary)
                } else {
                    Text(item.displayText)
                        .lineLimit(2)
                        .font(.body)
                        .foregroundColor(.primary)
                }

                HStack(spacing: 4) {
                    Text(item.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                }
            }

            Spacer()

            // Pin button
            Button(action: { appState.togglePin(for: item) }) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .foregroundColor(item.isPinned ? .accentColor : .secondary.opacity(0.3))
            }
            .buttonStyle(.plain)
            .help(item.isPinned ? "Unpin" : "Pin")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(appState.selectedItemID == item.id
                      ? Color.accentColor.opacity(0.15)
                      : Color.clear)
                .padding(2)
        )
        .onTapGesture {
            appState.selectedItemID = item.id
        }
        .onTapGesture(count: 2) {
            appState.copyItemToPasteboard(item)
        }
        .contextMenu {
            Button(action: { appState.copyItemToPasteboard(item) }) {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            if item.plainText != nil {
                Button(action: {
                    appState.selectedItemID = item.id
                    appState.pasteSelectedAsPlainText()
                }) {
                    Label("Paste as Plain Text", systemImage: "text.alignleft")
                }
            }
            Button(action: { appState.togglePin(for: item) }) {
                Label(item.isPinned ? "Unpin" : "Pin", systemImage: "pin")
            }
            Divider()
            Button(role: .destructive, action: { appState.deleteItem(item) }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
