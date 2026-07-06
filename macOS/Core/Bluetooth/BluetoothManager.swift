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
    
    // Fila dedicada para operações de rede Bluetooth, evitando travar a Main Thread
    private let bluetoothQueue = DispatchQueue(label: "com.galaxybuds.bluetooth", qos: .userInitiated)
    
    // UUID padrão para a Serial Port Profile (SPP)
    private let sppServiceUUID = IOBluetoothSDPUUID(uuid16: 0x1101)
    
    public override init() {
        super.init()
    }
    
    // MARK: - Descoberta e Conexão
    
    /// Busca entre os dispositivos já pareados do macOS algum que corresponda aos Galaxy Buds.
    public func connectToPairedBuds() {
        bluetoothQueue.async {
            // Obter todos os dispositivos pareados do sistema (sem gastar bateria fazendo um novo Inquiry)
            guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
                print("Nenhum dispositivo Bluetooth pareado no Mac.")
                return
            }
            
            // Filtrar usando "Buds" (cobre Galaxy Buds, Buds+, Buds Live, Buds Pro, Buds2, Buds2 Pro, Buds3, Buds3 Pro)
            guard let budsDevice = pairedDevices.first(where: { ($0.nameOrAddress ?? "").contains("Buds") }) else {
                print("Nenhum Galaxy Buds encontrado nos dispositivos pareados.")
                return
            }
            
            print("Encontrado: \(budsDevice.nameOrAddress ?? "Unknown"). Iniciando tentativa de conexão...")
            
            self.openRFCOMMChannel(device: budsDevice)
        }
    }
    
    private func openRFCOMMChannel(device: IOBluetoothDevice) {
        // Encontrar o registro de serviço (SDP) para SPP
        guard let sdpRecord = device.getServiceRecord(for: sppServiceUUID) else {
            print("Serviço SPP (Serial Port Profile) não encontrado no dispositivo.")
            return
        }
        
        var channelID: BluetoothRFCOMMChannelID = 0
        if sdpRecord.getRFCOMMChannelID(&channelID) == kIOReturnSuccess {
            // Abrir canal serial assincronamente com Delegate na nossa classe
            let status = device.openRFCOMMChannelAsync(&rfcommChannel, withChannelID: channelID, delegate: self)
            
            if status != kIOReturnSuccess {
                print("Erro ao tentar abrir o canal RFCOMM async: \(status)")
            }
        } else {
            print("Falha ao obter o ID de canal RFCOMM a partir do SDP.")
        }
    }
    
    public func disconnect() {
        bluetoothQueue.async {
            self.rfcommChannel?.closeChannel()
            self.rfcommChannel = nil
            
            Task { @MainActor in
                self.isConnected = false
                print("Desconectado.")
            }
        }
    }
    
    // MARK: - Transmissão de Dados
    
    /// Codifica e envia um pacote SppMessage pela rede serial
    public func send(message: SppMessage) {
        bluetoothQueue.async { [weak self] in
            guard let channel = self?.rfcommChannel, channel.isOpen() else {
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
}

// MARK: - IOBluetoothRFCOMMChannelDelegate
extension BluetoothManager: IOBluetoothRFCOMMChannelDelegate {
    
    public func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        if error == kIOReturnSuccess {
            print("Conexão RFCOMM aberta com sucesso!")
            
            Task { @MainActor in
                self.isConnected = true
            }
            
            // Ao conectar, enviamos o handshake do MVP (Manager Info) para acordar o dispositivo e pedir status
            let handshakeMsg = SppMessage(id: .managerInfo, type: .request, payload: Data())
            self.send(message: handshakeMsg)
            
        } else {
            print("Falha ao completar a abertura do canal RFCOMM. Erro: \(error)")
            Task { @MainActor in
                self.isConnected = false
            }
        }
    }
    
    public func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let incomingData = Data(bytes: dataPointer, count: dataLength)
        
        // Passar a decodificação pesada para background
        bluetoothQueue.async {
            do {
                let message = try SppMessage.decode(from: incomingData)
                self.processReceivedMessage(message)
            } catch {
                // Em um ambiente de produção real, é necessário acumular os buffers caso o pacote chegue fragmentado.
                // Mas para o MVP, assumimos pacotes curtos inteiros.
                print("Aviso: Falha ao decodificar a mensagem recebida: \(error)")
            }
        }
    }
    
    public func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        print("O canal RFCOMM foi fechado pelo dispositivo remoto ou pelo sistema.")
        Task { @MainActor in
            self.isConnected = false
        }
    }
    
    // MARK: - Processamento de Mensagens
    
    /// Atualiza os estados do @Observable a partir de um pacote recebido.
    private func processReceivedMessage(_ message: SppMessage) {
        // Garantir que a UI atualize na Main Actor
        Task { @MainActor in
            switch message.id {
                
            case .statusUpdated, .extendedStatusUpdated:
                // No protocolo real da Samsung, a bateria geralmente está localizada em índices fixos do payload (ex: bytes 1, 2, 3)
                // Para o MVP, definimos um esqueleto defensivo para evitar crashes:
                if message.payload.count >= 4 {
                    self.batteryLevelL = Int(message.payload[1])
                    self.batteryLevelR = Int(message.payload[2])
                    self.batteryLevelCase = Int(message.payload[3])
                }
                
            case .ambientModeUpdated, .noiseControlsUpdate:
                // Exemplo simplificado, o byte de controle diz se é ANC, Ambient ou Off
                if let modeByte = message.payload.first {
                    switch modeByte {
                    case 0x00: self.currentNoiseMode = "Off"
                    case 0x01: self.currentNoiseMode = "ANC"
                    case 0x02: self.currentNoiseMode = "Ambient"
                    default: self.currentNoiseMode = "Unknown"
                    }
                }
                
            default:
                // Ignora logs muito ruidosos, mas pode ser ativado para debug
                // print("Mensagem recebida mas não mapeada no MVP: \(message.id)")
                break
            }
        }
    }
}
