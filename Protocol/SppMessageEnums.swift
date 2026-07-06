import Foundation

/// Tipos de mensagem (Request ou Response)
public enum MsgTypes: UInt8 {
    case request = 0
    case response = 1
}

/// Constantes do pacote (Start of Message, End of Message)
public enum MsgConstants: UInt8 {
    case smepSom = 0xFC
    case smepEom = 0xCC
    
    case som = 0xFD
    case eom = 0xDD
    
    case legacySom = 0xFE
    case legacyEom = 0xEE
}

/// Identificadores de Mensagens (MVP)
/// Contém estritamente os comandos para Handshake/Conexão, Bateria, Modos de Ruído e Equalizador.
public enum MsgIds: UInt8 {
    
    // MARK: - Handshake / Conexão e Status (Inclui Bateria)
    /// Usado geralmente para solicitar o status inicial / handshake
    case managerInfo = 136
    /// Status atualizado (contém dados essenciais como a bateria L, R e Case)
    case statusUpdated = 96
    /// Status estendido
    case extendedStatusUpdated = 97
    /// Informação de versão (usado em handshake inicial)
    case versionInfo = 99
    
    // MARK: - Modos de Ruído (ANC, Ambient, Off)
    /// Atualizar controles de ruído
    case noiseControlsUpdate = 119
    /// Configurar modos de controle de ruído
    case noiseControls = 120
    /// Configurar modo ambiente (em alguns modelos antigos)
    case setAmbientMode = 128
    /// Atualização de modo ambiente
    case ambientModeUpdated = 129
    
    // MARK: - Equalizador Básico
    /// Mudar o preset do equalizador
    case equalizer = 134
}
