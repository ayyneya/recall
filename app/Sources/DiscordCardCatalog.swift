import Foundation

// What each part of the card can say (Customize's tiles), from what is known: the profile (Full), what
// Recall remembers (CareerHistory.swift) and the game's log. A piece with nothing true to say right now
// gives nil and takes no turn: a record with no games in its period, a title not earned, a moment that is
// no longer news, anything from the profile while it's private or the rank may be out of date. The words
// are the app's own, filled in with numbers and names; nothing the player types goes on the card.

/// What a card is made from, at one moment.
struct CardInputs {
    var place:PresenceState = .unknown
    var voice:GroupVoice?
    /// Whether the match is a competitive one, when a source can tell (none can yet: PresenceFacts).
    var competitive:Bool?
    /// The profile; nil without a BattleTag, while it's private or not found, or before the first look.
    var profile:CareerCard?
    var history=CareerHistory()
    /// The BattleTag's name, for line 1 while the profile has none.
    var tagName:String?
    var launched:Date
    /// The matches the log saw in this run, the one going on included.
    var matches=0
    var now:Date
    var texts:PresenceTexts
    var calendar:Calendar = .current
}

/// A large picture, ready for the card.
struct CardImage: Equatable {
    let url:URL
    let hover:String?
    /// The hero it shows, for the hero's page.
    var hero:String?=nil
}

extension CardInputs {
    var inMatch:Bool { if case .match=place { return true };return false }
    var menus:Bool { place == .menu }
    var name:String? { profile?.identity?.name ?? tagName }
    /// The latest change while it is news (until a game opens after the one it came from).
    var news:ProfileChange? { profile == nil ? nil : history.news(before:launched) }
    /// The ranks the card may show: none once the last look is too old for the matches played since.
    var ranks:[CareerRank] { profile != nil && !history.rankStale(now:now) ? profile!.ranks : [] }
    func rank(_ choice:RankChoice)->CareerRank? {
        let ranks=self.ranks
        switch choice {
        case .role(let role): return ranks.first { $0.role == role }
        case .highest: return ranks.max { $0.standing < $1.standing }
        case .lastPlayed: return CareerCard(ranks:ranks,last:profile?.last).rank
        }
    }
    /// Every rank, in the roles' order, with how the last session moved it ("Tank ↑ Emerald 1").
    var allRanks:[(rank:CareerRank,text:String)] {
        ranks.sorted { CareerRank.Role.allCases.firstIndex(of:$0.role)! < CareerRank.Role.allCases.firstIndex(of:$1.role)! }.map { ($0,rankText($0)) }
    }
    /// ↑ up a division, ↟ two or more, ↓ and ↡ down, – the same: what the last session did to this role.
    func arrow(_ rank:CareerRank)->String {
        guard let change=history.changes.last else { return "–" }
        let steps:Int
        if let moves=change.rankMoves { steps=moves[rank.role.rawValue] ?? 0 }
        else {
            guard let moved=change.session.rank,moved.role == rank.role else { return "–" }
            steps=change.rankSteps ?? (change.session.promoted ? 1 : -1)
        }
        return steps >= 2 ? "↟" : steps == 1 ? "↑" : steps == -1 ? "↓" : steps <= -2 ? "↡" : "–"
    }
    func rankText(_ rank:CareerRank)->String {
        // One phrase per role, with the mark and the rank apart, so a role's phrase never shares a key with the same
        // words elsewhere ("Support {0}" is Support Recall).
        switch rank.role {
        case .tank: return L("Tank {0} {1}",arrow(rank),rank.name)
        case .damage: return L("Damage {0} {1}",arrow(rank),rank.name)
        case .support: return L("Support {0} {1}",arrow(rank),rank.name)
        case .open: return L("6v6 {0} {1}",arrow(rank),rank.name)
        }
    }

