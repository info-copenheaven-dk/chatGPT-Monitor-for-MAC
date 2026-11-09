import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: QuotaStore
    @ViewState<Bool> private var editing = false
    @ViewState<Bool> private var settings = false
    private var fullLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("ChatGPT-forbrug", systemImage: "gauge.with.dots.needle.50percent").font(.title2.bold())
                Spacer()
                Button { store.miniLayout = true } label: { Image(systemName: "rectangle.compress.vertical") }
                    .help("Vis mini-layout")
                    .accessibilityLabel("Vis mini-layout")
                Button { settings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Indstillinger")
            }
            Picker("Produkt", selection: $store.selectedProduct) {
                ForEach(MonitoredProduct.allCases) { Text($0.title).tag($0) }
            }
            if store.supportsAutomatic {
                Picker("Datakilde", selection: $store.sourceMode) {
                    ForEach(SourceMode.allCases) { Text($0.title).tag($0) }
                }
            }
            if store.groups.count > 1 {
                Picker("Kvote", selection: $store.selectedGroupID) {
                    ForEach(store.groups) { Text($0.groupName).tag($0.groupID) }
                }
            } else { Text(store.snapshot.groupName).font(.caption).foregroundStyle(.secondary) }
            if store.source.capabilities.isDevelopment {
                Label("UDVIKLINGSDATA – ikke dit faktiske forbrug", systemImage: "hammer.fill")
                    .font(.caption.bold()).foregroundStyle(.orange)
            }
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(spacing: 12) {
                    ForEach(store.snapshot.periods) { period in
                        QuotaCard(period: period, now: context.date)
                    }
                }
            }
            Text(store.snapshot.sourceLabel).font(.caption).foregroundStyle(.secondary)
            if store.source.capabilities.canRefresh, let next = store.nextRefreshAt {
                Text("Næste automatiske forsøg: \(QuotaFormat.date(next))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if !store.source.capabilities.isDevelopment {
                Text(store.source.capabilities.supportsManualEntry
                     ? "Manuelle værdier gemmes på denne Mac og ændres ikke automatisk."
                     : "Kvoter læses fra din Codex-konto.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let error = store.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
                if store.supportsAutomatic && store.sourceMode == .automatic {
                    Button("Log ind med ChatGPT…") {
                        Task { if let url = await store.beginLogin() { NSWorkspace.shared.open(url) } }
                    }
                }
            }
            HStack {
                if store.source.capabilities.supportsManualEntry {
                    Button("Indtast værdier…") { editing = true }.keyboardShortcut("e", modifiers: .command)
                }
                Spacer()
                if store.isLoading { ProgressView().controlSize(.small) }
                Button("Opdater") { Task { await store.load() } }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(store.isLoading || !store.source.capabilities.canRefresh)
            }
        }
        .padding(20).frame(width: 400)

    }

    var body: some View {
        Group {
            if store.miniLayout { miniLayout } else { fullLayout }
        }
        .preferredColorScheme(store.theme == .system ? nil : store.theme == .light ? .light : .dark)
        .background(WindowStateReader(alwaysOnTop: store.alwaysOnTop))
        .task(id: store.selectionKey) { await store.runUpdates() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
            Task { await store.resumeAfterWake() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            store.shutdown()
        }
        .sheet(isPresented: $editing) { ManualEntryView(store: store) }
        .sheet(isPresented: $settings) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Indstillinger").font(.title2.bold())
                Picker("Tema", selection: $store.theme) {
                    ForEach(ThemeChoice.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Mini-layout", isOn: $store.miniLayout)
                Toggle("Altid øverst", isOn: $store.alwaysOnTop)
                Stepper("Opdateringsinterval: \(store.refreshInterval) min", value: $store.refreshInterval, in: 1...60)
                Text("Automatiske kilder opdateres med dette interval. Manuelle værdier ændres ikke. Indstillinger gemmes på denne Mac.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Codex-program (tom = find automatisk)", text: $store.cliPath)
                    .textFieldStyle(.roundedBorder)
                Text("Login opbevares af Codex i macOS-nøgleringen.")
                    .font(.caption).foregroundStyle(.secondary)
                if store.supportsAutomatic {
                    Button("Log ind med ChatGPT…") {
                        Task { if let url = await store.beginLogin() { NSWorkspace.shared.open(url) } }
                    }
                }
                if let message = store.loginMessage { Text(message).font(.caption) }
                Button("Luk") { settings = false }.keyboardShortcut(.defaultAction)
            }.padding(24).frame(width: 350)
        }
    }

    private var miniLayout: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(spacing: 12) {
                ForEach(store.snapshot.periods) { period in
                    MiniQuotaCard(period: period, now: context.date,
                                  context: "\(store.selectedProduct.title) · \(store.snapshot.groupName)\n\(store.snapshot.sourceLabel)",
                                  development: store.source.capabilities.isDevelopment)
                }
            }
            .padding(12).frame(width: 360)
        }
        .contextMenu {
            Button("Vis fuldt layout") { store.miniLayout = false }
            Button("Indstillinger…") { settings = true }
            if store.source.capabilities.supportsManualEntry {
                Button("Indtast værdier…") { editing = true }
            }
            Button("Opdater") { Task { await store.load() } }
                .disabled(store.isLoading || !store.source.capabilities.canRefresh)
        }
    }

}

