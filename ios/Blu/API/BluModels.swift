import Foundation

/// Response models mapped from the parsed protobuf tree by field number. The paths below were
/// checked against real responses (docs/PROTOCOL.md, docs/SCHEMA.md):
///
///   AccountListAllResponse { 3: Account*, 6: Amount totalActual, 7: balances* }
///   Account { 1: AccountIdentifier, 3: type, 5: representations, 6: AccountAmounts,
///             7: dates, 10: ownerName, 15: localized }
///   Transaction { 1: id, 2: accountId, 3: category, 4: amounts, 5: dates, 6: type,
///                 7: status, 10: counterparty, 13: memo, 15: localized }
///   CardListAllResponse { 3: Card* }, Card { 1: id/pan, 2: CardNumber{1: pan, 2: bank}, 4: linkedAccount }

struct Money: Hashable {
    var raw: String        // machine value, e.g. "35263024.000000"
    var display: String    // server-localised, e.g. "۳۵٬۲۶۳٬۰۲۴ ریال"

    init(raw: String, display: String) {
        self.raw = raw
        self.display = display
    }

    /// `Amount { value: DecimalValue { rawValue(1), localizedDescription(15) }, localizedDescription(15) }`
    init?(pb: PBMessage) {
        guard let value = pb.message(1) else { return nil }
        let rawValue = value.string(1) ?? "0"
        self.init(raw: rawValue, display: value.localizedLabel ?? pb.localizedLabel ?? rawValue)
    }

    /// Digits only, in Latin form — used for arithmetic.
    var digits: String { raw.split(separator: ".").first.map(String.init) ?? raw }

    /// Persian-grouped amount without the currency word, falling back to the server string when the
    /// machine value is not a plain number (the API encodes some negatives as a nested variant).
    var compact: String {
        guard let value = Double(digits) else { return withoutCurrency }
        return Persian.digits(Persian.grouped(Int(value)))
    }

    var withoutCurrency: String { display.replacingOccurrences(of: " ریال", with: "") }
}

struct BankAccount: Identifiable, Hashable {
    var id: String
    var number: String            // "611828005101688601"
    var formatted: String?        // "IR - 71 0560 6118 2800 5101 6886 01"
    var localizedNumber: String?  // "۶۱۱۸۲۸۰۰۵۱۰۱۶۸۸۶۰۱"
    var title: String             // "حساب کوتاهمدت"
    var kind: String              // "کوتاهمدت"
    var subtitle: String          // owner name
    var actualBalance: Money?
    var availableBalance: Money?
    var holdingBalance: Money?

    init(id: String, number: String, formatted: String?, localizedNumber: String?, title: String,
         kind: String, subtitle: String, actualBalance: Money?, availableBalance: Money?,
         holdingBalance: Money?) {
        self.id = id
        self.number = number
        self.formatted = formatted
        self.localizedNumber = localizedNumber
        self.title = title
        self.kind = kind
        self.subtitle = subtitle
        self.actualBalance = actualBalance
        self.availableBalance = availableBalance
        self.holdingBalance = holdingBalance
    }

    var numberGrouped: String { localizedNumber ?? Persian.groupNumber(number) }

    static func list(from response: PBMessage) -> [BankAccount] {
        response.messages(3).compactMap(BankAccount.init(pb:))
    }

    static func total(from response: PBMessage) -> Money? {
        response.message(6).flatMap(Money.init(pb:))
    }

    init?(pb: PBMessage) {
        guard let identifier = pb.message(1) else { return nil }
        number = identifier.string(1) ?? "-"
        id = number
        formatted = identifier.string(14)
        localizedNumber = identifier.string(15)
        kind = pb.message(3)?.localizedLabel ?? ""
        title = pb.string(15) ?? (kind.isEmpty ? "حساب" : kind)
        subtitle = pb.message(10)?.localizedLabel ?? ""

        let amounts = pb.message(6)
        actualBalance = amounts?.message(1).flatMap(Money.init(pb:))
        availableBalance = amounts?.message(2).flatMap(Money.init(pb:))
        holdingBalance = amounts?.message(4).flatMap(Money.init(pb:))
    }
}

struct BankTransaction: Identifiable, Hashable {
    var id: String
    var title: String            // category, e.g. "خرید از فروشگاه"
    var subtitle: String         // counterparty / memo
    var category: String
    var iconName: String         // SF Symbol derived from the server's icon slug
    var amount: Money?
    var isCredit: Bool           // type(6) == 2 ("بستانکار")
    var date: String             // "۲۸ مهر ۱۴۰۵"
    var dayKey: String
    var time: String             // "۲۲:۳۰"
    var status: String

    init(id: String, title: String, subtitle: String, category: String, iconName: String,
         amount: Money?, isCredit: Bool, date: String, dayKey: String, time: String, status: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.iconName = iconName
        self.amount = amount
        self.isCredit = isCredit
        self.date = date
        self.dayKey = dayKey
        self.time = time
        self.status = status
    }

    static func list(from response: PBMessage) -> [BankTransaction] {
        response.messages(3).compactMap(BankTransaction.init(pb:))
    }