    /// Each hero's time over both modes, all time (OverFast's keys): as Recall has counted it (HeroHours), which a new
    /// season doesn't take away, or the profile's own totals before it has.
    var heroTime:[String:Int] {
        if profile != nil,let counted=history.hours?.heroes,!counted.isEmpty { return counted }
        return modes.reduce(into:[:]) { total,mode in for (hero,seconds) in mode.heroes { total[hero,default:0]+=seconds } }
    }
    /// The profile's totals, Competitive and Quick Play.
    var modes:[ModeStats] { profile.map { Array($0.totals.values) } ?? [] }
    /// The heroes by time played, most first (by name when two are alike).
    var topHeroes:[String] { heroTime.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key) }
    func heroName(_ key:String)->String { profile?.heroes[key]?.name ?? key.capitalized }
    func hours(_ seconds:Int)->String { seconds >= 3600 ? L("{0}h",String(seconds/3600)) : L("{0}m",String(max(1,seconds/60))) }
    /// A role's share of the time played (the heroes' roles as OverFast lists them).
    func share(_ role:CareerRank.Role)->Double {
        let time=heroTime,total=time.values.reduce(0,+)
        guard total > 0 else { return 0 }
        return Double(time.filter { profile?.heroes[$0.key]?.role == role }.values.reduce(0,+))/Double(total)
    }

    /// Line 1's words before where the player is; nil leaves just the place.
    func lineOne(_ item:LineOne,rank choice:RankChoice)->String? {
        switch item {
        case .name: return name
        case .nameAndTitle: return [name,profile?.identity?.title].compactMap { $0 }.joined(separator:" ").nilIfEmpty
        case .main: return topHeroes.first.map { L("{0} main",heroName($0)) } ?? name
        // The rank on line 1 in the menus only: in a match it would read as this match's.
        case .rank: return menus ? rank(choice).map(rankText) ?? name : name
        case .placeOnly: return nil
        }
    }

    /// The button after Get Recall, when there is somewhere for it to go.
    func button(_ button:SecondButton,picture:CardImage?)->(label:String,url:URL)? {
        switch button {
        case .careerProfile: return profile?.page.map { (L("Career Profile"),$0) }
        case .heroPage:
            guard let hero=picture?.hero ?? topHeroes.first,let url=URL(string:"https://overwatch.blizzard.com/en-us/heroes/\(hero)/") else { return nil }
            return (heroName(hero),url)
        case .patchNotes: return (L("Patch notes"),URL(string:"https://overwatch.blizzard.com/en-us/news/patch-notes/")!)
        }
    }
}

extension CardPiece {
    /// Says nothing about the match the player is in (its mode, its result), which the log can't know.
    var safeInMatch:Bool {
        switch self {
        case .hero,.tonight,.title: return true
        default: return false
        }
    }

