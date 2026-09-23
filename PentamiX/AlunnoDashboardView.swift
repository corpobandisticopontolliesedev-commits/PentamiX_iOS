import SwiftUI
import Supabase

struct AlunnoDashboardView: View {
    var onLogout: () -> Void
    
    @State private var selectedTabIndex = 0
    @State private var idCollegato: String? = nil
    @State private var profiloAlunno: AlunnoProfilo? = nil
    @State private var loadingProfilo = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Top App Bar
            HStack {
                Image("logo_pentamix")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .cornerRadius(8)
                
                VStack(alignment: .leading) {
                    Text("PentamiX")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.accademiaText)
                    Text(getTabDescription())
                        .font(.system(size: 12))
                        .foregroundColor(Theme.accademiaRed)
                }
                Spacer()
                
                Button(action: {
                    Task {
                        try? await supabase.auth.signOut()
                        onLogout()
                    }
                }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(Theme.accademiaRed)
                        .font(.system(size: 20))
                }
            }
            .padding()
            .background(Theme.accademiaCard)
            
            // Content
            ZStack {
                Theme.accademiaDark.ignoresSafeArea()
                
                if loadingProfilo {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Theme.accademiaRed))
                } else if let idCollegato = idCollegato {
                    if selectedTabIndex == 0 {
                        LezioniAlunnoView(alunnoId: idCollegato)
                    } else if selectedTabIndex == 1 {
                        PagamentiAlunnoView()
                    } else {
                        DocumentiAlunnoView(alunnoId: idCollegato, profilo: profiloAlunno)
                    }
                }
            }
            
            // Bottom Navigation Bar
            HStack {
                TabBarItem(icon: "calendar", title: "Lezioni", isSelected: selectedTabIndex == 0) { selectedTabIndex = 0 }
                TabBarItem(icon: "cart.fill", title: "Contabilità", isSelected: selectedTabIndex == 1) { selectedTabIndex = 1 }
                TabBarItem(icon: "doc.text.fill", title: "Documenti", isSelected: selectedTabIndex == 2) { selectedTabIndex = 2 }
            }
            .padding(.vertical, 8)
            .background(Theme.accademiaCard)
        }
        .task {
            await fetchProfilo()
        }
    }
    
    func getTabDescription() -> String {
        switch selectedTabIndex {
        case 0: return "I tuoi prossimi appuntamenti"
        case 1: return "Situazione Contabile"
        case 2: return "Moduli e liberatorie"
        default: return ""
        }
    }
    
    func fetchProfilo() async {
        do {
            let user = try await supabase.auth.session.user
            let profili: [UtenteLoggato] = try await supabase.database
                .from("utenti")
                .select("id_collegato")
                .eq("id", value: user.id.uuidString)
                .execute()
                .value
            
            if let idColl = profili.first?.id_collegato {
                self.idCollegato = idColl
                let datiAlunno: [AlunnoProfilo] = try await supabase.database
                    .from("alunni")
                    .select("data_nascita, anno_scheda_firmata, anno_liberatoria_firmata")
                    .eq("id", value: idColl)
                    .execute()
                    .value
                self.profiloAlunno = datiAlunno.first
            }
        } catch {
            print("Errore fetch profilo: \(error)")
        }
        loadingProfilo = false
    }
}

// Viste interne

struct LezioniAlunnoView: View {
    let alunnoId: String
    @State private var lezioni: [LezioneDB] = []
    @State private var loading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Prossimi Appuntamenti")
                    .foregroundColor(Theme.accademiaMuted)
                    .font(.system(size: 14, weight: .bold))
                    .padding(.bottom, 8)
                
                if loading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Theme.accademiaRed))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                } else if lezioni.isEmpty {
                    VStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.accademiaMuted)
                        Text("Non hai lezioni pianificate in calendario.")
                            .foregroundColor(Theme.accademiaMuted)
                            .font(.system(size: 14))
                            .padding(.top, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Theme.accademiaCard)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x374151), lineWidth: 1))
                } else {
                    ForEach(lezioni) { lezione in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(formattaData(lezione.data_lezione)), \(String(lezione.ora_inizio.prefix(5)))")
                                    .foregroundColor(Theme.accademiaRed)
                                    .font(.system(size: 12, weight: .bold))
                                
                                Text(lezione.tipi_lezioni?.tipo ?? "Lezione")
                                    .foregroundColor(Theme.accademiaText)
                                    .font(.system(size: 16, weight: .bold))
                                    .padding(.vertical, 2)
                                
                                Text("Docente: \(lezione.docenti?.nome ?? "") \(lezione.docenti?.cognome ?? "")")
                                    .foregroundColor(Theme.accademiaMuted)
                                    .font(.system(size: 13))
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Theme.accademiaInput)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(16)
        }
        .task {
            await fetchLezioni()
        }
    }
    
    func fetchLezioni() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        
        do {
            let result: [LezioneDB] = try await supabase.database
                .from("registro")
                .select("id, data_lezione, ora_inizio, stato_lezione, tipi_lezioni(tipo), docenti(nome, cognome)")
                .eq("alunno_id", value: alunnoId)
                .gte("data_lezione", value: today)
                .eq("stato_lezione", value: "Pianificata")
                .execute()
                .value
            
            // Ordinamento
            self.lezioni = result.sorted { ($0.data_lezione + $0.ora_inizio) < ($1.data_lezione + $1.ora_inizio) }
        } catch {
            print("Errore fetch lezioni: \(error)")
        }
        loading = false
    }
    
    func formattaData(_ dataStr: String) -> String {
        let inFormatter = DateFormatter()
        inFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inFormatter.date(from: dataStr) else { return dataStr }
        let outFormatter = DateFormatter()
        outFormatter.dateFormat = "dd/MM/yyyy"
        return outFormatter.string(from: date)
    }
}

