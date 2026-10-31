import SwiftUI
import Supabase

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
    
    private func agendaRow(for l: LezioneCompleta) -> some View {
        let isGruppo = l.tipi_lezioni?.modalita == "Collettiva"
        return Button(action: { editingLezione = l; showEventModal = true }) {
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
                            alunnoSelectionField(isCollettiva: isCollettiva == true, attivi: attivi)
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
                                .disabled(true)
                                .foregroundColor(Theme.accademiaMuted) 
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
            if !isEdit && isCollettiva == true && selectedAlunniIds.isEmpty { return false }
            if (isEdit || isCollettiva != true) && selectedAlunnoId.isEmpty { return false }
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
                let isCollettiva = tipiLezioniList.first(where: { $0.id == selectedTipoId })?.modalita == "Collettiva"
                let alunniSelezionati: [String?] = isTutor ? [nil] : (!isEdit && isCollettiva == true ? Array(selectedAlunniIds) : [selectedAlunnoId])
                
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