import SwiftUI

/// One-time-code entry. The code is AES-256-GCM encrypted under the session key before it leaves the
/// device, exactly like the password.
///
/// The digit boxes are the tap target and the text field is an invisible overlay on top of them, so
/// tapping the boxes — the obvious thing to do — raises the numeric keyboard. The screen also
/// focuses itself on appear and declares `.oneTimeCode` so iOS can autofill the SMS code.
struct OTPView: View {
    @EnvironmentObject private var store: BluStore
    @State private var code = ""
    @FocusState private var codeFocused: Bool

    private let codeLength = 6

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
        .scrollDismissesKeyboard(.never)
        .contentShape(Rectangle())
        .onTapGesture { codeFocused = true }
        .task { await focusSoon() }
    }

    private func focusSoon() async {
        // Focusing in the same run loop as the phase change is unreliable; a short delay works.
        try? await Task.sleep(nanoseconds: 400_000_000)
        codeFocused = true
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
            Text(phoneLine)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
    }

    private var phoneLine: String {
        let masked = store.otpMaskedPhone
        return masked.isEmpty ? "کد پیامک‌شده را وارد کنید" : "کد پیامک‌شده به \(masked) را وارد کنید"
    }

    private var codeField: some View {
        SurfaceCard {
            VStack(spacing: 14) {
                boxes
                Text("برای وارد کردن کد، روی خانه‌ها بزنید")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private var boxes: some View {
        ZStack {
            HStack(spacing: 9) {
                ForEach(0..<codeLength, id: \.self) { index in
                    OTPBox(character: character(at: index), isActive: index == code.count)
                }
            }
            codeInput
        }
        .contentShape(Rectangle())
        .onTapGesture { codeFocused = true }
    }

    /// Invisible text field stretched over the boxes: it owns the keyboard, the boxes own the looks.
    private var codeInput: some View {
        TextField("", text: $code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($codeFocused)
            .foregroundColor(.clear)
            .tint(.clear)
            .opacity(0.02)
            .frame(maxWidth: .infinity, minHeight: 56)
            .accessibilityLabel("کد تأیید")
            .onChange(of: code) { newValue in
                let filtered = newValue.filter(\.isNumber)
                if filtered != newValue {
                    code = String(filtered.prefix(codeLength))
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
            codeFocused = false
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
                codeFocused = false
                store.cancelOTP()
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.bluAccent)
        }
        .padding(.top, 4)
    }
}

struct OTPBox: View {
    let character: String
    var isActive = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.bluSurfaceHigh)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(borderColor, lineWidth: isActive ? 1.6 : 1)
                )
            Text(character)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(height: 56)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }

    private var borderColor: Color {
        if isActive { return .bluAccent }
        return character.isEmpty ? Color.white.opacity(0.08) : Color.bluAccent.opacity(0.45)
    }
}
