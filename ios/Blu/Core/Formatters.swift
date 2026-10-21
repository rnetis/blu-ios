import Foundation
import SwiftUI

/// Persian number/date helpers. Amounts and dates arrive from the server already localised, so
/// these are for values the app computes itself (grouping, relative day headers, timers).
enum Persian {
    static let digitsTable = Array("۰۱۲۳۴۵۶۷۸۹")

    static func digits(_ text: String) -> String {
        var out = String()
        for character in text {
            if let value = character.wholeNumberValue, (0...9).contains(value) {
                out.append(digitsTable[value])
            } else {
                out.append(character)
            }
        }
        return out
    }

    static func grouped(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "٬"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// "611828005101688601" -> "۶۱۱۸ ۲۸۰۰ ۵۱۰۱ ۶۸۸۶ ۰۱"
    static func groupNumber(_ number: String) -> String {
        let digitsOnly = number.filter(\.isNumber)
        guard digitsOnly.count > 6 else { return digits(number) }
        var chunks: [String] = []
        var remaining = Array(digitsOnly)
        let firstCount = remaining.count % 4 == 0 ? 4 : remaining.count % 4
        chunks.append(String(remaining.prefix(firstCount)))
        remaining.removeFirst(firstCount)
        while !remaining.isEmpty {
            chunks.append(String(remaining.prefix(4)))
            remaining.removeFirst(min(4, remaining.count))
        }
        return Persian.digits(chunks.joined(separator: " "))
    }

    static func secondsLabel(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let rest = seconds % 60
        return Persian.digits(String(format: "%02d:%02d", minutes, rest))
    }
}

extension Color {
    static let bluBackground = Color(red: 0.043, green: 0.058, blue: 0.098)
    static let bluSurface = Color(red: 0.086, green: 0.110, blue: 0.169)
    static let bluSurfaceHigh = Color(red: 0.129, green: 0.161, blue: 0.235)
    static let bluAccent = Color(red: 0.0, green: 0.83, blue: 0.67)
    static let bluViolet = Color(red: 0.45, green: 0.36, blue: 0.95)
    static let bluBlue = Color(red: 0.16, green: 0.44, blue: 0.98)
    static let bluCredit = Color(red: 0.24, green: 0.85, blue: 0.60)
    static let bluDebit = Color(red: 0.98, green: 0.45, blue: 0.53)
}

enum BluTheme {
    static let cardRadius: CGFloat = 22
    static let tileRadius: CGFloat = 18

    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [Color.bluBackground, Color(red: 0.06, green: 0.09, blue: 0.18)],
                       startPoint: .top, endPoint: .bottom)
    }

    static var balanceGradient: LinearGradient {
        LinearGradient(colors: [Color.bluViolet, Color.bluBlue],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var cardGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.05, green: 0.13, blue: 0.24), Color.bluSurfaceHigh],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: BluTheme.cardRadius, style: .continuous)
                    .fill(Color.bluSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: BluTheme.cardRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
    }
}

struct SectionHeader: View {
    let title: String
    var action: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
            if let action {
                Button(action: { onAction?() }) {
                    Text(action).font(.system(size: 13)).foregroundColor(.bluAccent)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

struct PillBadge: View {
    let text: String
    var tint: Color = .bluAccent

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.16)))
    }
}
