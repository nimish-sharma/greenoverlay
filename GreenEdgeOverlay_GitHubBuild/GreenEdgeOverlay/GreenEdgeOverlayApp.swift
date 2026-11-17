
import SwiftUI
import AppKit
import CoreGraphics

@MainActor
final class OverlaySettings: ObservableObject {
    static let shared = OverlaySettings()

    @Published var topOpacity: Double = 0.45
    @Published var bottomOpacity: Double = 0.45
    @Published var leftOpacity: Double = 0.45
    @Published var rightOpacity: Double = 0.45

    @Published var topCM: Double = 5
    @Published var bottomCM: Double = 5
    @Published var leftCM: Double = 5
    @Published var rightCM: Double = 5

    @Published var cornerRadius: Double = 18
    @Published var enabled = true
}

struct EdgeStrip: View {
    enum Side {
        case top, bottom, left, right
    }

    let side: Side
    let opacity: Double
    let radius: CGFloat

    var body: some View {
        let green = Color(red: 0, green: 1, blue: 0)
        let transparent = green.opacity(0)

        let fill: LinearGradient = {
            switch side {
            case .top:
                return LinearGradient(
                    stops: [
                        .init(color: green.opacity(opacity), location: 0),
                        .init(color: green.opacity(opacity * 0.72), location: 0.35),
                        .init(color: transparent, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

            case .bottom:
                return LinearGradient(
                    stops: [
                        .init(color: green.opacity(opacity), location: 0),
                        .init(color: green.opacity(opacity * 0.72), location: 0.35),
                        .init(color: transparent, location: 1)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )

            case .left:
                return LinearGradient(
                    stops: [
                        .init(color: green.opacity(opacity), location: 0),
                        .init(color: green.opacity(opacity * 0.72), location: 0.35),
                        .init(color: transparent, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

            case .right:
                return LinearGradient(
                    stops: [
                        .init(color: green.opacity(opacity), location: 0),
                        .init(color: green.opacity(opacity * 0.72), location: 0.35),
                        .init(color: transparent, location: 1)
                    ],
                    startPoint: .trailing,
                    endPoint: .leading
                )
            }
        }()

        fill
            .clipShape(
                RoundedRectangle(
                    cornerRadius: radius,
                    style: .continuous
                )
            )
            .allowsHitTesting(false)
    }
}

struct OverlayView: View {
    @ObservedObject var settings: OverlaySettings
    let screen: NSScreen

    private func points(forCM cm: Double, horizontal: Bool) -> CGFloat {
        let key = NSDeviceDescriptionKey("NSScreenNumber")

        if let displayID = screen.deviceDescription[key] as? CGDirectDisplayID {
            let size = CGDisplayScreenSize(displayID)
            let physicalMM = horizontal ? size.width : size.height
            let pointLength = horizontal ? screen.frame.width : screen.frame.height

            if physicalMM > 0 {
                return CGFloat(cm / (Double(physicalMM) / 10.0)) * pointLength
            }
        }

        return CGFloat(cm) * 72.0 / 2.54
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if settings.enabled {
                    VStack(spacing: 0) {
                        EdgeStrip(
                            side: .top,
                            opacity: settings.topOpacity,
                            radius: CGFloat(settings.cornerRadius)
                        )
                        .frame(
                            height: min(
                                points(forCM: settings.topCM, horizontal: false),
                                proxy.size.height
                            )
                        )
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 0) {
                        EdgeStrip(
                            side: .left,
                            opacity: settings.leftOpacity,
                            radius: CGFloat(settings.cornerRadius)
                        )
                        .frame(
                            width: min(
                                points(forCM: settings.leftCM, horizontal: true),
                                proxy.size.width
                            )
                        )

                        Spacer(minLength: 0)

                        EdgeStrip(
                            side: .right,
                            opacity: settings.rightOpacity,
                            radius: CGFloat(settings.cornerRadius)
                        )
                        .frame(
                            width: min(
                                points(forCM: settings.rightCM, horizontal: true),
                                proxy.size.width
                            )
                        )
                    }

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        EdgeStrip(
                            side: .bottom,
                            opacity: settings.bottomOpacity,
                            radius: CGFloat(settings.cornerRadius)
                        )
                        .frame(
                            height: min(
                                points(forCM: settings.bottomCM, horizontal: false),
                                proxy.size.height
                            )
                        )
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildPanels),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshVisibility),
            name: .overlaySettingsChanged,
            object: nil
        )
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
            panel.level = NSWindow.Level(
                rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1
            )
            panel.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary
            ]

            panel.contentView = NSHostingView(
                rootView: OverlayView(
                    settings: OverlaySettings.shared,
                    screen: screen
                )
            )

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

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        return false
    }
}

extension Notification.Name {
    static let overlaySettingsChanged =
        Notification.Name("overlaySettingsChanged")
}

struct ContentView: View {
    @ObservedObject private var s = OverlaySettings.shared

    private func edgeSlider(
        _ label: String,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value.wrappedValue, specifier: "%.1f") cm")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...10, step: 0.1)
        }
    }

    private func opacitySlider(
        _ label: String,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Green Edge Overlay")
                        .font(.title2.bold())
                    Text("Solid RGB green • strongest at bezel")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("On", isOn: $s.enabled)
                    .labelsHidden()
            }

            Divider()

            Text("Independent edge widths")
                .font(.headline)

            edgeSlider("Top width", value: $s.topCM)
            edgeSlider("Bottom width", value: $s.bottomCM)
            edgeSlider("Left width", value: $s.leftCM)
            edgeSlider("Right width", value: $s.rightCM)

            Divider()

            Text("Independent edge opacity")
                .font(.headline)

            opacitySlider("Top opacity", value: $s.topOpacity)
            opacitySlider("Bottom opacity", value: $s.bottomOpacity)
            opacitySlider("Left opacity", value: $s.leftOpacity)
            opacitySlider("Right opacity", value: $s.rightOpacity)

            Divider()

            HStack {
                Text("Corner rounding")
                Spacer()
                Text("\(Int(s.cornerRadius)) px")
                    .foregroundStyle(.secondary)
            }

            Slider(value: $s.cornerRadius, in: 0...60, step: 1)

            HStack {
                Button("Reset") {
                    s.topOpacity = 0.45
                    s.bottomOpacity = 0.45
                    s.leftOpacity = 0.45
                    s.rightOpacity = 0.45

                    s.topCM = 5
                    s.bottomCM = 5
                    s.leftCM = 5
                    s.rightCM = 5

                    s.cornerRadius = 18
                    s.enabled = true
                }

                Spacer()

                Text("Click-through • all displays")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .frame(width: 410)
        .onChange(of: s.enabled) { _ in
            NotificationCenter.default.post(
                name: .overlaySettingsChanged,
                object: nil
            )
        }
    }
}

@main
struct GreenEdgeOverlayApp: App {
    @NSApplicationDelegateAdaptor(OverlayController.self)
    private var controller

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
