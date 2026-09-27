import Foundation

struct Utente: Codable {
    let id: UUID
    let email: String
    let ruolo: String
    let stato: String
    let id_collegato: String?
}
