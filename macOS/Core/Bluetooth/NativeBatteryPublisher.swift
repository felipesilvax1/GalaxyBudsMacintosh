import Foundation
import IOKit

/// Gerencia power sources virtuais no IOKit para que as baterias dos Galaxy Buds
/// apareçam no widget de bateria nativo do macOS (menu bar + System Settings).
///
/// Usa as APIs públicas IOPSCreatePowerSource / IOPSSetPowerSourceDetails / IOPSReleasePowerSource
/// exportadas pelo IOKit.framework para registrar fontes de energia que o sistema reconhece nativamente.
///
/// NOTA: O tipo "UPS" é usado porque é o único tipo não-interno aceito pela API.
/// Isso faz o macOS mostrar "UPS Level: X%" na barra de bateria, mas é o único caminho
/// para integração nativa sem usar APIs privadas.
final class NativeBatteryPublisher {
    
    /// Handles para os 3 power sources (L, R, Case). Retidos enquanto o app roda.
    private var leftHandle: Unmanaged<CFTypeRef>?
    private var rightHandle: Unmanaged<CFTypeRef>?
    private var caseHandle: Unmanaged<CFTypeRef>?
    
    /// Indica se os power sources foram criados com sucesso
    private(set) var isPublishing: Bool = false
    
    deinit {
        removeAllSources()
    }
    
    // MARK: - Public API
    
    /// Cria os 3 power sources virtuais (Left, Right, Case) no IOKit.
    /// Chamado quando a conexão RFCOMM é estabelecida.
    func createSources(deviceName: String) {
        guard !isPublishing else { return }
        
        leftHandle = createSource(name: "\(deviceName) L")
        rightHandle = createSource(name: "\(deviceName) R")
        caseHandle = createSource(name: "\(deviceName) Case")
        
        isPublishing = (leftHandle != nil || rightHandle != nil || caseHandle != nil)
        
        if isPublishing {
            print("🔋 NativeBatteryPublisher: Power sources criados com sucesso!")
        } else {
            print("⚠️ NativeBatteryPublisher: Falha ao criar power sources (pode necessitar permissões)")
        }
    }
    
    /// Atualiza os níveis de bateria nos power sources registrados.
    /// Chamado sempre que um STATUS_UPDATED ou EXTENDED_STATUS_UPDATED chega.
    func updateLevels(left: Int, right: Int, caseLevel: Int) {
        guard isPublishing else { return }
        
        if let h = leftHandle {
            updateSource(handle: h, capacity: left)
        }
        if let h = rightHandle {
            updateSource(handle: h, capacity: right)
        }
        if let h = caseHandle {
            updateSource(handle: h, capacity: caseLevel)
        }
    }
    
    /// Remove todos os power sources. Chamado ao desconectar.
    func removeAllSources() {
        if let h = leftHandle {
            IOPSReleasePowerSource(h.takeUnretainedValue())
            leftHandle = nil
        }
        if let h = rightHandle {
            IOPSReleasePowerSource(h.takeUnretainedValue())
            rightHandle = nil
        }
        if let h = caseHandle {
            IOPSReleasePowerSource(h.takeUnretainedValue())
            caseHandle = nil
        }
        
        if isPublishing {
            print("🔋 NativeBatteryPublisher: Power sources removidos.")
            isPublishing = false
        }
    }
    
    // MARK: - Private
    
    private func createSource(name: String) -> Unmanaged<CFTypeRef>? {
        var handle: Unmanaged<CFTypeRef>?
        let status = IOPSCreatePowerSource(&handle)
        
        guard status == kIOReturnSuccess, let psHandle = handle else {
            print("❌ IOPSCreatePowerSource falhou para '\(name)': 0x\(String(format: "%08x", status))")
            return nil
        }
        
        // Configurar o power source com valores iniciais
        let details: [String: Any] = [
            kIOPSNameKey: name,
            kIOPSTypeKey: kIOPSUPSType,           // Único tipo não-interno aceito pela API
            kIOPSTransportTypeKey: "Bluetooth",     // Indicar transporte Bluetooth
            kIOPSPowerSourceStateKey: kIOPSACPowerValue,
            kIOPSCurrentCapacityKey: 0,
            kIOPSMaxCapacityKey: 100,
            kIOPSIsChargingKey: false,
            kIOPSIsPresentKey: true,
        ]
        
        let setStatus = IOPSSetPowerSourceDetails(psHandle.takeUnretainedValue(), details as CFDictionary)
        if setStatus != kIOReturnSuccess {
            print("❌ IOPSSetPowerSourceDetails falhou para '\(name)': 0x\(String(format: "%08x", setStatus))")
            IOPSReleasePowerSource(psHandle.takeUnretainedValue())
            return nil
        }
        
        return handle
    }
    
    private func updateSource(handle: Unmanaged<CFTypeRef>, capacity: Int) {
        let details: [String: Any] = [
            kIOPSCurrentCapacityKey: capacity,
            kIOPSMaxCapacityKey: 100,
            kIOPSIsChargingKey: false,
            kIOPSIsPresentKey: true,
            kIOPSPowerSourceStateKey: kIOPSACPowerValue,
        ]
        
        let status = IOPSSetPowerSourceDetails(handle.takeUnretainedValue(), details as CFDictionary)
        if status != kIOReturnSuccess {
            print("⚠️ IOPSSetPowerSourceDetails update falhou: 0x\(String(format: "%08x", status))")
        }
    }
}
