import SwiftUI

/// One-time-code entry. The code is AES-256-GCM encrypted under the session key before it leaves
/// the device, exactly like the password.
struct OTPView: View {
    @EnvironmentObject private var store: BluStore
    @State private var code = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                codeField
                if let message = store.errorMessage { ErrorBanner(text: message) }
                verifyButton
                resendRow
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.bluSurfaceHigh).frame(width: 84, height: 84)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.bluAccent)
            }
            .padding(.top, 34)
            Text("کد تأیید را وارد کنید")
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(.white)
            Text("کد پیامک‌شده به \(store.otpMaskedPhone) را وارد کنید")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
    }

    private var codeField: some View {
        SurfaceCard {
            VStack(spacing: 14) {
                boxes
                TextField("کد ۵ رقمی", text: $code)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .environment(\.layoutDirection, .leftToRight)
                    .onChange(of: code) { newValue in
                        let filtered = newValue.filter(\.isNumber)
                        code = String(filtered.prefix(5))
                    }
            }
        }
    }

    private var boxes: some View {
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { index in
                OTPBox(character: character(at: index))
            }
        }
    }

    private func character(at index: Int) -> String {
        let digits = Array(code)
        guard index < digits.count else { return "" }
        return Persian.digits(String(digits[index]))
    }

    private var verifyButton: some View {
        Button {
            Task { await store.verify(code: code) }
        } label: {
            HStack(spacing: 10) {
                if store.isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                Text(store.isLoading ? "در حال بررسی…" : "تأیید و ورود")
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [.bluViolet, .bluBlue],
                                         startPoint: .leading, endPoint: .trailing))
            )
            .foregroundColor(.white)
        }
        .disabled(store.isLoading || code.count < 4)
        .opacity(code.count < 4 ? 0.6 : 1)
    }

    private var resendRow: some View {
        VStack(spacing: 8) {
            Text("ارسال دوباره کد تا \(Persian.secondsLabel(store.otpSecondsLeft))")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
            Button("تغییر نام کاربری") {
                store.phase = .login
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.bluAccent)
        }
        .padding(.top, 4)
    }
}

struct OTPBox: View {
    let character: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.bluSurfaceHigh)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(character.isEmpty ? Color.white.opacity(0.08) : Color.bluAccent.opacity(0.6),
                                lineWidth: 1)
                )
            Text(character)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(height: 56)
    }
}
