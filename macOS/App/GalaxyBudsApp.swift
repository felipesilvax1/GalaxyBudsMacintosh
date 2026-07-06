import SwiftUI

@main
struct GalaxyBudsApp: App {
    @State private var bluetoothManager = BluetoothManager()
    
    init() {
        // Inicialização da Telemetria Nativa
        _ = TelemetryManager.shared
    }
    
    var body: some Scene {
        MenuBarExtra("Buds On Mac", systemImage: "earbuds") {
            MenuBarView(bluetoothManager: bluetoothManager)
        }
        .menuBarExtraStyle(.window)
    }
}
