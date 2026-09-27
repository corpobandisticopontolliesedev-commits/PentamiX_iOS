import SwiftUI

struct Theme {
    static let accademiaDark = Color(hex: 0x121212) //[cite: 1]
    static let accademiaCard = Color(hex: 0x1A1A1A) //[cite: 1]
    static let accademiaInput = Color(hex: 0x262626) //[cite: 1]
    static let accademiaRed = Color(hex: 0xB30000) //[cite: 1]
    static let accademiaText = Color(hex: 0xFFFFFF) //[cite: 1]
    static let accademiaMuted = Color(hex: 0xAAAAAA) //[cite: 1]
}

// Estensione utile per inizializzare i colori tramite codice Hex in SwiftUI
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}
