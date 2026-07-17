import SwiftUI
import FirebaseCore
import FirebaseAuth

// AppDelegate can be kept for other uses, but we move Firebase config to init()
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return true
    }
}

@main
struct XDREWiOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var authManager: AuthManager

    init() {
        // ✅ Configure Firebase FIRST
        if let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: plistPath) {
            if let bundleID = Bundle.main.bundleIdentifier {
                options.bundleID = bundleID
            }
            FirebaseApp.configure(options: options)
        } else {
            FirebaseApp.configure()
        }
        
        // ✅ Safely initialize AuthManager AFTER Firebase is configured
        _authManager = StateObject(wrappedValue: AuthManager.shared)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - Root Auth Coordinator
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            switch authManager.authState {
            case .loading:
                SplashView()

            case .signedOut:
                LoginView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))

            case .signedIn:
                MainCoordinatorView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: authManager.isSignedIn)
    }
}

// MARK: - Splash Screen
struct SplashView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.45, green: 0.35, blue: 0.9), Color(red: 0.6, green: 0.4, blue: 1.0)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.3), radius: 20)

                Text("XDREW Chat")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                ProgressView()
                    .tint(.white.opacity(0.6))
                    .scaleEffect(0.8)
                    .padding(.top, 8)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }
}
