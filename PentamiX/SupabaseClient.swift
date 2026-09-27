import Foundation
import Supabase

// Inizializzazione globale del client
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://mqdpojtisighqjmyzdwz.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xZHBvanRpc2lnaHFqbXl6ZHd6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc3MDM0MDgsImV4cCI6MjA4MzI3OTQwOH0.d-zu-ykNTkzd-oooHpSwNOg1Dp6DtsC1c1Ro4ePDuXM" //
)
