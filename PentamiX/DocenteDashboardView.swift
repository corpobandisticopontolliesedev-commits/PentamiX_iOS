import SwiftUI
import Supabase

// MARK: - Modelli di Inserimento / Aggiornamento
struct RegistroInsertUpdate: Codable {
    let id: String?
    let docente_id: String?
    let docente_sostituito_id: String?
    let tipo_lezione_id: String?
    let alunno_id: String?
    let ora_inizio: String
    let durata_minuti: Int
    let note: String
    let stato_lezione: String
    let contabilizza_docente: Bool
    let anno_accademico: String
    let data_lezione: String
    let recurrence_group_id: String?
}

struct RegistroFutureUpdate: Codable {
    let docente_id: String?
    let docente_sostituito_id: String?
    let tipo_lezione_id: String?
    let alunno_id: String?
    let ora_inizio: String
    let durata_minuti: Int
    let note: String
    let contabilizza_docente: Bool
    let anno_accademico: String
}

struct StatoLezioneUpdate: Codable {
    let stato_lezione: String
}

struct NuovoAlunnoInsert: Codable {
    let nome: String
    let cognome: String
    let email: String?
    let cellulare: String?
    let stato: String
    let school_id: String?
    let indirizzo: String?
    let numero_civico: String?
    let cap: String?
    let paese: String?
    let provincia: String?
    let nome_genitore: String?
    let email_genitore: String?
    let cellulare_genitore: String?
    let codice_fiscale: String?
    let data_nascita: String?
    let luogo_nascita: String?
    let provincia_nascita: String?
    let numero_tessera: String?
}

struct AlunnoUpdate: Codable {
    let nome: String
    let cognome: String
    let email: String?
    let cellulare: String?
    let indirizzo: String?
    let numero_civico: String?
    let cap: String?
    let paese: String?
    let provincia: String?
    let nome_genitore: String?
    let email_genitore: String?
    let cellulare_genitore: String?
    let codice_fiscale: String?
    let data_nascita: String?
    let luogo_nascita: String?
    let provincia_nascita: String?
    let numero_tessera: String?
}

struct AssociazioneInsert: Codable {
    let alunno_id: String
    let docente_id: String
}

// MARK: - View Principale
struct DocenteDashboardView: View {
    var onLogout: () -> Void
    @State private var selectedTabIndex = 0
    
    @State private var docenteId: String? = nil
    @State private var schoolId: String? = nil
    @State private var alunniList: [AlunnoRef] = []
    @State private var tipiLezioniList: [TipiLezioni] = []
    @State private var loading = true
    
    var body: some View {
        VStack(spacing: 0) {
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
            
            ZStack {
                Theme.accademiaDark.ignoresSafeArea()
                
                if loading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.accademiaRed))
                        .scaleEffect(1.5)
                } else if let docId = docenteId {
                    tabContent(for: docId)
                }
            }
            
            HStack {
                TabBarItem(icon: "calendar", title: "Agenda", isSelected: selectedTabIndex == 0) { selectedTabIndex = 0 }
                TabBarItem(icon: "list.bullet", title: "Registro", isSelected: selectedTabIndex == 1) { selectedTabIndex = 1 }
                TabBarItem(icon: "person.2.fill", title: "Alunni", isSelected: selectedTabIndex == 2) { selectedTabIndex = 2 }
            }
            .padding(.vertical, 8)
            .background(Theme.accademiaCard)
        }
        .task {
            await fetchInitialData()
        }
    }
    
    // Estratto in una funzione @ViewBuilder separata con uno switch:
    // risolve l'errore "Generic parameter 'C'/'R'/'Content'/'Label' could not be inferred"
    // causato da un if/else-if annidato dentro un if-let dentro uno ZStack, che mandava
    // in crisi il type-checker di Swift su questa combinazione di viste eterogenee.
    @ViewBuilder
    private func tabContent(for docId: String) -> some View {
        switch selectedTabIndex {
        case 0:
            AgendaDocenteView(
                docenteId: docId,
                schoolId: schoolId,
                alunniList: alunniList,
                tipiLezioniList: tipiLezioniList
            )
        case 1:
            RegistroDocenteView(
                docenteId: docId,
                schoolId: schoolId,
                alunniList: alunniList,
                tipiLezioniList: tipiLezioniList
            )
        default:
            RubricaDocenteView(
                docenteId: docId,
                schoolId: schoolId,
                onAlunnoAggiunto: { nuovoAlunno in
                    let ref = AlunnoRef(id: nuovoAlunno.id, nome: nuovoAlunno.nome, cognome: nuovoAlunno.cognome)
                    self.alunniList.append(ref)
                    self.alunniList.sort { $0.cognome < $1.cognome }
                }
            )
        }
    }
    
    func getTabDescription() -> String {
        switch selectedTabIndex {
        case 0: return "Orario Settimanale"
        case 1: return "Storico e consuntivazione"
        case 2: return "Rubrica allievi"
        default: return ""
        }
    }
    
    func fetchInitialData() async {
        loading = true
        do {
            let user = try await supabase.auth.session.user
            let profili: [UtenteLoggato] = try await supabase.from("utenti")
                .select("id_collegato, school_id")
                .eq("id", value: user.id.uuidString)
                .execute()
                .value
            
            guard let profilo = profili.first,
                  let currentDocenteId = profilo.id_collegato,
                  let currentSchoolId = profilo.school_id else {
                loading = false
                return
            }
            
            self.docenteId = currentDocenteId
            self.schoolId = currentSchoolId
            
            let assoc: [AssociazioneDocente] = try await supabase.from("associazioni")
                .select("alunni(id, nome, cognome)")
                .eq("docente_id", value: currentDocenteId)
                .execute()
                .value
            
            self.alunniList = assoc.compactMap { $0.alunni }
                .map { AlunnoRef(id: $0.id, nome: $0.nome, cognome: $0.cognome) }
                .sorted { $0.cognome < $1.cognome }
            
            let aaList: [AnnoAccademico] = try await supabase.from("anni_accademici")
                .select()
                .eq("school_id", value: currentSchoolId)
                .eq("is_current", value: true)
                .execute()
                .value
            
            let annoCorrente = aaList.first?.anno ?? "2026/2027"
            
            let tariffe: [TariffaRef] = try await supabase.from("tariffe")
                .select("tipo_lezione")
                .eq("school_id", value: currentSchoolId)
                .eq("anno_accademico", value: annoCorrente)
                .execute()
                .value
            
            let tipiConTariffa = Set(tariffe.map { $0.tipo_lezione })
            
            let competenze: [CompetenzaRef] = try await supabase.from("docenti_tipi_lezioni")
                .select("tipo_lezione_id")
                .eq("docente_id", value: currentDocenteId)
                .execute()
                .value
            
            let competenzeIds = competenze.map { $0.tipo_lezione_id }
            
            if !competenzeIds.isEmpty {
                let allTipi: [TipiLezioni] = try await supabase.from("tipi_lezioni")
                    .select()
                    .eq("school_id", value: currentSchoolId)
                    .eq("attivo", value: true)
                    .execute()
                    .value
                
                var uniqueTipi: [String: TipiLezioni] = [:]
                for tipo in allTipi {
                    if competenzeIds.contains(tipo.id) && tipiConTariffa.contains(tipo.tipo) {
                        if uniqueTipi[tipo.tipo] == nil {
                            uniqueTipi[tipo.tipo] = tipo
                        }
                    }
                }
                self.tipiLezioniList = uniqueTipi.values.sorted { $0.tipo < $1.tipo }
            }
            
        } catch {
            print("Errore fetch dati base docente: \(error)")
        }
        loading = false
    }
}

