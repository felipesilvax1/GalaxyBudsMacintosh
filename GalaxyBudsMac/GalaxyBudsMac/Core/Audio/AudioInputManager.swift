import CoreAudio
import Foundation
import IOBluetooth
import Observation

// MARK: - Modelo de dispositivo de entrada

/// Dispositivo de áudio com pelo menos um canal de entrada (microfone).
nonisolated struct AudioInputDevice: Equatable, Identifiable {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let transportType: UInt32
    
    var isBluetooth: Bool {
        transportType == kAudioDeviceTransportTypeBluetooth ||
        transportType == kAudioDeviceTransportTypeBluetoothLE
    }
    var isBuiltIn: Bool { transportType == kAudioDeviceTransportTypeBuiltIn }
    var isVirtualOrAggregate: Bool {
        transportType == kAudioDeviceTransportTypeVirtual ||
        transportType == kAudioDeviceTransportTypeAggregate
    }
}

// MARK: - Camada fina sobre CoreAudio (HAL)

/// Somente consulta/troca o dispositivo de entrada PADRÃO do sistema.
/// Nunca abre streams de áudio, então não requer permissão de microfone (TCC)
/// nem o entitlement `device.audio-input`.
nonisolated enum AudioDevices {
    private static let system = AudioObjectID(kAudioObjectSystemObject)
    
    private static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
    
    static var defaultInputAddress: AudioObjectPropertyAddress { address(kAudioHardwarePropertyDefaultInputDevice) }
    static var devicesAddress: AudioObjectPropertyAddress { address(kAudioHardwarePropertyDevices) }
    
    private static func hasInputChannels(_ id: AudioObjectID) -> Bool {
        var addr = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeInput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return false }
        
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return false }
        
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.contains { $0.mNumberChannels > 0 }
    }
    
    private static func stringProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0)
        }
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
    
    private static func transportType(_ id: AudioObjectID) -> UInt32 {
        var addr = address(kAudioDevicePropertyTransportType)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return 0 }
        return value
    }
    
    static func device(for id: AudioDeviceID) -> AudioInputDevice? {
        guard id != kAudioObjectUnknown, hasInputChannels(id) else { return nil }
        return AudioInputDevice(
            id: id,
            name: stringProperty(id, kAudioObjectPropertyName) ?? "?",
            uid: stringProperty(id, kAudioDevicePropertyDeviceUID) ?? "",
            transportType: transportType(id)
        )
    }
    
    /// Todos os dispositivos que têm entrada de áudio.
    static func allInputs() -> [AudioInputDevice] {
        var addr = devicesAddress
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap(device(for:))
    }
    
    static func defaultInput() -> AudioInputDevice? {
        var addr = defaultInputAddress
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &id) == noErr else { return nil }
        return device(for: id)
    }
    
    @discardableResult
    static func setDefaultInput(_ device: AudioInputDevice) -> Bool {
        var addr = defaultInputAddress
        var id = device.id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(system, &addr, 0, nil, size, &id)
        if status != noErr { print("AudioDevices: falha ao trocar input padrão (\(status))") }
        return status == noErr
    }
    
    /// Microfone interno do Mac; se não houver (ex.: Mac mini), o primeiro input
    /// que não seja Bluetooth/virtual/agregado (ex.: USB).
    static func preferredNonBluetoothInput(in inputs: [AudioInputDevice]) -> AudioInputDevice? {
        inputs.first(where: { $0.isBuiltIn })
            ?? inputs.first(where: { !$0.isBluetooth && !$0.isVirtualOrAggregate })
    }
    
    /// Atalho usado pela Siri/Atalhos: troca para o mic do Mac e devolve o dispositivo escolhido.
    @discardableResult
    static func switchToMacMicrophone() -> AudioInputDevice? {
        guard let target = preferredNonBluetoothInput(in: allInputs()) else { return nil }
        if defaultInput() == target { return target }
        return setDefaultInput(target) ? target : nil
    }
}

// MARK: - Gerenciador reativo

/// Resolve o problema "Galaxy Buds presos em qualidade de telefone":
/// quando o microfone dos Buds vira o input padrão, o macOS troca o fone para o perfil HFP
/// (mono, 8–16 kHz) e não volta para A2DP sozinho. Aqui devolvemos o input ao mic do Mac,
/// manualmente (botão) ou automaticamente (toggle "Manter no Mac").
@MainActor
@Observable
final class AudioInputManager {
    
    // MARK: Estado para a UI
    private(set) var currentInputName: String = "—"
    /// O input padrão atual é o microfone dos Buds (⇒ fone em modo telefone).
    private(set) var isBudsMicActive: Bool = false
    /// Existe algum microfone não-Bluetooth para onde voltar.
    private(set) var macMicAvailable: Bool = false
    /// Os Buds expõem um microfone no sistema agora (conectados por áudio).
    private(set) var budsMicPresent: Bool = false
    /// O usuário pediu explicitamente o mic dos Buds (ex.: chamada): auto-lock pausado.
    private(set) var autoPaused: Bool = false
    
