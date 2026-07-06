import AppIntents
import Foundation

/// Enum dos modos de ruído para Siri parametrizar.
enum NoiseModeSetting: String, AppEnum {
    case anc = "ANC"
    case ambient = "Ambient"
    case off = "Off"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Noise Mode")
    
    static var caseDisplayRepresentations: [NoiseModeSetting: DisplayRepresentation] = [
        .anc: DisplayRepresentation(title: "Active Noise Cancellation", subtitle: "Blocks outside noise"),
        .ambient: DisplayRepresentation(title: "Ambient Sound", subtitle: "Lets outside sound in"),
        .off: DisplayRepresentation(title: "Off", subtitle: "No noise control")
    ]
}

/// Intent para Siri: "Set noise mode to ANC" / "Ativa o ANC nos Galaxy Buds"
struct SetNoiseModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Galaxy Buds Noise Mode"
    static var description = IntentDescription("Changes the noise control mode on your Galaxy Buds.")
    
    // Precisa abrir o app para enviar o comando Bluetooth RFCOMM
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Noise Mode")
    var mode: NoiseModeSetting
    
    static var parameterSummary: some ParameterSummary {
        Summary("Set noise mode to \(\.$mode)")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard BudsData.isConnected else {
            return .result(dialog: "Your Galaxy Buds are not connected.")
        }
        
        // Escrever o comando pendente para o app principal processar
        BudsData.pendingNoiseMode = mode.rawValue
        
        // Notificar o app principal via DistributedNotificationCenter
        DistributedNotificationCenter.default().post(
            name: .init("tech.miguellabs.galaxybuds.setNoiseMode"),
            object: nil
        )
        
        let modeName: String
        switch mode {
        case .anc: modeName = "Active Noise Cancellation"
        case .ambient: modeName = "Ambient Sound"
        case .off: modeName = "Off"
        }
        
        return .result(dialog: "Noise mode set to \(modeName).")
    }
}
