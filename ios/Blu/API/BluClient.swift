import CryptoKit
import Foundation

enum BluError: LocalizedError {
    case crypto(String)
    case transport(String)
    case service(code: Int, message: String, http: Int)
    case decoding(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .crypto(let detail):     return "خطای رمزنگاری: \(detail)"
        case .transport(let detail):  return "خطای ارتباط: \(detail)"
        case .service(let code, let message, let http):
            return "سرویس بانک خطا برگرداند (\(code) / HTTP \(http)): \(message)"
        case .decoding(let detail):   return "خطای تفسیر پاسخ: \(detail)"
        case .notAuthenticated:       return "برای این درخواست باید وارد حساب شوید."
        }
    }
}

/// One HTTP round trip against the openapi gateway.
///
/// Every call carries a `RequestContext` (request id, app/device identity, platform, locale) and —
/// once the session key exists and the call is not public — an `X-Jws-Signature` detached JWS plus
/// the bearer token.
final class BluClient {
    static let baseURL = URL(string: "https://openapi.sdb247.com/openapi/v0/")!

    // Identity of this installation. The server binds a session key to it, so it is persisted.
    private(set) var deviceId: Data
    private var keyPair: P256.KeyAgreement.PrivateKey
    private(set) var keyId: String?
    private(set) var aesKey: SymmetricKey?
    private(set) var hmacKey: SymmetricKey?

    // Session state
    private(set) var bearer: Data?
    private(set) var tokenIssue: UInt64?
    private(set) var tokenExpire: UInt64?
    private(set) var profileId: String?
    private(set) var profileType: UInt64 = 1
    private(set) var accountNumber: String?
    private(set) var accountType: UInt64 = 41

    private let urlSession: URLSession

    init() {
        let stored = UserDefaults.standard.data(forKey: "blu.deviceId")
        if let stored, stored.count == 16 {
            deviceId = stored
        } else {
            var bytes = Data()
            for _ in 0..<16 { bytes.append(UInt8.random(in: 0...255)) }
            deviceId = bytes
            UserDefaults.standard.set(bytes, forKey: "blu.deviceId")
        }
        keyPair = BluCrypto.newKeyPair()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        urlSession = URLSession(configuration: config)
    }

    var isKeyEstablished: Bool { aesKey != nil && hmacKey != nil }
    var isAuthenticated: Bool { bearer != nil }

    // MARK: - Context

    private func requestIdentifier() -> (uuid: UUID, string: String, bytes: Data) {
        let uuid = UUID()
        let bytes = withUnsafeBytes(of: uuid.uuid) { Data($0) }
        return (uuid, uuid.uuidString.lowercased(), bytes)
    }

    /// `RequestContext` — see docs/SCHEMA.md. Field numbers come from the extracted schema:
    ///   requestId(1) bytes, authenticationToken(4), app(8), locale(9), accountProfileInfo(10), platform(11)
    /// and inside `app`: debuggerAttached(10), deviceId(998), version(999) {major,minor,patch,build}.
    func context(requestId: Data, authenticated: Bool) -> Data {
        var app = PB.bool(10, false)
        app += PB.bytes(998, deviceId)
        app += PB.message(999, PB.int(1, 3) + PB.int(2, 11) + PB.int(3, 0) + PB.int(4, 30))

        var context = PB.bytes(1, requestId)
        if authenticated, let bearer {
            var token = PB.message(1, PB.int(1, tokenIssue ?? 0))
            token += PB.message(2, PB.int(1, tokenExpire ?? 0))
            token += PB.bytes(3, bearer)
            context += PB.message(4, token)
        }
        context += PB.message(8, app)
        context += PB.message(9, PB.string(1, "fa_IR"))
        if authenticated, let profileId, let accountNumber {
            var info = PB.string(1, profileId)
            info += PB.int(2, profileType)
            info += PB.message(3, PB.string(1, accountNumber))
            info += PB.int(4, accountType)
            context += PB.message(10, info)
        }
        context += PB.message(11, PB.int(1, 1) + PB.int(2, 1) + PB.message(3, PB.int(1, 15)))
        return context
    }

    // MARK: - Transport

