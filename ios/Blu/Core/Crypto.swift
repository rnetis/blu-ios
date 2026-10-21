import CryptoKit
import Foundation

/// The transport crypto of the Blu gateway, mirrored from the web client:
///
///   1. client generates an ephemeral P-256 ECDH key pair and posts its SPKI public key
///      (`session/key-exchange`);
///   2. the server answers with its own SPKI public key plus a `keyId`;
///   3. the raw ECDH shared secret (32 bytes) is used **directly** as both the AES-256-GCM key
///      (field-level secrets such as the password) and the HMAC-SHA256 key (the JWS signature);
///   4. every request is signed as a detached-payload JWS: `base64url(header) + ".." + base64url(HMAC)`.
enum BluCrypto {
    static let ivLength = 12

    // MARK: - base64url (no padding)

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - key agreement

    static func newKeyPair() -> P256.KeyAgreement.PrivateKey { P256.KeyAgreement.PrivateKey() }

    /// SPKI/DER form of the public key — byte-compatible with WebCrypto's `spki` export.
    static func spki(_ key: P256.KeyAgreement.PublicKey) -> Data { key.derRepresentation }

    static func sharedSecret(privateKey: P256.KeyAgreement.PrivateKey, serverSPKI: Data) throws -> Data {
        let serverKey = try P256.KeyAgreement.PublicKey(derRepresentation: serverSPKI)
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: serverKey)
        return secret.withUnsafeBytes { Data($0) }
    }

    // MARK: - AES-256-GCM, `iv || ciphertext || tag`

    static func encrypt(_ plaintext: Data, key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw BluError.crypto("AES-GCM produced no combined box") }
        return combined
    }

    static func decrypt(_ blob: Data, key: SymmetricKey) throws -> Data {
        guard blob.count > ivLength else { throw BluError.crypto("ciphertext too short") }
        let box = try AES.GCM.SealedBox(combined: blob)
        return try AES.GCM.open(box, using: key)
    }

    // MARK: - HS256 detached-payload JWS

    static func jwsSignature(body: Data, key: SymmetricKey) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: body, using: key))
    }

    /// Header JSON in the same field order the web client emits (the header is signed as sent, so
    /// order is only cosmetic — but matching it keeps packet captures comparable).
    static func jwsHeaderJSON(requestId: String, keyId: String) -> Data {
        let json = "{\"alg\":\"HS256\",\"kid\":\"\(keyId)\",\"crit\":[\"b64\"],\"b64\":false,\"requestId\":\"\(requestId)\"}"
        return Data(json.utf8)
    }

    /// `header.payload.signature` with the payload detached (`b64: false`): the signing input is
    /// `base64url(header) + "." + rawBody` and the serialized form omits the payload entirely.
    static func detachedJWS(requestId: String, keyId: String, body: Data, key: SymmetricKey) -> String {
        let encodedHeader = base64URL(jwsHeaderJSON(requestId: requestId, keyId: keyId))
        var signingInput = Data(encodedHeader.utf8)
        signingInput.append(0x2E) // "."
        signingInput.append(body)
        let signature = jwsSignature(body: signingInput, key: key)
        return encodedHeader + ".." + base64URL(signature)
    }
}
