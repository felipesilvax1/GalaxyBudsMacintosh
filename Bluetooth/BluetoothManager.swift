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
        if sdpRecord.getRFCOMMChannelID(&channelID) == kIOReturnSuccess {
            let status = device.openRFCOMMChannelAsync(&rfcommChannel, withChannelID: channelID, delegate: self)
            if status != kIOReturnSuccess {
                print("Erro ao tentar abrir o canal RFCOMM async: \(status)")
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
}

// MARK: - IOBluetoothRFCOMMChannelDelegate
extension BluetoothManager: IOBluetoothRFCOMMChannelDelegate {
    
    public func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        if error == kIOReturnSuccess {
            print("Conexão RFCOMM aberta com sucesso!")
            self.isConnected = true
            self.dataBuffer.removeAll() // Resetar buffer ao conectar
            
            // Ao conectar, enviamos o handshake do MVP (Manager Info) para acordar o dispositivo e pedir status
            let handshakeMsg = SppMessage(id: .managerInfo, type: .request, payload: Data())
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
                
                // Se decodificou com sucesso, remover os bytes do pacote do buffer
                self.dataBuffer.removeFirst(message.size)
                
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
            
        case .statusUpdated, .extendedStatusUpdated:
            // Dependendo do payload da Samsung, os dados de bateria costumam estar em posições fixas.
            // Aqui estamos assumindo bytes de exemplo (no protocolo oficial, geralmente L e R e Case).
            // Se o payload for maior ou igual a 4 bytes, fazemos o parse seguro.
            if message.payload.count >= 4 {
                self.batteryLevelL = Int(message.payload[1])
                self.batteryLevelR = Int(message.payload[2])
                self.batteryLevelCase = Int(message.payload[3])
                print("Bateria Atualizada: L \(self.batteryLevelL)% R \(self.batteryLevelR)% Case \(self.batteryLevelCase)%")
            } else {
                print("Payload de bateria muito pequeno: \(message.payload.count) bytes")
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
