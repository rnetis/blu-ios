import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var store: BluStore
    @State private var query = ""
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable {
        case all = "همه"
        case credit = "واریز"
        case debit = "برداشت"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summary
                    searchField
                    filterRow
                    grouped
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 26)
            }
            .scrollIndicators(.hidden)
            .background(BluTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("تراکنش‌ها")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await store.loadAll() }
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            StatTile(title: "تعداد", value: Persian.digits("\(filtered.count)"), icon: "number")
            StatTile(title: "مجموع واریز", value: creditTotal, icon: "arrow.down.circle")
            StatTile(title: "مجموع برداشت", value: debitTotal, icon: "arrow.up.circle")
        }
    }

    private var creditTotal: String {
        let sum = filtered.filter(\.isCredit).compactMap { numeric($0) }.reduce(0, +)
        return Persian.grouped(Int(abs(sum)))
    }

    private var debitTotal: String {
        let sum = filtered.filter { !$0.isCredit }.compactMap { numeric($0) }.reduce(0, +)
        return Persian.grouped(Int(abs(sum)))
    }

    private func numeric(_ transaction: BankTransaction) -> Double? {
        guard let raw = transaction.amount?.raw.split(separator: ".").first else { return nil }
        return Double(raw)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(.white.opacity(0.4))
            TextField("جست‌وجو در تراکنش‌ها", text: $query)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .autocorrectionDisabled(true)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.bluSurface)
        )
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases, id: \.self) { item in
                Button {
                    filter = item
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(filter == item ? .bluBackground : .white.opacity(0.75))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(filter == item ? Color.bluAccent : Color.bluSurface)
                        )
                }
            }
            Spacer()
        }
    }

    private var grouped: some View {
        VStack(spacing: 16) {
            ForEach(groups, id: \.key) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.key)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 4)
                    SurfaceCard(padding: 6) {
                        VStack(spacing: 0) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { pair in
                                TransactionRow(transaction: pair.element, showsDay: false)
                                if pair.offset < group.items.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.06))
                                        .padding(.leading, 62)
                                }
                            }
                        }
                    }
                }
            }
            if groups.isEmpty { empty }
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.3))
            Text(store.isLoading ? "در حال دریافت…" : "تراکنشی یافت نشد")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var filtered: [BankTransaction] {
        store.transactions.filter { transaction in
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .credit:
                matchesFilter = transaction.isCredit
            case .debit:
                matchesFilter = !transaction.isCredit
            }
            let matchesQuery = query.isEmpty
                || transaction.title.contains(query)
                || transaction.category.contains(query)
                || transaction.subtitle.contains(query)
            return matchesFilter && matchesQuery
        }
    }

    private struct Group {
        var key: String
        var items: [BankTransaction]
    }

    private var groups: [Group] {
        var order: [String] = []
        var buckets: [String: [BankTransaction]] = [:]
        for transaction in filtered {
            let key = transaction.dayKey
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(transaction)
        }
        return order.map { Group(key: $0, items: buckets[$0] ?? []) }
    }
}
