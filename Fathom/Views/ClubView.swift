import SwiftUI

/// Inside the club. Only reachable when GateController.inClub is true;
/// leaving, by button or by backgrounding past the grace, locks it.
struct ClubView: View {
    @Environment(GateController.self) private var gate
    @State private var showAbout = false

    var body: some View {
        ZStack {
            DepthBackground()
            ScrollView {
                VStack(spacing: 30) {
                    header
                    ledger
                    tonight
                    cellar
                    NoteBoardView()
                    rules
                    leave
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 36)
            }
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("YOU ARE BELOW")
                .font(.fathomBody(11))
                .tracking(4)
                .foregroundStyle(FathomColor.mist)
            Text("The Fathom Club")
                .font(.fathomDisplay(34))
                .foregroundStyle(FathomColor.brass)
            Text("Good evening, Founder. The water is fine and the hour is yours.")
                .font(.fathomBody(15))
                .foregroundStyle(FathomColor.mist)
        }
    }

    private var ledger: some View {
        VStack(spacing: 14) {
            ClubHeading(title: "The Ledger")
            ForEach(ClubContent.ledger) { member in
                HStack(alignment: .top, spacing: 14) {
                    Text(String(format: "No. %03d", member.number))
                        .font(.fathomBody(13))
                        .foregroundStyle(FathomColor.brass)
                        .frame(width: 58, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.name)
                            .font(.fathomBody(16))
                            .foregroundStyle(FathomColor.parchment)
                        Text(member.note)
                            .font(.fathomBody(13))
                            .foregroundStyle(FathomColor.mist)
                    }
                    Spacer()
                }
            }
        }
    }

    private var tonight: some View {
        VStack(spacing: 14) {
            ClubHeading(title: "Tonight at Fathom")
            ForEach(ClubContent.tonight) { item in
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
                    Spacer()
                }
            }
        }
    }

    private var cellar: some View {
        VStack(spacing: 14) {
            ClubHeading(title: "The Cellar")
            ForEach(ClubContent.cellar) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.fathomBody(16))
                        .foregroundStyle(FathomColor.parchment)
                    Text(item.note)
                        .font(.fathomBody(13))
                        .foregroundStyle(FathomColor.mist)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var rules: some View {
        VStack(spacing: 14) {
            ClubHeading(title: "House Rules")
            ForEach(Array(ClubContent.houseRules.enumerated()), id: \.offset) { index, rule in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1).")
                        .font(.fathomBody(14))
                        .foregroundStyle(FathomColor.brass)
                    Text(rule)
                        .font(.fathomBody(15))
                        .foregroundStyle(FathomColor.parchment)
                    Spacer()
                }
            }
        }
    }

    private var leave: some View {
        VStack(spacing: 12) {
            BrassButton(title: "Return to the surface") { gate.lock() }
            Button("About this gate") { showAbout = true }
                .font(.fathomBody(13))
                .foregroundStyle(FathomColor.mist)
                .underline()
        }
        .padding(.top, 6)
    }
}
