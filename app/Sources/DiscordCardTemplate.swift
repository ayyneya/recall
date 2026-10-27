import Foundation

// The card's own design (Customize): what each part of the Discord card shows. Line 1, Line 2, the large
// picture and the small badge each hold a list. A list of one is fixed; longer ones take turns, all on one
// clock: the item shown is the turn (the time over the pace) counted round the list's items that have
// something to say right now. Nothing keeps a timer, so the same moment always makes the same card, and a
// Recall that restarts carries on where it was. Full is the Default design; Custom is the player's own.

/// What goes before where the player is, on line 1 ("pyxee · In Menus").
enum LineOne: String, Codable, CaseIterable { case name,nameAndTitle,main,rank,placeOnly }

enum CardMoment: String, Codable, CaseIterable { case rankChange,newBest,seasonHigh,milestone,comeback,newSeason }
enum RankLine: String, Codable, CaseIterable { case current,climb,peak,all,change }
enum RecordMode: String, Codable, CaseIterable { case competitive,quickPlay,both }
enum HeroLine: String, Codable, CaseIterable { case main,hours,role,winRate }
enum BestLine: String, Codable, CaseIterable { case eliminations,damage,healing,killStreak,multikill,new }
enum TonightLine: String, Codable, CaseIterable { case matches,nights,week }
enum TitleLine: String, Codable, CaseIterable { case endorsement,hours,roleMain,flex,oneTrick,century }

/// One thing Line 2 can say (DiscordCardCatalog.swift has the words).
enum CardPiece: Codable, Hashable {
    /// The first that applies: something that just happened, the last session, the first look, tonight.
    case highlights
    /// Only when something happened, the first time the player plays after it.
    case moment(CardMoment)
    case rank(RankLine)
    case record(CareerPeriod,RecordMode,winRate:Bool)
    /// A hero by OverFast's key; nil is the player's most-played.
    case hero(String?,HeroLine)
    case best(BestLine)
    case tonight(TonightLine)
    /// Titles earned from the profile's hours.
    case title(TitleLine)
}

/// A line in Line 2's list: what it says, maybe a second piece after it ("Week · Comp 12–9 · Juno · 15h"),
/// and whether it shows in a match too. Only lines that say nothing about the match can (CardPiece.safeInMatch).
struct CardLine: Codable, Hashable {
    var piece:CardPiece
    var second:CardPiece?=nil
    var inMatch=true
}

enum CardPicture: Codable, Hashable { case playerIcon,lastHero,overwatch,rankEmblem,recall,roleMain,topHeroes,hero(String) }
enum CardBadge: String, Codable, CaseIterable { case rank,mac,recall }
/// The timer counts from when the game opened, or starts over with each match.
enum CardTimer: String, Codable { case session,match }
/// The button after Get Recall.
enum SecondButton: String, Codable, CaseIterable { case careerProfile,heroPage,patchNotes }
/// In the group's voice chat: say so on Line 2 with the count, keep Line 2 and add the count, or keep Line 2 alone.
enum PartyChoice: String, Codable { case sayVoice,addCount,noCount }
/// The rank every rank line and the badge show.
enum RankChoice: Codable, Hashable { case role(CareerRank.Role),highest,lastPlayed }

struct DiscordCardDesign: Codable, Equatable, Identifiable {
    /// The ready-made designs' own ids ("default"); a UUID for the player's.
    var id:String
    /// The player's own name for it (a ready-made design's is its id's: shownName).
    var name:String
    var lineOne:[LineOne]=[.name]
    var lineTwo:[CardLine]=[CardLine(piece:.highlights)]
    /// The large picture's own list; nil follows Line 2 (each line brings its own picture).
    var pictures:[CardPicture]?=nil
    var badges:[CardBadge]=[.rank]
    var timer:CardTimer = .match
    var button:SecondButton? = .careerProfile
    var party:PartyChoice = .sayVoice
    /// Seconds each turn lasts.
    var pace=45
    var rank:RankChoice = .lastPlayed

    static let paces=[20,45,60,120,300]
    /// Discord takes an update every few seconds at most; the editor offers 20 seconds and up.
    static let shortestPace=20
    var readyMade:Bool { Self.readyMade.contains { $0.id == id } }
    /// The name the editor shows: the player's own, or a ready-made design's in the app's language.
    var shownName:String {
        switch id {
        case "default": return L("Default")
        case "climber": return L("Climber")
        case "main": return L("Main")
        case "grinder": return L("Grinder")
        case "showoff": return L("Show-off")
        default: return name
        }
    }

