# Blu Client — iOS

An unofficial, personal-use iOS client for the **Blu Bank** (بلو) open API, written in SwiftUI with
no third-party dependencies.

The gateway has no published API documentation and ships no protobuf descriptors, so the wire
format in this client was reconstructed from the web client's own JavaScript and from a local
capture of the owner's own browser session. The recovered protocol is documented in
[`docs/PROTOCOL.md`](docs/PROTOCOL.md); the field tables the client encodes against are in
[`docs/SCHEMA.md`](docs/SCHEMA.md). A standalone Python reference implementation of the handshake
lives in [`tools/blu_ref_client.py`](tools/blu_ref_client.py) — use it to sanity-check the crypto
against the live service without touching the app.

> **Unofficial.** Not affiliated with Blu Bank / Saman Bank. It signs in as *you*, with *your*
> credentials, and still requires the SMS one-time code — no authentication step is bypassed. Use
> it only with an account you own.

## What it does

| Area | State |
|------|-------|
| ECDH P-256 key exchange, AES-256-GCM field encryption, detached-JWS signing | implemented, verified live against the gateway |
| Login (username + password) → SMS one-time code → session token | implemented from the captured flow, **not** verified end-to-end (needs your real credentials) |
| Accounts, balances, transaction history, cards, profile | implemented (read-only), mapped from the response schema |
| Transfers / payments | deliberately **not** implemented — money movement is left to the official app |
| Demo mode | complete: three accounts, twelve transactions, two cards, profile |

## Design notes

* **Read-only by construction.** Only `*/list`, `*/get` and the auth endpoints are wired up.
* **No secrets at rest.** The password and the OTP are encrypted with the session key and sent
  once; nothing is written to disk — the token lives in memory for the session only. The only
  persisted value is the 16-byte installation id the server binds the session key to.
* **Nothing captured is bundled.** No request log, account number or personal data from the
  capture is in this repository; demo values are invented.
* **Persian-first UI.** Right-to-left layout, Persian digits and grouping, server-side localised
  amounts and Jalali dates used verbatim.

## Download the IPA

[`v1.0.0`](https://github.com/rnetis/blu-ios/releases/latest) carries an **unsigned
`BluClient.ipa`** (+ sha256) built by CI. Install it with AltStore, Sideloadly, or a free Apple ID
via Xcode — no Mac needed to *build* it, only to sign and install it, and sideloading preserves
nothing beyond the app bundle (this app stores no credentials anyway).

The first screen offers demo mode, so you can explore the whole interface without an account.

*v1.0.1 fixes the one-time-code step: the on-screen keyboard now opens (the digit boxes are the
tap target, with focus taken automatically on appear), and the `otp_request` id from the login
response's deep link is parsed and echoed back — without it the verify call could not succeed.*

## Building

```bash
cd ios
brew install xcodegen          # macOS only
xcodegen generate              # writes BluClient.xcodeproj + Info.plist
open BluClient.xcodeproj       # set your own signing team to run on a device
```

### Unsigned IPA from CI (no Mac required)

`.github/workflows/ios-ipa.yml` archives on a `macos-latest` runner with code signing disabled,
zips `Payload/` into `BluClient.ipa`, uploads it as an artifact, and attaches it to the GitHub
release when a `v*` tag is pushed.

Sideload the resulting IPA with AltStore, Sideloadly or Xcode (free 7-day provisioning), or
re-sign it yourself.

## Screens

* **ورود** — username/password with a per-field error surface and a demo-mode shortcut.
* **کد تأیید** — one-time code entry with countdown and masked phone number.
* **خانه** — gradient balance card, account/wallet switcher, quick-action grid, latest transactions.
* **تراکنشها** — search, credit/debit filter, day-grouped rows with merchant-category icons,
  credit/debit totals.
* **کارتها** — card visuals with masked PAN (tap to reveal), card metadata.
* **پروفایل** — identity block, account counters, national code / birth date / address, a
  technical session log that shows what the gateway actually answered, and sign-out.
