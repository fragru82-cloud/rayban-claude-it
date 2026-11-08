import SwiftUI
import UIKit

/// Gedächtnis ansehen und verwalten: Einträge löschen, selbst ergänzen, aus der Claude-App übernehmen.
struct MemoryView: View {
    @ObservedObject var memory: MemoryStore
    @Binding var enabled: Bool

    @State private var newFact = ""
    @State private var showImport = false
    @State private var confirmClear = false

    var body: some View {
        List {
            Group {
                Section {
                    Toggle("Claude ricorda cose su di te", isOn: $enabled)
                } footer: {
                    Text("Di’ per esempio «Ehi Claude, ricorda che mia figlia si chiama Mia», oppure Claude annota da solo ciò che è importante a lungo termine. «Dimentica quella cosa su …» la cancella. L’elenco resta solo su questo iPhone e viene inviato a Claude all’inizio di ogni conversazione.")
                }

                if enabled {
                    Section {
                        Button {
                            showImport = true
                        } label: {
                            Label("Importa dall’app Claude", systemImage: "square.and.arrow.down.on.square")
                        }
                        HStack {
                            TextField("Aggiungi tu, es. «Beve l’espresso senza zucchero»", text: $newFact)
                                .submitLabel(.done)
                                .onSubmit(addFact)
                            Button("Ricorda", action: addFact)
                                .disabled(MemoryStore.clean(newFact).isEmpty)
                        }
                    }

                    Section {
                        if memory.items.isEmpty {
                            Text("Ancora niente in memoria.").foregroundStyle(Color.hudMuted)
                        }
                        ForEach(memory.items.reversed()) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.text)
                                Text(item.created, format: .dateTime.day().month().year())
                                    .font(.hudMono(10)).foregroundStyle(Color.hudMuted)
                            }
                        }
                        .onDelete { offsets in
                            // Anzeige ist umgekehrt (neueste oben) → Indizes zurückrechnen
                            let count = memory.items.count
                            memory.remove(at: IndexSet(offsets.map { count - 1 - $0 }))
                        }
                    } header: {
                        HUDLabel("In memoria (\(memory.items.count))")
                    } footer: {
                        Text("Scorri a sinistra per eliminare.")
                    }

                    if !memory.items.isEmpty {
                        Section {
                            Button("Dimentica tutto", role: .destructive) { confirmClear = true }
                        }
                    }
                }
            }
            .hudSection()
        }
        .navigationTitle("Memoria")
        .hudList()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImport) { MemoryImportView(memory: memory) }
        .confirmationDialog("Eliminare davvero tutte le \(memory.items.count) voci?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Dimentica tutto", role: .destructive) { memory.clear() }
        }
    }

    private func addFact() {
        guard memory.add(newFact) != nil else { return }
        newFact = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// Übernahme aus der offiziellen Claude-App: Dort fragt man Claude nach einer Zusammenfassung
/// und fügt sie hier ein. (Eine Schnittstelle zum direkten Auslesen der Chats gibt es nicht.)
struct MemoryImportView: View {
    @ObservedObject var memory: MemoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var copied = false

    static let prompt = "Riassumi in brevi punti ciò che sai in modo duraturo su di me dalle nostre chat precedenti: nomi, famiglia, lavoro, preferenze, progetti, appuntamenti importanti. Una riga per punto, senza introduzione."

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    step(1, "Apri l’app Claude (o claude.ai) e invia a Claude questa domanda:")
                    Text(Self.prompt)
                        .font(.callout)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.hudBackground.opacity(0.7), in: RoundedRectangle(cornerRadius: HUDMetrics.radius))
                        .overlay(RoundedRectangle(cornerRadius: HUDMetrics.radius)
                            .strokeBorder(Color.hudLineStrong, lineWidth: HUDMetrics.hairline))
                    Button {
                        UIPasteboard.general.string = Self.prompt
                        copied = true
                    } label: {
                        Label(copied ? "Copiata ✓" : "Copia domanda", systemImage: "doc.on.doc")
                    }
                    step(2, "Copia la risposta di Claude e incollala qui sotto.")
                } header: {
                    HUDLabel("Come fare")
                } footer: {
                    Text("Ancora più semplice dal PC: l’app Claude Desktop è collegata a RayBan Claude. Lì basta dire «Trasferisci agli occhiali ciò che sai di me» e Claude lo scrive direttamente qui.")
                }
                .hudSection()

                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)
                    // PasteButton fügt ohne die Rückfrage „Einfügen erlauben?“ ein
                    PasteButton(payloadType: String.self) { strings in
                        if let pasted = strings.first { text = pasted }
                    }
                } header: {
                    HUDLabel("Risposta di Claude")
                } footer: {
                    Text("Ogni riga diventa una voce. Dai una letta veloce e cancella ciò che Claude non deve sapere: tutto resta solo su questo iPhone.")
                }
                .hudSection()
            }
            .hudList()
            .navigationTitle("Dall’app Claude")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Importa") {
                        _ = memory.importLines(text)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            HUDStepBadge(number: number)
            Text(text)
        }
    }
}
