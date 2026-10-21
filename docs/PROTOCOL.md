# Blu Bank openapi protocol (reverse-engineered)

Notes on how `app.blubank.com` (Blu Bank's web client, bundle version 3.11.0.30) talks to
`openapi.sdb247.com`. This is a personal-use interoperability note: the client in this repository
authenticates **as the account owner** with the owner's own credentials and does not bypass,
weaken or skip any authentication step (the SMS one-time code is still required, and still typed by
the user).

Everything below was derived from a local Burp export of the owner's own browser session plus the
web client's own JavaScript, and the handshake was re-verified live (see *Verification status*).

## Transport

* `POST https://openapi.sdb247.com/openapi/v0/<domain>/<service>`
* **HTTP/2 is mandatory** — the APISIX edge resets HTTP/1.1 connections.
* `Content-Type: application/x-protobuf;reqMsg="solutions.saman.bluebank.services.<Name>Request"; respMsg="…Response";`
* Request bodies are **protobuf, not encrypted as a whole**; only genuinely sensitive *fields*
  (password, OTP, PIN, CVV) are AES-GCM encrypted.
* Edge (APISIX/openresty) answers `401 Authorization Required` for every path outside its
  whitelist (`session/key-exchange`, `session/login`, …) — i.e. a bearer token is checked at the
  gateway before the service sees the request.
* Service-level outcome rides in the response body:
  `Response { context(1) { status(1) { code(1), message(2) } } }` — `code == 0` means OK.

## Session key exchange (public)

1. Client generates an ephemeral **ECDH P-256** key pair.
2. `session/key-exchange` with `SessionKeyExchangeRequest`:

   | # | field | type | value |
   |---|-------|------|-------|
   | 1 | context | message | see below |
   | 2 | deviceId | bytes | 16-byte installation id |
   | 3 | publicKey | bytes | client public key, **SPKI/DER** (91 bytes) |
   | 4 | cipherMethod | enum | `3` = `CIPHER_METHOD_AES256_GCM_V1` |

   `SessionKeyExchangeResponse`: `context(1)`, `keyId(2)` (hex **string**), `publicKey(3)` (SPKI).
3. The raw ECDH shared secret (`Z`, 32 bytes — the X coordinate) is used **directly** as
   *both* keys:

   * AES-256-GCM key for field-level secrets,
   * HMAC-SHA256 key for the request signature.

   WebCrypto does exactly this via `deriveKey({name:"ECDH", public}, priv, {name:"AES-GCM", length:256})`
   and `…{name:"HMAC", length:256, hash:"SHA-256"}` — no KDF is applied on top.
4. `keyId` is remembered and used as the JWS `kid` for every later request.

## Request signature

Authenticated calls carry `X-Jws-Signature`, a **detached-payload compact JWS** (RFC 7797
`b64:false`):

```
header  = {"alg":"HS256","kid":"<keyId>","crit":["b64"],"b64":false,"requestId":"<uuid>"}
signing = base64url(header) "." <raw request body bytes>
value   = base64url(header) ".." base64url(HMAC-SHA256(signing, hmacKey))
```

`X-Request-Id` carries the same uuid string, and `context.requestId` carries it as 16 raw bytes.
`Authorization: Bearer <token>` is added once a token exists. Both the signature and the bearer
header are only attached to non-public calls (the web client models this as
`isPublicService = !isAuthenticated()`).

## Field-level encryption (`bluEncrypt` / `bluDecrypt`)

```
blob = iv(12 random bytes) || AES-256-GCM(ciphertext || tag)
```

Used for `Password{ encoded(1) }` (login) and `OneTimePin{ …(1) }` (OTP verify).

## RequestContext

| # | field | type | notes |
|---|-------|------|-------|
| 1 | requestId | bytes | 16 raw bytes of the request uuid |
| 4 | authenticationToken | message | `{ issueDate(1){…}, expireDate(2){…}, bearer(3) bytes }` — authenticated calls only |
| 8 | app | message | `{ debuggerAttached(10)=false, deviceId(998) bytes, version(999){ major(1), minor(2), patch(3), build(4) } }` |
| 9 | locale | message | `{ identifier(1) = "fa_IR" }` |
| 10 | accountProfileInfo | message | `{ profileId(1), profileType(2)=1, accountNumber(3){ accountNumber(1) }, accountType(4)=41 }` |
| 11 | platform | message | `{ type(1)=1, os(2)=1, version(3){…} }` |

## Authentication flow

1. `session/key-exchange` (public, unsigned).
2. `session/login` — **public, unsigned**:

   ```
   SessionLoginRequest {
     context(1)
     authentication(3) { plain(3) { username(1) string, password(2) Password{ encoded(1) } } }
     device(4) {
       id(1)            = 16-byte device id
       appInfo(2)       = { version(1){3,11,0,30}, bundleId(3)="blu.saman.solutions" }
       platform(3)      = { type(1)=1, os(2)=1, version(3){…} }
       name(5)          = browser/app name
       locale(7)        = { identifier(1)="fa_IR" }
     }
   }
   ```

   Response carries `authenticationToken(2)` (a limited JWT) and a `navigationUri(5)` deep link
   such as `blubank://app/navigate?page=login/device-verify&otp_request=…&masked_phone=…`.

   The `otp_request` parameter is *itself* a base64-encoded `OTPRequest` protobuf, not a bare id:

   ```
   CiQwYTRhY2FjYy03Mzc5LTQ4OWEtOWFhZC00NDBkYWI2NTQ3NzASCwj7rODWBhC878E6GgIIdw==
   → { id(1): "0a4acacc-7379-489a-9aad-440dab654770",
       issued(2): { seconds(1): 1792546427, nanos(2): 753000000 },
       kind(3): { 1: 119 } }
   ```

   Those three values (id, issued.seconds, kind) are what step 3 must echo back; an empty or stale id
   is rejected. The code itself is **6 digits**, readable off the captured ciphertext length
   (34 bytes = 12-byte IV + 16-byte tag + 6 bytes of plaintext).
3. `user/otp/verify`:

   ```
   UserOTPVerifyRequest {
     context(1)                  # includes the limited token from step 2
     otpRequest(2) { id(1) = otp_request, issued(2){…}, reason/type(3){…} }
     oneTimePin(3) { encoded(1) = bluEncrypt(code) }
   }
   ```

   Response carries the full `authenticationToken(5)` and `navigationUri(2)`
   (`payment/main&profile-id=main&profile-type=ACCOUNT_PROFILE_TYPE_PERSONAL`).
4. Authenticated reads (`user/profile/get`, `account/deposit/list/all`,
   `account/transaction/list/all`, `account/card/list/all`, …) with `context.authenticationToken`
   plus the JWS/bearer headers.

## Verification status

Verified live from a Linux host against the real gateway:

* `session/key-exchange` → `200`, `status.code = 0`, `keyId` (16 bytes) and the server's 91-byte
  SPKI key returned; ECDH shared secret derived and used as AES/HMAC key.
* Response protobuf decodes with the field numbers above; request bodies reproduce the captured
  byte layout exactly (`references` in `tools/blu_ref_client.py`).
* The edge's HTTP/2-only requirement, the `401` wall for non-whitelisted paths, and the
  `context.status` error shape were all observed directly.

**Not verified:** `session/login` and everything downstream, because that requires the account
owner's real username/password. Note that the service maps *every* failure mode — malformed body,
unknown username, undecryptable password — to gRPC `code 13 Internal Server Error`, so a
probe with invented credentials cannot distinguish "wrong credentials" from "wrong protocol";
the error surface simply does not discriminate. The app is therefore built to show exactly what
the server answered, and to be usable in demo mode without any account.

Client-side detail recovered later: `navigationUri(5)` carries the challenge as a query parameter,
`otp_request` is a base64 `OTPRequest` protobuf whose `id`/`issued.seconds`/`kind` must be echoed in
`UserOTPVerifyRequest.otpRequest`, and the code is 6 digits. Without parsing that deep link the verify
call sends an empty id and cannot succeed.
