import Foundation
@preconcurrency import IOBluetooth
import Observation

/// Semáforo thread-safe para garantir uma única conexão por vez.
/// Replica o ConnSemaphore do C# original (SemaphoreSlim(1, 1)).
/// Isolado fora do @MainActor para evitar conflitos de isolamento do Swift 6.
final class ConnectionSemaphore: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 1)
    
    /// Tenta adquirir o semáforo. Retorna true se conseguiu.
    func tryAcquire() -> Bool {
        return semaphore.wait(timeout: .now()) == .success
    }
    
    /// Libera o semáforo.
    func release() {
        semaphore.signal()
    }
}
/// Gerenciador Bluetooth responsável por lidar com o pareamento, conexão RFCOMM e comunicação com os Galaxy Buds.
/// Utiliza @Observable para garantir reatividade direta com views SwiftUI no macOS 14+.
///
/// ARQUITETURA DE THREADING (replica o original Bluetooth.mm):
/// - As propriedades reativas (@Observable) vivem na MainActor para o SwiftUI.
/// - Toda a sequência de conexão RFCOMM roda numa thread de background via DispatchQueue.global().
///   Isso é OBRIGATÓRIO porque as APIs do IOBluetooth (openConnection, openRFCOMMChannelSync)
///   bloqueiam a thread atual, e o IOBluetooth precisa do RunLoop da MainThread livre para processar eventos.
/// - Os callbacks de delegate (rfcommChannelData, rfcommChannelClosed, sdpQueryComplete)
///   são chamados pelo IOBluetooth na thread interna dele, então são marcados `nonisolated`
///   e fazem dispatch manual para MainActor quando precisam atualizar estado da UI.
@MainActor
@Observable
public class BluetoothManager: NSObject {
    
    // MARK: - Estado Reativo da UI
    public var isConnected: Bool = false
    public var deviceName: String = "Galaxy Buds"
    public var batteryLevelL: Int = 0
    public var batteryLevelR: Int = 0
    public var batteryLevelCase: Int = 0
    public var currentNoiseMode: String = "Off"
    public var voiceDetectEnabled: Bool = false
    public var voiceDetectTimeout: Int = 10 // 5, 10, ou 15 segundos
    
    // MARK: - Estado Interno de Bluetooth
    private var rfcommChannel: IOBluetoothRFCOMMChannel?
    
    // Buffer para acumular dados de pacotes fragmentados
    private var dataBuffer = Data()
    
    // UUIDs conhecidos dos Galaxy Buds (várias gerações)
    // Estes bytes são big-endian (network order), idênticos ao que o C# produz após FixEndiannessOfGuidBytes
    private var sppUUIDs: [IOBluetoothSDPUUID] {
        let newBytes: [UInt8] = [0x2E, 0x73, 0xA4, 0xAD, 0x33, 0x2D, 0x41, 0xFC, 0x90, 0xE2, 0x16, 0xBE, 0xF0, 0x65, 0x23, 0xF2]
        let altBytes: [UInt8] = [0xF8, 0x62, 0x06, 0x74, 0xA1, 0xED, 0x41, 0xAB, 0xA8, 0xB9, 0xDE, 0x9A, 0xD6, 0x55, 0x72, 0x9D]
        
        let sppNew = IOBluetoothSDPUUID(bytes: newBytes, length: 16)
        let sppAlt = IOBluetoothSDPUUID(bytes: altBytes, length: 16)
        let sppStd = IOBluetoothSDPUUID(uuid16: 0x1101)
        let sppLeg = IOBluetoothSDPUUID(uuid16: 0x1102)
        
        return [sppNew, sppStd, sppLeg, sppAlt].compactMap { $0 }
    }
    
    // Semáforo de conexão — garante apenas UMA tentativa por vez (como o C# original)
    private nonisolated(unsafe) let _connSemaphore = ConnectionSemaphore()
    
    private var connectionNotification: IOBluetoothUserNotification?
    