// MARK: - Agenda View
struct AgendaDocenteView: View {
    let docenteId: String
    let schoolId: String?
    let alunniList: [AlunnoRef]
    let tipiLezioniList: [TipiLezioni]
    
    @State private var selectedDate = Date()
    @State private var lezioni: [LezioneCompleta] = []
    @State private var loading = true
    @State private var showDatePicker = false
    @State private var showEventModal = false
    @State private var editingLezione: LezioneCompleta? = nil
    
    let queryFormatter: DateFormatter = { let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; return df }()
    let displayFormatter: DateFormatter = { let df = DateFormatter(); df.dateFormat = "dd/MM/yyyy"; return df }()
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button(action: { changeDate(by: -1) }) { Image(systemName: "arrow.left").foregroundColor(Theme.accademiaText).font(.system(size: 20)) }
                    Spacer()
                    VStack {
                        Text(displayFormatter.string(from: selectedDate)).font(.system(size: 18, weight: .bold)).foregroundColor(Theme.accademiaText)
                        Text("Cambia Data").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.accademiaRed)
                    }.onTapGesture { showDatePicker = true }
                    Spacer()
                    Button(action: { changeDate(by: 1) }) { Image(systemName: "arrow.right").foregroundColor(Theme.accademiaText).font(.system(size: 20)) }
                }
                .padding()
                
                agendaListContent
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        editingLezione = LezioneCompleta(
                            id: nil, data_lezione: queryFormatter.string(from: selectedDate), ora_inizio: getNextHalfHour(),
                            durata_minuti: 60, stato_lezione: "Pianificata", alunno_id: nil, tipo_lezione_id: nil, docente_id: docenteId, note: nil,
                            importo_saldato: nil, docente_sostituito_id: nil, recurrence_group_id: nil, contabilizza_docente: true,
                            alunni: nil, tipi_lezioni: nil, docenti: nil
                        )
                        showEventModal = true
                    }) {
                        Image(systemName: "plus").font(.system(size: 24, weight: .bold)).foregroundColor(Theme.accademiaText)
                            .frame(width: 56, height: 56).background(Theme.accademiaRed).clipShape(Circle()).shadow(radius: 4)
                    }.padding()
                }
            }
        }
        .task(id: selectedDate) { await fetchAgenda() }
        .sheet(isPresented: $showDatePicker) {
            VStack {
                DatePicker("Seleziona Data", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle()).colorScheme(.dark).accentColor(Theme.accademiaRed).padding()
                Button("OK") { showDatePicker = false }.font(.system(size: 16, weight: .bold)).foregroundColor(Theme.accademiaRed).padding()
            }.background(Theme.accademiaCard).presentationDetents([.medium])
        }
        .sheet(item: $editingLezione) { lezione in
            ModalEventoDialog(
                lezione: lezione, schoolId: schoolId, alunniList: alunniList, tipiLezioniList: tipiLezioniList,
                onDismiss: { editingLezione = nil },
                onSave: { Task { await fetchAgenda(); editingLezione = nil } }
            )
        }
    }
    
    @ViewBuilder
    private var agendaListContent: some View {
        if loading {
            Spacer(); ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Theme.accademiaRed)); Spacer()
        } else if lezioni.isEmpty {
            Spacer(); Text("Nessuna lezione in agenda.").foregroundColor(Theme.accademiaMuted).font(.system(size: 16)); Spacer()
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(lezioni, id: \.id) { l in
                        agendaRow(for: l)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 80)
            }
        }
    }
    
    @ViewBuilder
    private func agendaRow(for l: LezioneCompleta) -> some View {
        let isGruppo = l.tipi_lezioni?.modalita == "Collettiva"
        Button(action: { editingLezione = l; showEventModal = true }) {
            HStack(alignment: .center) {
                VStack {
                    Text(String(l.ora_inizio.prefix(5))).foregroundColor(Theme.accademiaRed).font(.system(size: 16, weight: .bold))
                    Text("\(l.durata_minuti ?? 60) min").foregroundColor(Theme.accademiaMuted).font(.system(size: 10))
                }.frame(width: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isGruppo ? "Gruppo: \(l.tipi_lezioni?.tipo ?? "")" : (l.alunni != nil ? "\(l.alunni!.cognome) \(l.alunni!.nome)" : "Attività / Riunione"))
                        .foregroundColor(Theme.accademiaText).font(.system(size: 16, weight: .bold)).multilineTextAlignment(.leading)
                    Text(l.tipi_lezioni?.tipo ?? "N.D.").foregroundColor(Theme.accademiaMuted).font(.system(size: 13))
                    if l.docente_sostituito_id != nil { Text("Supplenza").foregroundColor(Color(hex: 0xF59E0B)).font(.system(size: 11, weight: .bold)) }
                    if let note = l.note, !note.isEmpty { Text("Note: \(note)").foregroundColor(Color(hex: 0xF59E0B)).font(.system(size: 11)).lineLimit(2) }
                }.padding(.leading, 12)
                Spacer()
                Text(l.stato_lezione.uppercased())
                    .font(.system(size: 9, weight: .bold)).foregroundColor(colorForStato(l.stato_lezione))
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(colorForStato(l.stato_lezione).opacity(0.2)).cornerRadius(6)
            }
            .padding(16).background(Theme.accademiaInput).cornerRadius(12)
        }.buttonStyle(PlainButtonStyle())
    }
    
    func changeDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    func getNextHalfHour() -> String {
        let now = Date()
        let cal = Calendar.current
        let minute = cal.component(.minute, from: now)
        var nextDate = now
        if minute < 30 {
            nextDate = cal.date(bySetting: .minute, value: 30, of: now)!
        } else {
            nextDate = cal.date(byAdding: .hour, value: 1, to: now)!
            nextDate = cal.date(bySetting: .minute, value: 0, of: nextDate)!
        }
        let df = DateFormatter(); df.dateFormat = "HH:mm:ss"; return df.string(from: nextDate)
    }
    
    func colorForStato(_ stato: String) -> Color {
        switch stato {
        case "Svolta": return Color(hex: 0x10B981)
        case "Alunno Assente", "Docente Assente": return Theme.accademiaRed
        default: return Color(hex: 0x3B82F6)
        }
    }
    
    func fetchAgenda() async {
        loading = true
        let dateStr = queryFormatter.string(from: selectedDate)
        do {
            let result: [LezioneCompleta] = try await supabase.from("registro")
                .select("id, data_lezione, ora_inizio, durata_minuti, stato_lezione, note, alunno_id, tipo_lezione_id, docente_id, importo_saldato, docente_sostituito_id, recurrence_group_id, contabilizza_docente, tipi_lezioni(id, tipo, modalita, colore_hex, durata_minuti), alunni(id, nome, cognome)")
                .eq("docente_id", value: docenteId)
                .eq("data_lezione", value: dateStr)
                .execute().value
            self.lezioni = result.sorted { $0.ora_inizio < $1.ora_inizio }
        } catch { print(error) }
        loading = false
    }
}

