import SwiftUI
import Supabase

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
    
    private func rubricaRow(for a: AlunnoDettaglio) -> some View {
        let u14 = isUnder14(data: a.data_nascita)
        let schedaOk = a.anno_scheda_firmata == annoAccademicoCorrente
        let libOk = a.anno_liberatoria_firmata == annoAccademicoCorrente
        
        return Button(action: { selectedAlunno = a }) {
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