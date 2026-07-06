import Foundation
@preconcurrency import IOBluetooth
import Observation

/// Gerenciador Bluetooth responsável por lidar com o pareamento, conexão RFCOMM e comunicação com os Galaxy Buds.
/// Utiliza @Observable para garantir reatividade direta com views SwiftUI no macOS 14+.
@MainActor
@Observable
public class BluetoothManager: NSObject {
    
    // MARK: - Estado Reativo da UI
    public var isConnected: Bool = false
    public var deviceName: String = "Galaxy Buds"
    public var batteryLevelL: Int = 0
    public var batteryLevelR: Int = 0
    public var batteryLevelCase: Int = 0
    public var currentNoiseMode: String = "Off" // Pode virar um Enum no futuro
    
    // MARK: - Estado Interno de Bluetooth
    private var rfcommChannel: IOBluetoothRFCOMMChannel?
    
    // Buffer para acumular dados de pacotes fragmentados (RFCOMM é um stream, não garante 1 pacote por evento)
    private var dataBuffer = Data()
    
    // UUIDs conhecidos dos Galaxy Buds (várias gerações)
    private var sppUUIDs: [IOBluetoothSDPUUID] {
        let newBytes: [UInt8] = [0x2E, 0x73, 0xA4, 0xAD, 0x33, 0x2D, 0x41, 0xFC, 0x90, 0xE2, 0x16, 0xBE, 0xF0, 0x65, 0x23, 0xF2]
        let altBytes: [UInt8] = [0xF8, 0x62, 0x06, 0x74, 0xA1, 0xED, 0x41, 0xAB, 0xA8, 0xB9, 0xDE, 0x9A, 0xD6, 0x55, 0x72, 0x9D]
        
        let sppNew = IOBluetoothSDPUUID(bytes: newBytes, length: 16)
        let sppAlt = IOBluetoothSDPUUID(bytes: altBytes, length: 16)
        let sppStd = IOBluetoothSDPUUID(uuid16: 0x1101)
        let sppLeg = IOBluetoothSDPUUID(uuid16: 0x1102)
        
        return [sppNew, sppStd, sppLeg, sppAlt].compactMap { $0 }
    }
    
    // Flag para SDP query (exatamente como o original Obj-C)
    private var sdpQueryDone: Bool = false
    
    private var connectionNotification: IOBluetoothUserNotification?
    
    public override init() {
        super.init()
        
        // Registrar para notificações automáticas de conexão quando a case for aberta
        connectionNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
        
        // Debug para listar dispositivos pareados na inicialização do manager
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
        if let name = device.name, name.localizedCaseInsensitiveContains("Buds") {
            print("Galaxy Buds conectado nativamente: \(name). Tentando conectar RFCOMM...")
            self.deviceName = name
            self.startConnectionOnBackgroundThread(device: device)
        }
    }
    
    // MARK: - Descoberta e Conexão
    
    /// Busca entre os dispositivos já pareados do macOS algum que corresponda aos Galaxy Buds.
    public func connectToPairedBuds() {
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
    /// CRUCIAL: As APIs bloqueantes do IOBluetooth (openConnection, performSDPQuery, openRFCOMMChannelSync)
    /// precisam que o RunLoop da MainThread esteja LIVRE para processar os eventos.
    /// Se chamadas na MainThread diretamente, causam deadlock silencioso.
    private func startConnectionOnBackgroundThread(device: IOBluetoothDevice) {
        // Capturar os UUIDs antes de ir para background (computed property @MainActor)
        let uuids = self.sppUUIDs
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performConnectionSync(device: device, uuids: uuids)
        }
    }
    
