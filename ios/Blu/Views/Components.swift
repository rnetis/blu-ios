import SwiftUI

/// Gradient balance card with the account identity and the two balances the API reports.
struct BalanceCard: View {
    let account: BankAccount?
    let total: Money?
    let isDemo: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            topRow
            amountBlock
            bottomRow
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(BluTheme.balanceGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: Color.bluViolet.opacity(0.35), radius: 20, y: 12)
    }

    private var topRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(account?.title ?? "حساب اصلی")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                Text(account?.numberGrouped ?? "—")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Image(systemName: "wave.3.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("موجودی قابل استفاده")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.65))
            Text(mainAmount)
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    private var mainAmount: String {
        let money = account?.availableBalance ?? account?.actualBalance ?? total
        guard let money else { return "—" }
        return money.display.replacingOccurrences(of: " ریال", with: "") + " ریال"
    }

    private var bottomRow: some View {
        HStack(spacing: 18) {
            stat(title: "مبلغ بلوکه", value: account?.holdingBalance?.display ?? "۰ ریال")
            if isDemo { PillBadge(text: "داده نمایشی", tint: .white) }
            Spacer()
        }
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
        }
    }
}

struct AccountChip: View {
    let account: BankAccount
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(account.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            Text(account.actualBalance?.compact ?? "—")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 148, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BluTheme.tileRadius, style: .continuous)
                .fill(isSelected ? Color.bluSurfaceHigh : Color.bluSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: BluTheme.tileRadius, style: .continuous)
                        .stroke(isSelected ? Color.bluAccent.opacity(0.7) : Color.white.opacity(0.06),
                                lineWidth: 1)
                )
        )
    }
}

struct QuickActionTile: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.bluSurfaceHigh)
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.bluAccent)
                }
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct TransactionRow: View {
    let transaction: BankTransaction
    var showsDay = true

    var body: some View {
        HStack(spacing: 12) {
            icon
            middle
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill((transaction.isCredit ? Color.bluCredit : Color.bluDebit).opacity(0.14))
                .frame(width: 40, height: 40)
            Image(systemName: transaction.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(transaction.isCredit ? .bluCredit : .bluDebit)
        }
    }

    private var middle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(transaction.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            Text(subtitleText)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
                .lineLimit(1)
        }
    }

    private var subtitleText: String {
        var parts: [String] = [transaction.category]
        if showsDay { parts.append(transaction.date) }
        if !transaction.time.isEmpty { parts.append(transaction.time) }
        return parts.joined(separator: " • ")
    }

    private var trailing: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(amountText)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(transaction.isCredit ? .bluCredit : .white)
            if !transaction.status.isEmpty {
                Text(transaction.status)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private var amountText: String {
        let display = transaction.amount?.display.replacingOccurrences(of: " ریال", with: "") ?? "—"
        return (transaction.isCredit ? "+" : "−") + display
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.bluAccent)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BluTheme.tileRadius, style: .continuous)
                .fill(Color.bluSurface)
        )
    }
}
