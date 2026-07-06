import SwiftUI

@main
struct GalaxyBudsApp: App {
    @State private var bluetoothManager = BluetoothManager()
    
    // Inicialização da Telemetria Nativa
    private let telemetryManager = TelemetryManager.shared
    
    // Gerenciador do Painel Flutuante
    private let connectionPanel = ConnectionPanel()
    
    var body: some Scene {
        MenuBarExtra("Galaxy Buds", systemImage: "earbuds") {
            MenuBarView(bluetoothManager: bluetoothManager)
        }
        .menuBarExtraStyle(.window) // Garante que a view SwiftUI seja renderizada como um painel rico (Control Center style) e não uma lista de botões.
        .onChange(of: bluetoothManager.isConnected) { isConnected in
            if isConnected {
                connectionPanel.showAndHide()
            }
        }
    }
}