    /// The words on Line 2, or nil when there's nothing true to say right now.
    func text(_ i:CardInputs,rank choice:RankChoice)->String? {
        switch self {
        case .highlights:
            guard i.menus else { return nil }
            for moment in CardMoment.allCases { if let text=CardPiece.moment(moment).text(i,rank:choice) { return text } }
            if let last=i.profile?.last { return L("Last · {0}",last.summary) }
            if i.profile != nil { return CardPiece.record(.all,.competitive,winRate:false).text(i,rank:choice) }
            return CardPiece.tonight(.matches).text(i,rank:choice)
        case .moment(let moment):
            guard i.menus else { return nil }
            switch moment {
            case .rankChange: return i.news?.session.rank.map(i.rankText)
            case .newBest: return i.news?.session.best.flatMap(Self.best).map { L("★ New best: {0}",$0) }
            case .seasonHigh: return i.news?.seasonHigh.map { L("★ Season high: {0}",$0.name) }
            case .milestone: return i.news?.milestone.map { L("★ {0} hours on {1}",String($0.hours),i.heroName($0.hero)) }
            case .comeback: return i.history.away(before:i.launched).map { L("First game in {0} days",String(Int($0/86400))) }
            case .newSeason: return i.profile != nil && i.history.newSeason(before:i.launched) != nil ? L("First game of the season") : nil
            }
        case .rank(let line):
            switch line {
            case .current: return i.rank(choice).map(i.rankText)
            case .climb:
                guard let now=i.rank(choice),let first=i.history.first(now.role),first.standing != now.standing else { return nil }
                return L("{0} → {1} this season",first.name,now.name)
            case .peak: return i.rank(choice).flatMap { i.history.peak($0.role) }.map { L("Season peak: {0}",$0.name) }
            case .all: return i.allRanks.isEmpty ? nil : i.allRanks.map(\.text).joined(separator:" · ")
            case .change: return CardPiece.moment(.rankChange).text(i,rank:choice)
            }
        case .record(let period,let mode,let winRate):
            // The last session and all time are the profile's own; the other periods add up what Recall remembers.
            let games:LastSession?
            switch period {
            case .last: games=i.profile?.last
            case .all: games=i.profile.map { LastSession(competitive:$0.totals["competitive"]?.games ?? Tally(),quickplay:$0.totals["quickplay"]?.games ?? Tally()) }
            default: games=i.profile == nil ? nil : i.history.session(period,now:i.now,calendar:i.calendar)
            }
            guard let games else { return nil }
            func tally(_ t:Tally,_ short:(String,String)->String)->String? {
                guard t.played > 0 else { return nil }
                let rate=winRate && mode != .both ? " · "+L("{0}%",String(Int((Double(t.won)*100/Double(t.played)).rounded()))) : ""
                return short(String(t.won),String(t.lost))+rate
            }
            let comp=tally(games.competitive) { L("Comp {0}–{1}",$0,$1) },quick=tally(games.quickplay) { L("QP {0}–{1}",$0,$1) }
            var body:String?
            switch mode {
            case .competitive: body=comp
            case .quickPlay: body=quick
            case .both: body=[comp,quick].compactMap { $0 }.joined(separator:" · ").nilIfEmpty
            }
            // The last session's other modes (Arcade, custom games) after its Competitive record.
            if period == .last,mode == .competitive,let shown=body,let other=games.other,other > 0,!winRate { body=shown+" · "+L("{0} other",String(other)) }
            guard let body else { return nil }
            switch period {
            case .last: return L("Last · {0}",body)
            case .today: return L("Today · {0}",body)
            case .week: return L("Week · {0}",body)
            case .season: return L("Season · {0}",body)
            case .all: return L("All · {0}",body)
            }
        case .hero(let key,let line):
            guard let hero=key ?? i.topHeroes.first,let time=i.heroTime[hero],time >= 60 else { return nil }
            let name=i.heroName(hero)
            switch line {
            // "Main" is earned: only the most-played hero has it; past half the hours, it's one-trick.
            case .main:
                guard hero == i.topHeroes.first else { return nil }
                return Double(time) > Double(i.heroTime.values.reduce(0,+))*0.5 ? L("{0} one-trick",name) : L("{0} main",name)
            case .hours: return L("{0} · {1}",name,i.hours(time))
            case .role:
                let rest="\(name) \(i.hours(time))"
                switch i.profile?.heroes[hero]?.role {
                case .tank?: return L("Tank · {0}",rest)
                case .damage?: return L("Damage · {0}",rest)
                case .support?: return L("Support · {0}",rest)
                default: return nil
                }
            case .winRate:
                let games=i.modes.compactMap { $0.heroGames?[hero] }.reduce(Tally(),+)
                guard games.played > 0 else { return nil }
                return L("{0} · {1}% wins",name,String(Int((Double(games.won)*100/Double(games.played)).rounded())))
            }
        case .best(let line):
            if line == .new { return CardPiece.moment(.newBest).text(i,rank:choice) }
            guard let value=line.value(i) else { return nil }
            let number=value.formatted(.number)
            switch line {
            case .eliminations: return L("Best: {0} elims in a game",number)
            case .damage: return L("Best: {0} damage",number)
            case .healing: return L("Best: {0} healing",number)
            case .killStreak: return L("Best: {0} kill streak",number)
            case .multikill: return L("Best: {0}-kill multikill",number)
            case .new: return nil
            }
        case .tonight(let line):
            switch line {
            case .matches:
                // In a match, which match it is; in the menus, how many there were.
                if i.inMatch { return i.matches > 0 ? L("Match {0} tonight",String(i.matches)) : nil }
                return i.matches == 1 ? L("1 match tonight") : i.matches > 1 ? L("{0} matches tonight",String(i.matches)) : nil
            case .nights:
                let nights=i.history.nightsInARow(now:i.now,playing:true,calendar:i.calendar)
                guard nights >= 2 else { return nil }
                let ordinal=NumberFormatter();ordinal.numberStyle = .ordinal;ordinal.locale=Locale(identifier:AppLanguage.current)
                return L("{0} night in a row",ordinal.string(from:NSNumber(value:nights)) ?? String(nights))
            case .week:
                let time=i.history.playedThisWeek(now:i.now,current:i.launched,calendar:i.calendar)
                return time >= 3600 ? L("Week · {0} played",i.hours(Int(time))) : nil
            }
        case .title(let line):
            guard i.profile != nil else { return nil }
            let total=i.heroTime.values.reduce(0,+)/3600
            switch line {
            case .endorsement: return i.profile?.identity?.endorsement.map { L("Endorsement {0}",String($0)) }
            case .hours: return total >= 1 ? L("{0}h in Overwatch",String(total)) : nil
            case .roleMain: return Self.roleMain(i)
            case .flex: return [.tank,.damage,.support].allSatisfy { i.share($0) >= 0.2 } ? L("Flex player") : nil
            case .oneTrick:
                guard let top=i.topHeroes.first,let time=i.heroTime[top],Double(time) > Double(i.heroTime.values.reduce(0,+))*0.5 else { return nil }
                return L("{0} one-trick",i.heroName(top))
            case .century: return total >= 100 ? L("{0} hours in",String(total/100*100)) : nil
            case .cardboardSupport: return Self.cardboard(i).earned ? L("Cardboard Support") : nil
            }
        }
    }

