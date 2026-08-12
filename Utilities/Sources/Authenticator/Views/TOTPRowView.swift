import SwiftUI

struct TOTPRowView: View {
    let entry: TOTPEntry
    let date: Date

    @State private var copied = false
    @State private var copyResetTask: Task<Void, Never>?

    var body: some View {
        let timing = TOTPEngine.timing(
            period: entry.period,
            date: date
        )

        HStack(spacing: AppConstants.Authenticator.Row.rowSpacing) {
            serviceIcon
            info
            Spacer()
            codeAndTimer(
                timeRemaining: timing.remaining,
                fraction: timing.fraction
            )
            copyButton
        }
        .padding(.vertical, AppConstants.Authenticator.Row.verticalPadding)
        .onDisappear { copyResetTask?.cancel() }
    }

    // MARK: - Sub-views

    private var serviceIcon: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(AppConstants.Authenticator.Row.iconOpacity))
                .frame(
                    width: AppConstants.Authenticator.Row.iconSize,
                    height: AppConstants.Authenticator.Row.iconSize
                )
            Text(entry.serviceName.prefix(1).uppercased())
                .font(.headline)
                .foregroundColor(.accentColor)
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: AppConstants.Authenticator.Row.infoSpacing) {
            Text(entry.serviceName).font(.headline)
            if !entry.username.isEmpty {
                Text(entry.username).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private func codeAndTimer(
        timeRemaining: Double,
        fraction: Double
    ) -> some View {
        HStack(spacing: AppConstants.Authenticator.Row.codeSpacing) {
            TOTPCodeText(
                entry: entry,
                date: date,
                isExpiring: timeRemaining <= AppConstants.Authenticator.Row.expirationThreshold
            )
            .equatable()

            ZStack {
                Circle().stroke(
                    Color.secondary.opacity(AppConstants.Authenticator.Row.trackOpacity),
                    lineWidth: AppConstants.Authenticator.Row.timerLineWidth
                )
                Circle()
                    .trim(from: 0, to: 1 - fraction)
                    .stroke(
                        timeRemaining <= AppConstants.Authenticator.Row.expirationThreshold
                            ? Color.red
                            : Color.accentColor,
                        style: StrokeStyle(
                            lineWidth: AppConstants.Authenticator.Row.timerLineWidth,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(
                        .degrees(AppConstants.Authenticator.Row.rotationDegrees)
                    )
                    .animation(
                        .linear(duration: AppConstants.Authenticator.Row.animationDuration),
                        value: fraction
                    )
                Text(String(Int(timeRemaining)))
                    .font(
                        .system(
                            size: AppConstants.Authenticator.Row.timerFontSize,
                            weight: .medium
                        )
                    )
                    .foregroundColor(.secondary)
            }
            .frame(
                width: AppConstants.Authenticator.Row.timerSize,
                height: AppConstants.Authenticator.Row.timerSize
            )
        }
    }

    private var copyButton: some View {
        Button(action: copyCode) {
            Image(
                systemName: copied ? "checkmark" : "doc.on.doc"
            )
                .foregroundColor(copied ? .green : .secondary)
                .frame(width: AppConstants.Authenticator.Row.copyButtonWidth)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func copyCode() {
        let code = TOTPEngine.generateCode(
            secret: entry.secret,
            algorithm: entry.algorithm,
            digits: entry.digits,
            period: entry.period,
            date: date
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation { copied = true }
        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor in
            do {
                try await Task.sleep(
                    for: .seconds(AppConstants.Authenticator.Row.copyFeedbackSeconds)
                )
            } catch {
                return
            }
            withAnimation { copied = false }
        }
    }
}

private struct TOTPCodeText: View, Equatable {
    let entry: TOTPEntry
    let date: Date
    let isExpiring: Bool

    private var counter: UInt64 {
        UInt64(date.timeIntervalSince1970) / UInt64(entry.period)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.entry == rhs.entry
            && lhs.counter == rhs.counter
            && lhs.isExpiring == rhs.isExpiring
    }

    var body: some View {
        let code = TOTPEngine.generateCode(
            secret: entry.secret,
            algorithm: entry.algorithm,
            digits: entry.digits,
            period: entry.period,
            date: date
        )
        Text(formattedCode(code))
            .font(.system(.title2, design: .monospaced).bold())
            .foregroundColor(isExpiring ? .red : .primary)
            .animation(.none, value: code)
    }

    private func formattedCode(_ code: String) -> String {
        guard (AppConstants.Authenticator.minimumDigits ...
               AppConstants.Authenticator.maximumDigits).contains(code.count) else {
            return code
        }
        let mid = code.index(code.startIndex, offsetBy: code.count / 2)
        return String(
            format: AppConstants.Authenticator.Row.groupedCodeFormat,
            String(code[..<mid]),
            String(code[mid...])
        )
    }
}