    init?(pb: PBMessage) {
        id = pb.string(1) ?? UUID().uuidString

        let categoryMessage = pb.message(3)
        category = categoryMessage?.string(2) ?? ""
        title = category.isEmpty ? "تراکنش" : category
        iconName = BankTransaction.icon(forSlug: BankTransaction.slug(from: categoryMessage?.message(1)))

        subtitle = pb.message(10)?.localizedLabel ?? pb.string(13) ?? pb.string(14) ?? ""

        amount = pb.message(4)?.message(1).flatMap(Money.init(pb:))
        isCredit = pb.message(6)?.int(1) == 2

        let posted = pb.message(5)?.message(1)
        let localizedDate = posted?.message(2)
        date = localizedDate?.string(2) ?? localizedDate?.string(1) ?? "—"
        dayKey = date
        time = posted?.message(3)?.string(1) ?? ""
        status = pb.message(7)?.localizedLabel ?? ""
    }

    /// The server ships an icon asset path such as
    /// `/images/transaction-icon/light-dark/payment-pos/svg/payment-pos.svg`; the slug names the
    /// transaction category, which is what turns into an SF Symbol.
    static func slug(from iconAsset: PBMessage?) -> String {
        guard let iconAsset else { return "" }
        for value in iconAsset.descendantStrings(3, maxDepth: 4) {
            guard let range = value.range(of: "transaction-icon/") else { continue }
            let rest = value[range.upperBound...]
            let parts = rest.split(separator: "/")
            if parts.count >= 2 { return String(parts[1]) }
        }
        return ""
    }

    static func icon(forSlug slug: String) -> String {
        switch slug {
        case "payment-pos":         return "cart.fill"
        case "remittance-transfer": return "arrow.left.arrow.right"
        case "deposit-transfer":    return "arrow.down.circle.fill"
        case "withdrawal":          return "arrow.up.circle.fill"
        case "bill":                return "doc.text.fill"
        case "topup", "top-up":     return "antenna.radiowaves.left.and.right"
        case "loan", "installment": return "calendar.badge.clock"
        case "cashback", "reward":  return "gift.fill"
        case "fee", "toll":         return "road.lanes"
        default:                    return "creditcard.fill"
        }
    }

    static func icon(for category: String) -> String {
        if category.contains("خرید") || category.contains("فروشگاه") { return "cart.fill" }
        if category.contains("انتقال") || category.contains("کارت")   { return "arrow.left.arrow.right" }
        if category.contains("شارژ")                                 { return "antenna.radiowaves.left.and.right" }
        if category.contains("قبض") || category.contains("عوارض")     { return "doc.text.fill" }
        if category.contains("دریافت") || category.contains("سپرده")  { return "arrow.down.circle.fill" }
        if category.contains("رستوران") || category.contains("کافه")  { return "cup.and.saucer.fill" }
        return "creditcard.fill"
    }
}

struct BankCard: Identifiable, Hashable {
    var id: String
    var pan: String              // full PAN as returned by the API
    var bankName: String
    var linkedAccount: String?
    var status: String

    init(id: String, pan: String, bankName: String, linkedAccount: String?, status: String) {
        self.id = id
        self.pan = pan
        self.bankName = bankName
        self.linkedAccount = linkedAccount
        self.status = status
    }

    var last4: String { String(pan.filter(\.isNumber).suffix(4)) }

    /// The app never displays the full PAN — a PIN-gated reveal belongs in the official app.
    var masked: String {
        let digits = pan.filter(\.isNumber)
        guard digits.count >= 8 else { return pan }
        return Persian.digits(String(digits.prefix(4))) + " •••• •••• "
            + Persian.digits(String(digits.suffix(4)))
    }

    static func list(from response: PBMessage) -> [BankCard] {
        response.messages(3).compactMap(BankCard.init(pb:))
    }

    init?(pb: PBMessage) {
        let number = pb.message(2)?.string(1) ?? pb.string(1)
        guard let number, !number.isEmpty else { return nil }
        pan = number
        id = pb.string(1) ?? number
        bankName = pb.message(2)?.message(2)?.localizedLabel ?? "کارت"
        linkedAccount = pb.message(4)?.message(1)?.string(1)
        status = pb.message(6)?.localizedLabel ?? ""
    }
}

struct UserProfile: Hashable {
    var username: String
    var fullName: String
    var nationalCode: String
    var phone: String
    var birthDate: String
    var address: String

    static func from(response: PBMessage) -> UserProfile? {
        guard let user = response.message(2) else { return nil }
        let person = response.message(3)
        return UserProfile(
            username: user.string(1) ?? "-",
            fullName: person?.localizedLabel ?? user.localizedLabel ?? user.string(1) ?? "کاربر",
            nationalCode: person?.descendantString(3) ?? user.descendantString(3) ?? "—",
            phone: user.string(5) ?? user.descendantString(5) ?? "—",
            birthDate: person?.descendantString(4) ?? "—",
            address: person?.descendantString(11) ?? "—"
        )
    }
}