// MARK: - Registro View
struct RegistroDocenteView: View {
    let docenteId: String
    let schoolId: String?
    let alunniList: [AlunnoRef]
    let tipiLezioniList: [TipiLezioni]
    
    @State private var lezioni: [LezioneCompleta] = []
    @State private var loading = true
    @State private var statoFilter = "Pianificate"
    @State private var showFilters = false
    @State private var editingLezione: LezioneCompleta? = nil
    
    let stati = ["Tutti gli stati", "Pianificate", "Svolta", "Alunno Assente", "Docente Assente"]
    let displayFormatter: DateFormatter = { let df = DateFormatter(); df.dateFormat = "dd/MM/yyyy"; return df }()
    let queryFormatter: DateFormatter = { let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; return df }()
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Button(action: { showFilters.toggle() }) {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease").foregroundColor(Theme.accademiaMuted)
                            Text("Filtri").foregroundColor(Theme.accademiaText)
                        }.padding(8).background(Theme.accademiaInput).cornerRadius(8)
                    }
                    Spacer()
                }.padding(16)
                
                if showFilters {
                    VStack(alignment: .leading) {
                        Text("Filtro Stato").font(.system(size: 12)).foregroundColor(Theme.accademiaMuted)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(stati, id: \.self) { stato in
                                    Text(stato).font(.system(size: 12)).padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(statoFilter == stato ? Theme.accademiaRed : Theme.accademiaCard)
                                        .foregroundColor(Theme.accademiaText).cornerRadius(16)
                                        .onTapGesture { statoFilter = stato }
                                }
                            }
                        }
                    }.padding(16).background(Theme.accademiaInput).padding(.horizontal, 16)
                }
                
                registroListContent
            }
        }
        .task(id: statoFilter) { await fetchRegistro() }
        .sheet(item: $editingLezione) { lezione in
            ModalEventoDialog(
                lezione: lezione, schoolId: schoolId, alunniList: alunniList, tipiLezioniList: tipiLezioniList,
                onDismiss: { editingLezione = nil },
                onSave: { Task { await fetchRegistro(); editingLezione = nil } }
            )
        }
    }
    
    @ViewBuilder
    private var registroListContent: some View {
        if loading {
            Spacer(); ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Theme.accademiaRed)); Spacer()
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(lezioni, id: \.id) { l in
                        registroRow(for: l)
                    }
                }.padding(16)
            }
        }
    }
    
    @ViewBuilder
    private func registroRow(for l: LezioneCompleta) -> some View {
        let safeDate = queryFormatter.date(from: l.data_lezione) ?? Date()
        let isPastOrToday = safeDate <= Date()
        
        Button(action: { editingLezione = l }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(displayFormatter.string(from: safeDate)) - \(String(l.ora_inizio.prefix(5)))")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(Theme.accademiaMuted)
                    Text(l.alunni != nil ? "\(l.alunni!.cognome) \(l.alunni!.nome)" : "Attività / Riunione")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(Theme.accademiaText).multilineTextAlignment(.leading)
                    Text(l.tipi_lezioni?.tipo ?? "").font(.system(size: 12)).foregroundColor(Theme.accademiaMuted)
                    if l.docente_sostituito_id != nil { Text("Supplenza").font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: 0xF59E0B)) }
                }
                Spacer()
                
                if l.stato_lezione == "Pianificata" && isPastOrToday {
                    HStack(spacing: 8) {
                        Button(action: { updateStato(id: l.id!, stato: "Svolta") }) {
                            Image(systemName: "checkmark").foregroundColor(Color(hex: 0x10B981)).frame(width: 36, height: 36)
                                .background(Color(hex: 0x10B981).opacity(0.2)).cornerRadius(8)
                        }.buttonStyle(PlainButtonStyle())
                        Button(action: { updateStato(id: l.id!, stato: "Alunno Assente") }) {
                            Image(systemName: "xmark").foregroundColor(Theme.accademiaRed).frame(width: 36, height: 36)
                                .background(Theme.accademiaRed.opacity(0.2)).cornerRadius(8)
                        }.buttonStyle(PlainButtonStyle())
                    }
                } else {
                    Text(l.stato_lezione)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(l.stato_lezione == "Svolta" ? Color(hex: 0x10B981) : Theme.accademiaRed)
                }
            }
            .padding(12).background(Theme.accademiaInput).cornerRadius(8)
        }.buttonStyle(PlainButtonStyle())
    }
    
    func fetchRegistro() async {
        loading = true
        do {
            var query = supabase.from("registro")
                .select("id, data_lezione, ora_inizio, durata_minuti, stato_lezione, alunno_id, tipo_lezione_id, docente_id, importo_saldato, note, docente_sostituito_id, recurrence_group_id, contabilizza_docente, tipi_lezioni(id, tipo, modalita, colore_hex, durata_minuti), alunni(id, nome, cognome)")
                .eq("docente_id", value: docenteId)
            
            if statoFilter == "Pianificate" { query = query.eq("stato_lezione", value: "Pianificata") }
            else if statoFilter != "Tutti gli stati" { query = query.eq("stato_lezione", value: statoFilter) }
            
            let result: [LezioneCompleta] = try await query.execute().value
            self.lezioni = Array(result.sorted { ($0.data_lezione + $0.ora_inizio) < ($1.data_lezione + $1.ora_inizio) }.prefix(100))
        } catch { print(error) }
        loading = false
    }
    
    func updateStato(id: String, stato: String) {
        Task {
            do {
                try await supabase.from("registro").update(StatoLezioneUpdate(stato_lezione: stato)).eq("id", value: id).execute()
                await fetchRegistro()
            } catch { print(error) }
        }
    }
}

// MARK: - Rubrica View
struct RubricaDocenteView: View {
    let docenteId: String
    let schoolId: String?
    var onAlunnoAggiunto: (AlunnoDettaglio) -> Void
    
    @State private var alunni: [AlunnoDettaglio] = []
    @State private var searchQuery = ""
    @State private var loading = true
    @State private var selectedAlunno: AlunnoDettaglio? = nil
    @State private var showNewAlunno = false
    @State private var annoAccademicoCorrente = ""
    
