import SwiftUI

struct ManualEntryView: View {
    @ObservedObject var store: QuotaStore
    @Environment(\.dismiss) private var dismiss
    @ViewState<[ManualPeriodDraft]> private var drafts: [ManualPeriodDraft]
    @ViewState<String?> private var errorMessage: String? = nil
    init(store: QuotaStore) {
        self.store = store
        _drafts = ViewState(initialValue: store.snapshot.periods.map(ManualPeriodDraft.init))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manuelle værdier").font(.title2.bold())
            Text(store.selectedProduct.title).foregroundStyle(.secondary)
            Text("Indtast den oplyste kvote og nulstilling. Fjern markeringen for ukendte værdier.").font(.caption)
            ForEach($drafts) { $draft in
                GroupBox(draft.title) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Angiv værdier for \(draft.title)", isOn: $draft.enabled)
                        TextField("Procent tilbage (0–100)", text: $draft.percent)
                            .disabled(!draft.enabled)
                        DatePicker("Frem til", selection: $draft.resetsAt, displayedComponents: [.date, .hourAndMinute])
                            .environment(\.locale, Locale(identifier: "da_DK"))
                            .disabled(!draft.enabled)
                    }.padding(6)
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.caption).accessibilityLabel("Fejl: \(errorMessage)") }
            HStack {
                Button("Annuller") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Gem") {
                    do {
                        let now = Date()
                        let periods = try drafts.map { try $0.validated(at: now) }
                        try store.saveManual(periods: periods)
                        dismiss()
                    } catch { errorMessage = error.localizedDescription }
                }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 420)
    }
}
