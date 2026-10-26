import SwiftUI

struct BoardNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var author: String
    var at: Date
}

/// The members' note board. Notes live on this phone only
/// (UserDefaults), which is the right scope for a prototype club.
struct NoteBoardView: View {
    @State private var notes: [BoardNote] = []
    @State private var draft = ""
    private let storageKey = "fathom.board.notes.v1"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClubHeading(title: "Members' Notes")
            HStack(spacing: 10) {
                TextField("Leave a note for the club…", text: $draft, axis: .vertical)
                    .font(.fathomBody(15))
                    .foregroundStyle(FathomColor.parchment)
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Button("Post") {
                    let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    notes.insert(BoardNote(text: text, author: "No. 001", at: Date()), at: 0)
                    draft = ""
                    save()
                }
                .font(.fathomBody(15))
                .fontWeight(.semibold)
                .foregroundStyle(FathomColor.brass)
            }
            if notes.isEmpty {
                Text("The board is bare. The first note of the evening is yours.")
                    .font(.fathomBody(14))
                    .foregroundStyle(FathomColor.mist)
                    .italic()
            }
            ForEach(notes) { note in
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.text)
                        .font(.fathomBody(15))
                        .foregroundStyle(FathomColor.parchment)
                    Text("\(note.author) · \(note.at.formatted(date: .abbreviated, time: .shortened))")
                        .font(.fathomBody(12))
                        .foregroundStyle(FathomColor.mist)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([BoardNote].self, from: data) else { return }
        notes = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