struct QuotaCard: View {
    let period: QuotaPeriod
    let now: Date
    private var color: Color { (period.remainingPercent ?? 100) <= 5 ? .red : .orange }
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(period.title).font(.headline)
                Spacer()
                Text(period.remainingPercent.map { "\(QuotaFormat.number($0)) % tilbage" }
                     ?? (period.status == .unavailable ? "Ikke tilgængelig" : "Ukendt"))
                    .monospacedDigit()
            }
            if let percent = period.remainingPercent {
                ProgressView(value: percent, total: 100)
                    .tint(period.warning == nil ? .accentColor : color)
                    .accessibilityLabel("Resterende kvote for \(period.title)")
            }
            if let amount = period.remainingAmount, let unit = period.unit {
                Text("\(QuotaFormat.number(amount)) \(unit) tilbage").font(.caption)
            }
            if let warning = period.warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill").font(.caption.bold()).foregroundStyle(color)
            }
            Text(period.displayStatus(at: now).rawValue).font(.caption.bold())
            Text("Frem til: \(period.resetsAt.map { QuotaFormat.date($0) } ?? "Ukendt")").font(.caption)
            Text(period.countdown(at: now)).font(.caption).monospacedDigit()
            Text(period.updatedAt.map { "Senest opdateret: \(QuotaFormat.date($0))" } ?? "Ingen værdier modtaget")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}



struct MiniQuotaCard: View {
    let period: QuotaPeriod
    let now: Date
    let context: String
    let development: Bool
    private var status: QuotaStatus { period.displayStatus(at: now) }
    private var tooltip: String {
        var lines = [context, status.rawValue,
                     "Frem til: \(period.resetsAt.map { QuotaFormat.date($0) } ?? "Ukendt")",
                     period.countdown(at: now)]
        if let updated = period.updatedAt { lines.append("Senest opdateret: \(QuotaFormat.date(updated))") }
        lines.append("Højreklik for fuldt layout og indstillinger.")
        return lines.joined(separator: "\n")
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(period.title).fontWeight(.semibold)
                if development {
                    Image(systemName: "hammer.fill").foregroundStyle(.orange).accessibilityLabel("Udviklingsdata")
                }
                Spacer()
                if status == .stale || status == .awaitingReset {
                    Image(systemName: "clock.badge.exclamationmark").foregroundStyle(.orange)
                        .accessibilityLabel(status.rawValue)
                }
                Text(period.remainingPercent.map { "\(QuotaFormat.number($0)) % tilbage" }
                     ?? (status == .unavailable ? "Ikke tilgængelig" : "Ukendt"))
                    .monospacedDigit()
            }
            if let percent = period.remainingPercent {
                ProgressView(value: percent, total: 100)
                    .tint(percent <= 5 ? .red : percent <= 20 ? .orange : .accentColor)
            } else {
                Capsule().fill(.primary.opacity(0.12)).frame(height: 6)
            }
            Text(period.countdown(at: now))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12))
        .contentShape(Rectangle())
        .help(tooltip)
        .accessibilityElement(children: .combine)
        .accessibilityHint(tooltip)
    }
}
