import SwiftUI

@main
struct BluApp: App {
    /// Read from the bundle so the version shown in the UI cannot drift from project.yml.
    static var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    @StateObject private var store = BluStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(.bluAccent)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: BluStore

    var body: some View {
        ZStack {
            BluTheme.backgroundGradient.ignoresSafeArea()
            content
        }
        .task { await store.prepare() }
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .intro: IntroView()
        case .login: LoginView()
        case .otp:   OTPView()
        case .home:  MainTabView()
        }
    }
}

/// Launch / key-exchange screen.
struct IntroView: View {
    @EnvironmentObject private var store: BluStore

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            LogoMark(size: 96)
            Text("بلو کلاینت")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
            Text("کلاینت شخصی و غیررسمی")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .bluAccent))
                Text(store.statusLine.isEmpty ? "در حال آماده‌سازی…" : store.statusLine)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.65))
                Button("ورود در حالت نمایشی") { store.enterDemo() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.bluAccent)
            }
            .padding(.bottom, 40)
        }
        .padding(24)
    }
}

/// Custom-drawn brand mark — no bundled artwork, so nothing to license.
struct LogoMark: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(LinearGradient(colors: [.bluViolet, .bluBlue],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
            Text("B")
                .font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.bluViolet.opacity(0.5), radius: 22, y: 10)
    }
}
