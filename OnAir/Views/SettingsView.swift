import SwiftUI

struct SettingsView: View {

    @ObservedObject var appState: AppState
    @Binding var showSettings: Bool

    var body: some View {
        VStack {
            Text("Settings — coming next")
        }
        .frame(width: 320, height: 300)
    }
}
