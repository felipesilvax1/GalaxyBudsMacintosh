import Foundation
import WidgetKit

/// Camada de dados compartilhada entre o app principal e extensões (Widget, Siri).
/// Usa UserDefaults via App Groups para persistir os dados de estado dos Galaxy Buds.
///
/// IMPORTANTE: Este arquivo DEVE ser adicionado a TODOS os targets que precisam ler/escrever
/// os dados dos Buds (Main App, Widget Extension).
struct BudsData {
    static let appGroupID = "group.tech.miguellabs.galaxybuds"
    
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    // MARK: - Battery Levels
    
    static var leftBattery: Int {
        get { defaults?.integer(forKey: "leftBattery") ?? -1 }
        set { defaults?.set(newValue, forKey: "leftBattery") }
    }
    
    static var rightBattery: Int {
        get { defaults?.integer(forKey: "rightBattery") ?? -1 }
        set { defaults?.set(newValue, forKey: "rightBattery") }
    }
    
    static var caseBattery: Int {
        get { defaults?.integer(forKey: "caseBattery") ?? -1 }
        set { defaults?.set(newValue, forKey: "caseBattery") }
    }
    
    // MARK: - Connection & State
    
    static var isConnected: Bool {
        get { defaults?.bool(forKey: "isConnected") ?? false }
        set { defaults?.set(newValue, forKey: "isConnected") }
    }
    
    static var deviceName: String {
        get { defaults?.string(forKey: "deviceName") ?? "Galaxy Buds" }
        set { defaults?.set(newValue, forKey: "deviceName") }
    }
    
    static var currentNoiseMode: String {
        get { defaults?.string(forKey: "currentNoiseMode") ?? "Off" }
        set { defaults?.set(newValue, forKey: "currentNoiseMode") }
    }
    
    static var voiceDetectEnabled: Bool {
        get { defaults?.bool(forKey: "voiceDetectEnabled") ?? false }
        set { defaults?.set(newValue, forKey: "voiceDetectEnabled") }
    }
    
    static var lastUpdated: Date {
        get {
            let ts = defaults?.double(forKey: "lastUpdated") ?? 0
            return ts > 0 ? Date(timeIntervalSince1970: ts) : .distantPast
        }
        set { defaults?.set(newValue.timeIntervalSince1970, forKey: "lastUpdated") }
    }
    
    // MARK: - Pending Commands (from Siri → Main App)
    
    static var pendingNoiseMode: String? {
        get { defaults?.string(forKey: "pendingNoiseMode") }
        set { defaults?.set(newValue, forKey: "pendingNoiseMode") }
    }
    
    // MARK: - Sync Helpers
    
    /// Escreve todos os dados de bateria de uma vez e notifica o widget para atualizar.
    static func syncBatteryData(left: Int, right: Int, caseLevel: Int, connected: Bool, deviceName: String) {
        leftBattery = left
        rightBattery = right
        caseBattery = caseLevel
        isConnected = connected
        self.deviceName = deviceName
        lastUpdated = Date()
        
        // Solicitar atualização do widget
        WidgetCenter.shared.reloadTimelines(ofKind: "BudsOnMacWidget")
    }
    
    /// Sincroniza o modo de ruído e notifica o widget.
    static func syncNoiseMode(_ mode: String) {
        currentNoiseMode = mode
        WidgetCenter.shared.reloadTimelines(ofKind: "BudsOnMacWidget")
    }
}
