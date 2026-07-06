import AppIntents

/// Intent para Siri: "What's my Galaxy Buds battery?" / "Qual a bateria dos meus Galaxy Buds?"
/// Retorna os níveis de bateria L, R e Case em formato falado.
struct GetBudsStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Galaxy Buds Battery"
    static var description = IntentDescription("Returns the current battery levels of your Galaxy Buds.")
    
    // Se o app não estiver rodando, abre ele pra garantir que os dados existam
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard BudsData.isConnected else {
            return .result(dialog: "Your Galaxy Buds are not connected.")
        }
        
        let left = BudsData.leftBattery
        let right = BudsData.rightBattery
        let caseLevel = BudsData.caseBattery
        
        return .result(
            dialog: "Left bud is at \(left)%, right bud is at \(right)%, and the case is at \(caseLevel)%."
        )
    }
}