struct PagamentiAlunnoView: View {
    let saldoSospeso: Double = 20.00
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                HStack {
                    Text("€")
                        .foregroundColor(Theme.accademiaRed)
                        .font(.system(size: 20, weight: .bold))
                    Text("Situazione Contabile")
                        .foregroundColor(Theme.accademiaText)
                        .font(.system(size: 20, weight: .bold))
                }
                
                Text("Importo attualmente in sospeso relativo a quote o lezioni effettuate.")
                    .foregroundColor(Theme.accademiaMuted)
                    .font(.system(size: 14))
                    .padding(.top, 12)
                
                Text(String(format: "€ %.2f", saldoSospeso))
                    .foregroundColor(Color(hex: 0xFCA5A5))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .padding(.top, 24)
                
                if saldoSospeso > 0 {
                    HStack(alignment: .top) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(Color(hex: 0xFCA5A5))
                        Text("Risulta un importo da saldare. Per visualizzare il dettaglio, rivolgiti alla Segreteria.")
                            .foregroundColor(Color(hex: 0xFCA5A5))
                            .font(.system(size: 13))
                    }
                    .padding(16)
                    .background(Color(hex: 0x3F1D1D))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: 0x7F1D1D), lineWidth: 1))
                    .padding(.top, 24)
                }
            }
            .padding(24)
            .background(Theme.accademiaCard)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x374151), lineWidth: 1))
            .padding(16)
            Spacer()
        }
    }
}

struct DocumentiAlunnoView: View {
    let alunnoId: String
    let profilo: AlunnoProfilo?
    
    var isUnder14: Bool {
        guard let dataStr = profilo?.data_nascita else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let birthDate = formatter.date(from: dataStr) else { return false }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return (ageComponents.year ?? 0) < 14
    }
    
    var schedaFirmata: Bool {
        return profilo?.anno_scheda_firmata != nil && !(profilo?.anno_scheda_firmata?.isEmpty ?? true)
    }
    
    var liberatoriaFirmata: Bool {
        return profilo?.anno_liberatoria_firmata != nil && !(profilo?.anno_liberatoria_firmata?.isEmpty ?? true)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DocumentSectionView(
                    titolo: "Scheda di Iscrizione",
                    statoOk: schedaFirmata
                )
                
                if isUnder14 {
                    DocumentSectionView(
                        titolo: "Liberatoria Under 14",
                        statoOk: liberatoriaFirmata
                    )
                }
            }
            .padding(16)
        }
    }
}

struct DocumentSectionView: View {
    let titolo: String
    let statoOk: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(titolo)
                    .foregroundColor(Theme.accademiaText)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Image(systemName: statoOk ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(statoOk ? Color(hex: 0x10B981) : Theme.accademiaRed)
            }
            
            Text(statoOk ? "Archiviato regolarmente." : "Mancante. Scarica, compila e carica.")
                .foregroundColor(statoOk ? Color(hex: 0x10B981) : Theme.accademiaRed)
                .font(.system(size: 12, weight: .bold))
                .padding(.top, 4)
            
            Button(action: {}) {
                HStack {
                    Image(systemName: "arrow.down.circle")
                    Text("Scarica Modulo Vuoto")
                }
                .font(.system(size: 13))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.accademiaCard)
                .foregroundColor(Theme.accademiaText)
                .cornerRadius(8)
            }
            .padding(.top, 16)
            
            HStack(spacing: 8) {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Scatta")
                    }
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accademiaRed)
                    .foregroundColor(Theme.accademiaText)
                    .cornerRadius(8)
                }
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Allega")
                    }
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accademiaCard)
                    .foregroundColor(Theme.accademiaText)
                    .cornerRadius(8)
                }
            }
            .padding(.top, 4)
            
            if statoOk {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                        Text("Visualizza File Caricato")
                    }
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accademiaDark)
                    .foregroundColor(Theme.accademiaText)
                    .cornerRadius(8)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Theme.accademiaInput)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x374151), lineWidth: 1))
    }
}

// Elemento della Custom Tab Bar
struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Theme.accademiaText : Theme.accademiaMuted)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? Theme.accademiaText : Theme.accademiaMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Theme.accademiaRed.opacity(0.2) : Color.clear)
            .cornerRadius(8)
        }
    }
}