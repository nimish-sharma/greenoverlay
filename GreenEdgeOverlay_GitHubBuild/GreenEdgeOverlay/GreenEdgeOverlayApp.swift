
import SwiftUI
import AppKit
import Combine
import CoreGraphics

// MARK: - Application

@main
struct GreenEdgeOverlayApp: App {
    @StateObject private var settings = OverlaySettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .frame(minWidth: 500, minHeight: 650)
                .onAppear {
                    OverlayController.shared.configure(settings: settings)
                }
        }
    }
}

// MARK: - Settings and Persistence

final class OverlaySettings: ObservableObject {

    private let defaults = UserDefaults.standard

    @Published var enabled: Bool {
        didSet { save() }
    }

    @Published var topEnabled: Bool {
        didSet { save() }
    }

    @Published var bottomEnabled: Bool {
        didSet { save() }
    }

    @Published var leftEnabled: Bool {
        didSet { save() }
    }

    @Published var rightEnabled: Bool {
        didSet { save() }
    }

    @Published var topOpacity: Double {
        didSet { save() }
    }

    @Published var bottomOpacity: Double {
        didSet { save() }
    }

    @Published var leftOpacity: Double {
        didSet { save() }
    }

    @Published var rightOpacity: Double {
        didSet { save() }
    }

    @Published var topCM: Double {
        didSet { save() }
    }

    @Published var bottomCM: Double {
        didSet { save() }
    }

    @Published var leftCM: Double {
        didSet { save() }
    }

    @Published var rightCM: Double {
        didSet { save() }
    }

    @Published var cornerRadius: Double {
        didSet { save() }
    }

    init() {
        enabled = defaults.object(forKey: "enabled") as? Bool ?? true

        topEnabled = defaults.object(forKey: "topEnabled") as? Bool ?? true
        bottomEnabled = defaults.object(forKey: "bottomEnabled") as? Bool ?? true
        leftEnabled = defaults.object(forKey: "leftEnabled") as? Bool ?? true
        rightEnabled = defaults.object(forKey: "rightEnabled") as? Bool ?? true

        topOpacity = defaults.object(forKey: "topOpacity") as? Double ?? 0.45
        bottomOpacity = defaults.object(forKey: "bottomOpacity") as? Double ?? 0.45
        leftOpacity = defaults.object(forKey: "leftOpacity") as? Double ?? 0.45
        rightOpacity = defaults.object(forKey: "rightOpacity") as? Double ?? 0.45

        topCM = defaults.object(forKey: "topCM") as? Double ?? 5.0
        bottomCM = defaults.object(forKey: "bottomCM") as? Double ?? 5.0
        leftCM = defaults.object(forKey: "leftCM") as? Double ?? 5.0
        rightCM = defaults.object(forKey: "rightCM") as? Double ?? 5.0

        cornerRadius = defaults.object(forKey: "cornerRadius") as? Double ?? 18.0
    }

    func save() {
        defaults.set(enabled, forKey: "enabled")

        defaults.set(topEnabled, forKey: "topEnabled")
        defaults.set(bottomEnabled, forKey: "bottomEnabled")
        defaults.set(leftEnabled, forKey: "leftEnabled")
        defaults.set(rightEnabled, forKey: "rightEnabled")

        defaults.set(topOpacity, forKey: "topOpacity")
        defaults.set(bottomOpacity, forKey: "bottomOpacity")
        defaults.set(leftOpacity, forKey: "leftOpacity")
        defaults.set(rightOpacity, forKey: "rightOpacity")

        defaults.set(topCM, forKey: "topCM")
        defaults.set(bottomCM, forKey: "bottomCM")
        defaults.set(leftCM, forKey: "leftCM")
        defaults.set(rightCM, forKey: "rightCM")

        defaults.set(cornerRadius, forKey: "cornerRadius")
    }

    func reset() {
        enabled = true

        topEnabled = true
        bottomEnabled = true
        leftEnabled = true
        rightEnabled = true

        topOpacity = 0.45
        bottomOpacity = 0.45
        leftOpacity = 0.45
        rightOpacity = 0.45

        topCM = 5.0
        bottomCM = 5.0
        leftCM = 5.0
        rightCM = 5.0

        cornerRadius = 18.0
    }
}

