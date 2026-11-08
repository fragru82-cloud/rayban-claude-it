import SwiftUI
import AVFoundation

struct SettingsView: View {
    @ObservedObject var viewModel: SessionViewModel
    @ObservedObject var rayBanManager: RayBanManager
    @ObservedObject var modeManager: ModeManager
    @Environment(\.dismiss) private var dismiss

    @State private var portText = ""
    @State private var testResult: (ok: Bool, text: String)?
    @State private var isTesting = false
    @State private var showRayBanInstructions = false
    @State private var showAddCustomMode = false

    private let accent = Color.hudCyan

    var body: some View {
        NavigationStack {
            List {
                Group {
                    connectionSection
                    directSection
                    memorySection
                    modesSection
                    cameraSection
                    rayBanSection
                    voiceSection
                    aboutSection
                }
                .hudSection()
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Impostazioni")
            .hudList()
            .sheet(isPresented: $showRayBanInstructions) { RayBanInstructionsView() }
            .sheet(isPresented: $showAddCustomMode) { AddCustomModeView(modeManager: modeManager) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fine") { dismiss() }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isConnected ? "Riconnetti" : "Connetti") {
                        Task { await viewModel.connect() }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { portText = String(viewModel.config.gatewayPort) }
        }
    }

    // MARK: - Verbindung

    private var connectionSection: some View {
        Section {
            HStack(spacing: 14) {
                let statusColor = viewModel.isConnected ? Color.hudOK : Color.hudBad
                Image(systemName: viewModel.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(statusColor)
                    .hudGlow(statusColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.isConnected ? "Connesso" : "Non connesso")
                        .font(.hudDisplay(15))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.hudInk)
                    Text(connectionDetail)
                        .font(.caption).foregroundStyle(Color.hudMuted)
                }
            }
            .padding(.vertical, 4)

            Picker("Tipo di connessione", selection: $viewModel.config.connectionMode) {
                ForEach(ConnectionMode.allCases) { Text($0.label).tag($0) }
            }

            if viewModel.config.connectionMode.usesPC {
                LabeledContent("Indirizzo PC") {
                    TextField("192.168.178.20", text: $viewModel.config.gatewayHost)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
                LabeledContent("Fuori casa (Tailscale)") {
                    TextField("100.x.y.z – facoltativo", text: $viewModel.config.remoteHost)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
                LabeledContent("Port") {
                    // Eigener Textzustand: früher sprang das Feld beim Löschen sofort auf 18790 zurück
                    TextField("18790", text: $portText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .onChange(of: portText) { _, text in
                            if let port = Int(text), (1024...65535).contains(port) { viewModel.config.gatewayPort = port }
                        }
                }
                LabeledContent("Token") {
                    SecureField("dalla dashboard", text: $viewModel.config.channelToken)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Button {
                    testConnection()
                } label: {
                    HStack {
                        Label("Prova connessione", systemImage: "bolt.horizontal.circle")
                        Spacer()
                        if isTesting {
                            ProgressView()
                        } else if let testResult {
                            Text(testResult.text).font(.caption).foregroundStyle(testResult.ok ? Color.hudOK : Color.hudBad)
                        }
                    }
                }
            }
        } header: {
            HUDLabel("Connessione")
        } footer: {
            Text(connectionFooter)
        }
    }

    private var connectionDetail: String {
        guard viewModel.isConnected else { return "Scansiona il codice QR o inserisci i dati" }
        return viewModel.viaTailscale ? "Fuori casa tramite Tailscale, usa il tuo abbonamento Claude" : "PC raggiungibile, token valido"
    }

    private var connectionFooter: String {
        switch viewModel.config.connectionMode {
        case .channel:
            return "Il modo più semplice: sul PC fai doppio clic su start.cmd e scansiona il codice QR della dashboard con la fotocamera dell’iPhone. Gratis con il tuo abbonamento Claude, tutti gli strumenti del PC disponibili. Fuori casa: installa Tailscale (gratuito) su PC e iPhone e ripeti l’associazione; così l’app interroga il PC di casa anche con i dati mobili, sempre tramite il tuo abbonamento."
        case .gateway:
            return "Modalità gateway: server proprio sul PC con chiave API Anthropic (a pagamento per richiesta). Il token compare all’avvio nella finestra del server."
        case .direct:
            return "Senza PC: l’iPhone interroga Claude direttamente via Internet (anche con i dati mobili). Serve una chiave API, vedi sotto."
        }
    }

    // MARK: - Ohne PC

    private var directSection: some View {
        Section {
            LabeledContent("Chiave API") {
                SecureField("sk-ant-…", text: $viewModel.config.anthropicAPIKey)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            if !viewModel.config.anthropicAPIKey.isEmpty && !viewModel.config.hasDirectKey {
                Label("Non sembra una chiave API Anthropic (inizia con sk-ant-)", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(Color.hudWarn)
            }
            Picker("Modello", selection: $viewModel.config.directModel) {
                ForEach(DirectClaudeClient.models) { model in
                    VStack(alignment: .leading) {
                        Text(model.name)
                        Text(model.hint).font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(model.id)
                }
            }
            if viewModel.config.connectionMode.usesPC {
                Toggle("Automatico se il PC non è raggiungibile", isOn: $viewModel.config.directFallback)
            }
            Toggle("Ricerca web (meteo, orari di apertura …)", isOn: $viewModel.config.webSearchEnabled)
            if let url = URL(string: "https://console.anthropic.com/settings/keys") {
                Link(destination: url) { Label("Crea una chiave API su Anthropic", systemImage: "key") }
            }
        } header: {
            HUDLabel("Senza PC (fuori casa)")
        } footer: {
            Text("Si paga a domanda: con Claude Opus 5.5 di solito 1–3 centesimi, Sonnet circa la metà, Haiku una frazione; ogni ricerca web circa 1 centesimo. Qui il tuo abbonamento Claude non vale: fuori casa puoi usarlo solo con Tailscale (vedi sopra). Senza PC non hai gli strumenti del PC (email, file), ma timer, chiamate, navigazione e foto sì. La chiave resta solo nel portachiavi di questo iPhone.")
        }
    }

    // MARK: - Gedächtnis

    private var memorySection: some View {
        Section {
            NavigationLink {
                MemoryView(memory: viewModel.memory, enabled: $viewModel.config.memoryEnabled)
            } label: {
                LabeledContent {
                    Text(viewModel.config.memoryEnabled ? "\(viewModel.memory.items.count) voci" : "disattivata")
                } label: {
                    Label("Cosa sa Claude di te", systemImage: "brain.head.profile")
                }
            }
        } header: {
            HUDLabel("Memoria")
        } footer: {
            Text("«Ehi Claude, ricorda …»: Claude lo memorizza, con e senza PC. Ciò che Claude sa di te dalle tue chat puoi importarlo incollandolo oppure direttamente dall’app Claude Desktop sul PC («Trasferisci agli occhiali ciò che sai di me»).")
        }
    }

    // MARK: - Modi

    private var modesSection: some View {
        Section {
            ForEach(VisionMode.builtInModes) { mode in
                Toggle(isOn: Binding(
                    get: { modeManager.isBuiltInModeVisible(mode.id) },
                    set: { _ in modeManager.toggleBuiltInModeVisibility(id: mode.id) }
                )) {
                    Label { Text(mode.name) } icon: { Image(systemName: mode.icon).foregroundStyle(mode.swiftColor) }
                }
                .disabled(mode.id == VisionMode.general.id)
            }
            ForEach(modeManager.customModes) { mode in
                Label { Text(mode.name) } icon: { Image(systemName: mode.icon).foregroundStyle(mode.swiftColor) }
            }
            .onDelete { indexSet in
                let modes = modeManager.customModes
                indexSet.map { modes[$0].id }.forEach { modeManager.deleteCustomMode(id: $0) }
            }
            Button {
                showAddCustomMode = true
            } label: {
                Label("Crea una modalità personalizzata", systemImage: "plus.circle.fill")
            }
        } header: {
            HUDLabel("Modalità esperto")
        } footer: {
            Text("Le modalità danno a Claude competenze e stile di risposta. Modalità attiva: \(modeManager.activeMode.name). Scorri a sinistra su una modalità personalizzata per eliminarla.")
        }
    }

    // MARK: - Kamera

    private var cameraSection: some View {
        Section {
            Picker("Fotocamera", selection: $viewModel.activeFrameSource) {
                ForEach(FrameSourceType.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
            }
            .pickerStyle(.segmented)

            LabeledContent("Stato", value: viewModel.frameSourceStatus.label)

            VStack(alignment: .leading) {
                LabeledContent("Immagine a Claude ogni", value: String(format: "%.1f s", viewModel.config.videoFrameInterval))
                Slider(value: $viewModel.config.videoFrameInterval, in: 0.5...5.0, step: 0.5)
            }
            VStack(alignment: .leading) {
                LabeledContent("Qualità JPEG", value: "\(Int(viewModel.config.videoJPEGQuality * 100)) %")
                Slider(value: $viewModel.config.videoJPEGQuality, in: 0.3...1.0, step: 0.05)
            }
        } header: {
            HUDLabel("Fotocamera")
        } footer: {
            Text("A ogni domanda l’immagine attuale viene inviata a Claude. Una qualità più alta aiuta a leggere i testi, ma consuma più dati.")
        }
    }

    // MARK: - Brille

    private var rayBanSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "eyeglasses").font(.system(size: 22)).foregroundStyle(accent).hudGlow(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rayBanManager.deviceModel ?? rayBanManager.glassesName).font(.body)
                    if rayBanManager.deviceModel != nil {
                        Text(rayBanManager.glassesName).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let battery = rayBanManager.batteryLevel {
                    Label("\(battery) %", systemImage: batteryIcon(battery)).font(.caption)
                }
            }
            LabeledContent("Registrazione", value: rayBanManager.registrationLabel)
            LabeledContent("Microfono e voce", value: AudioSessionManager.shared.currentRouteLabel)
            if let open = rayBanManager.hingesOpen {
                LabeledContent("Aste", value: open ? "aperte" : "chiuse")
            }
            if let hint = rayBanManager.updateHint {
                Label(hint, systemImage: "arrow.down.circle").font(.caption).foregroundStyle(Color.hudWarn)
            }
            Toggle("Gesti (sperimentale)", isOn: $viewModel.config.glassesGestures)
            if viewModel.config.glassesGestures, rayBanManager.isRegistered {
                LabeledContent("Gesti", value: rayBanManager.gesturesActive ? "attivi" : "non attivi")
                if let hint = rayBanManager.gestureHint {
                    Label(hint, systemImage: "hand.tap").font(.caption).foregroundStyle(Color.hudWarn)
                }
            }
            if rayBanManager.isRegistered {
                Button("Scollega occhiali", role: .destructive) {
                    Task { await rayBanManager.unregister() }
                }
            } else {
                Button {
                    Task { await viewModel.connectGlasses() }
                } label: {
                    Label("Collega gli occhiali tramite Meta AI", systemImage: "link.circle.fill")
                }
            }
            Button {
                showRayBanInstructions = true
            } label: {
                Label("Guida Ray-Ban Meta Gen 2", systemImage: "book.closed.fill")
            }
        } header: {
            HUDLabel("Ray-Ban Meta")
        } footer: {
            Text("Registrazione una tantum: l’app Meta AI si apre per la conferma. Da quel momento gli occhiali hanno sempre la precedenza: prima fotocamera, microfono e altoparlante dei Ray-Ban Meta, l’iPhone solo come riserva. La fotocamera degli occhiali si accende solo per una foto, quando chiedi qualcosa che richiede un’immagine. Gesti (sperimentale, disattivati di default, non ancora testati su occhiali reali): doppio tocco sul touchpad e Claude ascolta subito; pressione breve del tasto di acquisizione e Claude descrive ciò che vedi. Per questo la connessione agli occhiali resta aperta.")
        }
    }

    private func batteryIcon(_ level: Int) -> String {
        switch level {
        case ..<15: return "battery.0percent"
        case ..<40: return "battery.25percent"
        case ..<65: return "battery.50percent"
        case ..<90: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    // MARK: - Sprache

    private var voiceSection: some View {
        Section {
            Picker("Lingua", selection: $viewModel.config.speechLanguage) {
                ForEach(ClaudeConfig.supportedLanguages, id: \.code) { Text($0.name).tag($0.code) }
            }
            VStack(alignment: .leading) {
                LabeledContent("Invia dopo una pausa di", value: String(format: "%.1f s", viewModel.config.speechPauseThreshold))
                Slider(value: $viewModel.config.speechPauseThreshold, in: 0.5...3.0, step: 0.25)
            }
            Picker("Voce dell’iPhone", selection: $viewModel.config.appleVoiceId) {
                Text("Automatica (la migliore installata)").tag("")
                ForEach(SpeechManager.installedVoices(for: viewModel.config.speechLanguage), id: \.identifier) { voice in
                    Text("\(voice.name)\(Self.qualityLabel(voice.quality))").tag(voice.identifier)
                }
            }
            VStack(alignment: .leading) {
                LabeledContent("Velocità della voce", value: Self.rateLabel(viewModel.config.speechRate))
                Slider(value: $viewModel.config.speechRate, in: 0.35...0.65, step: 0.05)
            }
            Toggle("Parola di attivazione «Ehi Claude» / «Claudi»", isOn: $viewModel.config.wakeWordEnabled)
            Toggle("Dopo la risposta continua ad ascoltare per poco", isOn: $viewModel.config.autoListen)
            Toggle("Continua ad ascoltare con iPhone bloccato", isOn: $viewModel.config.listenWhenLocked)
            Toggle("Schermo acceso finché l’app è aperta", isOn: $viewModel.config.keepScreenOn)

            if viewModel.config.connectionMode != .channel {
                LabeledContent("Chiave ElevenLabs") {
                    SecureField("facoltativa", text: $viewModel.config.elevenLabsAPIKey)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if !viewModel.config.elevenLabsAPIKey.isEmpty {
                    Picker("Voce", selection: $viewModel.config.elevenLabsVoiceId) {
                        ForEach(ElevenLabsVoice.allVoices) { Text("\($0.name) – \($0.description)").tag($0.id) }
                    }
                }
            }
        } header: {
            HUDLabel("Lingua e voce")
        } footer: {
            Text((viewModel.config.wakeWordEnabled
                  ? "Con la parola di attivazione l’app ascolta a mani libere, come Meta AI, anche con l’iPhone bloccato in tasca (in alto a destra compare il pallino arancione del microfono). Di’ «Ehi Claude» o «Claudi» e poi la tua domanda. Il riconoscimento avviene solo sull’iPhone. "
                  : "")
                 + (viewModel.config.connectionMode == .channel
                 ? "Di default si usa la voce gratuita dell’iPhone. Una voce ElevenLabs si imposta dalla dashboard del PC. Consiglio: in Impostazioni di iOS → Accessibilità → Contenuto letto ad alta voce → Voci scarica una voce «Premium»: suona molto più naturale."
                 : "Senza chiave ElevenLabs parla la voce gratuita dell’iPhone."))
        }
    }

    private static func qualityLabel(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        if quality == .premium { return " · Premium" }
        if quality == .enhanced { return " · Avanzata" }
        return ""
    }

    private static func rateLabel(_ rate: Double) -> String {
        if rate < 0.45 { return "lenta" }
        if rate > 0.55 { return "veloce" }
        return "normale"
    }

    // MARK: - Über

    private var aboutSection: some View {
        Section {
            LabeledContent("Versione", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
            if let url = URL(string: "https://github.com/MoinMornhart/RayBanClaude") {
                Link(destination: url) { Label("Progetto su GitHub", systemImage: "chevron.left.forwardslash.chevron.right") }
            }
        } header: {
            HUDLabel("Info su RayBan Claude")
        } footer: {
            Text("Open source (MIT), fork di visionclaude. Progetto non ufficiale, non affiliato a Meta, Ray-Ban/EssilorLuxottica o Anthropic.")
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            do {
                try await viewModel.bridge.checkAuthorized()
                testResult = (true, "OK, token valido")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                testResult = (false, error.localizedDescription)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            isTesting = false
        }
    }
}

// MARK: - Eigener Modus

struct AddCustomModeView: View {
    @ObservedObject var modeManager: ModeManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedColor = "#E87B35"
    @State private var systemPrompt = ""
    @State private var quickActionsText = ""

    private let iconOptions = [
        "star.fill", "heart.fill", "flame.fill", "leaf.fill", "hammer.fill", "paintbrush.fill", "wrench.fill", "scissors",
        "cart.fill", "bag.fill", "house.fill", "car.fill", "cross.case.fill", "stethoscope", "pill.fill", "book.fill",
        "graduationcap.fill", "music.note", "camera.fill", "fork.knife", "cup.and.saucer.fill", "pawprint.fill",
        "map.fill", "lightbulb.fill",
    ]
    private let colorOptions = [
        "#E87B35", "#EF4444", "#F59E0B", "#EAB308", "#22C55E", "#06B6D4",
        "#3B82F6", "#6366F1", "#A855F7", "#EC4899", "#F43F5E", "#84CC16",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section(hud: "Nome") {
                        TextField("es. Cuoco, Giardiniere, Ripetizioni", text: $name)
                    }
                    Section(hud: "Icona") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                            ForEach(iconOptions, id: \.self) { icon in
                                let isSelected = selectedIcon == icon
                                Button { selectedIcon = icon } label: {
                                    Image(systemName: icon)
                                        .frame(width: 34, height: 34)
                                        .foregroundStyle(isSelected ? Color.white : Color.hudInk)
                                        .background(RoundedRectangle(cornerRadius: HUDMetrics.radius)
                                            .fill(isSelected ? (Color(hex: selectedColor) ?? .orange) : Color.hudSurface))
                                        .overlay(RoundedRectangle(cornerRadius: HUDMetrics.radius)
                                            .strokeBorder(isSelected ? Color.clear : Color.hudLine, lineWidth: HUDMetrics.hairline))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Section(hud: "Colore") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                            ForEach(colorOptions, id: \.self) { hex in
                                Button { selectedColor = hex } label: {
                                    Circle()
                                        .fill(Color(hex: hex) ?? .orange)
                                        .frame(width: 34, height: 34)
                                        .overlay(Circle().strokeBorder(.white, lineWidth: selectedColor == hex ? 3 : 0))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Section {
                        TextEditor(text: $systemPrompt)
                            .frame(minHeight: 110)
                            .scrollContentBackground(.hidden)
                    } header: {
                        HUDLabel("Istruzioni per Claude")
                    } footer: {
                        Text("Descrivi competenze e stile di risposta, es. «Sei un cuoco. Riconosci gli ingredienti e proponi piatti veloci.»")
                    }
                    Section {
                        TextField("Cos’è questo?, Come lo cucino?", text: $quickActionsText)
                    } header: {
                        HUDLabel("Comandi rapidi (separati da virgola)")
                    }
                }
                .hudSection()
            }
            .hudList()
            .navigationTitle("Nuova modalità")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salva") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                                  || systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let actions = quickActionsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        modeManager.addCustomMode(
            name: name.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            color: selectedColor,
            prompt: systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            quickActions: actions
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Anleitung Brille

struct RayBanInstructionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Group {
                    Section(hud: "Requisiti") {
                        Text("Ray-Ban Meta (Gen 2 o Gen 1), Oakley Meta o Meta Ray-Ban Display")
                        Text("App Meta AI (almeno versione 290) con gli occhiali già associati")
                        Text("Firmware degli occhiali aggiornato (almeno V128): l’app Meta AI propone gli aggiornamenti")
                        linkRow("Scarica l’app Meta AI", "https://apps.apple.com/app/meta-ai/id1662457680")
                    }
                    Section(hud: "1 · Attiva la modalità sviluppatore") {
                        step(1, "App Meta AI → Impostazioni → i tuoi occhiali → Modalità sviluppatore → attiva")
                        step(2, "Riavvia gli occhiali: tieni premuto il tasto per 15 secondi, poi premilo brevemente")
                        Text("Dopo un aggiornamento del firmware la modalità sviluppatore può disattivarsi: in quel caso riattivala.")
                            .font(.caption).foregroundStyle(Color.hudMuted)
                    }
                    Section(hud: "2 · Collega in RayBan Claude") {
                        step(3, "Impostazioni → «Collega gli occhiali tramite Meta AI»")
                        step(4, "Nell’app Meta AI tocca «Consenti»: tornerai qui")
                        step(5, "In basso a destra passa a «Occhiali» e conferma l’accesso alla fotocamera")
                    }
                    Section(hud: "Consigli per Gen 2") {
                        Text("Apri le aste: con le aste chiuse lo stream si ferma (riparte da solo quando le riapri).")
                        Text("Un tocco sul touchpad mette in pausa la connessione, un altro la riprende.")
                        Text("Con i gesti attivi (Impostazioni → Ray-Ban Meta): doppio tocco sul touchpad e Claude ascolta subito, senza «Ehi Claude». Pressione breve del tasto di acquisizione: foto, e Claude ti dice cosa vedi.")
                        Text("Finché i gesti sono attivi, tocco prolungato chiude la connessione (l’app si ricollega dopo qualche secondo) e lo scorrimento sull’asta potrebbe non cambiare il volume: in quel caso regolalo dall’iPhone o disattiva i gesti.")
                        Text("Claude può scattare da solo una foto nitida con gli occhiali, ad esempio per leggere un testo.")
                        Text("Sotto il 10 % di batteria gli occhiali non avviano lo stream della fotocamera.")
                    }
                    Section(hud: "Problemi?") {
                        Text("Occhiali non trovati: sono accesi, con le aste aperte e collegati nell’app Meta AI?")
                        Text("«Dispositivo non disponibile»: spegni e riaccendi gli occhiali, poi ricollegali.")
                        linkRow("Documentazione Meta Wearables", "https://wearables.developer.meta.com/docs/develop/")
                    }
                }
                .hudSection()
            }
            .hudList()
            .navigationTitle("Configura Ray-Ban Meta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Fine") { dismiss() }.fontWeight(.semibold) }
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            HUDStepBadge(number: number)
            Text(text)
        }
    }

    @ViewBuilder
    private func linkRow(_ title: String, _ urlString: String) -> some View {
        if let url = URL(string: urlString) {
            Link(destination: url) { Label(title, systemImage: "arrow.up.right.square") }
        }
    }
}
