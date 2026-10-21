import Foundation

/// Sample content for demo mode. Every value here is invented — the app never bundles real
/// account data, and the UI labels this mode explicitly.
enum DemoData {
    static let accounts: [BankAccount] = [
        BankAccount(id: "1", number: "611828005101688601", iban: "IR710560611828005101688601",
                    title: "حساب کوتاه‌مدت بلو", subtitle: "حساب اصلی",
                    actualBalance: Money(raw: "35263024", display: "۳۵٬۲۶۳٬۰۲۴ ریال"),
                    availableBalance: Money(raw: "35263024", display: "۳۵٬۲۶۳٬۰۲۴ ریال"),
                    extraBalance: Money(raw: "1140000", display: "۱٬۱۴۰٬۰۰۰ ریال"),
                    extraTitle: "بلوباکس"),
        BankAccount(id: "2", number: "611828005101688602", iban: nil,
                    title: "بلوباکس", subtitle: "پس‌انداز روزانه",
                    actualBalance: Money(raw: "8600000", display: "۸٬۶۰۰٬۰۰۰ ریال"),
                    availableBalance: nil, extraBalance: nil, extraTitle: nil),
        BankAccount(id: "3", number: "611828005101688603", iban: nil,
                    title: "کیف پول بلو", subtitle: "پرداخت‌های خرد",
                    actualBalance: Money(raw: "425000", display: "۴۲۵٬۰۰۰ ریال"),
                    availableBalance: nil, extraBalance: nil, extraTitle: nil)
    ]

    static let transactions: [BankTransaction] = [
        make(date: "امروز", time: "۱۴:۰۲", title: "فروشگاه افق کوروش", subtitle: "خرید روزانه",
             category: "خرید فروشگاهی", amount: "-۸۴۵٬۰۰۰"),
        make(date: "امروز", time: "۰۹:۱۵", title: "واریز حقوق", subtitle: "حقوق مهر",
             category: "واریز", amount: "+۴۸٬۰۰۰٬۰۰۰"),
        make(date: "دیروز", time: "۲۰:۴۴", title: "اسنپ", subtitle: "سفر درون‌شهری",
             category: "حمل و نقل", amount: "-۱۹۸٬۰۰۰", icon: "car.fill"),
        make(date: "دیروز", time: "۱۲:۳۰", title: "کافه لمیز", subtitle: "پرداخت کارتی",
             category: "رستوران و کافه", amount: "-۴۸۰٬۰۰۰"),
        make(date: "۲ روز پیش", time: "۱۸:۰۷", title: "انتقال به بلوباکس", subtitle: "پس‌انداز خودکار",
             category: "انتقال", amount: "-۵٬۰۰۰٬۰۰۰"),
        make(date: "۲ روز پیش", time: "۱۰:۱۲", title: "شارژ ایرانسل", subtitle: "بسته اینترنت",
             category: "شارژ", amount: "-۳۲۰٬۰۰۰"),
        make(date: "۳ روز پیش", time: "۱۶:۵۰", title: "قبض برق", subtitle: "پرداخت قبض",
             category: "قبض و عوارض", amount: "-۷۵۰٬۰۰۰"),
        make(date: "۳ روز پیش", time: "۰۸:۰۵", title: "عوارض آزادراه", subtitle: "پرداخت خودکار",
             category: "قبض و عوارض", amount: "-۶۵٬۰۰۰"),
        make(date: "۴ روز پیش", time: "۲۱:۳۴", title: "دیجی‌کالا", subtitle: "خرید آنلاین",
             category: "خرید فروشگاهی", amount: "-۲٬۳۵۰٬۰۰۰"),
        make(date: "۴ روز پیش", time: "۱۳:۲۲", title: "تاپ‌آپ بلوکارت", subtitle: "افزایش موجودی",
             category: "انتقال", amount: "+۳٬۰۰۰٬۰۰۰"),
        make(date: "۵ روز پیش", time: "۱۱:۱۱", title: "داروخانه هلال", subtitle: "خرید دارو",
             category: "سلامت", amount: "-۵۶۰٬۰۰۰", icon: "cross.case.fill"),
        make(date: "۵ روز پیش", time: "۰۷:۴۷", title: "بازگشت وجه", subtitle: "لغو خرید ناموفق",
             category: "بازگشت", amount: "+۱٬۲۰۰٬۰۰۰")
    ]

    static let cards: [BankCard] = [
        BankCard(id: "c1", number: "6104 3377 **** 6886", holder: "دارنده کارت",
                 title: "بلوکارت", status: "فعال", expiry: "۰۷/۲۸", cvv2: "***"),
        BankCard(id: "c2", number: "6104 3377 **** 1420", holder: "دارنده کارت",
                 title: "کارت مجازی", status: "فعال", expiry: "۰۹/۲۷", cvv2: "***")
    ]

    static let profile = UserProfile(username: "demo", fullName: "کاربر نمونه",
                                     nationalCode: "۰۰۰۰۰۰۰۰۰۰", phone: "۰۹۱۲***۶۷۸۹",
                                     birthDate: "۱ فروردین ۱۳۷۰",
                                     address: "تهران، خیابان نمونه، پلاک ۱")

    static let transferMethods = ["بلو به بلو", "کارت به کارت", "بین بانکی (ساتنا)", "پایا"]

    private static func make(date: String, time: String, title: String, subtitle: String,
                             category: String, amount: String, icon: String? = nil) -> BankTransaction {
        let negative = amount.hasPrefix("-")
        let clean = amount.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "-", with: "")
        return BankTransaction(id: UUID().uuidString,
                               title: title,
                               subtitle: subtitle,
                               category: category,
                               iconName: icon ?? BankTransaction.icon(for: category),
                               amount: Money(raw: clean, display: clean + " ریال"),
                               isCredit: !negative,
                               date: date,
                               time: time,
                               status: "موفق",
                               dayKey: date)
    }
}