    var filteredAlunni: [AlunnoDettaglio] {
        if searchQuery.isEmpty { return alunni }
        return alunni.filter { $0.nome.localizedCaseInsensitiveContains(searchQuery) || $0.cognome.localizedCaseInsensitiveContains(searchQuery) }
    }
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.accademiaMuted)
                    
                    TextField("Cerca alunno per nome o cognome...", text: $searchQuery)
                        .foregroundColor(Theme.accademiaText)
                        .autocapitalization(.none)
                }
                .padding(12)
                .background(Theme.accademiaInput)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accademiaCard, lineWidth: 1))
                .padding(16)
                
                rubricaListContent
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showNewAlunno = true }) {
                        Image(systemName: "plus").font(.system(size: 24, weight: .bold)).foregroundColor(Theme.accademiaText)
                            .frame(width: 56, height: 56).background(Theme.accademiaRed).clipShape(Circle()).shadow(radius: 4)
                    }.padding()
                }
            }
        }
        .task { await fetchAlunni() }
        .sheet(item: $selectedAlunno) { alunno in
            SchedaAlunnoModal(alunno: alunno, onDismiss: { selectedAlunno = nil }, onSave: { Task { await fetchAlunni(); selectedAlunno = nil } })
        }
        .sheet(isPresented: $showNewAlunno) {
            ModalNuovoAlunnoDialog(
                schoolId: schoolId, docenteId: docenteId,
                onDismiss: { showNewAlunno = false },
                onSave: { a in onAlunnoAggiunto(a); showNewAlunno = false; Task { await fetchAlunni() } }
            )
        }
    }
    
    @ViewBuilder
    private var rubricaListContent: some View {
        if loading {
            Spacer(); ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Theme.accademiaRed)); Spacer()
        } else if filteredAlunni.isEmpty {
            Spacer(); Text("Nessun alunno trovato.").foregroundColor(Theme.accademiaMuted); Spacer()
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(filteredAlunni) { a in
                        rubricaRow(for: a)
                    }
                }.padding(.horizontal, 16).padding(.bottom, 80)
            }
        }
    }
    
    @ViewBuilder
    private func rubricaRow(for a: AlunnoDettaglio) -> some View {
        let u14 = isUnder14(data: a.data_nascita)
        let schedaOk = a.anno_scheda_firmata == annoAccademicoCorrente
        let libOk = a.anno_liberatoria_firmata == annoAccademicoCorrente
        
        Button(action: { selectedAlunno = a }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(a.cognome) \(a.nome)").font(.system(size: 16, weight: .bold)).foregroundColor(Theme.accademiaText)
                    Spacer()
                    Text(a.stato ?? "Attivo")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(a.stato == "Sospeso" ? Color(hex: 0xF59E0B) : Color(hex: 0x10B981))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(a.stato == "Sospeso" ? Color(hex: 0xF59E0B).opacity(0.2) : Color(hex: 0x10B981).opacity(0.2))
                        .cornerRadius(16)
                }
                
                if let ind = a.indirizzo, !ind.isEmpty {
                    Text("\(ind) \(a.numero_civico ?? ""), \(a.cap ?? "") \(a.paese ?? "")")
                        .font(.system(size: 11)).foregroundColor(Theme.accademiaMuted)
                }
                
                HStack(spacing: 16) {
                    if let cell = a.cellulare, !cell.isEmpty {
                        HStack(spacing: 4) { Image(systemName: "phone.fill"); Text(cell) }.font(.system(size: 12)).foregroundColor(Theme.accademiaMuted)
                    }
                    if let email = a.email, !email.isEmpty {
                        HStack(spacing: 4) { Image(systemName: "envelope.fill"); Text(String(email.prefix(15)) + "...") }.font(.system(size: 12)).foregroundColor(Theme.accademiaMuted)
                    }
                }
                
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: schedaOk ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(schedaOk ? Color(hex: 0x10B981) : Theme.accademiaRed).font(.system(size: 12))
                        Text("Iscriz.").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.accademiaMuted)
                    }
                    if u14 {
                        HStack(spacing: 4) {
                            Image(systemName: libOk ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(libOk ? Color(hex: 0x10B981) : Color(hex: 0xF59E0B)).font(.system(size: 12))
                            Text("Lib. U14").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.accademiaMuted)
                        }.padding(.leading, 12)
                    }
                }
            }
            .padding(16).background(Theme.accademiaInput).cornerRadius(12)
        }.buttonStyle(PlainButtonStyle())
    }
    
    func fetchAlunni() async {
        loading = true
        do {
            var aaQuery = supabase.from("anni_accademici").select().eq("is_current", value: true)
            if let sid = schoolId { aaQuery = aaQuery.eq("school_id", value: sid) }
            let aaList: [AnnoAccademico] = try await aaQuery.execute().value
            annoAccademicoCorrente = aaList.first?.anno ?? "2026/2027"
            
            let result: [AssociazioneDocente] = try await supabase.from("associazioni")
                .select("alunni(id, nome, cognome, email, cellulare, stato, anno_scheda_firmata, anno_liberatoria_firmata, data_nascita, indirizzo, numero_civico, cap, paese, provincia, nome_genitore, email_genitore, cellulare_genitore, codice_fiscale, luogo_nascita, provincia_nascita, numero_tessera)")
                .eq("docente_id", value: docenteId).execute().value
            self.alunni = result.compactMap { $0.alunni }.sorted { $0.cognome < $1.cognome }
        } catch { print(error) }
        loading = false
    }
    
    func isUnder14(data: String?) -> Bool {
        guard let data = data else { return false }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: data) else { return false }
        let age = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
        return age < 14
    }
}

// MARK: - Modale Editabile Scheda Alunno
struct SchedaAlunnoModal: View {
    let alunno: AlunnoDettaglio
    var onDismiss: () -> Void
    var onSave: () -> Void
    
    @State private var isEditing = false
    @State private var saving = false
    
    @State private var nome: String
    @State private var cognome: String
    @State private var email: String
    @State private var cellulare: String
    @State private var indirizzo: String
    @State private var nCivico: String
    @State private var citta: String
    @State private var cap: String
    @State private var prov: String
    @State private var nomeGenitore: String
    @State private var emailGenitore: String
    @State private var cellulareGenitore: String
    @State private var codiceFiscale: String
    @State private var dataNascita: Date
    @State private var luogoNascita: String
    @State private var provNascita: String
    @State private var numeroTessera: String
    