// MARK: - Overlay Controller

final class OverlayController {

    static let shared = OverlayController()

    private var settings: OverlaySettings?
    private var cancellables = Set<AnyCancellable>()

    private var panels: [CGDirectDisplayID: NSPanel] = [:]

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func configure(settings: OverlaySettings) {
        self.settings = settings

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                DispatchQueue.main.async {
                    self?.updateOverlays()
                }
            }
            .store(in: &cancellables)

        updateOverlays()
    }

    @objc private func screenConfigurationChanged() {
        updateOverlays()
    }

    private func updateOverlays() {
        guard let settings = settings else { return }

        // Only use external displays.
        let externalScreens = NSScreen.screens.filter { screen in
            guard let displayID = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID else {
                return false
            }

            // CGDisplayIsBuiltin returns 0 for an external display.
            return CGDisplayIsBuiltin(displayID) == 0
        }

        let activeIDs = Set(
            externalScreens.compactMap { screen in
                screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                ] as? CGDirectDisplayID
            }
        )

        // Remove panels for disconnected displays.
        for (displayID, panel) in panels {
            if !activeIDs.contains(displayID) {
                panel.close()
                panels.removeValue(forKey: displayID)
            }
        }

        // Create or update panels.
        for screen in externalScreens {
            guard let displayID = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID else {
                continue
            }

            if let panel = panels[displayID] {
                panel.setFrame(screen.frame, display: true)

                if let hostingView = panel.contentView as? NSHostingView<OverlayView> {
                    hostingView.rootView = OverlayView(
                        settings: settings,
                        screen: screen
                    )
                }
            } else {
                createPanel(for: screen, displayID: displayID, settings: settings)
            }
        }

        refreshVisibility()
    }

    private func createPanel(
        for screen: NSScreen,
        displayID: CGDirectDisplayID,
        settings: OverlaySettings
    ) {
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver

        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        let hostingView = NSHostingView(
            rootView: OverlayView(
                settings: settings,
                screen: screen
            )
        )

        hostingView.frame = screen.frame
        hostingView.autoresizingMask = [.width, .height]

        panel.contentView = hostingView

        panels[displayID] = panel

        panel.orderFrontRegardless()
    }

    private func refreshVisibility() {
        guard let settings = settings else { return }

        for panel in panels.values {
            if settings.enabled {
                panel.orderFrontRegardless()
            } else {
                panel.orderOut(nil)
            }
        }
    }
}

// MARK: - Overlay View

struct OverlayView: View {

    @ObservedObject var settings: OverlaySettings
    let screen: NSScreen

    private func points(forCM cm: Double) -> CGFloat {
        guard let displayID = screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? CGDirectDisplayID else {
            return CGFloat(cm * 72.0 / 2.54)
        }

        let physicalSize = CGDisplayScreenSize(displayID)

        if physicalSize.width > 0 {
            let pointsPerCM = screen.frame.width / (physicalSize.width / 10.0)
            return CGFloat(cm) * pointsPerCM
        }

        return CGFloat(cm * 72.0 / 2.54)
    }

    var body: some View {
        GeometryReader { geometry in

            ZStack(alignment: .topLeading) {

                if settings.enabled {

                    // TOP EDGE
                    if settings.topEnabled {
                        EdgeStrip(
                            opacity: settings.topOpacity,
                            direction: .top,
                            cornerRadius: settings.cornerRadius
                        )
                        .frame(
                            width: geometry.size.width,
                            height: points(forCM: settings.topCM)
                        )
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .top
                        )
                    }

                    // BOTTOM EDGE
                    if settings.bottomEnabled {
                        EdgeStrip(
                            opacity: settings.bottomOpacity,
                            direction: .bottom,
                            cornerRadius: settings.cornerRadius
                        )
                        .frame(
                            width: geometry.size.width,
                            height: points(forCM: settings.bottomCM)
                        )
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .bottom
                        )
                    }

                    // LEFT EDGE
                    if settings.leftEnabled {
                        EdgeStrip(
                            opacity: settings.leftOpacity,
                            direction: .left,
                            cornerRadius: settings.cornerRadius
                        )
                        .frame(
                            width: points(forCM: settings.leftCM),
                            height: geometry.size.height
                        )
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .leading
                        )
                    }

                    // RIGHT EDGE
                    if settings.rightEnabled {
                        EdgeStrip(
                            opacity: settings.rightOpacity,
                            direction: .right,
                            cornerRadius: settings.cornerRadius
                        )
                        .frame(
                            width: points(forCM: settings.rightCM),
                            height: geometry.size.height
                        )
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .trailing
                        )
                    }
                }
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Gradient Strip