    /// Lines that are earned (the titles from hours, a hero's "main"): how far along the player is (1 is earned),
    /// what earned it, or what it still takes. nil for every other line, and without the profile.
    func progress(_ i:CardInputs)->(done:Double,earned:String?,needed:String?)? {
        guard i.profile != nil else { return nil }
        let percent={ (share:Double) in String(Int((share*100).rounded())) }
        switch self {
        case .title(.roleMain):
            guard let role=[CareerRank.Role.tank,.damage,.support].max(by:{ i.share($0) < i.share($1) }) else { return nil }
            let share=i.share(role),done=min(1,share/0.45)
            let words:(String,String)
            switch role {
            case .tank: words=(L("Earned: Tank is {0}% of your hours",percent(share)),L("Tank is {0}% of your hours; a main needs 45%.",percent(share)))
            case .damage: words=(L("Earned: Damage is {0}% of your hours",percent(share)),L("Damage is {0}% of your hours; a main needs 45%.",percent(share)))
            default: words=(L("Earned: Support is {0}% of your hours",percent(share)),L("Support is {0}% of your hours; a main needs 45%.",percent(share)))
            }
            return done >= 1 ? (1,words.0,nil) : (done,nil,words.1)
        case .title(.flex):
            let least=[CareerRank.Role.tank,.damage,.support].map(i.share).min() ?? 0
            return least >= 0.2 ? (1,L("Earned: every role is 20% or more of your hours"),nil)
                                : (least/0.2,nil,L("Your least-played role is {0}% of your hours; flex needs 20% of each.",percent(least)))
        case .title(.oneTrick):
            guard let top=i.topHeroes.first,let time=i.heroTime[top] else { return nil }
            let share=Double(time)/Double(max(1,i.heroTime.values.reduce(0,+)))
            return share > 0.5 ? (1,L("Earned: {0} is {1}% of your hours",i.heroName(top),percent(share)),nil)
                               : (share/0.5,nil,L("{0} is {1}% of your hours; needs over half.",i.heroName(top),percent(share)))
        case .title(.cardboardSupport):
            let cardboard=Self.cardboard(i),share=i.share(.support)
            if cardboard.earned { return (1,L("Earned: Support main, more damage than healing"),nil) }
            if !cardboard.main { return (min(0.5,share/0.45/2),nil,L("Support is {0}% of your hours; needs 45%, and more damage than healing.",percent(share))) }
            return (0.5+0.5*min(0.97,Double(cardboard.damage)/Double(max(1,cardboard.healing))),nil,
                    L("Support main. Damage {0}, healing {1}: damage has to be more.",cardboard.damage.formatted(.number),cardboard.healing.formatted(.number)))
        case .title(.century):
            let hours=i.heroTime.values.reduce(0,+)/3600
            return hours >= 100 ? (1,L("Earned at 100 hours"),nil) : (Double(hours)/100,nil,L("{0} of 100 hours played.",String(hours)))
        case .hero(let key,.main):
            guard let top=i.topHeroes.first,let topTime=i.heroTime[top] else { return nil }
            let hero=key ?? top,time=i.heroTime[hero] ?? 0
            if hero == top {
                // One ladder: main, then one-trick past half the hours.
                let share=Double(time)/Double(max(1,i.heroTime.values.reduce(0,+)))
                return share > 0.5 ? (1,L("Earned: one-trick, {0}% of your hours",percent(share)),nil)
                                   : (1,L("Earned: main, {0}. One-trick past half your hours ({1}% now)",i.hours(time),percent(share)),nil)
            }
            return (min(0.97,Double(time)/Double(topTime)),nil,L("{0} {1}. Your most-played, {2}, has {3}.",i.heroName(hero),i.hours(time),i.heroName(top),i.hours(topTime)))
        default: return nil
        }
    }