    init(alunno: AlunnoDettaglio, onDismiss: @escaping () -> Void, onSave: @escaping () -> Void) {
        self.alunno = alunno
        self.onDismiss = onDismiss
        self.onSave = onSave
        
        _nome = State(initialValue: alunno.nome)
        _cognome = State(initialValue: alunno.cognome)
        _email = State(initialValue: alunno.email ?? "")
        _cellulare = State(initialValue: alunno.cellulare ?? "")
        _indirizzo = State(initialValue: alunno.indirizzo ?? "")
        _nCivico = State(initialValue: alunno.numero_civico ?? "")
        _citta = State(initialValue: alunno.paese ?? "")
        _cap = State(initialValue: alunno.cap ?? "")
        _prov = State(initialValue: alunno.provincia ?? "")
        _nomeGenitore = State(initialValue: alunno.nome_genitore ?? "")
        _emailGenitore = State(initialValue: alunno.email_genitore ?? "")
        _cellulareGenitore = State(initialValue: alunno.cellulare_genitore ?? "")
        _codiceFiscale = State(initialValue: alunno.codice_fiscale ?? "")
        _luogoNascita = State(initialValue: alunno.luogo_nascita ?? "")
        _provNascita = State(initialValue: alunno.provincia_nascita ?? "")
        _numeroTessera = State(initialValue: alunno.numero_tessera ?? "")
        
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        _dataNascita = State(initialValue: df.date(from: alunno.data_nascita ?? "") ?? Date())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Modifica Alunno" : "Scheda Alunno")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.accademiaText)
                Spacer()
                if !isEditing {
                    Button(action: { isEditing = true }) {
                        Image(systemName: "pencil").foregroundColor(Theme.accademiaText).padding(.trailing, 12)
                    }
                }
                Button(action: onDismiss) { Image(systemName: "xmark").foregroundColor(Theme.accademiaMuted) }
            }.padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    anagraficaSection
                    residenzaSection
                    genitoreSection
                    datiFiscaliSection
                }.padding(.horizontal).padding(.bottom, 20)
            }
            
            schedaFooter
        }
        .background(Theme.accademiaDark)
        .preferredColorScheme(.dark)
    }
    
    @ViewBuilder
    private var schedaFooter: some View {
        if isEditing {
            Button(action: executeUpdate) {
                Text(saving ? "Salvataggio..." : "Salva Modifiche")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.accademiaText)
                    .frame(maxWidth: .infinity).padding()
                    .background(Theme.accademiaRed).cornerRadius(8)
            }
            .disabled(saving || nome.isEmpty || cognome.isEmpty)
            .padding()
        } else {
            let cellToCall = (alunno.cellulare_genitore?.isEmpty == false) ? alunno.cellulare_genitore : alunno.cellulare
            if let cell = cellToCall, !cell.isEmpty {
                Button(action: { if let url = URL(string: "tel:\(cell)") { UIApplication.shared.open(url) } }) {
                    HStack {
                        Image(systemName: "phone.fill").foregroundColor(Color(hex: 0x10B981))
                        Text("Chiama \(cell)").foregroundColor(Theme.accademiaText)
                    }.frame(maxWidth: .infinity).padding().background(Theme.accademiaInput).cornerRadius(8)
                }.padding(.horizontal).padding(.bottom, 8)
            }
            
            Button(action: onDismiss) {
                Text("Chiudi").font(.system(size: 16, weight: .bold)).foregroundColor(Theme.accademiaText)
                    .frame(maxWidth: .infinity).padding().background(Theme.accademiaRed).cornerRadius(8)
            }.padding(.horizontal).padding(.bottom)
        }
    }
    
    // Ogni sezione della scheda estratta separatamente: il "Group" con dentro un if/else
    // (campo Data Nascita: DatePicker vs Text) combinato con più righe era il blocco che
    // mandava in crisi il type-checker, causando gli errori spuri su 'TableColumnBuilder'.
    @ViewBuilder
    private var anagraficaSection: some View {
        Text("ANAGRAFICA ALUNNO").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.accademiaRed)
        HStack { EditableTextField(label: "Nome", text: $nome, isEditing: isEditing); EditableTextField(label: "Cognome", text: $cognome, isEditing: isEditing) }
        EditableTextField(label: "Email", text: $email, isEditing: isEditing, keyboardType: .emailAddress)
        EditableTextField(label: "Cellulare", text: $cellulare, isEditing: isEditing, keyboardType: .phonePad)
    }
    
    @ViewBuilder
    private var residenzaSection: some View {
        Text("RESIDENZA").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.accademiaRed).padding(.top, 8)
        HStack { EditableTextField(label: "Indirizzo", text: $indirizzo, isEditing: isEditing); EditableTextField(label: "N.Civ", text: $nCivico, isEditing: isEditing).frame(width: 80) }
        HStack { EditableTextField(label: "Città", text: $citta, isEditing: isEditing); EditableTextField(label: "CAP", text: $cap, isEditing: isEditing).frame(width: 80); EditableTextField(label: "PR", text: $prov, isEditing: isEditing).frame(width: 60) }
    }
    
    @ViewBuilder
    private var genitoreSection: some View {
        Text("GENITORE / REFERENTE").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.accademiaRed).padding(.top, 8)
        EditableTextField(label: "Nome Genitore", text: $nomeGenitore, isEditing: isEditing)
        HStack { EditableTextField(label: "Email Genitore", text: $emailGenitore, isEditing: isEditing, keyboardType: .emailAddress); EditableTextField(label: "Cellulare Genitore", text: $cellulareGenitore, isEditing: isEditing, keyboardType: .phonePad) }
    }
    
    @ViewBuilder
    private var datiFiscaliSection: some View {
        Text("DATI FISCALI E TESSERAMENTO").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.accademiaRed).padding(.top, 8)
        EditableTextField(label: "Codice Fiscale", text: $codiceFiscale, isEditing: isEditing)
        dataNascitaField
        HStack { EditableTextField(label: "Luogo di Nascita", text: $luogoNascita, isEditing: isEditing); EditableTextField(label: "Prov.", text: $provNascita, isEditing: isEditing).frame(width: 60) }
        EditableTextField(label: "Numero Tessera", text: $numeroTessera, isEditing: isEditing)
    }
    
    @ViewBuilder
    private var dataNascitaField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Data Nascita").font(.system(size: 10)).foregroundColor(Theme.accademiaMuted)
            if isEditing {
                DatePicker("", selection: $dataNascita, displayedComponents: .date)
                    .labelsHidden().colorScheme(.dark)
            } else {
                Text(formattedDataNascita).font(.system(size: 14)).foregroundColor(Theme.accademiaText).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Theme.accademiaDark).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
            }
        }
    }
    
    private var formattedDataNascita: String {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        return df.string(from: dataNascita)
    }
    
    func executeUpdate() {
        saving = true
        Task {
            do {
                let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
                let payload = AlunnoUpdate(
                    nome: nome.trimmingCharacters(in: .whitespaces), cognome: cognome.trimmingCharacters(in: .whitespaces),
                    email: email.isEmpty ? nil : email, cellulare: cellulare.isEmpty ? nil : cellulare,
                    indirizzo: indirizzo.isEmpty ? nil : indirizzo, numero_civico: nCivico.isEmpty ? nil : nCivico,
                    cap: cap.isEmpty ? nil : cap, paese: citta.isEmpty ? nil : citta, provincia: prov.isEmpty ? nil : prov,
                    nome_genitore: nomeGenitore.isEmpty ? nil : nomeGenitore, email_genitore: emailGenitore.isEmpty ? nil : emailGenitore, cellulare_genitore: cellulareGenitore.isEmpty ? nil : cellulareGenitore,
                    codice_fiscale: codiceFiscale.isEmpty ? nil : codiceFiscale, data_nascita: df.string(from: dataNascita),
                    luogo_nascita: luogoNascita.isEmpty ? nil : luogoNascita, provincia_nascita: provNascita.isEmpty ? nil : provNascita, numero_tessera: numeroTessera.isEmpty ? nil : numeroTessera
                )
                try await supabase.from("alunni").update(payload).eq("id", value: alunno.id).execute()
                isEditing = false
                onSave()
            } catch { print("Update Error: \(error)") }
            saving = false
        }
    }
}

struct EditableTextField: View {
    let label: String
    @Binding var text: String
    let isEditing: Bool
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundColor(Theme.accademiaMuted)
            if isEditing {
                TextField(label, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .padding(12).background(Theme.accademiaInput).foregroundColor(Theme.accademiaText).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accademiaRed, lineWidth: 1))
            } else {
                Text(text.isEmpty ? "-" : text).font(.system(size: 14)).foregroundColor(Theme.accademiaText)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Theme.accademiaDark)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
            }
        }
    }
}

