import Foundation
import IOBluetooth
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
            // Executamos no MainActor para garantir RunLoop
            self.openRFCOMMChannel(device: device)
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
        self.openRFCOMMChannel(device: budsDevice)
    }
    
    private func openRFCOMMChannel(device: IOBluetoothDevice) {
        var targetRecord: IOBluetoothSDPServiceRecord? = nil
        
        for uuid in sppUUIDs {
            if let record = device.getServiceRecord(for: uuid) {
                targetRecord = record
                print("Serviço SPP encontrado com UUID: \(uuid)")
                break
            }
        }
        
        guard let sdpRecord = targetRecord else {
            print("Nenhum serviço SPP conhecido encontrado no dispositivo.")
            return
        }
        
        var channelID: BluetoothRFCOMMChannelID = 0
        if targetRecord!.getRFCOMMChannelID(&channelID) == kIOReturnSuccess {
            print("Canal RFCOMM ID: \(channelID)")
            
            // 1. Abrir conexão base antes (necessário em algumas versões do macOS)
            if !device.isConnected() {
                let connStatus = device.openConnection()
                if connStatus != kIOReturnSuccess && connStatus != kIOReturnTimeout {
                    print("Erro ao tentar abrir a conexão base (openConnection): \(connStatus)")
                }
            }
            
            // 2. Usar a versão Sync com Workaround para o bug do macOS
            var tempChannel: IOBluetoothRFCOMMChannel? = nil
            let status = device.openRFCOMMChannelSync(&tempChannel, withChannelID: channelID, delegate: self)
            self.rfcommChannel = tempChannel
            
            DispatchQueue.global().async {
                var waitCount = 0
                while self.rfcommChannel?.isOpen() == false && waitCount < 15 {
                    Thread.sleep(forTimeInterval: 0.1)
                    waitCount += 1
                }
                
                DispatchQueue.main.async {
                    if self.rfcommChannel?.isOpen() == true {
                        print("Canal RFCOMM está OPEN após \(waitCount * 100)ms (Status original: \(status))")
                        self.rfcommChannelOpenComplete(self.rfcommChannel, status: kIOReturnSuccess)
                    } else {
                        print("Falha ao abrir o canal RFCOMM async/sync após 1.5s. Status original: \(status)")
                    }
                }
            }
            
        } else {
            print("Falha ao obter o ID de canal RFCOMM a partir do SDP.")
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
