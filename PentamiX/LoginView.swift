import SwiftUI
import Supabase

struct LoginView: View {
    var onLoginSuccess: (String) -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var loading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack {
            Theme.accademiaDark.ignoresSafeArea()
            
            VStack {
                VStack(spacing: 0) {
                    Image("logo_pentamix")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 240)
                        .cornerRadius(20)
                        .padding(.bottom, 16)
                    
                    Text("AREA RISERVATA")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Theme.accademiaText)
                        .padding(.bottom, 4)
                    
                    Text("PENTAMIX MOBILE")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.accademiaMuted)
                        .padding(.bottom, 32)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(Theme.accademiaRed)
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 16)
                    }
                    
                    TextField("Email", text: $email)
                        .padding()
                        .background(Theme.accademiaInput)
                        .foregroundColor(Theme.accademiaText)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accademiaRed, lineWidth: 1))
                        .padding(.bottom, 16)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Theme.accademiaInput)
                        .foregroundColor(Theme.accademiaText)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accademiaRed, lineWidth: 1))
                        .padding(.bottom, 32)
                    
                    Button(action: {
                        Task { await eseguiLogin() }
                    }) {
                        Text(loading ? "ACCESSO IN CORSO..." : "ACCEDI")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.accademiaText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Theme.accademiaRed)
                            .cornerRadius(8)
                    }
                    .disabled(loading)
                }
                .padding(32)
                .background(Theme.accademiaCard)
                .cornerRadius(16)
                .padding(16)
            }
        }
    }
    
    func eseguiLogin() async {
        loading = true
        errorMessage = nil
        
        do {
            let currentEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            
            try await supabase.auth.signIn(email: currentEmail, password: password)
            let user = try await supabase.auth.session.user
            
            let profili: [Utente] = try await supabase.from("utenti")
                .select()
                .eq("id", value: user.id.uuidString)
                .execute()
                .value
            
            guard let profilo = profili.first else {
                try? await supabase.auth.signOut()
                errorMessage = "Profilo utente non configurato nel database."
                loading = false
                return
            }
            
            if profilo.stato == "Inattivo" {
                try? await supabase.auth.signOut()
                errorMessage = "Accesso negato: account disabilitato."
                loading = false
                return
            }
            
            if profilo.ruolo == "Admin" || profilo.ruolo == "Gestore" {
                try? await supabase.auth.signOut()
                errorMessage = "L'app mobile è riservata esclusivamente a Docenti e Alunni."
                loading = false
                return
            }
            
            onLoginSuccess(profilo.ruolo)
            
        } catch {
            errorMessage = "Credenziali non valide o errore di connessione."
        }
        
        loading = false
    }
}
