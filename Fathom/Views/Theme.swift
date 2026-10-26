import SwiftUI

/// Fathom's palette: ink depths and old brass, dark only.
enum FathomColor {
    static let abyss = Color(red: 0.004, green: 0.016, blue: 0.03)
    static let deep = Color(red: 0.008, green: 0.05, blue: 0.085)
    static let water = Color(red: 0.02, green: 0.11, blue: 0.17)
    static let brass = Color(red: 0.78, green: 0.64, blue: 0.39)
    static let brassDim = Color(red: 0.55, green: 0.44, blue: 0.26)
    static let parchment = Color(red: 0.93, green: 0.89, blue: 0.8)
    static let mist = Color(red: 0.62, green: 0.71, blue: 0.76)
    static let danger = Color(red: 0.85, green: 0.45, blue: 0.35)
}

extension Font {
    static func fathomDisplay(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
    static func fathomBody(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
}

/// The living depth behind every screen: a vertical gradient, drifting
/// particles rising through it, slow sonar rings from the entrance,
/// and a caustic shimmer sweeping the top. All procedural; no assets.
struct DepthBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [FathomColor.water, FathomColor.deep, FathomColor.abyss],
                startPoint: .top, endPoint: .bottom
            )
            CausticShimmer()
            SonarRings()
            DriftingParticles()
        }
        .ignoresSafeArea()
    }
}

private struct CausticShimmer: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.05), .clear, Color.white.opacity(0.03), .clear],
                startPoint: UnitPoint(x: 0.2 + 0.15 * sin(t * 0.11), y: 0),
                endPoint: UnitPoint(x: 0.8 + 0.15 * cos(t * 0.09), y: 0.55)
            )
            .blendMode(.screen)
        }
    }
}

private struct SonarRings: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let cycle = 9.0
                    let progress = ((t + Double(i) * cycle / 3.0).truncatingRemainder(dividingBy: cycle)) / cycle
                    Circle()
                        .stroke(FathomColor.brass.opacity(0.14 * (1.0 - progress)), lineWidth: 1)
                        .frame(width: 60 + 520 * progress, height: 60 + 520 * progress)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

private struct DriftingParticles: View {
    // Fixed pseudo-random seeds so the field is stable between redraws.
    private let motes: [(x: Double, y: Double, size: Double, speed: Double, phase: Double)] =
        (0..<36).map { i in
            let a = Double((i * 37) % 100) / 100.0
            let b = Double((i * 53) % 100) / 100.0
            return (x: a, y: b, size: 1.0 + Double((i * 7) % 3), speed: 0.008 + Double((i * 11) % 10) * 0.0015, phase: Double((i * 29) % 100) / 100.0 * 6.28)
        }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ForEach(Array(motes.enumerated()), id: \.offset) { _, mote in
                    let rise = (mote.y - t * mote.speed).truncatingRemainder(dividingBy: 1.0)
                    let y = (rise < 0 ? rise + 1.0 : rise) * geo.size.height
                    let x = mote.x * geo.size.width + 6.0 * sin(t * 0.4 + mote.phase)
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: mote.size, height: mote.size)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

/// A heavy brass action button.
struct BrassButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.fathomBody(17))
                .fontWeight(.semibold)
                .tracking(1.5)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(colors: [FathomColor.brass, FathomColor.brassDim], startPoint: .top, endPoint: .bottom)
                )
                .foregroundStyle(FathomColor.abyss)
                .clipShape(Capsule())
                .shadow(color: FathomColor.brass.opacity(0.25), radius: 12, y: 4)
        }
    }
}

/// A quiet outlined button for secondary actions.
struct GhostButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.fathomBody(15))
                .tracking(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .foregroundStyle(FathomColor.parchment)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(FathomColor.brass.opacity(0.35), lineWidth: 1))
        }
    }
}

/// Section heading in club voice.
struct ClubHeading: View {
    var title: String
    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(FathomColor.brass.opacity(0.6)).frame(height: 1)
            Text(title.uppercased())
                .font(.fathomBody(13))
                .tracking(3)
                .foregroundStyle(FathomColor.brass)
                .fixedSize()
            Rectangle().fill(FathomColor.brass.opacity(0.6)).frame(height: 1)
        }
    }
}
