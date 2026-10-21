import SwiftUI

struct CardsView: View {
    @EnvironmentObject private var store: BluStore
    @State private var selected: BankCard?
    @State private var revealsPan = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    stack
                    detail
                    if store.cards.isEmpty { empty }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .background(BluTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("کارت‌ها")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var stack: some View {
        VStack(spacing: 14) {
            ForEach(store.cards) { card in
                CardVisual(card: card,
                           isSelected: card.id == (selected?.id ?? store.cards.first?.id),
                           revealsPan: revealsPan && card.id == (selected?.id ?? store.cards.first?.id))
                    .onTapGesture {
                        selected = card
                        withAnimation(.easeInOut(duration: 0.25)) { revealsPan.toggle() }
                    }
            }
        }
    }

    private var detail: some View {
        Group {
            if let card = selected ?? store.cards.first {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "اطلاعات کارت")
                        infoRow(title: "نوع کارت", value: card.title)
                        divider
                        infoRow(title: "وضعیت", value: card.status.isEmpty ? "—" : card.status)
                        divider
                        infoRow(title: "تاریخ انقضا", value: card.expiry)
                        divider
                        infoRow(title: "دارنده", value: card.holder)
                    }
                }
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 13)).foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundColor(.white)
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "creditcard")
                .font(.system(size: 26))
                .foregroundColor(.white.opacity(0.3))
            Text(store.isDemo ? "در حالت نمایشی کارتی ثبت نشده" : "کارتی برای نمایش نیست")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct CardVisual: View {
    let card: BankCard
    let isSelected: Bool
    let revealsPan: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            topRow
            numberRow
            bottomRow
        }
        .padding(20)
        .frame(height: 196)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BluTheme.cardGradient)
                .overlay(alignment: .topTrailing) { glow }
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(isSelected ? Color.bluAccent.opacity(0.8) : Color.white.opacity(0.08),
                                lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, y: 10)
    }

    private var topRow: some View {
        HStack {
            Text(card.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "wifi")
                .rotationEffect(.degrees(90))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var numberRow: some View {
        HStack(spacing: 12) {
            chip
            Text(revealsPan ? card.masked : maskAll)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .environment(\.layoutDirection, .leftToRight)
            Spacer()
        }
    }

    private var maskAll: String {
        let digits = card.number.filter(\.isNumber)
        let last4 = String(digits.suffix(4))
        return Persian.digits("•••• •••• •••• \(last4)")
    }

    private var chip: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                LinearGradient(colors: [Color(white: 0.85), Color(white: 0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(width: 38, height: 28)
            .overlay(chipLines)
    }

    private var chipLines: some View {
        VStack(spacing: 5) {
            Rectangle().fill(Color.black.opacity(0.18)).frame(height: 1)
            Rectangle().fill(Color.black.opacity(0.18)).frame(height: 1)
            Rectangle().fill(Color.black.opacity(0.18)).frame(height: 1)
        }
        .padding(.horizontal, 6)
    }

    private var bottomRow: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("دارنده کارت").font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
                Text(card.holder).font(.system(size: 12, weight: .medium)).foregroundColor(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("انقضا").font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
                Text(card.expiry.isEmpty ? "—" : card.expiry)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }

    private var glow: some View {
        Circle()
            .fill(Color.bluViolet.opacity(0.35))
            .frame(width: 150, height: 150)
            .blur(radius: 46)
            .offset(x: 40, y: -40)
            .clipped()
    }
}
