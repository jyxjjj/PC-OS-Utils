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

        HStack(spacing: 12) {
            serviceIcon
            info
            Spacer()
            codeAndTimer(
                timeRemaining: timing.remaining,
                fraction: timing.fraction
            )
            copyButton
        }
        .padding(.vertical, 6)
        .onDisappear { copyResetTask?.cancel() }
    }

    // MARK: - Sub-views

    private var serviceIcon: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 40, height: 40)
            Text(entry.serviceName.prefix(1).uppercased())
                .font(.headline)
                .foregroundColor(.accentColor)
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 2) {
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
        HStack(spacing: 8) {
            TOTPCodeText(
                entry: entry,
                date: date,
                isExpiring: timeRemaining <= 5
            )
            .equatable()

            ZStack {
                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: 1.0 - fraction)
                    .stroke(
                        timeRemaining <= 5 ? Color.red : Color.accentColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: fraction)
                Text("\(Int(timeRemaining))")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 28, height: 28)
        }
    }

    private var copyButton: some View {
        Button(action: copyCode) {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .foregroundColor(copied ? .green : .secondary)
                .frame(width: 20)
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
                try await Task.sleep(for: .seconds(2))
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
        guard (6 ... 8).contains(code.count) else { return code }
        let mid = code.index(code.startIndex, offsetBy: code.count / 2)
        return "\(code[..<mid]) \(code[mid...])"
    }
}
