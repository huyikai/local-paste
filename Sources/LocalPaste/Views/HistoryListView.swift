import SwiftUI

struct HistoryListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(selection: $appState.selectedItemIDs) {
            ForEach(appState.filteredItems) { item in
                ItemRowView(item: item)
                    .environmentObject(appState)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    .listRowSeparator(.hidden)
            }
            .onMove(perform: appState.moveItems)
        }
        .listStyle(.plain)
        .onChange(of: appState.selectedItemID) { newID in
            if let id = newID {
                appState.selectedItemIDs = [id]
            }
        }
    }
}
