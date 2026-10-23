import AppIntents
import Foundation

/// Intent para Siri/Atalhos: "Use Mac microphone in Buds On Mac".
/// Troca o input padrão do sistema para o microfone do Mac, tirando os Buds do modo telefone.
struct UseMacMicrophoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Use Mac Microphone"
    static var description = IntentDescription("Switches the input to the Mac's microphone so your Galaxy Buds go back to high-quality audio.")
    
    // Roda no processo do app (menu bar), onde o CoreAudio já está disponível.
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let device = AudioDevices.switchToMacMicrophone() else {
            return .result(dialog: "I couldn't find a Mac microphone to switch to.")
        }
        return .result(dialog: "Input switched to \(device.name).")
    }
}
