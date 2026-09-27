import SwiftUI
import Supabase

struct ContentView: View {
    @State private var currentRole: String? = nil
    @State private var isCheckingRole = true
    
    var body: some View {
        ZStack {
            Theme.accademiaDark.ignoresSafeArea()
            
            if isCheckingRole {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accademiaRed))
                    .scaleEffect(1.5)
            } else {
                if currentRole == nil {
                    LoginView(onLoginSuccess: { ruolo in
                        currentRole = ruolo
                    })
                } else if currentRole == "Docente" {
                    DocenteDashboardView(onLogout: {
                        currentRole = nil
                    })
                } else {
                    AlunnoDashboardView(onLogout: {
                        currentRole = nil
                    })
                }
            }
        }
        .task {
            await checkSession()
        }
    }
    
    func checkSession() async {
        isCheckingRole = true
        do {
            let session = try await supabase.auth.session
            let user = session.user
            
            let profili: [Utente] = try await supabase.from("utenti")
                .select()
                .eq("id", value: user.id.uuidString)
                .execute()
                .value
            
            if let profilo = profili.first, profilo.stato != "Inattivo" {
                currentRole = profilo.ruolo
            } else {
                try? await supabase.auth.signOut()
                currentRole = nil
            }
        } catch {
            currentRole = nil
        }
        isCheckingRole = false
    }
}