// MARK: - Modale Evento (Complex)
struct ModalEventoDialog: View {
    let lezione: LezioneCompleta
    let schoolId: String?
    let alunniList: [AlunnoRef]
    let tipiLezioniList: [TipiLezioni]
    var onDismiss: () -> Void
    var onSave: () -> Void
    
    @State private var dataLezione: Date = Date()
    @State private var oraInizio: Date = Date()
    @State private var durata = ""
    @State private var stato = ""
    @State private var note = ""
    @State private var contabilizzaDocente = true
    @State private var selectedAlunnoId: String = ""
    @State private var selectedAlunniIds: Set<String> = []
    @State private var selectedTipoId: String = ""
    @State private var isSupplenza = false
    @State private var docenteSostituitoId: String = ""
    @State private var isTutor = false
    @State private var isRecurring = false
    @State private var recurrenceType = "weekly"
    
    @State private var tuttiDocenti: [DocenteRef] = []
    @State private var alunniSupplenza: [AlunnoRef] = []
    @State private var annoAccademicoCorrente = ""
    @State private var saving = false
    @State private var errorMsg: String? = nil
    
    let isEdit: Bool
    let isPaid: Bool
    
    init(lezione: LezioneCompleta, schoolId: String?, alunniList: [AlunnoRef], tipiLezioniList: [TipiLezioni], onDismiss: @escaping () -> Void, onSave: @escaping () -> Void) {
        self.lezione = lezione
        self.schoolId = schoolId
        self.alunniList = alunniList
        self.tipiLezioniList = tipiLezioniList
        self.onDismiss = onDismiss
        self.onSave = onSave
        self.isEdit = lezione.id != nil
        self.isPaid = (lezione.importo_saldato ?? 0.0) > 0.0
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.accademiaDark.ignoresSafeArea()
                Form {
                    if isPaid {
                        Section { Text("Lezione parzialmente o totalmente pagata. Modifiche limitate a Note e Stato.").font(.system(size: 12)).foregroundColor(Color(hex: 0xF59E0B)).listRowBackground(Color(hex: 0xF59E0B).opacity(0.2)) }
                    }
                    
                    Section(header: Text("Gestione Docente").foregroundColor(Theme.accademiaRed)) {
                        Toggle("Questa lezione è una supplenza?", isOn: $isSupplenza)
                            .disabled(isPaid)
                            .onChange(of: isSupplenza) { _, newValue in
                                if newValue { isTutor = false }
                            }
                        
                        if isSupplenza {
                            Picker("Docente da Sostituire", selection: $docenteSostituitoId) {
                                Text("Seleziona...").tag("")
                                ForEach(tuttiDocenti.filter { $0.id != lezione.docente_id }) { d in Text("\(d.cognome) \(d.nome)").tag(d.id) }
                            }
                            .disabled(isPaid)
                            .onChange(of: docenteSostituitoId) { _, _ in
                                Task { await loadAlunniSupplenza() }
                            }
                        }
                        
                        Toggle("Attività Tutor / Riunione", isOn: $isTutor)
                            .disabled(isPaid)
                            .onChange(of: isTutor) { _, newValue in
                                if newValue {
                                    selectedAlunnoId = ""
                                    selectedAlunniIds.removeAll()
                                    isSupplenza = false
                                }
                            }
                    }.listRowBackground(Theme.accademiaInput).foregroundColor(Theme.accademiaText)
                    
                    Section(header: Text("Dettagli").foregroundColor(Theme.accademiaRed)) {
                        Picker("Tipo Lezione", selection: $selectedTipoId) {
                            Text("Seleziona...").tag("")
                            ForEach(tipiLezioniList) { t in Text("\(t.tipo) \(t.modalita == "Collettiva" ? "(Gruppo)" : "(Singolo)")").tag(t.id) }
                        }
                        .disabled(isPaid)
                        .onChange(of: selectedTipoId) { _, val in
                            if let t = tipiLezioniList.first(where: { $0.id == val }), let dur = t.durata_minuti {
                                durata = "\(dur)"
                            }
                        }
                        
                        if !isTutor {
                            let isCollettiva = tipiLezioniList.first(where: { $0.id == selectedTipoId })?.modalita == "Collettiva"
                            let attivi = isSupplenza ? alunniSupplenza : alunniList
                            alunnoSelectionField(isCollettiva: isCollettiva, attivi: attivi)
                        }
                    }.listRowBackground(Theme.accademiaInput).foregroundColor(Theme.accademiaText)
                    
                    Section(header: Text("Pianificazione").foregroundColor(Theme.accademiaRed)) {
                        DatePicker("Data", selection: $dataLezione, displayedComponents: .date).disabled(isPaid)
                        DatePicker("Ora Inizio", selection: $oraInizio, displayedComponents: .hourAndMinute).disabled(isPaid)
                        HStack {
                            Text("Durata (min)")
                            Spacer()
                            TextField("", text: $durata)
                                .multilineTextAlignment(.trailing)
                                .disabled(true) // <- Disabilitato per tutti
                                .foregroundColor(Theme.accademiaMuted) // <- Colore grigio per far capire che è di sola lettura
                        }
                    }.listRowBackground(Theme.accademiaInput).foregroundColor(Theme.accademiaText)
                    
                    Section(header: Text("Stato e Note").foregroundColor(Theme.accademiaRed)) {
                        Picker("Stato", selection: $stato) {
                            Text("Pianificata").tag("Pianificata")
                            Text("Svolta").tag("Svolta")
                            Text("Alunno Assente").tag("Alunno Assente")
                            Text("Docente Assente").tag("Docente Assente")
                        }.disabled(isRecurring)
                        TextField("Note (Opzionale)", text: $note).foregroundColor(Theme.accademiaText)
                    }.listRowBackground(Theme.accademiaInput).foregroundColor(Theme.accademiaText)
                    
                    Section(header: Text("Opzioni Avanzate").foregroundColor(Theme.accademiaRed)) {
                        Toggle("Retribuisci Docente", isOn: $contabilizzaDocente).disabled(isPaid)
                        if !isEdit {
                            Toggle("Ripeti lezione", isOn: $isRecurring)
                                .onChange(of: isRecurring) { _, newValue in
                                    if newValue { stato = "Pianificata" }
                                }
                            if isRecurring {
                                Picker("Frequenza", selection: $recurrenceType) { Text("Settimanale").tag("weekly"); Text("Ogni 2 sett.").tag("biweekly") }.pickerStyle(SegmentedPickerStyle())
                            }
                        }
                    }.listRowBackground(Theme.accademiaInput).foregroundColor(Theme.accademiaText)
                    
                    if isEdit && !isPaid {
                        Section { Button(action: executeDelete) { Text("Elimina Lezione").foregroundColor(Theme.accademiaRed).frame(maxWidth: .infinity) } }.listRowBackground(Theme.accademiaInput)
                    }
                }
                .scrollContentBackground(.hidden)
                .navigationTitle(isEdit ? "Modifica Lezione" : "Pianifica Lezione")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("Annulla") { onDismiss() }.foregroundColor(Theme.accademiaMuted) }
                    ToolbarItem(placement: .navigationBarTrailing) { Button(saving ? "Salvataggio..." : "Salva") { executeSave() }.bold().foregroundColor(Theme.accademiaRed).disabled(saving || !isValid()) }
                }
                .alert(isPresented: .constant(errorMsg != nil)) { Alert(title: Text("Errore"), message: Text(errorMsg ?? ""), dismissButton: .default(Text("OK")) { errorMsg = nil }) }
            }
            .task { await setupInitialData() }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accademiaRed)
    }
    
    // Estratto dalla Form per evitare che il type-checker debba risolvere in un colpo solo
    // un if/else che alterna NavigationLink (con ScrollView/LazyVStack annidati) e Picker:
    // è questa combinazione a generare gli errori spuri su 'TableColumn<R,C,Content,Label>'.
    @ViewBuilder
    private func alunnoSelectionField(isCollettiva: Bool, attivi: [AlunnoRef]) -> some View {
        if !isEdit && isCollettiva {
            NavigationLink(destination: alunniMultiSelectView(attivi: attivi)) {
                Text("Alunni (Gruppo) Selezionati: \(selectedAlunniIds.count)")
            }
        } else {
            Picker("Alunno", selection: $selectedAlunnoId) {
                Text("Seleziona...").tag("")
                ForEach(attivi) { a in Text("\(a.cognome) \(a.nome)").tag(a.id) }
            }.disabled(isPaid)
        }
    }
    
    @ViewBuilder
    private func alunniMultiSelectView(attivi: [AlunnoRef]) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(attivi, id: \.id) { a in
                    Button(action: {
                        if selectedAlunniIds.contains(a.id) {
                            selectedAlunniIds.remove(a.id)
                        } else {
                            selectedAlunniIds.insert(a.id)
                        }
                    }) {
                        HStack {
                            Text("\(a.cognome) \(a.nome)")
                                .foregroundColor(Theme.accademiaText)
                            Spacer()
                            if selectedAlunniIds.contains(a.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.accademiaRed)
                            }
                        }
                        .padding()
                        .background(Theme.accademiaInput)
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .background(Theme.accademiaDark.ignoresSafeArea())
        .navigationTitle("Seleziona Alunni")
    }
    
    func setupInitialData() async {
        let dfDate = DateFormatter(); dfDate.dateFormat = "yyyy-MM-dd"
        let dfTime = DateFormatter(); dfTime.dateFormat = "HH:mm:ss"
        
        dataLezione = dfDate.date(from: lezione.data_lezione) ?? Date()
        oraInizio = dfTime.date(from: lezione.ora_inizio) ?? Date()
        durata = lezione.durata_minuti != nil ? "\(lezione.durata_minuti!)" : (tipiLezioniList.count == 1 ? "\(tipiLezioniList.first!.durata_minuti ?? 60)" : "60")
        stato = lezione.stato_lezione
        note = lezione.note ?? ""
        contabilizzaDocente = lezione.contabilizza_docente ?? true
        selectedAlunnoId = lezione.alunno_id ?? ""
        selectedTipoId = lezione.tipo_lezione_id ?? (tipiLezioniList.count == 1 ? tipiLezioniList.first!.id : "")
        isSupplenza = lezione.docente_sostituito_id != nil
        docenteSostituitoId = lezione.docente_sostituito_id ?? ""
        isTutor = isEdit && lezione.alunno_id == nil
        
        do {
            var docQuery = supabase.from("docenti").select("id, nome, cognome").eq("stato", value: "Attivo")
            if let sid = schoolId { docQuery = docQuery.eq("school_id", value: sid) }
            tuttiDocenti = try await docQuery.execute().value
            
            var aaQuery = supabase.from("anni_accademici").select().eq("is_current", value: true)
            if let sid = schoolId { aaQuery = aaQuery.eq("school_id", value: sid) }
            let aaList: [AnnoAccademico] = try await aaQuery.execute().value
            
            annoAccademicoCorrente = aaList.first?.anno ?? "2026/2027"
            if isSupplenza { await loadAlunniSupplenza() }
        } catch { print(error) }
    }
    
    func loadAlunniSupplenza() async {
        guard !docenteSostituitoId.isEmpty else { return }
        do {
            let assoc: [AssociazioneDocente] = try await supabase.from("associazioni").select("alunni(id, nome, cognome)").eq("docente_id", value: docenteSostituitoId).execute().value
            alunniSupplenza = assoc.compactMap { $0.alunni }.map { AlunnoRef(id: $0.id, nome: $0.nome, cognome: $0.cognome) }.sorted { $0.cognome < $1.cognome }
        } catch { print(error) }
    }
    
    func isValid() -> Bool {
        if selectedTipoId.isEmpty { return false }
        let isCollettiva = tipiLezioniList.first(where: { $0.id == selectedTipoId })?.modalita == "Collettiva"
        if !isTutor {
            if !isEdit && isCollettiva && selectedAlunniIds.isEmpty { return false }
            if (isEdit || !isCollettiva) && selectedAlunnoId.isEmpty { return false }
        }
        if isSupplenza && docenteSostituitoId.isEmpty { return false }
        return true
    }
    
    func executeSave() {
        saving = true
        Task {
            do {
                let dfDate = DateFormatter(); dfDate.dateFormat = "yyyy-MM-dd"
                let dfTime = DateFormatter(); dfTime.dateFormat = "HH:mm:00"
                let alunniSelezionati: [String?] = isTutor ? [nil] : (!isEdit && (tipiLezioniList.first(where: { $0.id == selectedTipoId })?.modalita == "Collettiva") ? Array(selectedAlunniIds) : [selectedAlunnoId])
                
                let baseDocenteId = lezione.docente_id
                let baseDocSostituito = isSupplenza ? docenteSostituitoId : nil
                let baseOra = dfTime.string(from: oraInizio)
                let baseDurata = Int(durata) ?? 60
                
                if isEdit {
                    let updatePayload = RegistroInsertUpdate(
                        id: lezione.id, docente_id: baseDocenteId, docente_sostituito_id: baseDocSostituito, tipo_lezione_id: selectedTipoId,
                        alunno_id: isTutor ? nil : selectedAlunnoId, ora_inizio: baseOra, durata_minuti: baseDurata, note: note,
                        stato_lezione: stato, contabilizza_docente: contabilizzaDocente, anno_accademico: annoAccademicoCorrente,
                        data_lezione: dfDate.string(from: dataLezione), recurrence_group_id: lezione.recurrence_group_id
                    )
                    try await supabase.from("registro").update(updatePayload).eq("id", value: lezione.id!).execute()
                } else {
                    var payloads: [RegistroInsertUpdate] = []
                    for alId in alunniSelezionati {
                        if isRecurring {
                            let newGroupId = UUID().uuidString
                            var currDate = dataLezione
                            let endYear = Int(annoAccademicoCorrente.split(separator: "/").last ?? "") ?? (Calendar.current.component(.year, from: Date()) + 1)
                            let endDate = dfDate.date(from: "\(endYear)-06-30") ?? Date().addingTimeInterval(3600*24*30*6)
                            
                            while currDate <= endDate {
                                payloads.append(RegistroInsertUpdate(id: UUID().uuidString, docente_id: baseDocenteId, docente_sostituito_id: baseDocSostituito, tipo_lezione_id: selectedTipoId, alunno_id: alId, ora_inizio: baseOra, durata_minuti: baseDurata, note: note, stato_lezione: "Pianificata", contabilizza_docente: contabilizzaDocente, anno_accademico: annoAccademicoCorrente, data_lezione: dfDate.string(from: currDate), recurrence_group_id: newGroupId))
                                currDate = Calendar.current.date(byAdding: .day, value: recurrenceType == "biweekly" ? 14 : 7, to: currDate)!
                            }
                        } else {
                            payloads.append(RegistroInsertUpdate(id: UUID().uuidString, docente_id: baseDocenteId, docente_sostituito_id: baseDocSostituito, tipo_lezione_id: selectedTipoId, alunno_id: alId, ora_inizio: baseOra, durata_minuti: baseDurata, note: note, stato_lezione: stato, contabilizza_docente: contabilizzaDocente, anno_accademico: annoAccademicoCorrente, data_lezione: dfDate.string(from: dataLezione), recurrence_group_id: nil))
                        }
                    }
                    try await supabase.from("registro").insert(payloads).execute()
                }
                onSave()
            } catch { errorMsg = error.localizedDescription }
            saving = false
        }
    }
    
    func executeDelete() {
        saving = true
        Task {
            do {
                if (lezione.importo_saldato ?? 0.0) > 0 { errorMsg = "Lezione già pagata, impossibile eliminare."; saving = false; return }
                try await supabase.from("registro").delete().eq("id", value: lezione.id!).execute()
                onSave()
            } catch { errorMsg = error.localizedDescription }
            saving = false
        }
    }
}

