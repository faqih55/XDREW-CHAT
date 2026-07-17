import SwiftUI

// MARK: - App State Manager
class AppState: ObservableObject {
    @Published var currentScreen: Screen = .dashboard
    
    enum Screen {
        case dashboard
    }
}

struct MainCoordinatorView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch appState.currentScreen {
            case .dashboard:
                DashboardView()
                    .environmentObject(appState)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appState.currentScreen)
    }
}
