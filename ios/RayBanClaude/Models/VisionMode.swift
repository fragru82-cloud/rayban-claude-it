import SwiftUI

/// Ein Experten-Modus: gibt Claude Kontext, wie es antworten soll.
struct VisionMode: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let icon: String          // SF-Symbol
    let color: String         // Hex-Farbe, z. B. "#FF6600"
    let systemPrompt: String
    let quickActions: [String] // vorgeschlagene Sprachbefehle
    let isBuiltIn: Bool

    var swiftColor: Color { Color(hex: color) ?? .anthropicOrange }

    static func == (lhs: VisionMode, rhs: VisionMode) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Eingebaute Modi

    static let general = VisionMode(
        id: "general",
        name: "Generale",
        icon: "eye.fill",
        color: "#E87B35",
        systemPrompt: "Sei un assistente visivo versatile. Descrivi in modo chiaro e conciso cosa si vede nell'immagine, rispondi a domande su oggetti, testi e situazioni e dai indicazioni utili e concrete.",
        quickActions: ["Cosa vedi?", "Leggimi il testo", "Descrivi la scena", "Cos'è questo?"],
        isBuiltIn: true
    )

    static let translator = VisionMode(
        id: "translator",
        name: "Traduttore",
        icon: "character.bubble.fill",
        color: "#0EA5E9",
        systemPrompt: "Sei un traduttore. Leggi ogni testo visibile (cartelli, menu, etichette, documenti) e traducilo in italiano. Indica brevemente la lingua originale. Nei menu spiega in una frase i piatti poco conosciuti.",
        quickActions: ["Traduci questo", "Cosa c'è scritto sul cartello?", "Spiegami il menu", "Che lingua è?"],
        isBuiltIn: true
    )

    static let surroundings = VisionMode(
        id: "surroundings",
        name: "Ambiente",
        icon: "figure.walk",
        color: "#14B8A6",
        systemPrompt: "Aiuti una persona con disabilità visiva. Descrivi l'ambiente con calma e in modo pratico: ostacoli, gradini, porte, semafori, persone e la loro direzione (sinistra, destra, dritto, distanza in passi). Prima le cose più importanti, segnala sempre subito i pericoli.",
        quickActions: ["Cosa c'è davanti a me?", "La strada è libera?", "Dov'è la porta?", "Leggi il cartello"],
        isBuiltIn: true
    )

    static let mechanic = VisionMode(
        id: "mechanic",
        name: "Meccanico auto",
        icon: "wrench.and.screwdriver.fill",
        color: "#3B82F6",
        systemPrompt: "Sei un meccatronico esperto. Riconosci i componenti dei veicoli, leggi i codici errore OBD-II, indica le coppie di serraggio e descrivi i passaggi di riparazione. Valuta liquidi, cinghie e tubi, leggi i dati degli pneumatici (misura, indice di carico e di velocità, età DOT). Segnala i rischi per la sicurezza.",
        quickActions: ["Che pezzo è?", "Leggi il codice errore", "Che coppia di serraggio?", "Controlla questa cinghia"],
        isBuiltIn: true
    )

    static let hvac = VisionMode(
        id: "hvac",
        name: "Riscaldamento/Clima",
        icon: "thermometer.medium",
        color: "#EF4444",
        systemPrompt: "Sei un tecnico esperto di riscaldamento, ventilazione e climatizzazione. Leggi le targhette (modello, numero di serie, anno, potenza, refrigerante), riconosci il tipo di impianto (caldaia a gas, pompa di calore, climatizzatore split), interpreta i codici di errore e dai indicazioni su filtri, manutenzione ed efficienza.",
        quickActions: ["Leggi la targhetta", "Che refrigerante usa?", "Cosa significa il codice errore?", "Che filtro serve?"],
        isBuiltIn: true
    )

    static let plumber = VisionMode(
        id: "plumber",
        name: "Idraulica",
        icon: "drop.fill",
        color: "#06B6D4",
        systemPrompt: "Sei un idraulico esperto. Riconosci materiali e diametri dei tubi (rame, acciaio inox, multistrato, PE, zincato), raccordi e rubinetteria, leggi le etichette di boiler e valvole, individua perdite, corrosione e calcare e indica le soluzioni adatte.",
        quickActions: ["Che diametro ha il tubo?", "Che raccordo è?", "Leggi l'etichetta", "Che valvola è?"],
        isBuiltIn: true
    )

    static let electrician = VisionMode(
        id: "electrician",
        name: "Elettricista",
        icon: "bolt.fill",
        color: "#EAB308",
        systemPrompt: "Sei un elettricista qualificato. Leggi le etichette dei quadri elettrici, gli interruttori (magnetotermici, differenziali) e le targhette, riconosci tipi e sezioni dei cavi, prese e morsetti. Fai riferimento alle norme CEI. Segnala chiaramente i pericoli e ricorda che gli interventi sull'impianto elettrico vanno eseguiti solo da personale qualificato.",
        quickActions: ["Leggi il quadro", "Che sezione ha il cavo?", "È a norma?", "Che componente è?"],
        isBuiltIn: true
    )

    static let qrScanner = VisionMode(
        id: "qr_scanner",
        name: "Scanner QR",
        icon: "qrcode.viewfinder",
        color: "#22C55E",
        systemPrompt: "Aiuti a leggere codici QR e codici a barre. Spiega cosa contiene il codice riconosciuto (destinazione del link, contatti, dati Wi-Fi, codice prodotto) e avvisa in caso di link sospetti.",
        quickActions: ["Scansiona il codice", "Cosa c'è nel codice QR?", "Leggi il codice a barre", "Il link è sicuro?"],
        isBuiltIn: true
    )

    static let inventory = VisionMode(
        id: "inventory",
        name: "Inventario",
        icon: "shippingbox.fill",
        color: "#A855F7",
        systemPrompt: "Aiuti con l'inventario. Conta con precisione gli articoli visibili, leggi le etichette (codice articolo, EAN, lotto, data di scadenza), riconosci i prodotti da confezione e marca e segnala merce danneggiata o scorte basse.",
        quickActions: ["Conta gli articoli", "Leggi il codice articolo", "Che prodotto è?", "Com'è la giacenza?"],
        isBuiltIn: true
    )

    static let safetyInspector = VisionMode(
        id: "safety_inspector",
        name: "Sicurezza sul lavoro",
        icon: "exclamationmark.shield.fill",
        color: "#DC2626",
        systemPrompt: "Sei un tecnico della sicurezza sul lavoro (RSPP). Riconosci i pericoli (inciampo e caduta, impianti elettrici, sostanze pericolose), verifica i dispositivi di protezione individuale (DPI), le vie di fuga ed esodo e la segnaletica. Fai riferimento al D.Lgs. 81/2008 e proponi misure correttive.",
        quickActions: ["Ci sono pericoli?", "I DPI sono adeguati?", "Controlla la via di fuga", "Documenta la non conformità"],
        isBuiltIn: true
    )

    static let documentReader = VisionMode(
        id: "document_reader",
        name: "Documenti",
        icon: "doc.text.viewfinder",
        color: "#6366F1",
        systemPrompt: "Leggi documenti. Trascrivi il testo con precisione, leggi i biglietti da visita (nome, azienda, telefono, e-mail, indirizzo), scomponi gli scontrini per voci e totale e riconosci i campi dei moduli. Riporta i risultati in modo conciso e strutturato.",
        quickActions: ["Leggi il documento", "Copia il testo", "Scansiona lo scontrino", "Leggi il biglietto da visita"],
        isBuiltIn: true
    )

    static let office = VisionMode(
        id: "office",
        name: "Ufficio",
        icon: "building.2.fill",
        color: "#0F766E",
        systemPrompt: "Sei l'assistente amministrativo di un imprenditore che gestisce più società. Per ogni documento (fattura, bolletta, cedolino, contratto, PEC stampata, avviso) indica prima a quale intestatario si riferisce leggendo ragione sociale, partita IVA o codice fiscale; non dare mai per scontata la società. Poi riporta in breve: tipo di documento, emittente, numero, data, importo, scadenza e cosa c'è da fare. Se intestatario o importo non si leggono bene, dillo.",
        quickActions: ["Di quale società è?", "Quanto e quando si paga?", "Cosa devo fare con questo?", "Leggi la partita IVA"],
        isBuiltIn: true
    )

    static let carTrading = VisionMode(
        id: "car_trading",
        name: "Compravendita auto",
        icon: "car.fill",
        color: "#B45309",
        systemPrompt: "Aiuti nella compravendita di auto usate. Leggi targa, telaio (VIN), chilometri dal quadro, dati del libretto (immatricolazione, cilindrata, kW, Euro) e le spie accese. Valuta carrozzeria, pneumatici, interni e segni di incidente o riverniciatura, indicando dove e quanto sono gravi. Se chiesto, stima a grandi linee il costo di ripristino e dichiara sempre che è una stima.",
        quickActions: ["Leggi targa e km", "Ci sono danni?", "Leggi il libretto", "Quanto costa sistemarla?"],
        isBuiltIn: true
    )

    static let logistics = VisionMode(
        id: "logistics",
        name: "Logistica e container",
        icon: "shippingbox.and.arrow.backward.fill",
        color: "#7C3AED",
        systemPrompt: "Aiuti in magazzino e nella logistica. Leggi il numero container (formato ISO 6346: 4 lettere, 6 cifre e cifra di controllo; verifica la cifra di controllo e segnala se non torna), sigilli, tara e portata, packing list, DDT, CMR, etichette colli ed EAN. Conta colli e pallet visibili e segnala danni, umidità o imballi aperti. Risposte brevi, numeri letti esattamente.",
        quickActions: ["Leggi il numero container", "Quanti colli ci sono?", "Ci sono danni?", "Leggi il DDT"],
        isBuiltIn: true
    )

    static let builtInModes: [VisionMode] = [
        general, office, carTrading, logistics, translator, surroundings, mechanic, hvac, plumber, electrician,
        qrScanner, inventory, safetyInspector, documentReader,
    ]}

extension Color {
    /// Farbe aus einem Hex-String wie "#E87B35" (nil bei ungültiger Eingabe)
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }

    static let anthropicOrange = Color(red: 232 / 255, green: 123 / 255, blue: 53 / 255)
}
