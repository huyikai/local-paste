import SwiftUI

struct HistoryListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: $appState.selectedItemIDs) {
                ForEach(appState.filteredItems) { item in
                    ItemRowView(item: item)
                        .id(item.id)
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        .listRowSeparator(.hidden)
                }
                .onMove(perform: appState.moveItems)
            }
            .listStyle(.plain)
            .environmentObject(appState)
            .onChange(of: appState.selectedItemID) { newID in
                guard let id = newID else { return }
                withAnimation {
                    proxy.scrollTo(id, anchor: .center)
                }
                appState.selectedItemIDs = [id]
            }
        }
    }
}
