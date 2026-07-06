import AppIntents

/// Registra frases automáticas que a Siri descobre sem configuração do usuário.
/// Apple exige que TODAS as frases contenham \(.applicationName).
struct BudsOnMacShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Consulta de bateria
        AppShortcut(
            intent: GetBudsStatusIntent(),
            phrases: [
                "What's my \(.applicationName) battery",
                "Check \(.applicationName) battery levels",
                "How much battery do my buds have in \(.applicationName)",
                "\(.applicationName) battery status"
            ],
            shortTitle: "Buds Battery",
            systemImageName: "battery.100"
        )
        
        // Controle de modo de ruído
        AppShortcut(
            intent: SetNoiseModeIntent(),
            phrases: [
                "Set \(.applicationName) noise mode to \(\.$mode)",
                "Change \(.applicationName) to \(\.$mode)",
                "Turn on \(\.$mode) in \(.applicationName)"
            ],
            shortTitle: "Set Noise Mode",
            systemImageName: "ear"
        )
    }
}
