import Cocoa
import SwiftUI

/// Painel flutuante customizado (sem bordas e que não rouba o foco da tela atual)
/// Serve para exibir o popup idêntico ao dos AirPods quando conectados.
public class ConnectionPanel: NSPanel {
    
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 110),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        
        // Efeito de vidro por trás do painel
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 20
        
        let hostingView = NSHostingView(rootView: ConnectionPopupView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor)
        ])
        
        self.contentView = visualEffectView
        
        // Posicionar na base da tela (como notificações) ou no topo
        if let screen = NSScreen.main {
            let x = (screen.frame.width - self.frame.width) / 2
            let y = screen.frame.height - self.frame.height - 50
            self.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            self.center()
        }
    }
    
    /// Anima o surgimento e o desaparecimento do painel
    public func showAndHide() {
        self.alphaValue = 0.0
        self.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            self.animator().alphaValue = 1.0
        } completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.5
                    self.animator().alphaValue = 0.0
                } completionHandler: {
                    self.orderOut(nil)
                }
            }
        }
    }
}

/// View SwiftUI exibida dentro do painel
struct ConnectionPopupView: View {
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: "earbuds")
                .font(.system(size: 44))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Galaxy Buds")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Conectados")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(24)
        // Background do painel já é o NSVisualEffectView hudWindow
    }
}