    public override init() {
        super.init()
        
        // Registrar para notificações automáticas de conexão quando a case for aberta
        connectionNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
        
        // Debug para listar dispositivos pareados
        if let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
            for device in devices {
                if let name = device.name {
                    print("Dispositivo pareado encontrado: \(name)")
                } else {
                    print("No name or address")
                }
            }
        }
    }
    
    // MARK: - Auto-detecção (Case Open)
    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // Guard: ignorar se já conectado ou já tentando conectar
        guard !self.isConnected else { return }
        
        if let name = device.name, name.localizedCaseInsensitiveContains("Buds") {
            print("Galaxy Buds detectado: \(name). Tentando conectar RFCOMM...")
            self.deviceName = name
            self.startConnectionOnBackgroundThread(device: device)
        }
    }
    
    // MARK: - Descoberta e Conexão
    
    /// Busca entre os dispositivos já pareados do macOS algum que corresponda aos Galaxy Buds.
    public func connectToPairedBuds() {
        guard !self.isConnected else {
            print("Já conectado, ignorando.")
            return
        }
        
        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            print("Nenhum dispositivo Bluetooth pareado no Mac.")
            return
        }
        
        guard let budsDevice = pairedDevices.first(where: { device in
            if let name = device.name, name.localizedCaseInsensitiveContains("Buds") {
                return true
            }
            return false
        }) else {
            print("Nenhum Galaxy Buds encontrado nos dispositivos pareados.")
            return
        }
        
        self.deviceName = budsDevice.name ?? "Galaxy Buds"
        print("Encontrado: \(budsDevice.nameOrAddress ?? "Unknown"). Iniciando tentativa de conexão...")
        self.startConnectionOnBackgroundThread(device: budsDevice)
    }
    
    /// Inicia a conexão Bluetooth em uma thread de background.
    /// CRUCIAL: As APIs bloqueantes do IOBluetooth precisam que o RunLoop da MainThread esteja LIVRE.
    private func startConnectionOnBackgroundThread(device: IOBluetoothDevice) {
        nonisolated(unsafe) let uuids = self.sppUUIDs
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.performConnectionSync(device: device, uuids: uuids)
        }
    }
    
    /// Executa toda a sequência de conexão de forma síncrona numa thread de background.
    /// Replica exatamente o fluxo do Bluetooth.mm original do GalaxyBudsClient.
    nonisolated private func performConnectionSync(device: IOBluetoothDevice, uuids: [IOBluetoothSDPUUID]) {
        
        // === SEMÁFORO: Garantir UMA tentativa por vez (como ConnSemaphore do C#) ===
        guard _connSemaphore.tryAcquire() else {
            print("Conexão já em andamento, ignorando tentativa duplicada.")
            return
        }
        defer { _connSemaphore.release() }
        
        // === PASSO 1: Abrir conexão base ===
        if !device.isConnected() {
            let status = device.openConnection()
            if status == kIOReturnTimeout {
                print("Erro: Timeout ao abrir conexão base com o dispositivo.")
                return
            }
            if status != kIOReturnSuccess {
                print("Erro ao abrir conexão base: \(status). Tentando continuar...")
            }
        }
        print("Conexão base OK. Iniciando SDP query...")
        
        // === PASSO 2: SDP Query ===
        // macOS imprime "This currently won't trigger SDP delegate" para objetos Swift,
        // então não dependemos do callback. Apenas disparamos a query para forçar o sistema
        // a atualizar os registros SDP em cache, e esperamos 1.5s.
        let sdpStatus = device.performSDPQuery(nil)
        if sdpStatus != kIOReturnSuccess {
            print("Aviso: SDP query retornou erro \(sdpStatus). Tentando com cache...")
        }
        // Esperar para o sistema processar a query (como o original Obj-C faz)
        Thread.sleep(forTimeInterval: 1.5)
        
        // === PASSO 3: Buscar serviço SPP ===
        // Bluetooth.mm linha 74: [device getServiceRecordForUUID:parsedUuid]
        var targetRecord: IOBluetoothSDPServiceRecord? = nil
        for uuid in uuids {
            if let record = device.getServiceRecord(for: uuid) {
                targetRecord = record
                print("Serviço SPP encontrado com UUID: \(uuid)")
                break
            }
        }
        
        guard let serviceRecord = targetRecord else {
            print("Nenhum serviço SPP encontrado no dispositivo.")
            return
        }
        
        // === PASSO 4: Obter RFCOMM Channel ID ===
        var channelID: BluetoothRFCOMMChannelID = 0
        let cidStatus = serviceRecord.getRFCOMMChannelID(&channelID)
        if cidStatus != kIOReturnSuccess {
            print("Erro ao obter RFCOMM Channel ID: \(cidStatus)")
            return
        }
        
        print("Serviço selecionado - Canal RFCOMM ID = \(channelID)")
        
        // === PASSO 5: Abrir canal RFCOMM Sync ===
        // Bluetooth.mm linha 93-126: openRFCOMMChannelSync + polling
        // NOTA: O status SEMPRE retorna kIOReturnError (bug do macOS). Ignoramos o status
        // e verificamos apenas se o canal abre via isOpen().
        var tempChannel: IOBluetoothRFCOMMChannel? = nil
        let rfcommStatus = device.openRFCOMMChannelSync(&tempChannel, withChannelID: channelID, delegate: self)
        
        if tempChannel == nil {
            print("Erro: canal RFCOMM é nil após openRFCOMMChannelSync. Status: \(rfcommStatus)")
            return
        }
        
        // Poll até o canal abrir (max 1.5s)
        var waitCount = 0
        while !tempChannel!.isOpen() && waitCount < 15 {
            Thread.sleep(forTimeInterval: 0.1)
            waitCount += 1
        }
        
        // Verificar resultado - ignorar status de erro se o canal está aberto
        if !tempChannel!.isOpen() {
            print("Erro: canal RFCOMM não abriu após 1.5s. Status original: \(rfcommStatus)")
            DispatchQueue.main.async {
                Task { @MainActor in
                    self.isConnected = false
                }
            }
            return
        }
        
        if rfcommStatus != kIOReturnSuccess {
            print("Aviso: openRFCOMMChannelSync retornou erro \(rfcommStatus), mas o canal está aberto!")
        }
        
        print("Canal RFCOMM aberto com sucesso após \(waitCount * 100)ms!")
        
        // Atualizar estado na MainActor e enviar handshake
        let channel = tempChannel!
        DispatchQueue.main.async {
            Task { @MainActor in
                self.rfcommChannel = channel
                self.isConnected = true
                self.dataBuffer.removeAll()
                
                print("Conexão RFCOMM estabelecida! Enviando handshake...")
                
                // Handshake: Manager Info (idêntico ao original C#)
                // Payload: [1 (Magic), 1 (ClientType Samsung), 34 (Android SDK)]
                let handshakeMsg = SppMessage(id: .managerInfo, type: .request, payload: Data([1, 1, 34]))
                self.send(message: handshakeMsg)
            }
        }
    }
    
    // MARK: - Disconnect
    
    public func disconnect() {
        print("Fechando conexão RFCOMM...")
        // Limpar delegate antes de fechar (como o original Obj-C faz)
        self.rfcommChannel?.setDelegate(nil)
        self.rfcommChannel?.close()
        self.rfcommChannel = nil
        self.isConnected = false
        self.dataBuffer.removeAll()
        print("Desconectado.")
    }
    
    // MARK: - Transmissão de Dados
    
    public func send(message: SppMessage) {
        guard let channel = self.rfcommChannel, channel.isOpen() else {
            print("Canal não está aberto, impossível enviar mensagem.")
            return
        }
        
        let data = message.encode()
        data.withUnsafeBytes { buffer in
            if let baseAddress = buffer.baseAddress {
                let status = channel.writeAsync(UnsafeMutableRawPointer(mutating: baseAddress), length: UInt16(data.count), refcon: nil)
                if status != kIOReturnSuccess {
                    print("Erro ao enviar dados no canal RFCOMM: \(status)")
                }
            }
        }
    }
    
    // MARK: - Controles de Ruído
    
    public func setNoiseControlMode(_ mode: String) {
        guard isConnected else { return }
        
        var modeByte: UInt8 = 0x00
        switch mode {
        case "ANC": modeByte = 0x01
        case "Ambient": modeByte = 0x02
        default: modeByte = 0x00 // Off
        }
        
        let message = SppMessage(id: .noiseControls, type: .request, payload: Data([modeByte]))
        self.send(message: message)
    }
    
    // MARK: - Voice Detect (Detect Conversations)
    
    /// Ativa/desativa o Voice Detect.
    /// Quando ativo, os fones mudam automaticamente para Ambient quando você começa a falar.
    public func setVoiceDetect(enabled: Bool) {
        guard isConnected else { return }
        self.voiceDetectEnabled = enabled
        let message = SppMessage(id: .setDetectConversations, type: .request, payload: Data([enabled ? 0x01 : 0x00]))
        self.send(message: message)
        print("Voice Detect: \(enabled ? "ATIVADO" : "DESATIVADO")")
    }
    
    /// Define o timeout do Voice Detect (quanto tempo fica em Ambient após parar de falar).
    /// Valores: 5, 10, ou 15 segundos.
    public func setVoiceDetectTimeout(_ seconds: Int) {
        guard isConnected else { return }
        self.voiceDetectTimeout = seconds
        
        // Wire format: 0=5s, 1=10s, 2=15s
        let wireValue: UInt8
        switch seconds {
        case 5: wireValue = 0
        case 15: wireValue = 2
        default: wireValue = 1 // 10s
        }
        
        let message = SppMessage(id: .setDetectConversationsDuration, type: .request, payload: Data([wireValue]))
        self.send(message: message)
        print("Voice Detect timeout: \(seconds)s")
    }
}

