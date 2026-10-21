import SwiftUI

/// Username + password. Credentials are never stored locally: the password is encrypted with the
/// session key and sent once; the token lives in memory for the session.
struct LoginView: View {
    @EnvironmentObject private var store: BluStore
    @State private var username = ""
    @State private var password = ""
    @State private var revealPassword = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                fields
                if let message = store.errorMessage { ErrorBanner(text: message) }
                primaryButton
                demoButton
                footnote
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            LogoMark(size: 76)
            Text("ورود به حساب")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Text("با نام کاربری و رمز عبور خود وارد شوید")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(.top, 24)
        .padding(.bottom, 6)
    }

    private var fields: some View {
        SurfaceCard {
            VStack(spacing: 16) {
                labeledField(title: "نام کاربری") {
                    TextField("مثلاً ۰۹۱۲۳۴۵۶۷۸۹", text: $username)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .environment(\.layoutDirection, .leftToRight)
                        .multilineTextAlignment(.leading)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                divider
                labeledField(title: "رمز عبور") {
                    HStack(spacing: 8) {
                        Button {
                            revealPassword.toggle()
                        } label: {
                            Image(systemName: revealPassword ? "eye.slash" : "eye")
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Group {
                            if revealPassword {
                                TextField("رمز عبور", text: $password)
                            } else {
                                SecureField("رمز عبور", text: $password)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .environment(\.layoutDirection, .leftToRight)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private var primaryButton: some View {
        Button {
            Task { await store.login(username: username, password: password) }
        } label: {
            HStack(spacing: 10) {
                if store.isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                Text(store.isLoading ? "در حال ورود…" : "ورود")
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
        .disabled(store.isLoading || username.isEmpty || password.isEmpty)
        .opacity(username.isEmpty || password.isEmpty ? 0.6 : 1)
    }

    private var demoButton: some View {
        Button {
            store.enterDemo()
        } label: {
            Text("مشاهده رابط با داده‌های نمایشی")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.bluAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.bluAccent.opacity(0.4), lineWidth: 1)
                )
        }
    }

    private var footnote: some View {
        Text("این برنامه یک کلاینت شخصی و غیررسمی است و به حساب کاربری خودتان وصل می‌شود. اطلاعات ورود شما ذخیره نمی‌شود.")
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.4))
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
    }

    @ViewBuilder
    private func labeledField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            content()
        }
    }
}

struct ErrorBanner: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.bluDebit)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.bluDebit.opacity(0.12))
        )
    }
}