    private func send(service: String, path: String, body: Data,
                      authenticated: Bool, requestId: String) async throws -> PBMessage {
        var request = URLRequest(url: BluClient.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/x-protobuf;reqMsg=\"solutions.saman.bluebank.services.\(service)Request\"; respMsg=\"solutions.saman.bluebank.services.\(service)Response\";",
                         forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("fa-IR", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://app.blubank.com", forHTTPHeaderField: "Origin")
        request.setValue("https://app.blubank.com/", forHTTPHeaderField: "Referer")
        request.setValue(requestId, forHTTPHeaderField: "X-Request-Id")
        if authenticated, let hmacKey, let keyId {
            let jws = BluCrypto.detachedJWS(requestId: requestId, keyId: keyId, body: body, key: hmacKey)
            request.setValue(jws, forHTTPHeaderField: "X-Jws-Signature")
        }
        if authenticated, let bearer {
            request.setValue("Bearer " + BluCrypto.base64URL(bearer), forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw BluError.transport(error.localizedDescription)
        }
        let http = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let message = PBMessage(data: data) else {
            let text = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
            throw BluError.decoding("HTTP \(http): \(text)")
        }
        if let status = message.message(1)?.message(1) {
            let code = Int(status.int(1) ?? 0)
            let text = status.string(2) ?? ""
            if code != 0 {
                throw BluError.service(code: code, message: text.isEmpty ? "نامشخص" : text, http: http)
            }
        }
        return message
    }

    // MARK: - Session

    /// Public: exchanges ECDH public keys and derives the AES/HMAC keys.
    func keyExchange() async throws {
        keyPair = BluCrypto.newKeyPair()
        let id = requestIdentifier()
        let context = context(requestId: id.bytes, authenticated: false)
        var body = PB.message(1, context)
        body += PB.bytes(2, deviceId)
        body += PB.bytes(3, BluCrypto.spki(keyPair.publicKey))
        body += PB.int(4, 3) // CIPHER_METHOD_AES256_GCM_V1

        let response = try await send(service: "SessionKeyExchange", path: "session/key-exchange",
                                      body: body, authenticated: false, requestId: id.string)
        guard let keyIdString = response.string(2), let serverKey = response.data(3) else {
            throw BluError.decoding("پاسخ تبادل کلید ناقص است")
        }
        let secret = try BluCrypto.sharedSecret(privateKey: keyPair, serverSPKI: serverKey)
        aesKey = SymmetricKey(data: secret)
        hmacKey = SymmetricKey(data: secret)
        keyId = keyIdString
    }

    /// Public: username + password. The password travels AES-256-GCM encrypted under the session key.
    func login(username: String, password: String) async throws {
        guard let aesKey else { throw BluError.crypto("کلید نشست ساخته نشده است") }
        let id = requestIdentifier()
        let context = context(requestId: id.bytes, authenticated: false)

        let encryptedPassword = try BluCrypto.encrypt(Data(password.utf8), key: aesKey)
        let plain = PB.string(1, username) + PB.message(2, PB.bytes(1, encryptedPassword))

        let version = PB.int(1, 3) + PB.int(2, 11) + PB.int(3, 0) + PB.int(4, 30)
        var appInfo = PB.message(1, version)
        appInfo += PB.string(3, "blu.saman.solutions")
        var device = PB.bytes(1, deviceId)
        device += PB.message(2, appInfo)
        device += PB.message(3, PB.int(1, 1) + PB.int(2, 1) + PB.message(3, PB.int(1, 15)))
        device += PB.string(5, "Blu Client iOS")
        device += PB.message(7, PB.string(1, "fa_IR"))

        var body = PB.message(1, context)
        body += PB.message(3, PB.message(3, plain))
        body += PB.message(4, device)

        let response = try await send(service: "SessionLogin", path: "session/login",
                                      body: body, authenticated: false, requestId: id.string)
        try applyToken(from: response)
    }

    /// Public: verifies the one-time code and receives the full session token.
    func verifyOTP(otpRequestId: String, issueTimestamp: UInt64, code: String) async throws {
        guard let aesKey else { throw BluError.crypto("کلید نشست ساخته نشده است") }
        let id = requestIdentifier()
        let context = context(requestId: id.bytes, authenticated: bearer != nil)

        let encryptedPin = try BluCrypto.encrypt(Data(code.utf8), key: aesKey)
        var otpRequest = PB.string(1, otpRequestId)
        otpRequest += PB.message(2, PB.int(1, issueTimestamp))
        otpRequest += PB.message(3, PB.int(1, 119))

        var body = PB.message(1, context)
        body += PB.message(2, otpRequest)
        body += PB.message(3, PB.bytes(1, encryptedPin))

        let response = try await send(service: "UserOTPVerify", path: "user/otp/verify",
                                      body: body, authenticated: false, requestId: id.string)
        try applyToken(from: response)
    }

    private func applyToken(from response: PBMessage) throws {
        guard let token = response.message(2) else { throw BluError.decoding("توکن احراز هویت در پاسخ نیست") }
        bearer = token.data(3)
        tokenIssue = token.message(1)?.int(1)
        tokenExpire = token.message(2)?.int(1)
    }

    // MARK: - Reads

    func fetchProfile() async throws -> PBMessage {
        try await authenticated(service: "UserGetProfile", path: "user/profile/get", body: Data())
    }

    func fetchProfiles() async throws -> PBMessage {
        try await authenticated(service: "AccountProfileList", path: "account-profile/profile/list", body: Data())
    }

    func fetchAccounts(page: String? = nil) async throws -> PBMessage {
        var body = Data()
        if let page { body += PB.message(2, PB.string(1, page)) }
        return try await authenticated(service: "AccountListAll", path: "account/deposit/list/all", body: body)
    }

    func fetchCards() async throws -> PBMessage {
        try await authenticated(service: "CardListAll", path: "account/card/list/all", body: Data())
    }

    func fetchTransactions(page: String? = nil) async throws -> PBMessage {
        var body = Data()
        if let page { body += PB.message(2, PB.string(1, page)) }
        return try await authenticated(service: "TransactionListAll", path: "account/transaction/list/all", body: body)
    }

    func fetchTransferMethods() async throws -> PBMessage {
        try await authenticated(service: "TransferListMethodsAvailable",
                                path: "transfer/methods/list/available", body: Data())
    }

    /// Wraps a request body with the shared context for an authenticated service call.
    private func authenticated(service: String, path: String, body: Data) async throws -> PBMessage {
        guard isAuthenticated else { throw BluError.notAuthenticated }
        let id = requestIdentifier()
        let context = context(requestId: id.bytes, authenticated: true)
        var full = PB.message(1, context)
        full += body
        return try await send(service: service, path: path, body: full,
                              authenticated: true, requestId: id.string)
    }

    func setProfile(id: String, type: UInt64, accountNumber: String?, accountType: UInt64) {
        profileId = id
        profileType = type
        self.accountNumber = accountNumber
        self.accountType = accountType
    }

    func resetSession() {
        bearer = nil
        tokenIssue = nil
        tokenExpire = nil
        aesKey = nil
        hmacKey = nil
        keyId = nil
        profileId = nil
        accountNumber = nil
    }
}
