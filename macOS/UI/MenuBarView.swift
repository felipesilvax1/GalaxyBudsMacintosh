import SwiftUI

struct MenuBarView: View {
    var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack(spacing: 16) {
            // MARK: - Header
            HStack {
                Text(bluetoothManager.deviceName)
                    .font(.headline)
                Spacer()
                Button(action: {
                    if bluetoothManager.isConnected {
                        bluetoothManager.disconnect()
                    } else {
                        bluetoothManager.connectToPairedBuds()
                    }
                }) {
                    Image(systemName: bluetoothManager.isConnected ? "link" : "link.badge.plus")
                        .foregroundColor(bluetoothManager.isConnected ? .blue : .primary)
                }
                .buttonStyle(.plain)
            }
            
            // MARK: - Bateria
            HStack(spacing: 20) {
                BatteryIndicator(label: "L", level: bluetoothManager.batteryLevelL)
                BatteryIndicator(label: "R", level: bluetoothManager.batteryLevelR)
                BatteryIndicator(label: "Case", level: bluetoothManager.batteryLevelCase)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // MARK: - Noise Control
            VStack(alignment: .leading, spacing: 10) {
                Text("Noise Control")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    NoiseButton(title: "ANC", icon: "waveform.path", isSelected: bluetoothManager.currentNoiseMode == "ANC") {
                        bluetoothManager.currentNoiseMode = "ANC"
                        bluetoothManager.setNoiseControlMode("ANC")
                    }
                    NoiseButton(title: "Off", icon: "power", isSelected: bluetoothManager.currentNoiseMode == "Off") {
                        bluetoothManager.currentNoiseMode = "Off"
                        bluetoothManager.setNoiseControlMode("Off")
                    }
                    NoiseButton(title: "Ambient", icon: "ear", isSelected: bluetoothManager.currentNoiseMode == "Ambient") {
                        bluetoothManager.currentNoiseMode = "Ambient"
                        bluetoothManager.setNoiseControlMode("Ambient")
                    }
                }
            }
            
            Divider()
            
            // MARK: - Voice Detect
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Voice Detect")
                            .font(.subheadline)
                        Text("Switches to Ambient when you speak")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { bluetoothManager.voiceDetectEnabled },
                        set: { bluetoothManager.setVoiceDetect(enabled: $0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                }
                
                if bluetoothManager.voiceDetectEnabled {
                    HStack(spacing: 8) {
                        Text("Timeout")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        ForEach([5, 10, 15], id: \.self) { seconds in
                            Button("\(seconds)s") {
                                bluetoothManager.setVoiceDetectTimeout(seconds)
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .fontWeight(bluetoothManager.voiceDetectTimeout == seconds ? .bold : .regular)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                bluetoothManager.voiceDetectTimeout == seconds
                                    ? Color.blue.opacity(0.2)
                                    : Color.primary.opacity(0.05)
                            )
                            .foregroundColor(
                                bluetoothManager.voiceDetectTimeout == seconds
                                    ? .blue
                                    : .primary
                            )
                            .clipShape(Capsule())
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: bluetoothManager.voiceDetectEnabled)
            
            Divider()
            
            // MARK: - Sair
            Button("Quit Galaxy Buds") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 320)
        // Aplica o efeito ultraThinMaterial para o visual nativo Control Center
        .background(Material.ultraThinMaterial)
    }
}

// MARK: - Componentes Auxiliares

struct BatteryIndicator: View {
    var label: String
    var level: Int
    
    var body: some View {
        VStack {
            Image(systemName: batteryIcon)
                .foregroundColor(batteryColor)
                .font(.title2)
            Text("\(level)%")
                .font(.caption)
                .fontWeight(.medium)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var batteryIcon: String {
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        return "battery.25"
    }
    
    private var batteryColor: Color {
        if level > 20 { return .green }
        return .red
    }
}

struct NoiseButton: View {
    var title: String
    var icon: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.blue : Color.primary.opacity(0.1))
                    .clipShape(Circle())
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
