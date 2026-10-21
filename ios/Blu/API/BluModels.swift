import Foundation

/// Response models mapped from the parsed protobuf tree by field number.
/// Field numbers come from the schema extracted out of the web client (docs/SCHEMA.md).

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

    var compact: String {
        let digits = raw.split(separator: ".").first.map(String.init) ?? raw
        guard let value = Double(digits) else { return display }
        return Persian.digits(Persian.grouped(Int(value)))
    }
}

struct BankAccount: Identifiable, Hashable {
    var id: String
    var number: String            // "611828005101688601"
    var iban: String?
    var title: String             // "بلو" / "کوتاهمدت"
    var subtitle: String          // owner or description
    var actualBalance: Money?
    var availableBalance: Money?
    var extraBalance: Money?
    var extraTitle: String?

    init(id: String, number: String, iban: String?, title: String, subtitle: String,
         actualBalance: Money?, availableBalance: Money?, extraBalance: Money?, extraTitle: String?) {
        self.id = id
        self.number = number
        self.iban = iban
        self.title = title
        self.subtitle = subtitle
        self.actualBalance = actualBalance
        self.availableBalance = availableBalance
        self.extraBalance = extraBalance
        self.extraTitle = extraTitle
    }

    var numberGrouped: String { Persian.groupNumber(number) }

    static func list(from response: PBMessage) -> [BankAccount] {
        response.messages(3).compactMap(BankAccount.init(pb:))
    }

    init?(pb: PBMessage) {
        guard let identifier = pb.message(1) else { return nil }
        number = identifier.string(1) ?? identifier.strings(1).first ?? "-"
        id = number
        iban = identifier.message(3)?.string(1)
        title = identifier.localizedLabel ?? identifier.string(15) ?? "حساب"
        subtitle = pb.message(10)?.localizedLabel ?? pb.string(15) ?? ""

        let amounts = pb.message(6)
        actualBalance = amounts?.message(1).flatMap(Money.init(pb:))
        availableBalance = amounts?.message(2).flatMap(Money.init(pb:))
        extraBalance = amounts?.message(4).flatMap(Money.init(pb:))
        extraTitle = "بلو باکس"
    }
}

struct BankTransaction: Identifiable, Hashable {
    var id: String
    var title: String            // counterparty / localized description
    var subtitle: String
    var category: String
    var iconName: String         // SF Symbol chosen from the merchant category
    var amount: Money?
    var isCredit: Bool
    var date: String             // server-localised Persian date
    var time: String
    var status: String
    var dayKey: String

    init(id: String, title: String, subtitle: String, category: String, iconName: String,
         amount: Money?, isCredit: Bool, date: String, time: String, status: String, dayKey: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.iconName = iconName
        self.amount = amount
        self.isCredit = isCredit
        self.date = date
        self.time = time
        self.status = status
        self.dayKey = dayKey
    }

    static func list(from response: PBMessage) -> [BankTransaction] {
        response.messages(3).compactMap(BankTransaction.init(pb:))
    }

    init?(pb: PBMessage) {
        id = pb.string(1) ?? UUID().uuidString
        let counterparty = pb.message(10)
        title = counterparty?.localizedLabel ?? pb.string(15) ?? pb.string(14) ?? "تراکنش"
        subtitle = pb.string(13) ?? pb.string(20) ?? pb.string(14) ?? ""

        let categoryMessage = pb.message(3)
        category = categoryMessage?.string(2) ?? pb.message(16)?.localizedLabel ?? "سایر"
        iconName = BankTransaction.icon(for: category)

        amount = pb.message(4)?.message(1).flatMap(Money.init(pb:))
        let rawValue = Double(amount?.raw.split(separator: ".").first.map(String.init) ?? "0") ?? 0
        isCredit = rawValue >= 0

        let dates = pb.message(5)
        let posted = dates?.message(1)
        date = posted?.localizedLabel ?? "—"
        dayKey = posted?.descendantString(14) ?? date
        time = posted?.descendantString(12) ?? ""
        status = pb.message(7)?.localizedLabel ?? ""
    }

    static func icon(for category: String) -> String {
        let key = category.lowercased()
        if key.contains("خرید") || key.contains("فروشگاه") { return "cart.fill" }
        if key.contains("انتقال") || key.contains("کارت")     { return "arrow.left.arrow.right" }
        if key.contains("شارژ")                              { return "antenna.radiowaves.left.and.right" }
        if key.contains("قبض") || key.contains("عوارض")       { return "doc.text.fill" }
        if key.contains("حقوق") || key.contains("واریز")      { return "arrow.down.circle.fill" }
        if key.contains("ناموفق") || key.contains("لغو")      { return "xmark.circle.fill" }
        if key.contains("رستوران") || key.contains("کافه")    { return "cup.and.saucer.fill" }
        return "creditcard.fill"
    }
}

struct BankCard: Identifiable, Hashable {
    var id: String
    var number: String           // masked PAN pieces
    var holder: String
    var title: String
    var status: String
    var expiry: String
    var cvv2: String?

    init(id: String, number: String, holder: String, title: String, status: String,
         expiry: String, cvv2: String?) {
        self.id = id
        self.number = number
        self.holder = holder
        self.title = title
        self.status = status
        self.expiry = expiry
        self.cvv2 = cvv2
    }

    var last4: String { String(number.filter(\.isNumber).suffix(4)) }

    var masked: String {
        let digits = number.filter(\.isNumber)
        guard digits.count >= 8 else { return number }
        return Persian.digits(String(digits.prefix(4))) + " •••• •••• "
            + Persian.digits(String(digits.suffix(4)))
    }

    static func list(from response: PBMessage) -> [BankCard] {
        response.messages(3).compactMap(BankCard.init(pb:))
    }

    init?(pb: PBMessage) {
        id = pb.string(1) ?? UUID().uuidString
        let numberMessage = pb.message(2)
        number = numberMessage?.string(1) ?? numberMessage?.descendantString(1) ?? "-"
        holder = pb.message(3)?.localizedLabel ?? "-"
        title = pb.message(5)?.localizedLabel ?? "بلوکارت"
        status = pb.message(6)?.localizedLabel ?? ""
        expiry = pb.message(8)?.localizedLabel ?? ""
        cvv2 = pb.message(9)?.descendantString(1)
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
        let person = user.message(2) ?? response.message(3)
        let name = person?.descendantString(10) ?? user.descendantString(10) ?? ""
        return UserProfile(
            username: user.string(1) ?? "-",
            fullName: person?.localizedLabel ?? name,
            nationalCode: person?.descendantString(3) ?? user.string(2) ?? "-",
            phone: user.string(5) ?? user.descendantString(5) ?? "-",
            birthDate: person?.descendantString(4) ?? "—",
            address: person?.descendantString(11) ?? "—"
        )
    }
}