    /// Cardboard Support (the player's own joke): Support is the main role (most played, 45% or more of the hours), yet
    /// the profile's damage is more than its healing.
    private static func cardboard(_ i:CardInputs)->(earned:Bool,main:Bool,damage:Int,healing:Int) {
        let support=i.share(.support)
        let main=support >= 0.45 && [CareerRank.Role.tank,.damage].allSatisfy { i.share($0) < support }
        let damage=i.modes.reduce(0) { $0+$1.damage },healing=i.modes.reduce(0) { $0+$1.healing }
        return (main && damage > healing,main,damage,healing)
    }
    /// The title for a role that has at least 45% of the time played.
    private static func roleMain(_ i:CardInputs)->String? {
        guard let role=[CareerRank.Role.tank,.damage,.support].max(by:{ i.share($0) < i.share($1) }),i.share(role) >= 0.45 else { return nil }
        switch role {
        case .tank: return L("Tank main")
        case .damage: return L("Damage main")
        case .support: return L("Support main")
        case .open: return nil
        }
    }
    /// A record beaten, in a few words ("53 elims").
    static func best(_ best:CareerBest)->String? {
        let value=best.value.formatted(.number)
        switch best.key {
        case "eliminations_most_in_game": return L("{0} elims",value)
        case "all_damage_done_most_in_game","hero_damage_done_most_in_game": return L("{0} damage",value)
        case "healing_done_most_in_game": return L("{0} healing",value)
        case "final_blows_most_in_game": return L("{0} final blows",value)
        case "solo_kills_most_in_game": return L("{0} solo kills",value)
        case "kill_streak_best": return L("{0} kill streak",value)
        case "multikill_best": return L("{0}-kill multikill",value)
        default: return nil
        }
    }