// MARK: - IOBluetoothDeviceAsyncCallbacks (SDP Query Delegate)
// O original Obj-C (Bluetooth.h:52) conforma com este protocolo para receber callbacks de SDP.
// SEM esta conformidade, performSDPQuery(self) não funciona — o IOBluetooth não despacha o callback.
extension BluetoothManager: IOBluetoothDeviceAsyncCallbacks {
    
    /// Chamado pelo IOBluetooth quando a SDP query completa (na thread interna do IOBluetooth).
    /// NOTA: macOS imprime "This currently won't trigger SDP delegate" para objetos Swift,
    /// então este callback pode nunca ser chamado. Mantido para compatibilidade futura.
    nonisolated public func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        if status != kIOReturnSuccess {
            print("SDP query callback (pode não disparar no macOS atual): erro \(status)")
        } else {
            print("SDP query callback: sucesso!")
        }
    }
    
    /// Chamado quando uma conexão base completa. Stub obrigatório do protocolo.
    nonisolated public func connectionComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        print("connectionComplete callback: status = \(status)")
    }
    
    /// Chamado quando uma consulta de nome remoto completa. Stub obrigatório do protocolo.
    nonisolated public func remoteNameRequestComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        print("remoteNameRequestComplete callback: status = \(status)")
    }
}

