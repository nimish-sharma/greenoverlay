import SwiftUI
import AppKit
import CoreGraphics

@MainActor
final class OverlaySettings: ObservableObject {
    static let shared = OverlaySettings()

    @Published var opacity: Double = 0.45
    @Published var topCM: Double = 5
    @Published var bottomCM: Double = 5
    @Published var leftCM: Double = 5
    @Published var rightCM: Double = 5
    @Published var cornerRadius: Double = 18
    @Published var enabled = true
}

struct EdgeStrip: View {
    enum Side { case top, bottom, left, right }

    let side: Side
    let opacity: Double
    let radius: CGFloat

    var body: some View {
        let green = Color(red: 0, green: 1, blue: 0)
        let fade = green.opacity(0)
        let fill: LinearGradient = {
            switch side {
            case .top:
                LinearGradient(stops: [
                    .init(color: green.opacity(opacity), location: 0),
                    .init(color: green.opacity(opacity * 0.72), location: 0.35),
                    .init(color: fade, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            case .bottom:
                LinearGradient(stops: [
                    .init(color: green.opacity(opacity), location: 0),
                    .init(color: green.opacity(opacity * 0.72), location: 0.35),
                    .init(color: fade, location: 1)
                ], startPoint: .bottom, endPoint: .top)
            case .left:
                LinearGradient(stops: [
                    .init(color: green.opacity(opacity), location: 0),
                    .init(color: green.opacity(opacity * 0.72), location: 0.35),
                    .init(color: fade, location: 1)
                ], startPoint: .leading, endPoint: .trailing)
            case .right:
                LinearGradient(stops: [
                    .init(color: green.opacity(opacity), location: 0),
                    .init(color: green.opacity(opacity * 0.72), location: 0.35),
                    .init(color: fade, location: 1)
                ], startPoint: .trailing, endPoint: .leading)
            }
        }()
        fill
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .allowsHitTesting(false)
    }
}

struct OverlayView: View {
    @ObservedObject var settings: OverlaySettings
    let screen: NSScreen

    // Convert centimetres to points using the physical panel dimensions when macOS reports them.
    private func points(forCM cm: Double, horizontal: Bool) -> CGFloat {
        let displayID = screen.deviceDescription[ NSDeviceDescriptionKey("NSScreenNumber") ] as? CGDirectDisplayID
        if let displayID {
            let mm = CGDisplayScreenSize(displayID)
            let physicalMM = horizontal ? mm.width : mm.height
            let pointLength = horizontal ? screen.frame.width : screen.frame.height
            if physicalMM > 0 {
                return CGFloat(cm / (Double(physicalMM) / 10.0)) * pointLength
            }
        }
        // Fallback: 96 points per inch, approximate only.
        return CGFloat(cm) * 72.0 / 2.54
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if settings.enabled {
                    VStack(spacing: 0) {
                        EdgeStrip(side: .top, opacity: settings.opacity,
                                  radius: CGFloat(settings.cornerRadius))
                            .frame(height: min(points(forCM: settings.topCM, horizontal: false), proxy.size.height))
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 0) {
                        EdgeStrip(side: .left, opacity: settings.opacity,
                                  radius: CGFloat(settings.cornerRadius))
                            .frame(width: min(points(forCM: settings.leftCM, horizontal: true), proxy.size.width))
                        Spacer(minLength: 0)
                        EdgeStrip(side: .right, opacity: settings.opacity,
                                  radius: CGFloat(settings.cornerRadius))
                            .frame(width: min(points(forCM: settings.rightCM, horizontal: true), proxy.size.width))
                    }
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        EdgeStrip(side: .bottom, opacity: settings.opacity,
                                  radius: CGFloat(settings.cornerRadius))
                            .frame(height: min(points(forCM: settings.bottomCM, horizontal: false), proxy.size.height))
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Color.clear)
        .ignoresSafeArea()
    }
}

@MainActor
final class OverlayController: NSObject, NSApplicationDelegate {
    private var panels: [NSPanel] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        rebuildPanels()
        NotificationCenter.default.addObserver(self, selector: #selector(rebuildPanels),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshVisibility),
            name: .overlaySettingsChanged, object: nil)
    }

    @objc private func rebuildPanels() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()

        for screen in NSScreen.screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.contentView = NSHostingView(rootView: OverlayView(
                settings: OverlaySettings.shared, screen: screen))
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        refreshVisibility()
    }

    @objc private func refreshVisibility() {
        if OverlaySettings.shared.enabled {
            panels.forEach { $0.orderFrontRegardless() }
        } else {
            panels.forEach { $0.orderOut(nil) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

extension Notification.Name {
    static let overlaySettingsChanged = Notification.Name("overlaySettingsChanged")
}

struct ContentView: View {
    @ObservedObject private var s = OverlaySettings.shared

    private func edgeSlider(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value.wrappedValue, specifier: "%.1f") cm")
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...10, step: 0.1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Green Edge Overlay").font(.title2.bold())
                    Text("Solid RGB green • strongest at bezel").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("On", isOn: $s.enabled).labelsHidden()
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Green opacity")
                    Spacer()
                    Text("\(Int(s.opacity * 100))%").monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $s.opacity, in: 0...1)
            }

            Divider()
            Text("Independent edge widths").font(.headline)
            edgeSlider("Top", value: $s.topCM)
            edgeSlider("Bottom", value: $s.bottomCM)
            edgeSlider("Left", value: $s.leftCM)
            edgeSlider("Right", value: $s.rightCM)

            Divider()
            HStack {
                Text("Corner rounding")
                Spacer()
                Text("\(Int(s.cornerRadius)) px").foregroundStyle(.secondary)
            }
            Slider(value: $s.cornerRadius, in: 0...60, step: 1)

            HStack {
                Button("Reset") {
                    s.opacity = 0.45
                    s.topCM = 5; s.bottomCM = 5; s.leftCM = 5; s.rightCM = 5
                    s.cornerRadius = 18
                    s.enabled = true
                }
                Spacer()
                Text("Click-through • all displays").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .frame(width: 390)
        .onChange(of: s.enabled) { _, _ in
            NotificationCenter.default.post(name: .overlaySettingsChanged, object: nil)
        }
    }
}

@main
struct GreenEdgeOverlayApp: App {
    @NSApplicationDelegateAdaptor(OverlayController.self) private var controller

    var body: some Scene {
        WindowGroup { ContentView() }
            .windowResizability(.contentSize)
    }
}
