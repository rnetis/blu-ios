import SwiftUI

/// Read-only view of the transfer methods the account is allowed to use. Creating a transfer moves
/// money, so the app deliberately stops at inspection — the gateway's write endpoints are not wired
/// up in this client.
struct TransferView: View {
    @EnvironmentObject private var store: BluStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                methods
                notice
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(BluTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("انتقال")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("روش‌های انتقال در دسترس")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Text("فهرست زیر از سرویس بانک خوانده می‌شود.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var methods: some View {
        SurfaceCard(padding: 6) {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { pair in
                    methodRow(pair.element)
                    if pair.offset < rows.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                            .padding(.leading, 56)
                    }
                }
            }
        }
    }

    private var rows: [String] {
        store.transferMethods.isEmpty ? DemoData.transferMethods : store.transferMethods
    }

    private func methodRow(_ title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.bluSurfaceHigh).frame(width: 38, height: 38)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.bluAccent)
            }
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }

    private var notice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundColor(.bluBlue)
            Text("این نسخه فقط خواندنی است. ثبت انتقال از داخل برنامه فعال نشده تا اشتباهی پول جابه‌جا نشود.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.bluBlue.opacity(0.12))
        )
    }
}