// MARK: - IOBluetoothRFCOMMChannelDelegate
// Todos os métodos são `nonisolated` porque o IOBluetooth os chama na thread interna dele,
// NÃO na MainThread. Acessos ao estado da UI são despachados via Task { @MainActor }.
extension BluetoothManager: IOBluetoothRFCOMMChannelDelegate {
    
    /// Chamado pelo IOBluetooth quando o canal RFCOMM abre (pode ser chamado em background).
    /// No nosso fluxo, NÃO dependemos deste callback — usamos polling de isOpen() como o original.
    /// Este método é mantido como safety net.
    nonisolated public func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        print("rfcommChannelOpenComplete callback: status = \(error)")
    }
    
    /// Chamado pelo IOBluetooth quando dados chegam no canal (na thread interna do IOBluetooth).
    nonisolated public func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        // Copiar os dados imediatamente (o ponteiro pode ser invalidado após este callback)
        let incomingData = Data(bytes: dataPointer, count: dataLength)
        
        DispatchQueue.main.async {
            Task { @MainActor in
                self.dataBuffer.append(incomingData)
                self.processBufferedData()
            }
        }
    }
    
    /// Chamado pelo IOBluetooth quando o canal é fechado pelo dispositivo remoto.
    nonisolated public func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        print("O canal RFCOMM foi fechado pelo dispositivo remoto ou pelo sistema.")
        DispatchQueue.main.async {
            Task { @MainActor in
                self.rfcommChannel = nil
                self.isConnected = false
                self.dataBuffer.removeAll()
            }
        }
    }
    
    // MARK: - Processamento de Dados Recebidos
    
    private func processBufferedData() {
        while true {
            do {
                let message = try SppMessage.decode(from: self.dataBuffer)
                self.dataBuffer.removeFirst(message.totalPacketSize)
                self.processReceivedMessage(message)
                
            } catch SppMessageError.tooSmall {
                break
            } catch SppMessageError.invalidSom {
                print("Aviso: SOM inválido. Descartando 1 byte para resincronizar...")
                if !self.dataBuffer.isEmpty {
                    self.dataBuffer.removeFirst()
                }
            } catch {
                print("Aviso: Falha de validação (\(error)). Descartando 1 byte.")
                if !self.dataBuffer.isEmpty {
                    self.dataBuffer.removeFirst()
                }
            }
        }
    }
    
    private func processReceivedMessage(_ message: SppMessage) {
        switch message.id {
            
        case .statusUpdated:
            if message.payload.count >= 4 {
                self.batteryLevelL = min(Int(message.payload[1] & 0x7F), 100)
                self.batteryLevelR = min(Int(message.payload[2] & 0x7F), 100)
                self.batteryLevelCase = min(Int(message.payload[3] & 0x7F), 100)
                print("Status Atualizado: L \(self.batteryLevelL)% R \(self.batteryLevelR)% Case \(self.batteryLevelCase)%")
            }
            
        case .extendedStatusUpdated:
            if message.payload.count >= 8 {
                self.batteryLevelL = min(Int(message.payload[2] & 0x7F), 100)
                self.batteryLevelR = min(Int(message.payload[3] & 0x7F), 100)
                self.batteryLevelCase = min(Int(message.payload[7] & 0x7F), 100)
                print("Extended Status: L \(self.batteryLevelL)% R \(self.batteryLevelR)% Case \(self.batteryLevelCase)%")
            }
            // Parse Voice Detect (bytes 26-27, como o C# original)
            if message.payload.count >= 28 {
                self.voiceDetectEnabled = message.payload[26] == 1
                let durationByte = min(message.payload[27], 2) // Clamp como o C#
                switch durationByte {
                case 0: self.voiceDetectTimeout = 5
                case 2: self.voiceDetectTimeout = 15
                default: self.voiceDetectTimeout = 10
                }
                print("Voice Detect: \(self.voiceDetectEnabled ? "ON" : "OFF"), timeout: \(self.voiceDetectTimeout)s")
            }
            
        case .ambientModeUpdated, .noiseControlsUpdate:
            if let modeByte = message.payload.first {
                switch modeByte {
                case 0x00: self.currentNoiseMode = "Off"
                case 0x01: self.currentNoiseMode = "ANC"
                case 0x02: self.currentNoiseMode = "Ambient"
                default: self.currentNoiseMode = "Unknown"
                }
                print("Noise mode atualizado para: \(self.currentNoiseMode)")
            }
            
        case .noiseReductionModeUpdate:
            if let byte = message.payload.first {
                print("ANC mode update: \(byte == 1 ? "enabled" : "disabled")")
            }
            
        default:
            print("Mensagem recebida: \(message.id)")
        }
    }
}