// MARK: - Modale Nuovo Alunno
struct ModalNuovoAlunnoDialog: View {
    let schoolId: String?
    let docenteId: String?
    var onDismiss: () -> Void
    var onSave: (AlunnoDettaglio) -> Void
    
    @State private var nome = ""; @State private var cognome = ""; @State private var email = ""; @State private var cellulare = ""
    @State private var indirizzo = ""; @State private var nCivico = ""; @State private var citta = ""; @State private var cap = ""; @State private var prov = ""
    @State private var nomeGenitore = ""; @State private var emailGenitore = ""; @State private var cellulareGenitore = ""
    @State private var codiceFiscale = ""; @State private var dataNascita = Date(); @State private var luogoNascita = ""; @State private var provNascita = ""; @State private var numeroTessera = ""
    @State private var saving = false; @State private var errorMsg: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.accademiaDark.ignoresSafeArea()
                Form {
                    Section(header: Text("Anagrafica Alunno").foregroundColor(Theme.accademiaRed)) {
                        TextField("Nome *", text: $nome).foregroundColor(Theme.accademiaText)
                        TextField("Cognome *", text: $cognome).foregroundColor(Theme.accademiaText)
                        TextField("Email", text: $email).keyboardType(.emailAddress).autocapitalization(.none).foregroundColor(Theme.accademiaText)
                        TextField("Cellulare", text: $cellulare).keyboardType(.phonePad).foregroundColor(Theme.accademiaText)
                    }.listRowBackground(Theme.accademiaInput)
                    
                    Section(header: Text("Residenza").foregroundColor(Theme.accademiaRed)) {
                        TextField("Indirizzo", text: $indirizzo).foregroundColor(Theme.accademiaText)
                        TextField("N. Civico", text: $nCivico).foregroundColor(Theme.accademiaText)
                        TextField("Città", text: $citta).foregroundColor(Theme.accademiaText)
                        TextField("CAP", text: $cap).foregroundColor(Theme.accademiaText)
                        TextField("Provincia", text: $prov).foregroundColor(Theme.accademiaText)
                    }.listRowBackground(Theme.accademiaInput)
                    
                    Section(header: Text("Genitore / Referente").foregroundColor(Theme.accademiaRed)) {
                        TextField("Nome Genitore", text: $nomeGenitore).foregroundColor(Theme.accademiaText)
                        TextField("Email", text: $emailGenitore).keyboardType(.emailAddress).autocapitalization(.none).foregroundColor(Theme.accademiaText)
                        TextField("Cellulare", text: $cellulareGenitore).keyboardType(.phonePad).foregroundColor(Theme.accademiaText)
                    }.listRowBackground(Theme.accademiaInput)
                    
                    Section(header: Text("Dati Fiscali").foregroundColor(Theme.accademiaRed)) {
                        TextField("Codice Fiscale", text: $codiceFiscale).autocapitalization(.allCharacters).foregroundColor(Theme.accademiaText)
                        DatePicker("Data Nascita", selection: $dataNascita, displayedComponents: .date).foregroundColor(Theme.accademiaText)
                        TextField("Luogo Nascita", text: $luogoNascita).foregroundColor(Theme.accademiaText)
                        TextField("Prov. Nascita", text: $provNascita).foregroundColor(Theme.accademiaText)
                        TextField("Numero Tessera", text: $numeroTessera).foregroundColor(Theme.accademiaText)
                    }.listRowBackground(Theme.accademiaInput)
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("Nuovo Alunno")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("Annulla") { onDismiss() }.foregroundColor(Theme.accademiaMuted) }
                    ToolbarItem(placement: .navigationBarTrailing) { Button(saving ? "Salvataggio..." : "Salva") { executeSave() }.bold().foregroundColor(Theme.accademiaRed).disabled(nome.isEmpty || cognome.isEmpty || saving) }
                }
                .alert(isPresented: .constant(errorMsg != nil)) { Alert(title: Text("Errore"), message: Text(errorMsg ?? ""), dismissButton: .default(Text("OK")) { errorMsg = nil }) }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accademiaRed)
    }
    
    func executeSave() {
        saving = true
        Task {
            do {
                let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
                let payload = NuovoAlunnoInsert(
                    nome: nome.trimmingCharacters(in: .whitespaces), cognome: cognome.trimmingCharacters(in: .whitespaces),
                    email: email.isEmpty ? nil : email, cellulare: cellulare.isEmpty ? nil : cellulare, stato: "Attivo", school_id: schoolId,
                    indirizzo: indirizzo.isEmpty ? nil : indirizzo, numero_civico: nCivico.isEmpty ? nil : nCivico, cap: cap.isEmpty ? nil : cap,
                    paese: citta.isEmpty ? nil : citta, provincia: prov.isEmpty ? nil : prov,
                    nome_genitore: nomeGenitore.isEmpty ? nil : nomeGenitore, email_genitore: emailGenitore.isEmpty ? nil : emailGenitore, cellulare_genitore: cellulareGenitore.isEmpty ? nil : cellulareGenitore,
                    codice_fiscale: codiceFiscale.isEmpty ? nil : codiceFiscale, data_nascita: df.string(from: dataNascita), luogo_nascita: luogoNascita.isEmpty ? nil : luogoNascita, provincia_nascita: provNascita.isEmpty ? nil : provNascita, numero_tessera: numeroTessera.isEmpty ? nil : numeroTessera
                )
                let result: [AlunnoDettaglio] = try await supabase.from("alunni").insert(payload).select().execute().value
                if let nuovo = result.first {
                    if let dId = docenteId { try await supabase.from("associazioni").insert(AssociazioneInsert(alunno_id: nuovo.id, docente_id: dId)).execute() }
                    onSave(nuovo)
                }
            } catch { errorMsg = error.localizedDescription }
            saving = false
        }
    }
}
