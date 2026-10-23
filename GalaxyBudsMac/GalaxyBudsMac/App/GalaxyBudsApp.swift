import SwiftUI

@main
struct GalaxyBudsApp: App {
    @State private var bluetoothManager = BluetoothManager()
    @State private var audioInput = AudioInputManager()
    
    init() {
        // Inicialização da Telemetria Nativa
        _ = TelemetryManager.shared
    }
    
    var body: some Scene {
        MenuBarExtra("Buds Connect", systemImage: "earbuds") {
            MenuBarView(bluetoothManager: bluetoothManager, audioInput: audioInput)
        }
        .menuBarExtraStyle(.window)
    }
}