    /// The picture a line brings when the picture follows Line 2.
    func picture(_ i:CardInputs,rank choice:RankChoice)->CardPicture {
        switch self {
        case .highlights: return i.profile?.hero == nil ? .playerIcon : .lastHero
        case .moment(let moment):
            switch moment {
            case .rankChange,.seasonHigh: return .rankEmblem
            case .newBest: return i.profile?.hero == nil ? .playerIcon : .lastHero
            case .milestone: return i.news?.milestone.map { .hero($0.hero) } ?? .playerIcon
            case .comeback: return .playerIcon
            case .newSeason: return .overwatch
            }
        case .rank: return .roleMain
        case .record(let period,_,_): return period == .last && i.profile?.hero != nil ? .lastHero : .topHeroes
        case .hero(let key,_): return key.map { .hero($0) } ?? .topHeroes
        case .best,.tonight,.title: return .playerIcon
        }
    }
}

extension CardPicture {
    /// The image and its hover text, or nil when there is none (the card then shows Overwatch's own icon).
    func image(_ i:CardInputs,rank choice:RankChoice,turn:Int)->CardImage? {
        func hero(_ key:String)->CardImage? {
            guard let portrait=i.profile?.heroes[key]?.portrait else { return nil }
            return CardImage(url:portrait,hover:i.heroTime[key].map { L("{0} · {1} played",i.heroName(key),i.hours($0)) },hero:key)
        }
        switch self {
        case .playerIcon:
            guard let identity=i.profile?.identity,let avatar=identity.avatar else { return nil }
            return CardImage(url:avatar,hover:[identity.name,identity.title].compactMap { $0 }.joined(separator:" · "))
        case .lastHero:
            // The last session's hero, with what was done on all heroes (the totals don't say which hero did what).
            guard let last=i.profile?.hero,let portrait=last.portrait else { return nil }
            let hover=[L("Most played last session: {0}",last.name),i.profile?.last?.stats.map { L("All heroes: {0}",$0) }].compactMap { $0 }.joined(separator:" · ")
            return CardImage(url:portrait,hover:hover,hero:i.profile?.last?.hero)
        case .overwatch: return nil
        case .rankEmblem: return i.rank(choice).map { CardImage(url:$0.icon,hover:$0.label()) }
        case .recall: return CardImage(url:Brand.discordBadge,hover:i.texts.badge)
        case .art(let art): return CardImage(url:Brand.art(art.file),hover:art.name)
        case .hero(let key): return hero(key)
        case .roleMain:
            // The most-played hero of the rank's role, or of any role without a rank.
            let role=i.rank(choice)?.role
            return i.topHeroes.first { role == nil || role == .open || i.profile?.heroes[$0]?.role == role }.flatMap(hero)
        case .topHeroes:
            let top=Array(i.topHeroes.prefix(5))
            return top.isEmpty ? nil : hero(top[turn%top.count])
        }
    }
}

extension String {
    var nilIfEmpty:String? { isEmpty ? nil : self }
}

extension BestLine {
    /// The profile's best for this line, over every mode (OverFast's keys; damage was hero damage on older profiles).
    func value(_ i:CardInputs)->Int? {
        let keys:[BestLine:[String]]=[.eliminations:["eliminations_most_in_game"],.damage:["all_damage_done_most_in_game","hero_damage_done_most_in_game"],
                                      .healing:["healing_done_most_in_game"],.killStreak:["kill_streak_best"],.multikill:["multikill_best"]]
        guard let key=keys[self]?.first(where:{ key in i.modes.contains { ($0.bests[key] ?? 0) > 0 } }) else { return nil }
        return i.modes.compactMap { $0.bests[key] }.max()
    }
}