enum EdgeDirection {
    case top
    case bottom
    case left
    case right
}

struct EdgeStrip: View {

    let opacity: Double
    let direction: EdgeDirection
    let cornerRadius: Double

    var body: some View {

        let green = Color(
            red: 0.0,
            green: 1.0,
            blue: 0.0
        )

        let gradient = LinearGradient(
            stops: [
                .init(color: green.opacity(opacity), location: 0.0),
                .init(color: green.opacity(opacity * 0.72), location: 0.35),
                .init(color: green.opacity(opacity * 0.25), location: 0.7),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: startPoint,
            endPoint: endPoint
        )

        gradient
            .clipShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
            )
    }

    private var startPoint: UnitPoint {
        switch direction {
        case .top: return .top
        case .bottom: return .bottom
        case .left: return .leading
        case .right: return .trailing
        }
    }

    private var endPoint: UnitPoint {
        switch direction {
        case .top: return .bottom
        case .bottom: return .top
        case .left: return .trailing
        case .right: return .leading
        }
    }
}

// MARK: - Settings Interface

struct ContentView: View {

    @EnvironmentObject var settings: OverlaySettings

    var body: some View {

        VStack(spacing: 16) {

            HStack {
                Image(systemName: "display")
                    .font(.system(size: 26))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Green Edge Overlay")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("External monitor only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("Enable", isOn: $settings.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider()

            ScrollView {

                VStack(spacing: 18) {

                    EdgeControl(
                        title: "Top Edge",
                        isEnabled: $settings.topEnabled,
                        opacity: $settings.topOpacity,
                        width: $settings.topCM
                    )

                    EdgeControl(
                        title: "Bottom Edge",
                        isEnabled: $settings.bottomEnabled,
                        opacity: $settings.bottomOpacity,
                        width: $settings.bottomCM
                    )

                    EdgeControl(
                        title: "Left Edge",
                        isEnabled: $settings.leftEnabled,
                        opacity: $settings.leftOpacity,
                        width: $settings.leftCM
                    )

                    EdgeControl(
                        title: "Right Edge",
                        isEnabled: $settings.rightEnabled,
                        opacity: $settings.rightOpacity,
                        width: $settings.rightCM
                    )

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {

                        HStack {
                            Text("Corner Radius")
                                .fontWeight(.medium)

                            Spacer()

                            Text("\(Int(settings.cornerRadius))")
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }

                        Slider(
                            value: $settings.cornerRadius,
                            in: 0...60
                        )
                    }

                    Divider()

                    Button("Reset to Defaults") {
                        settings.reset()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            }

            Divider()

            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)

                Text("Settings save automatically")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding(20)
    }
}

// MARK: - Individual Edge Controls

struct EdgeControl: View {

    let title: String

    @Binding var isEnabled: Bool
    @Binding var opacity: Double
    @Binding var width: Double

    var body: some View {

        VStack(alignment: .leading, spacing: 10) {

            HStack {

                Toggle(title, isOn: $isEnabled)
                    .fontWeight(.semibold)

                Spacer()

                Text(isEnabled ? "ON" : "OFF")
                    .font(.caption)
                    .foregroundColor(isEnabled ? .green : .secondary)
            }

            if isEnabled {

                VStack(spacing: 8) {

                    HStack {
                        Text("Opacity")

                        Spacer()

                        Text("\(Int(opacity * 100))%")
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }

                    Slider(
                        value: $opacity,
                        in: 0...1
                    )

                    HStack {
                        Text("Width")

                        Spacer()

                        Text(String(format: "%.1f cm", width))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }

                    Slider(
                        value: $width,
                        in: 0.5...15.0
                    )
                }
                .padding(.leading, 10)
            }
        }
        .padding(14)
        .background(Color.gray.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
