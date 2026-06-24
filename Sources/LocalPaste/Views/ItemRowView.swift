import SwiftUI

struct ItemRowView: View {
    @EnvironmentObject var appState: AppState
    let item: ClipboardItem

    var body: some View {
        HStack(spacing: 10) {
            // App icon
            Group {
                if let icon = item.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .cornerRadius(4)
                } else {
                    Image(systemName: item.contentTypeIcon)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 18)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 3) {
                if let image = item.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 48)
                        .cornerRadius(4)
                } else if let attr = item.attributedPreview {
                    Text(attr)
                        .lineLimit(3)
                        .font(.system(size: 13))
                } else {
                    Text(item.displayText)
                        .lineLimit(2)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                }

                // Meta
                HStack(spacing: 6) {
                    if let app = item.appName {
                        Text(app)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Text(item.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.accentColor)
                    }
                }
            }

            Spacer(minLength: 4)

            Button(action: { appState.togglePin(for: item) }) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12))
                    .foregroundColor(item.isPinned ? .accentColor : .secondary.opacity(0.45))
            }
            .buttonStyle(.plain)
            .help(item.isPinned ? "Unpin" : "Pin")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(appState.selectedItemID == item.id
                      ? Color.accentColor.opacity(0.12)
                      : Color.clear)
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
        )
        .onTapGesture { appState.selectedItemID = item.id }
        .onTapGesture(count: 2) { appState.copyItemToPasteboard(item) }
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