    /// Full's card, and the ready-made ones Customize starts from.
    static let standard=DiscordCardDesign(id:"default",name:"")
    static let readyMade:[DiscordCardDesign]=[
        standard,
        DiscordCardDesign(id:"climber",name:"",lineTwo:[CardLine(piece:.rank(.current)),CardLine(piece:.rank(.climb)),CardLine(piece:.rank(.peak))]),
        DiscordCardDesign(id:"main",name:"",lineTwo:[CardLine(piece:.hero(nil,.main)),CardLine(piece:.hero(nil,.hours)),CardLine(piece:.hero(nil,.role))],button:.heroPage),
        DiscordCardDesign(id:"grinder",name:"",lineTwo:[CardLine(piece:.record(.week,.competitive,winRate:false)),CardLine(piece:.tonight(.matches)),CardLine(piece:.tonight(.nights))]),
        DiscordCardDesign(id:"showoff",name:"",lineTwo:[CardLine(piece:.best(.eliminations)),CardLine(piece:.best(.damage)),CardLine(piece:.best(.healing))]),
    ]

    /// The turn at a moment: the same for every list, so they change together.
    func turn(at now:Date)->Int { Int(now.timeIntervalSince1970)/max(pace,Self.shortestPace) }
    /// When the next turn starts, if anything would change then (some list has more than one item to show).
    func nextTurn(_ inputs:CardInputs)->Date? {
        let shown=Shown(self,inputs,turn:turn(at:inputs.now))
        // The top heroes take turns within their one picture.
        let heroes=inputs.menus && inputs.topHeroes.count > 1 && (pictures ?? [(shown.lineTwo.first?.piece ?? .highlights).picture(inputs,rank:rank)]).contains(.topHeroes)
        guard shown.lineOne.count > 1 || shown.lineTwo.count > 1 || shown.pictures.count > 1 || shown.badges.count > 1 || heroes else { return nil }
        let pace=max(self.pace,Self.shortestPace)
        return Date(timeIntervalSince1970:TimeInterval((turn(at:inputs.now)+1)*pace))
    }

    /// The card Discord gets (its SET_ACTIVITY activity), at Full and Custom. Customize's preview can hold it
    /// at a turn of its own (the item the player clicked).
    func activity(_ inputs:CardInputs,turn held:Int?=nil)->[String:Any] {
        let turn=held ?? turn(at:inputs.now),shown=Shown(self,inputs,turn:turn)
        func pick<T>(_ list:[T])->T? { list.isEmpty ? nil : list[turn%list.count] }
        var start=inputs.launched
        if timer == .match,case .match(let since)=inputs.place { start=since }
        var card:[String:Any]=["type":0,"timestamps":["start":Int(start.timeIntervalSince1970)]]
        let place=inputs.menus ? inputs.texts.menu : inputs.inMatch ? inputs.texts.match : nil
        let one=[pick(shown.lineOne) ?? nil,place].compactMap { $0 }.joined(separator:" · ")
        if one.count >= 2 { card["details"]=PresenceCard.fit(one) }
        // Line 2, or the group's voice chat in its place, with Discord's own count after it.
        let line=pick(shown.lineTwo)
        var state=line?.text
        if let voice=inputs.voice,party != .noCount {
            if party == .sayVoice || state == nil { state=inputs.texts.voice }
            card["party"]=["id":voice.party,"size":[min(voice.count,PresenceCard.largestGroup),PresenceCard.largestGroup]]
        }
        if let state,state.count >= 2 { card["state"]=PresenceCard.fit(state) }
        var assets:[String:String]=[:]
        // The large picture: in the menus only (in a match it would read as the hero being played now). Following
        // Line 2, it is the one the line brings; or the next in its own list.
        let picture:CardImage?
        if pictures == nil { picture=inputs.menus ? (line?.piece ?? .highlights).picture(inputs,rank:rank).image(inputs,rank:rank,turn:turn) : nil } else { picture=pick(shown.pictures) }
        if let picture {
            assets["large_image"]=picture.url.absoluteString
            if let hover=picture.hover,hover.count >= 2 { assets["large_text"]=PresenceCard.fit(hover) }
        }
        let badge=pick(shown.badges) ?? .mac
        if badge == .rank,let rank=inputs.rank(rank) {
            let all=(inputs.allRanks.map(\.text)+[inputs.texts.badge]).joined(separator:" · ")
            assets["small_image"]=rank.icon.absoluteString;assets["small_text"]=PresenceCard.fit(all)
        } else {
            assets["small_image"]=(badge == .recall ? Brand.discordBadge : Brand.macBadge).absoluteString;assets["small_text"]=inputs.texts.badge
        }
        card["assets"]=assets
        // Get Recall first, always; Discord shows buttons to everyone but the player.
        var buttons=[["label":String(L("Get {0}",Brand.name).prefix(32)),"url":Brand.repository.absoluteString]]
        if let second=button.flatMap({ inputs.button($0,picture:picture) }) {
            buttons.append(["label":String(second.label.prefix(32)),"url":second.url.absoluteString])
        }
        card["buttons"]=buttons
        return card
    }

