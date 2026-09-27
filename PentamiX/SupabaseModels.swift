import Foundation

struct UtenteLoggato: Codable {
    let id_collegato: String?
    let school_id: String?
}

struct AlunnoProfilo: Codable {
    let data_nascita: String?
    let anno_scheda_firmata: String?
    let anno_liberatoria_firmata: String?
}

struct TipoLezione: Codable {
    let tipo: String
    let modalita: String?
}

struct DocenteMinimo: Codable {
    let nome: String
    let cognome: String
}

struct LezioneDB: Codable, Identifiable {
    let id: String
    let data_lezione: String
    let ora_inizio: String
    let stato_lezione: String
    let tipi_lezioni: TipoLezione?
    let docenti: DocenteMinimo?
}

struct AnnoAccademico: Codable {
    let anno: String
    let data_inizio: String
    let data_fine: String?
    let is_current: Bool
    let school_id: String?
}

struct TariffaRef: Codable {
    let tipo_lezione: String
}

struct CompetenzaRef: Codable {
    let tipo_lezione_id: String
}

struct TipiLezioni: Codable, Identifiable, Hashable {
    let id: String
    let tipo: String
    let modalita: String?
    let colore_hex: String?
    let durata_minuti: Int?
}

struct AlunnoRef: Codable, Identifiable {
    let id: String
    let nome: String
    let cognome: String
}

struct DocenteRef: Codable, Identifiable {
    let id: String
    let nome: String
    let cognome: String
}

struct LezioneCompleta: Codable, Identifiable {
    let id: String?
    let data_lezione: String
    let ora_inizio: String
    let durata_minuti: Int?
    let stato_lezione: String
    let alunno_id: String?
    let tipo_lezione_id: String?
    let docente_id: String?
    let note: String?
    let importo_saldato: Double?
    let docente_sostituito_id: String?
    let recurrence_group_id: String?
    let contabilizza_docente: Bool?
    let alunni: AlunnoRef?
    let tipi_lezioni: TipiLezioni?
    let docenti: DocenteRef?
}

struct AlunnoDettaglio: Codable, Identifiable {
    let id: String
    let nome: String
    let cognome: String
    let email: String?
    let cellulare: String?
    let stato: String?
    let anno_scheda_firmata: String?
    let anno_liberatoria_firmata: String?
    let data_nascita: String?
    let indirizzo: String?
    let numero_civico: String?
    let cap: String?
    let paese: String?
    let provincia: String?
    let nome_genitore: String?
    let email_genitore: String?
    let cellulare_genitore: String?
    let codice_fiscale: String?
    let luogo_nascita: String?
    let provincia_nascita: String?
    let numero_tessera: String?
}

struct AssociazioneDocente: Codable {
    let alunni: AlunnoDettaglio?
}
