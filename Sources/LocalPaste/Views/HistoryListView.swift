import SwiftUI

struct HistoryListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(appState.filteredItems) { item in
                        ItemRowView(item: item)
                            .environmentObject(appState)
                            .id(item.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: appState.selectedItemID) { newID in
                guard let id = newID else { return }
                withAnimation {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }
}