    /// What each list has to show at this moment, in its order: the items with nothing to say are left out.
    struct Shown {
        var lineOne:[String?]
        var lineTwo:[(piece:CardPiece,text:String)]
        var pictures:[CardImage]
        var badges:[CardBadge]
        init(_ design:DiscordCardDesign,_ inputs:CardInputs,turn:Int) {
            lineOne=design.lineOne.isEmpty ? [nil] : design.lineOne.map { inputs.lineOne($0,rank:design.rank) }
            lineTwo=design.lineTwo.compactMap { line in
                if inputs.inMatch && (!line.inMatch || !line.piece.safeInMatch) { return nil }
                guard let text=line.piece.text(inputs,rank:design.rank) else { return nil }
                let second=line.second.flatMap { inputs.inMatch && !$0.safeInMatch ? nil : $0.text(inputs,rank:design.rank) }
                return (line.piece,second.map { text+" · "+$0 } ?? text)
            }
            pictures=inputs.menus ? (design.pictures ?? []).compactMap { $0.image(inputs,rank:design.rank,turn:turn) } : []
            // The rank in the badge's place: in the menus, or in a match known to be competitive.
            let rankBadge=inputs.rank(design.rank) != nil && (inputs.menus || inputs.competitive == true)
            badges=design.badges.filter { $0 != .rank || rankBadge }
            if badges.isEmpty { badges=[design.badges.contains(.recall) && !design.badges.contains(.mac) ? .recall : .mac] }
        }
    }
}

/// The player's cards: the one in use, and their own designs, kept in this Mac's settings.
struct DiscordCardShelf: Codable, Equatable {
    var chosen="default"
    var mine:[DiscordCardDesign]=[]
    /// Ready-made cards the player deleted from My cards (Bring back shows them again).
    var hidden:[String]=[]
    var all:[DiscordCardDesign] { DiscordCardDesign.readyMade+mine }
    var inUse:DiscordCardDesign { all.first { $0.id == chosen } ?? .standard }
    static func load(_ store:UserDefaults = .standard)->DiscordCardShelf {
        store.data(forKey:"discordCards").flatMap { try? JSONDecoder().decode(Self.self,from:$0) } ?? DiscordCardShelf()
    }
    func save(_ store:UserDefaults = .standard) { store.set(try? JSONEncoder().encode(self),forKey:"discordCards") }
}
// Cards kept by an earlier or later Recall still read: what a card didn't have yet takes today's default, and a
// card this Recall can't read at all (a part it doesn't know) is left out rather than losing all of them.
extension DiscordCardShelf {
    init(from decoder:Decoder) throws {
        let kept=try decoder.container(keyedBy:CodingKeys.self)
        self.init()
        chosen=try kept.decodeIfPresent(String.self,forKey:.chosen) ?? chosen
        mine=(try? kept.decodeIfPresent([Readable<DiscordCardDesign>].self,forKey:.mine))?.compactMap(\.value) ?? []
        hidden=(try? kept.decodeIfPresent([String].self,forKey:.hidden)) ?? []
    }
}
extension DiscordCardDesign {
    init(from decoder:Decoder) throws {
        let kept=try decoder.container(keyedBy:CodingKeys.self)
        self.init(id:try kept.decode(String.self,forKey:.id),name:try kept.decodeIfPresent(String.self,forKey:.name) ?? "")
        lineOne=try kept.decodeIfPresent([LineOne].self,forKey:.lineOne) ?? lineOne
        lineTwo=try kept.decodeIfPresent([CardLine].self,forKey:.lineTwo) ?? lineTwo
        pictures=try kept.decodeIfPresent([CardPicture].self,forKey:.pictures)
        badges=try kept.decodeIfPresent([CardBadge].self,forKey:.badges) ?? badges
        timer=try kept.decodeIfPresent(CardTimer.self,forKey:.timer) ?? timer
        // No second button is kept as no key at all (as nil pictures are).
        button=try kept.decodeIfPresent(SecondButton.self,forKey:.button)
        party=try kept.decodeIfPresent(PartyChoice.self,forKey:.party) ?? party
        pace=try kept.decodeIfPresent(Int.self,forKey:.pace) ?? pace
        rank=try kept.decodeIfPresent(RankChoice.self,forKey:.rank) ?? rank
    }
}
/// One item of a list read on its own: nil when it can't be, so the rest of the list still reads.
private struct Readable<Value:Decodable>: Decodable {
    let value:Value?
    init(from decoder:Decoder) throws { value=try? Value(from:decoder) }
}
