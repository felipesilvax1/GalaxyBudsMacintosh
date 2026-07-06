import Foundation
import MetricKit

/// Gerenciador de telemetria focado estritamente no ecossistema nativo da Apple via MetricKit.
/// Evita o uso de Sentry ou envio de relatórios de uso da máquina do usuário para servidores de terceiros.
@MainActor
class TelemetryManager: NSObject, MXMetricManagerSubscriber {
    static let shared = TelemetryManager()
    
    private override init() {
        super.init()
        MXMetricManager.shared.add(self)
        print("MetricKit Telemetry Iniciada. Mantendo logs no ecossistema Apple.")
    }
    
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            if let cpuMetrics = payload.cpuMetrics {
                print("[MetricKit] Tempo de CPU Acumulado: \(cpuMetrics.cumulativeCPUTime.value) \(cpuMetrics.cumulativeCPUTime.unit.symbol)")
            }
            if let memoryMetrics = payload.memoryMetrics {
                print("[MetricKit] Pico de Memória: \(memoryMetrics.peakMemoryUsage.value) \(memoryMetrics.peakMemoryUsage.unit.symbol)")
            }
            // Sem envios HTTP, telemetria restrita ao log local para garantir privacidade.
        }
    }
    
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for diagnostic in payloads {
            if let crashDiag = diagnostic.crashDiagnostics, !crashDiag.isEmpty {
                print("[MetricKit] Alerta: \(crashDiag.count) crash(es) detectados e armazenados localmente.")
            }
        }
    }
}
