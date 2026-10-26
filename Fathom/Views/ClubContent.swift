import Foundation

/// All of the club's content is fictional demo material. No real
/// people, no real cellar, no real evening has ever happened here.
enum ClubContent {
    struct Member: Identifiable {
        var id: Int { number }
        var number: Int
        var name: String
        var note: String
    }

    static let ledger: [Member] = [
        Member(number: 1, name: "The Founder", note: "Bound by mark and face. Seat by the deep window."),
        Member(number: 2, name: "E. Halloway", note: "Chess, second board. Never before nine."),
        Member(number: 3, name: "M. Okafor", note: "Keeper of the chart room keys."),
        Member(number: 4, name: "I. Petrovna", note: "Reads the weather glass better than the glass reads itself."),
        Member(number: 5, name: "T. Abernathy", note: "Founder of the silent hour. Still observing it."),
        Member(number: 6, name: "R. Delacroix", note: "Cellar adviser. Trust her on anything bottled before the war."),
        Member(number: 7, name: "S. Whitlock", note: "Brings the harbour charts nobody asked for and everybody needs."),
        Member(number: 8, name: "A. Ferreira", note: "Plays the piano under water, metaphorically."),
        Member(number: 9, name: "J. Lindqvist", note: "Won the lamp-trimming cup three years running."),
        Member(number: 10, name: "C. Beaumont", note: "Present most evenings. Sworn to the long table."),
        Member(number: 11, name: "H. Nakamura", note: "Keeps the tide log in a hand too beautiful to argue with."),
    ]

    struct ProgramItem: Identifiable {
        var id = UUID()
        var time: String
        var title: String
        var detail: String
    }

    static let tonight: [ProgramItem] = [
        ProgramItem(time: "19:00", title: "The Doors Sound", detail: "The bell is rung once. Late arrivals swim."),
        ProgramItem(time: "19:30", title: "Shanties in Minor Keys", detail: "The Fathom Quartet opens the evening below the waterline."),
        ProgramItem(time: "20:15", title: "Lighthouse Optics, A Lecture", detail: "Member No. 11 on lenses, lamps, and being seen from far away."),
        ProgramItem(time: "21:00", title: "The Silent Hour", detail: "Chess, reading, and no conversation above a murmur."),
        ProgramItem(time: "22:30", title: "The Chart Room Opens", detail: "Harbour charts, wreck maps, and one atlas that is mostly wrong."),
        ProgramItem(time: "23:45", title: "Last Sounding", detail: "The depth is called. Members drift up at their leisure."),
    ]

    struct CellarItem: Identifiable {
        var id = UUID()
        var name: String
        var note: String
    }

    static let cellar: [CellarItem] = [
        CellarItem(name: "Brine & Tonic", note: "Gin, tonic, a whisper of seawater the steward swears is metaphorical."),
        CellarItem(name: "The Six-Fathom Old Fashioned", note: "Bourbon, demerara, bitters, one orange coin, no shortcuts."),
        CellarItem(name: "Kelp Garden Cup", note: "A green, cold, alcohol-free pour for the morning watch."),
        CellarItem(name: "Chateau Fathom, house red", note: "A fictional vintage from a slope that does not exist. Drinks beautifully."),
        CellarItem(name: "Pressure-Test Port", note: "Kept at depth since the club's founding, which is to say in the imagination."),
        CellarItem(name: "Still Water, Sparkling Water", note: "Both at cellar temperature, both taken seriously."),
    ]

    static let houseRules: [String] = [
        "What is said at depth stays at depth.",
        "The mark opens nothing alone; the face opens nothing alone. Together, politely, they open the door.",
        "No photographs below the waterline.",
        "The long table is for everyone; the deep window seat is earned.",
        "Settle your sounding before the Last Sounding is called.",
        "Members vouch for guests in writing, in the Ledger, or not at all.",
        "The steward's ruling on the weather glass is final.",
    ]
}
