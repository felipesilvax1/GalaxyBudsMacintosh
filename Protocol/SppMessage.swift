import Foundation

public enum SppMessageError: Error {
    case tooSmall
    case invalidSom
    case invalidEom
    case sizeMismatch
    case invalidChecksum
}

public struct SppMessage {
    public var id: MsgIds
    public var type: MsgTypes
    public var payload: Data
    public var crc16: UInt16
    public var isFragment: Bool
    
    // O tamanho consiste em: 1 (MsgId) + payload.count + 2 (CRC)
    public var size: Int {
        return 1 + payload.count + 2
    }
    
    public init(id: MsgIds, type: MsgTypes = .request, payload: Data = Data(), isFragment: Bool = false) {
        self.id = id
        self.type = type
        self.payload = payload
        self.isFragment = isFragment
        self.crc16 = 0
    }
    
    // MARK: - Encode
    
    /// Codifica a mensagem num Data pronto para ser enviado via Bluetooth.
    /// Assume o formato moderno não-legacy (ex: Buds+ e mais recentes)
    public func encode(som: UInt8 = MsgConstants.som.rawValue, eom: UInt8 = MsgConstants.eom.rawValue) -> Data {
        var data = Data()
        
        // 1. Start Of Message
        data.append(som)
        
        // 2. Header (Tamanho + Flags) (2 bytes, Little Endian)
        var headerValue = UInt16(size & 0x3FF)
        if isFragment {
            headerValue |= 0x2000
        }
        if type == .response {
            headerValue |= 0x1000
        }
        
        withUnsafeBytes(of: headerValue.littleEndian) { buffer in
            data.append(contentsOf: buffer)
        }
        
        // 3. Message ID
        data.append(id.rawValue)
        
        // 4. Payload
        data.append(payload)
        
        // 5. CRC16-CCITT calculado sobre o [MsgId + Payload]
        var crcData = Data()
        crcData.append(id.rawValue)
        crcData.append(payload)
        let calculatedCrc = SppMessage.calculateCrc16(data: crcData)
        
        // Adiciona CRC16 em Little Endian
        withUnsafeBytes(of: calculatedCrc.littleEndian) { buffer in
            data.append(contentsOf: buffer)
        }
        
        // 6. End Of Message
        data.append(eom)
        
        return data
    }
    
    // MARK: - Decode
    
    /// Decodifica um fluxo de dados (Data) numa SppMessage
    public static func decode(from raw: Data, expectedSom: UInt8 = MsgConstants.som.rawValue, expectedEom: UInt8 = MsgConstants.eom.rawValue) throws -> SppMessage {
        guard raw.count >= 6 else {
            throw SppMessageError.tooSmall
        }
        
        var offset = 0
        
        // 1. Verifica SOM
        let som = raw[offset]
        guard som == expectedSom else {
            throw SppMessageError.invalidSom
        }
        offset += 1
        
        // 2. Header
        let headerValue = raw[offset..<offset+2].withUnsafeBytes { $0.loadUnaligned(as: UInt16.self).littleEndian }
        offset += 2
        
        let isFrag = (headerValue & 0x2000) != 0
        let msgType: MsgTypes = (headerValue & 0x1000) != 0 ? .request : .response
        let expectedSize = Int(headerValue & 0x3FF)
        
        // 3. Message ID
        let rawId = raw[offset]
        let msgId = MsgIds(rawValue: rawId) ?? .statusUpdated // Fallback para manter simples no MVP
        offset += 1
        
        // 4. Payload
        // O tamanho real do payload é expectedSize - 3 (1 do msgId, 2 do CRC)
        var payloadSize = expectedSize - 3
        if payloadSize < 0 { payloadSize = 0 }
        
        let payload = Data(raw[offset..<offset+payloadSize])
        offset += payloadSize
        
        // 5. CRC16
        let packetCrc = raw[offset..<offset+2].withUnsafeBytes { $0.loadUnaligned(as: UInt16.self).littleEndian }
        offset += 2
        
        // Validação do CRC
        var crcValidationData = Data()
        crcValidationData.append(rawId)
        crcValidationData.append(payload)
        
        let calculatedCrc = SppMessage.calculateCrc16(data: crcValidationData)
        guard calculatedCrc == packetCrc else {
            throw SppMessageError.invalidChecksum
        }
        
        // 6. EOM
        let eom = raw[offset]
        guard eom == expectedEom else {
            throw SppMessageError.invalidEom
        }
        
        var message = SppMessage(id: msgId, type: msgType, payload: payload, isFragment: isFrag)
        message.crc16 = packetCrc
        return message
    }
    
    // MARK: - CRC16-CCITT
    
    public static func calculateCrc16(data: Data) -> UInt16 {
        var crc: UInt16 = 0x0000
        for byte in data {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                if (crc & 0x8000) != 0 {
                    crc = (crc << 1) ^ 0x1021
                } else {
                    crc <<= 1
                }
            }
        }
        return crc
    }
}
