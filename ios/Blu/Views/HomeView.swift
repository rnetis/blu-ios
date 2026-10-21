import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var store: BluStore

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("خانه", systemImage: "house.fill") }
            TransactionsView()
                .tabItem { Label("تراکنش‌ها", systemImage: "list.bullet.rectangle") }
            CardsView()
                .tabItem { Label("کارت‌ها", systemImage: "creditcard.fill") }
            ProfileView()
                .tabItem { Label("پروفایل", systemImage: "person.crop.circle") }
        }
        .background(BluTheme.backgroundGradient.ignoresSafeArea())
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: BluStore
    @State private var showTransfer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    greetingRow
                    BalanceCard(account: store.selectedAccount,
                                total: store.totalBalance,
                                isDemo: store.isDemo)
                    accountsRow
                    quickActions
                    recentTransactions
                    if let message = store.errorMessage { ErrorBanner(text: message) }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(BluTheme.backgroundGradient.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .navigationDestination(isPresented: $showTransfer) { TransferView() }
            .refreshable { await store.loadAll() }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("بلو کلاینت").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                Task { await store.loadAll() }
            } label: {
                Image(systemName: "arrow.clockwise").foregroundColor(.bluAccent)
            }
        }
    }

    private var greetingRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.bluSurfaceHigh).frame(width: 46, height: 46)
                Text(initialLetter)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(store.profile?.fullName ?? "به بلو کلاینت خوش آمدید")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            if store.isDemo { PillBadge(text: "نمایشی", tint: .bluBlue) }
        }
        .padding(.top, 6)
    }

    private var initialLetter: String {
        let name = store.profile?.fullName ?? "B"
        return String(name.prefix(1))
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "صبح بخیر" }
        if hour < 18 { return "وقت بخیر" }
        return "شب بخیر"
    }

    private var accountsRow: some View {
        Group {
            if store.accounts.count > 1 {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "حساب‌ها و کیف پول‌ها")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(store.accounts) { account in
                                AccountChip(account: account,
                                            isSelected: account.id == store.selectedAccount?.id)
                                    .onTapGesture { store.selectedAccountId = account.id }
                            }
                        }
                    }
                }
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "دسترسی سریع")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                      spacing: 12) {
                QuickActionTile(icon: "arrow.left.arrow.right", title: "انتقال") { showTransfer = true }
                QuickActionTile(icon: "creditcard", title: "بلوکارت") {}
                QuickActionTile(icon: "doc.text", title: "قبض‌ها") {}
                QuickActionTile(icon: "antenna.radiowaves.left.and.right", title: "شارژ") {}
                QuickActionTile(icon: "chart.pie", title: "تحلیل") {}
                QuickActionTile(icon: "banknote", title: "واریز") {}
                QuickActionTile(icon: "gift", title: "جایزه") {}
                QuickActionTile(icon: "ellipsis", title: "بیشتر") {}
            }
        }
    }

    private var recentTransactions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "آخرین تراکنش‌ها")
            SurfaceCard(padding: 6) {
                VStack(spacing: 0) {
                    ForEach(Array(store.transactions.prefix(5).enumerated()), id: \.element.id) { pair in
                        TransactionRow(transaction: pair.element, showsDay: false)
                        if pair.offset < min(5, store.transactions.count) - 1 {
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 62)
                        }
                    }
                    if store.transactions.isEmpty {
                        emptyState
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray").font(.system(size: 22)).foregroundColor(.white.opacity(0.35))
            Text(store.isLoading ? "در حال دریافت اطلاعات…" : "تراکنشی برای نمایش نیست")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }
}
