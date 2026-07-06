import SwiftUI

@main
struct GalaxyBudsApp: App {
    @State private var bluetoothManager = BluetoothManager()
    
    init() {
        // Inicialização da Telemetria Nativa
        _ = TelemetryManager.shared
    }
    
    var body: some Scene {
        MenuBarExtra("Galaxy Buds", systemImage: "earbuds") {
            MenuBarView(bluetoothManager: bluetoothManager)
        }
        .menuBarExtraStyle(.window) // Garante que a view SwiftUI seja renderizada como um painel rico (Control Center style) e não uma lista de botões.
    }
}
