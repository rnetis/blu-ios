import Foundation
import SwiftUI

/// Single source of truth for the UI. Two modes:
///  - **live**: talks to the openapi gateway through `BluClient` (needs the user's own credentials);
///  - **demo**: sample data baked into the app so the interface can be explored with no account.
@MainActor
final class BluStore: ObservableObject {
    enum Phase { case intro, login, otp, home }

    @Published var phase: Phase = .intro
    @Published var isDemo = false
    @Published var isLoading = false
    @Published var statusLine = ""
    @Published var errorMessage: String?

    @Published var accounts: [BankAccount] = []
    @Published var apiTotal: Money?
    @Published var transactions: [BankTransaction] = []
    @Published var cards: [BankCard] = []
    @Published var profile: UserProfile?
    @Published var selectedAccountId: String?
    @Published var transferMethods: [String] = []

    @Published var otpMaskedPhone = ""
    @Published var otpRequestId: String?
    @Published var otpChallenge: OTPChallenge?
    @Published var otpSecondsLeft = 0

    @Published var diagnostics: [String] = []

    private let client = BluClient()
    private var otpTimer: Timer?

    var selectedAccount: BankAccount? {
        accounts.first { $0.id == selectedAccountId } ?? accounts.first
    }

    var isAuthenticated: Bool { client.isAuthenticated }

    /// Total from the API when present, otherwise the first account's actual balance.
    var totalBalance: Money? { apiTotal ?? accounts.compactMap(\.actualBalance).first }

    // MARK: - Lifecycle

    func prepare() async {
        if isDemo { return }
        isLoading = true
        statusLine = "در حال تبادل کلید امن…"
        do {
            try await client.keyExchange()
            log("تبادل کلید انجام شد — keyId: \(client.keyId ?? "-")")
            phase = .login
        } catch {
            log("تبادل کلید ناموفق: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            phase = .login
        }
        isLoading = false
        statusLine = ""
    }

    func enterDemo() {
        isDemo = true
        accounts = DemoData.accounts
        transactions = DemoData.transactions
        cards = DemoData.cards
        profile = DemoData.profile
        transferMethods = DemoData.transferMethods
        selectedAccountId = accounts.first?.id
        phase = .home
        log("حالت نمایشی فعال شد (دادهها نمونه هستند)")
    }

    func cancelOTP() {
        stopOTPTimer()
        otpChallenge = nil
        otpRequestId = nil
        errorMessage = nil
        phase = .login
    }

    func logout() {
        stopOTPTimer()
        otpChallenge = nil
        otpRequestId = nil
        client.resetSession()
        accounts = []
        transactions = []
        cards = []
        profile = nil
        isDemo = false
        phase = .intro
        Task { await prepare() }
    }

    // MARK: - Auth

    func login(username: String, password: String) async {
        isLoading = true
        errorMessage = nil
        statusLine = "در حال ورود…"
        do {
            if !client.isKeyEstablished { try await client.keyExchange() }
            let outcome = try await client.login(username: username, password: password)
            switch outcome {
            case .otpRequested(let challenge):
                log("ورود پذیرفته شد — کد یک‌بارمصرف درخواست شد (\(challenge.requestId.prefix(8))…)")
                otpChallenge = challenge
                otpRequestId = challenge.requestId
                otpMaskedPhone = challenge.maskedPhone.isEmpty
                    ? maskedPhone(from: username)
                    : challenge.maskedPhone
                statusLine = "کد پیامک‌شده را وارد کنید"
                phase = .otp
                startOTPTimer()
            case .authenticated:
                log("ورود کامل شد — توکن دریافت شد")
                phase = .home
                await loadAll()
            }
        } catch {
            errorMessage = error.localizedDescription
            log("ورود ناموفق: \(error.localizedDescription)")
        }
        isLoading = false
        statusLine = ""
    }

    func verify(code: String) async {
        guard let challenge = otpChallenge else {
            errorMessage = "درخواست کد پیدا نشد؛ دوباره وارد شوید."
            phase = .login
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await client.verifyOTP(challenge: challenge, code: code)
            log("کد تأیید شد — نشست کامل شد")
            phase = .home
            stopOTPTimer()
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
            log("تأیید کد ناموفق: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func loadAll() async {
        guard !isDemo else { return }
        isLoading = true
        do {
            let accountsResponse = try await client.fetchAccounts()
            accounts = BankAccount.list(from: accountsResponse)
            apiTotal = BankAccount.total(from: accountsResponse)
            selectedAccountId = accounts.first?.id
            log("\(accounts.count) حساب دریافت شد")

            let profileResponse = try await client.fetchProfile()
            profile = UserProfile.from(response: profileResponse)
            log("پروفایل دریافت شد")

            if let selected = accounts.first {
                client.setProfile(id: profile?.username ?? "main", type: 1,
                                  accountNumber: selected.number, accountType: 41)
            }

            let txResponse = try await client.fetchTransactions()
            transactions = BankTransaction.list(from: txResponse)
            log("\(transactions.count) تراکنش دریافت شد")

            let cardResponse = try await client.fetchCards()
            cards = BankCard.list(from: cardResponse)
            log("\(cards.count) کارت دریافت شد")

            if let methods = try? await client.fetchTransferMethods() {
                transferMethods = methods.messages(2).compactMap { $0.localizedLabel }
            }
        } catch {
            errorMessage = error.localizedDescription
            log("بارگذاری داده ناموفق: \(error.localizedDescription)")
        }
        isLoading = false
    }

    // MARK: - Helpers

    private func maskedPhone(from username: String) -> String {
        let digits = username.filter(\.isNumber)
        guard digits.count >= 6 else { return username }
        let prefix = digits.prefix(4)
        let suffix = digits.suffix(2)
        return "\(Persian.digits(String(prefix)))***\(Persian.digits(String(suffix)))"
    }

    private func startOTPTimer() {
        stopOTPTimer()
        otpSecondsLeft = 90
        otpTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.otpSecondsLeft > 0 { self.otpSecondsLeft -= 1 } else { self.stopOTPTimer() }
            }
        }
    }

    private func stopOTPTimer() {
        otpTimer?.invalidate()
        otpTimer = nil
    }

    private func log(_ line: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        diagnostics.insert("\(stamp) — \(line)", at: 0)
        if diagnostics.count > 40 { diagnostics.removeLast() }
    }
}