    /// Executa toda a sequência de conexão de forma síncrona numa thread de background.
    /// Replica exatamente o fluxo do Bluetooth.mm original do GalaxyBudsClient.
    nonisolated private func performConnectionSync(device: IOBluetoothDevice, uuids: [IOBluetoothSDPUUID]) {
        
        // === PASSO 1: Abrir conexão base ===
        // "Before we can open the RFCOMM channel, we need to open a connection to the device."
        if !device.isConnected() {
            let status = device.openConnection()
            if status == kIOReturnTimeout {
                print("Erro: Timeout ao abrir conexão base com o dispositivo.")
                return
            }
            if status != kIOReturnSuccess {
                print("Erro ao abrir conexão base: \(status)")
                // Não falhar fatalmente, tentar continuar
            }
        }
        
        // === PASSO 2: SDP Query com polling (como o original Obj-C) ===
        // "sdp query with uuids specified silently fails since Ventura"
        DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                self.sdpQueryDone = false
            }
        }
        
        let sdpStatus = device.performSDPQuery(self)
        if sdpStatus != kIOReturnSuccess {
            print("Erro ao iniciar SDP query: \(sdpStatus). Tentando continuar sem SDP...")
        } else {
            // Poll até SDP completar, exatamente como o original
            var i = 0
            var done = false
            while !done && i < 15 {
                Thread.sleep(forTimeInterval: 0.1)
                i += 1
                DispatchQueue.main.sync {
                    MainActor.assumeIsolated {
                        done = self.sdpQueryDone
                    }
                }
            }
            if !done {
                print("Aviso: SDP query expirou (timeout).")
            }
        }
        
        // === PASSO 3: Buscar serviço SPP ===
        var targetRecord: IOBluetoothSDPServiceRecord? = nil
        for uuid in uuids {
            if let record = device.getServiceRecord(for: uuid) {
                targetRecord = record
                print("Serviço SPP encontrado com UUID: \(uuid)")
                break
            }
        }
        
        guard let serviceRecord = targetRecord else {
            print("Nenhum serviço SPP encontrado no dispositivo. ***Isso não deveria acontecer.***")
            return
        }
        
        // === PASSO 4: Obter canal RFCOMM ID ===
        var channelID: BluetoothRFCOMMChannelID = 0
        let cidStatus = serviceRecord.getRFCOMMChannelID(&channelID)
        if cidStatus != kIOReturnSuccess {
            print("Erro ao obter RFCOMM Channel ID: \(cidStatus)")
            return
        }
        
        print("Serviço selecionado - Canal RFCOMM ID = \(channelID)")
        
        // === PASSO 5: Abrir canal RFCOMM Sync ===
        // "As it appears to be a macOS bug, we work it around by using openRFCOMMChannelSync
        // then relying on RFCOMM channel to open after at most 1.5s"
        var tempChannel: IOBluetoothRFCOMMChannel? = nil
        let rfcommStatus = device.openRFCOMMChannelSync(&tempChannel, withChannelID: channelID, delegate: self)
        
        if tempChannel == nil {
            print("Erro: canal RFCOMM é nil após openRFCOMMChannelSync. Status: \(rfcommStatus)")
            return
        }
        
        // Poll até o canal abrir (máx 1.5s), como o original
        var waitCount = 0
        while !tempChannel!.isOpen() && waitCount < 15 {
            Thread.sleep(forTimeInterval: 0.1)
            waitCount += 1
        }
        
        // Verificar resultado - ignorar status de erro se o canal está aberto
        // "For unknown reasons, status is always kIOReturnError even if connection was successful"
        if !tempChannel!.isOpen() {
            print("Erro: canal RFCOMM não abriu após 1.5s. Status original: \(rfcommStatus)")
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.isConnected = false
                }
            }
            return
        }
        
        if rfcommStatus != kIOReturnSuccess {
            print("Aviso: openRFCOMMChannelSync retornou erro \(rfcommStatus), mas o canal está aberto!")
        }
        
        print("Canal RFCOMM aberto com sucesso após \(waitCount * 100)ms!")
        
        // Atualizar estado na MainThread
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.rfcommChannel = tempChannel
                self.rfcommChannelOpenComplete(tempChannel, status: kIOReturnSuccess)
            }
        }
    }
    
    // MARK: - SDP Query Delegate Callback
    @objc nonisolated public func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        if status != kIOReturnSuccess {
            print("Erro na SDP query: \(status)")
        } else {
            print("SDP query completou com sucesso!")
        }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.sdpQueryDone = true
            }
        }
    }
    
    public func disconnect() {
        print("Fechando conexão RFCOMM...")
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
                    print("Erro ao enviar dados no canal RFCOMM.")
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
}

// MARK: - IOBluetoothRFCOMMChannelDelegate
extension BluetoothManager: IOBluetoothRFCOMMChannelDelegate {
    
    public func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        if error == kIOReturnSuccess {
            print("Conexão RFCOMM aberta com sucesso!")
            self.isConnected = true
            self.dataBuffer.removeAll() // Resetar buffer ao conectar
            
            // Ao conectar, enviamos o handshake do MVP (Manager Info) para acordar o dispositivo e pedir status.
            // Payload: 1 (Magic), 1 (Tipo Samsung), 34 (Android SDK version simulada)
            let handshakeMsg = SppMessage(id: .managerInfo, type: .request, payload: Data([1, 1, 34]))
            self.send(message: handshakeMsg)
            
        } else {
            print("Falha ao completar a abertura do canal RFCOMM. Erro: \(error)")
            self.isConnected = false
        }
    }
    
    public func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let incomingData = Data(bytes: dataPointer, count: dataLength)
        self.dataBuffer.append(incomingData)
        
        // Tentar decodificar enquanto houver pacotes completos no buffer
        while true {
            do {
                let message = try SppMessage.decode(from: self.dataBuffer)
                
                // Se decodificou com sucesso, remover os bytes exatos do pacote na rede
                self.dataBuffer.removeFirst(message.totalPacketSize)
                
                // Processar a mensagem
                self.processReceivedMessage(message)
                
            } catch SppMessageError.tooSmall {
                // Buffer não tem dados suficientes ainda, esperar próximo pacote
                break
            } catch SppMessageError.invalidSom {
                print("Aviso: SOM inválido. Descartando 1 byte para tentar resincronizar...")
                if !self.dataBuffer.isEmpty {
                    self.dataBuffer.removeFirst()
                }
            } catch {
                // Outro erro de validação (CRC, tamanho, etc). Descartamos o primeiro byte e tentamos resincronizar.
                print("Aviso: Falha de validação (\(error)). Descartando 1 byte.")
                if !self.dataBuffer.isEmpty {
                    self.dataBuffer.removeFirst()
                }
            }
        }
    }
    
    public func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        print("O canal RFCOMM foi fechado pelo dispositivo remoto ou pelo sistema.")
        self.isConnected = false
        self.dataBuffer.removeAll()
    }
    
    // MARK: - Processamento de Mensagens
    
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
                // No ExtendedStatusUpdate (Buds+ ou superior), L é payload[2], R é payload[3], Case é payload[7]
                self.batteryLevelL = min(Int(message.payload[2] & 0x7F), 100)
                self.batteryLevelR = min(Int(message.payload[3] & 0x7F), 100)
                self.batteryLevelCase = min(Int(message.payload[7] & 0x7F), 100)
                print("Extended Status: L \(self.batteryLevelL)% R \(self.batteryLevelR)% Case \(self.batteryLevelCase)%")
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
            
        default:
            // break
            print("Mensagem recebida: \(message.id)")
        }
    }
}