    var autoKeepOnMac: Bool {
        didSet {
            UserDefaults.standard.set(autoKeepOnMac, forKey: Self.autoKey)
            autoPaused = false
            enforceIfNeeded()
        }
    }
    
    // MARK: Interno
    private static let autoKey = "audio.autoKeepOnMac"
    
    private var defaultListener: AudioObjectPropertyListenerBlock?
    private var devicesListener: AudioObjectPropertyListenerBlock?
    private var pendingSwitch: Task<Void, Never>?
    private var recentSwitches: [Date] = []
    
    init() {
        UserDefaults.standard.register(defaults: [Self.autoKey: true])
        self.autoKeepOnMac = UserDefaults.standard.bool(forKey: Self.autoKey)
        refresh()
        startListening()
        enforceIfNeeded()
    }
    
    // MARK: Ações da UI
    
    /// Botão "Usar microfone do Mac".
    func useMacMicrophone() {
        autoPaused = false
        guard let target = AudioDevices.preferredNonBluetoothInput(in: AudioDevices.allInputs()) else { return }
        performSwitch(to: target)
    }
    
    /// Link "Usar mic dos Buds" (chamadas). Pausa o auto-lock até os Buds saírem ou o toggle mudar.
    func useBudsMicrophone() {
        guard let buds = budsInput(in: AudioDevices.allInputs()) else { return }
        autoPaused = true
        AudioDevices.setDefaultInput(buds)
        refresh()
    }
    
    // MARK: Estado
    
    func refresh() {
        let inputs = AudioDevices.allInputs()
        let current = AudioDevices.defaultInput()
        let buds = budsInput(in: inputs)
        
        currentInputName = current?.name ?? "—"
        macMicAvailable = AudioDevices.preferredNonBluetoothInput(in: inputs) != nil
        budsMicPresent = buds != nil
        isBudsMicActive = (current != nil && current == buds)
        
        // Buds foram embora: sai da pausa para que o próximo ciclo volte a proteger.
        if buds == nil { autoPaused = false }
    }
    
    /// Endereços (formato "aa-bb-cc-…") dos Buds pareados. Os UIDs CoreAudio dos dispositivos
    /// Bluetooth são "AA-BB-CC-…:input", o que permite casar sem depender do nome.
    private func pairedBudsAddresses() -> Set<String> {
        let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        let addresses = paired
            .filter { $0.name?.localizedCaseInsensitiveContains("Buds") == true }
            .compactMap { $0.addressString?.uppercased().replacingOccurrences(of: ":", with: "-") }
        return Set(addresses)
    }
    
    private func budsInput(in inputs: [AudioInputDevice]) -> AudioInputDevice? {
        let addresses = pairedBudsAddresses()
        return inputs.first { device in
            guard device.isBluetooth else { return false }
            let uid = device.uid.uppercased().replacingOccurrences(of: ":", with: "-")
            if addresses.contains(where: { uid.hasPrefix($0) }) { return true }
            return device.name.localizedCaseInsensitiveContains("Buds")
        }
    }
    
    // MARK: Auto-lock
    
    private func startListening() {
        let main = DispatchQueue.main
        
        let onDefaultChanged: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.refresh()
                self?.enforceIfNeeded()
            }
        }
        let onDevicesChanged: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.refresh()
                self?.enforceIfNeeded()
                // O macOS costuma definir o input padrão alguns instantes depois de o fone conectar.
                try? await Task.sleep(for: .seconds(2))
                self?.refresh()
                self?.enforceIfNeeded()
            }
        }
        defaultListener = onDefaultChanged
        devicesListener = onDevicesChanged
        
        var defaultAddr = AudioDevices.defaultInputAddress
        var devicesAddr = AudioDevices.devicesAddress
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultAddr, main, onDefaultChanged)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, main, onDevicesChanged)
    }
    
    private func enforceIfNeeded() {
        guard autoKeepOnMac, !autoPaused, isBudsMicActive, macMicAvailable else { return }
        
        pendingSwitch?.cancel()
        pendingSwitch = Task { [weak self] in
            // Debounce: evita brigar com trocas em cascata do próprio sistema.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            self.refresh()
            guard self.autoKeepOnMac, !self.autoPaused, self.isBudsMicActive,
                  let target = AudioDevices.preferredNonBluetoothInput(in: AudioDevices.allInputs()) else { return }
            self.performSwitch(to: target)
        }
    }
    
    private func performSwitch(to target: AudioInputDevice) {
        // Anti-loop: no máximo 5 trocas em 10 s (caso algo no sistema force o fone de volta).
        let now = Date()
        recentSwitches = recentSwitches.filter { now.timeIntervalSince($0) < 10 }
        guard recentSwitches.count < 5 else {
            print("AudioInputManager: muitas trocas seguidas, abortando para evitar loop.")
            return
        }
        recentSwitches.append(now)
        
        AudioDevices.setDefaultInput(target)
        refresh()
    }
}
