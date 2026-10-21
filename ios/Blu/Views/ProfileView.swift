import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: BluStore
    @State private var showDiagnostics = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    identity
                    accountSummary
                    settings
                    diagnosticsSection
                    logoutButton
                    if let message = store.errorMessage { ErrorBanner(text: message) }
                    footnote
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .background(BluTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("پروفایل")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var identity: some View {
        SurfaceCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [.bluViolet, .bluBlue],
                                                 startPoint: .top, endPoint: .bottom))
                        .frame(width: 58, height: 58)
                    Text(initial)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.profile?.fullName ?? "کاربر")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(store.profile?.phone ?? "—")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .environment(\.layoutDirection, .leftToRight)
                }
                Spacer()
                if store.isDemo { PillBadge(text: "نمایشی", tint: .bluBlue) }
            }
        }
    }

    private var initial: String {
        String((store.profile?.fullName ?? "B").prefix(1))
    }

    private var accountSummary: some View {
        HStack(spacing: 12) {
            StatTile(title: "حساب", value: Persian.digits("\(store.accounts.count)"), icon: "banknote")
            StatTile(title: "کارت", value: Persian.digits("\(store.cards.count)"), icon: "creditcard")
            StatTile(title: "تراکنش", value: Persian.digits("\(store.transactions.count)"), icon: "list.bullet")
        }
    }

    private var settings: some View {
        SurfaceCard(padding: 6) {
            VStack(spacing: 0) {
                settingRow(icon: "person.text.rectangle", title: "اطلاعات هویتی",
                           value: store.profile?.nationalCode ?? "—")
                divider
                settingRow(icon: "calendar", title: "تاریخ تولد", value: store.profile?.birthDate ?? "—")
                divider
                settingRow(icon: "mappin.and.ellipse", title: "نشانی",
                           value: store.profile?.address ?? "—")
                divider
                settingRow(icon: "shield.lefthalf.filled", title: "امنیت",
                           value: store.isAuthenticated ? "نشست فعال" : "بدون نشست")
            }
        }
    }

    private func settingRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.bluAccent)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.85))
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.45))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 12)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1).padding(.leading, 48)
    }

    private var diagnosticsSection: some View {
        SurfaceCard(padding: 6) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showDiagnostics.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.bluAccent)
                            .frame(width: 24)
                        Text("گزارش فنی نشست")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.85))
                        Spacer()
                        Image(systemName: showDiagnostics ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.vertical, 13)
                    .padding(.horizontal, 12)
                }
                if showDiagnostics { diagnosticsBody }
            }
        }
    }

    private var diagnosticsBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(store.diagnostics.enumerated()), id: \.offset) { pair in
                Text(pair.element)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if store.diagnostics.isEmpty {
                Text("گزارشی ثبت نشده است.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
    }

    private var logoutButton: some View {
        Button {
            store.logout()
        } label: {
            Text(store.isDemo ? "خروج از حالت نمایشی" : "خروج از حساب")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.bluDebit)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.bluDebit.opacity(0.12))
                )
        }
    }

    private var footnote: some View {
        Text("کلاینت غیررسمی • نسخه \(BluApp.version)")
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.3))
            .padding(.top, 4)
    }
}
