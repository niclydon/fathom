import SwiftUI

/// The Surface: the club's public face. A name in brass over dark
/// water, a sealed board teasing tonight's members' evening, and the
/// entrance itself.
struct SurfaceView: View {
    @Environment(GateController.self) private var gate
    @State private var showDescent = false
    @State private var showAbout = false

    var body: some View {
        ZStack {
            DepthBackground()
            ScrollView {
                VStack(spacing: 28) {
                    header
                    sealedBoard
                    entrance
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 36)
            }
        }
        .fullScreenCover(isPresented: $showDescent) {
            DescentView()
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("EST. SIX FATHOMS DOWN")
                .font(.fathomBody(11))
                .tracking(4)
                .foregroundStyle(FathomColor.mist)
            Text("FATHOM")
                .font(.fathomDisplay(52))
                .tracking(14)
                .foregroundStyle(FathomColor.brass)
            Text("THE FATHOM CLUB")
                .font(.fathomBody(13))
                .tracking(6)
                .foregroundStyle(FathomColor.parchment.opacity(0.8))
            Text("A members' club beneath the harbour. The door is a mark and a face, in that order, and nothing less than both.")
                .font(.fathomBody(15))
                .foregroundStyle(FathomColor.mist)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    private var sealedBoard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClubHeading(title: "Members' Evening")
            ForEach(ClubContent.tonight.prefix(3)) { item in
                HStack(alignment: .top, spacing: 14) {
                    Text(item.time)
                        .font(.fathomBody(14))
                        .foregroundStyle(FathomColor.brass)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.fathomBody(16))
                            .foregroundStyle(FathomColor.parchment)
                        Text(item.detail)
                            .font(.fathomBody(13))
                            .foregroundStyle(FathomColor.mist)
                    }
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                Text("The rest of the board is members' business.")
                    .font(.fathomBody(13))
                    .italic()
            }
            .foregroundStyle(FathomColor.brassDim)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(FathomColor.brass.opacity(0.22), lineWidth: 1))
    }

    private var entrance: some View {
        VStack(spacing: 14) {
            Button {
                showDescent = true
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(colors: [FathomColor.brass, FathomColor.brassDim], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 5
                        )
                        .frame(width: 118, height: 118)
                    Circle()
                        .fill(RadialGradient(colors: [FathomColor.water, FathomColor.abyss], center: .center, startRadius: 4, endRadius: 56))
                        .frame(width: 100, height: 100)
                    VStack(spacing: 2) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 20))
                        Text("DESCEND")
                            .font(.fathomBody(11))
                            .tracking(2.5)
                    }
                    .foregroundStyle(FathomColor.brass)
                }
            }
            Text(gate.isEnrolled ? "Members' entrance. Present your mark." : "New to the club? The entrance binds your mark first.")
                .font(.fathomBody(13))
                .foregroundStyle(FathomColor.mist)
                .multilineTextAlignment(.center)
        }
    }

    private var footer: some View {
        Button {
            showAbout = true
        } label: {
            Text("About this gate")
                .font(.fathomBody(13))
                .tracking(1)
                .foregroundStyle(FathomColor.mist.opacity(0.8))
                .underline()
        }
        .padding(.top, 4)
    }
}
