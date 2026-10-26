import SwiftUI

@main
struct FathomApp: App {
    @State private var gate = GateController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(gate)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, newPhase in
                    gate.scenePhaseChanged(to: newPhase)
                }
        }
    }
}

struct RootView: View {
    @Environment(GateController.self) private var gate

    var body: some View {
        if gate.inClub {
            ClubView()
        } else {
            SurfaceView()
        }
    }
}
