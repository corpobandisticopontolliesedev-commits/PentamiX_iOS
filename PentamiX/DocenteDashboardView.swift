import SwiftUI
import Supabase

struct DocenteDashboardView: View {
    var onLogout: () -> Void
    @State private var selectedTabIndex = 0
    
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
                
                // Pulsante di Logout
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
            
            // Area Contenuti (Placeholder temporaneo)
            ZStack {
                Theme.accademiaDark.ignoresSafeArea()
                VStack {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.accademiaMuted)
                    Text("Dashboard Docente in costruzione...")
                        .foregroundColor(Theme.accademiaMuted)
                        .padding(.top, 16)
                }
            }
            
            // Bottom Navigation Bar
            HStack {
                TabBarItem(icon: "calendar", title: "Agenda", isSelected: selectedTabIndex == 0) { selectedTabIndex = 0 }
                TabBarItem(icon: "list.bullet", title: "Registro", isSelected: selectedTabIndex == 1) { selectedTabIndex = 1 }
                TabBarItem(icon: "person.2.fill", title: "Alunni", isSelected: selectedTabIndex == 2) { selectedTabIndex = 2 }
            }
            .padding(.vertical, 8)
            .background(Theme.accademiaCard)
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
}