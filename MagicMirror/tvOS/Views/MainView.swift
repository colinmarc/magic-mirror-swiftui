import SwiftUI

enum Tabs {
    case browse
    case servers
}

struct MainView: View {
    @State private var selection: Tabs = .browse
    
    var body: some View {
        TabView(selection: $selection) {
            Tab("Applications", systemImage: "play.circle", value: .browse) {
                Text("browser view")
            }
            
            TabSection("Configuration") {
                Tab("Servers", systemImage: "play.circle", value: .servers) {
                    Text("browser view")
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    MainView()
}
