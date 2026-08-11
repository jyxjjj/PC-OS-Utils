import SwiftUI
import AppKit

struct LauncherView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var isOpeningFeature = false

    private let projectURL = URL(string: "https://github.com/jyxjjj/PC-OS-Utils")!

    private var version: String {
        let shortVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as! String
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as! String
        return "\(shortVersion) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("小工具")
                        .font(.largeTitle.bold())
                    Text("选择要启动的工具。")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Link(destination: projectURL) {
                    Image("GitHubLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .padding(8)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
            }

            GlassEffectContainer(spacing: 18) {
                HStack(spacing: 18) {
                    toolCard(
                        title: "订阅管理",
                        description: "管理订阅、到期提醒、价格与续费记录。",
                        symbol: "calendar.badge.clock",
                        tint: .blue,
                        windowID: "subtrack"
                    )
                    toolCard(
                        title: "身份验证器",
                        description: "管理本地加密的 TOTP 验证码。",
                        symbol: "key.viewfinder",
                        tint: .cyan,
                        windowID: "authenticator"
                    )
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)

            Divider()

            HStack(alignment: .center, spacing: 24) {
                Text("GNU Affero General Public License v3.0")
                    .font(.headline)

                Spacer(minLength: 12)

                Text("Version \(version)")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(34)
        .padding(.top, 16)
        .background {
            LinearGradient(
                colors: [.black, Color.blue.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            if !isOpeningFeature {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func toolCard(
        title: String,
        description: String,
        symbol: String,
        tint: Color,
        windowID: String
    ) -> some View {
        Button {
            isOpeningFeature = true
            openWindow(id: windowID)
            dismissWindow(id: "launcher")
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.title2.bold())
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Label("启动", systemImage: "arrow.up.forward.app")
                    .font(.headline)
                    .foregroundStyle(tint)
            }
            .padding(22)
            .frame(
                maxWidth: .infinity,
                minHeight: 234,
                maxHeight: .infinity,
                alignment: .leading
            )
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
