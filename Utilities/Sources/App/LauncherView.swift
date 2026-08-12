import SwiftUI
import AppKit

struct LauncherView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var isOpeningFeature = false

    private let projectURL = URL(string: AppConstants.Launcher.projectURL)!

    private var version: String {
        let shortVersion = Bundle.main.object(
            forInfoDictionaryKey: AppConstants.Launcher.shortVersionKey
        ) as! String
        let build = Bundle.main.object(
            forInfoDictionaryKey: AppConstants.Launcher.buildVersionKey
        ) as! String
        return String(
            format: AppConstants.Launcher.versionFormat,
            shortVersion,
            build
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppConstants.Launcher.outerSpacing) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppConstants.Launcher.titleSpacing) {
                    Text(AppConstants.Launcher.title)
                        .font(.largeTitle.bold())
                    Text(AppConstants.Launcher.subtitle)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Link(destination: projectURL) {
                    Image(AppConstants.Launcher.gitHubLogoAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: AppConstants.Launcher.logoSize,
                            height: AppConstants.Launcher.logoSize
                        )
                        .padding(AppConstants.Launcher.logoPadding)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
            }

            GlassEffectContainer(spacing: AppConstants.Launcher.cardContainerSpacing) {
                HStack(spacing: AppConstants.Launcher.cardContainerSpacing) {
                    toolCard(
                        title: AppConstants.Launcher.subTrackTitle,
                        description: AppConstants.Launcher.subTrackDescription,
                        symbol: "calendar.badge.clock",
                        tint: .blue,
                        windowID: AppConstants.Application.subTrackWindowID
                    )
                    toolCard(
                        title: AppConstants.Launcher.authenticatorTitle,
                        description: AppConstants.Launcher.authenticatorDescription,
                        symbol: "key.viewfinder",
                        tint: .cyan,
                        windowID: AppConstants.Application.authenticatorWindowID
                    )
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)

            Divider()

            HStack(alignment: .center, spacing: AppConstants.Launcher.footerSpacing) {
                Text(AppConstants.Launcher.license)
                    .font(.headline)

                Spacer(minLength: AppConstants.Launcher.footerMinimumSpacer)

                Text(version)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(AppConstants.Launcher.contentPadding)
        .padding(.top, AppConstants.Launcher.topPadding)
        .background {
            LinearGradient(
                colors: [
                    .black,
                    Color.blue.opacity(AppConstants.Launcher.gradientBlueOpacity),
                ],
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
            dismissWindow(id: AppConstants.Application.launcherWindowID)
        } label: {
            VStack(alignment: .leading, spacing: AppConstants.Launcher.cardContentSpacing) {
                Image(systemName: symbol)
                    .font(.system(size: AppConstants.Launcher.cardSymbolSize, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.title2.bold())
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppConstants.Launcher.cardMinimumSpacer)
                Label(
                    AppConstants.Launcher.launch,
                    systemImage: "arrow.up.forward.app"
                )
                    .font(.headline)
                    .foregroundStyle(tint)
            }
            .padding(AppConstants.Launcher.cardPadding)
            .frame(
                maxWidth: .infinity,
                minHeight: AppConstants.Launcher.cardMinimumHeight,
                maxHeight: .infinity,
                alignment: .leading
            )
            .glassEffect(
                .regular.interactive(),
                in: .rect(cornerRadius: AppConstants.Launcher.cardCornerRadius)
            )
            .contentShape(
                RoundedRectangle(cornerRadius: AppConstants.Launcher.cardCornerRadius)
            )
        }
        .buttonStyle(.plain)
    }
}
