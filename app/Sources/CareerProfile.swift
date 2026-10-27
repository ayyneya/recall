import Foundation

// The career profile on the Discord card (Full): the player's ranks, who they are in the game, and how
// their last session went, from their public Overwatch career profile through OverFast (an open-source
// service, github.com/TeKrop/overfast-api), never from Blizzard's pages directly. Blizzard updates a
// profile only after the player quits the game (seen October 25: the profile's time was the second the
// game closed), so what the card tells is the session before this one, looked up as the game opens.
// The game's log adds what the profile can't: how many matches that session had, so the ones outside
// Competitive and Quick Play (Arcade, custom games) are counted too.
// Only the BattleTag is sent, and only at fixed moments: as the game opens, once about twelve minutes
// after it closes (when Blizzard has updated the profile; never during a match), and once when a
// BattleTag is entered; at most one lookup in ten minutes (OverFast's own cache time), and never before
// a wait OverFast asked for. The whole profile (about half a megabyte) is asked for only when it changed.
// Each change is also kept, dated, in the history (CareerHistory.swift), for the card's periods.

/// A BattleTag as the player types it ("Name#1234"), and as OverFast takes it ("Name-1234"). Checked
/// here first, so a tag OverFast would refuse is never sent.
enum BattleTag {
    static func playerID(_ tag:String)->String? {
        let text=tag.trimmingCharacters(in:.whitespaces)
        guard text.range(of:#"^\p{L}[\p{L}\p{N}]{2,11}#[0-9]{3,8}$"#,options:.regularExpression) != nil else { return nil }
        return text.replacingOccurrences(of:"#",with:"-")
    }
}

/// A competitive rank on PC for one role, as the profile shows it.
struct CareerRank: Codable, Equatable {
    enum Role: String, Codable, CaseIterable { case tank,damage,support,open }
    let role:Role
    /// "emerald": the division's name as OverFast gives it.
    let division:String
    /// 1 is the division's best, 5 its lowest.
    let tier:Int
    let icon:URL
    /// The divisions from lowest to highest; one this list doesn't know counts lowest.
    static let divisions=["bronze","silver","gold","platinum","emerald","diamond","master","grandmaster","champion"]
    /// Higher is better: the division, then the tier within it.
    var standing:Int { (Self.divisions.firstIndex(of:division) ?? -1)*10+(6-tier) }
}

/// Games, as the profile counts them.
struct Tally: Codable, Equatable {
    var played=0,won=0,lost=0
}

/// One mode's totals on the profile (all heroes), each hero's time played, and its best games.
struct ModeStats: Codable, Equatable {
    var games=Tally()
    var heroes:[String:Int]=[:]
    var eliminations=0,deaths=0,damage=0,healing=0
    /// The profile's "best in a game" records ("eliminations_most_in_game": 46).
    var bests:[String:Int]=[:]
    /// Each hero's games, for its win rate; nil in what an older Recall kept.
    var heroGames:[String:Tally]?
}

/// Who the player is in the game: what the profile's header shows.
struct CareerIdentity: Codable, Equatable {
    var name:String
    var title:String?
    var endorsement:Int?
    var avatar:URL?
    /// The name card's picture (Settings shows that Recall reads it; the card doesn't show it).
    var namecard:URL?=nil
}

/// A hero as OverFast lists them: name, portrait and role.
struct CareerHero: Codable, Equatable {
    let name:String
    let portrait:URL?
    let role:CareerRank.Role?
}

/// A record beaten in the last session ("eliminations_most_in_game" is now 46).
struct CareerBest: Codable, Equatable {
    let key:String
    let value:Int
    /// The records the card tells, in the order it prefers them.
    static let told=["eliminations_most_in_game","all_damage_done_most_in_game","healing_done_most_in_game","final_blows_most_in_game",
                     "solo_kills_most_in_game","kill_streak_best","multikill_best"]
}

/// What changed on the profile since it was last looked at: the session (or sessions) before this one.
struct LastSession: Codable, Equatable {
    var competitive=Tally(),quickplay=Tally()
    /// Matches the game's log saw beyond these two modes (Arcade, custom games…); nil when the log
    /// wasn't followed throughout, so they can't be told.
    var other:Int?
    /// OverFast's key for the hero played longest ("soldier-76"), and the role of the hero played longest
    /// in Competitive.
    var hero:String?
    var role:CareerRank.Role?
    var eliminations=0,deaths=0,damage=0,healing=0
    var best:CareerBest?
    /// A rank that moved, and which way.
    var rank:CareerRank?
    var promoted=false
    var played:Int { competitive.played+quickplay.played+(other ?? 0) }

    /// The difference between two looks at the profile, with the log's count of the matches between
    /// them; nil when nothing was played.
    static func between(_ before:[String:ModeStats],_ after:[String:ModeStats],heroes:[String:CareerHero]=[:],matches:Int?=nil)->LastSession? {
        guard let oldComp=before["competitive"],let newComp=after["competitive"],let oldQuick=before["quickplay"],let newQuick=after["quickplay"] else { return nil }
        func change(_ old:Tally,_ new:Tally)->Tally {
            Tally(played:max(0,new.played-old.played),won:max(0,new.won-old.won),lost:max(0,new.lost-old.lost))
        }
        /// The key that grew most (the first by name when two grew alike).
        func most(_ new:[String:Int],_ old:[String:Int])->String? {
            var best:(key:String,gain:Int)?
            for (key,value) in new.sorted(by:{ $0.key < $1.key }) {
                let gain=value-(old[key] ?? 0)
                if gain > 0 && gain > (best?.gain ?? 0) { best=(key,gain) }
            }
            return best?.key
        }
        var session=LastSession(competitive:change(oldComp.games,newComp.games),quickplay:change(oldQuick.games,newQuick.games))
        // The log's matches beyond these modes; a count lower than theirs means it missed some, and tells nothing.
        if let matches,matches >= session.competitive.played+session.quickplay.played { session.other=matches-session.competitive.played-session.quickplay.played }
        guard session.played > 0 else { return nil }
        var both=newQuick.heroes,bothBefore=oldQuick.heroes
        for (key,value) in newComp.heroes { both[key,default:0]+=value }
        for (key,value) in oldComp.heroes { bothBefore[key,default:0]+=value }
        session.hero=most(both,bothBefore)
        session.role=most(newComp.heroes,oldComp.heroes).flatMap { heroes[$0]?.role }
        for (old,new) in [(oldComp,newComp),(oldQuick,newQuick)] {
            session.eliminations+=max(0,new.eliminations-old.eliminations);session.deaths+=max(0,new.deaths-old.deaths)
            session.damage+=max(0,new.damage-old.damage);session.healing+=max(0,new.healing-old.healing)
        }
        // A record beaten in either mode: the first the card prefers, at its new value.
        for key in CareerBest.told {
            let beaten=[(oldComp,newComp),(oldQuick,newQuick)].compactMap { old,new -> Int? in
                guard let value=new.bests[key],let was=old.bests[key],was > 0,value > was else { return nil }
                return value
            }
            if let value=beaten.max() { session.best=CareerBest(key:key,value:value);break }
        }
        return session
    }
    /// The rank that moved most between two looks (a new season, with no rank before, moves none).
    mutating func ranks(from before:[CareerRank],to after:[CareerRank]) {
        let moved=after.compactMap { new -> (CareerRank,Int)? in
            guard let old=before.first(where:{ $0.role == new.role }),old.standing != new.standing else { return nil }
            return (new,new.standing-old.standing)
        }.max { abs($0.1) < abs($1.1) }
        rank=moved?.0;promoted=(moved?.1 ?? 0) > 0
    }
}

/// What the card shows from the profile.
struct CareerCard: Equatable {
    var identity:CareerIdentity?
    var ranks:[CareerRank]=[]
    var season:Int?
    var last:LastSession?
    /// The last session's hero, as OverFast lists them.
    var hero:CareerHero?
    /// The player's career page on Blizzard's site, for the card's button.
    var page:URL?
    /// The profile's totals by mode (all time: records, bests, each hero's time and games), and the heroes
    /// as OverFast lists them (names, roles, portraits).
    var totals:[String:ModeStats]=[:]
    var heroes:[String:CareerHero]=[:]
    /// The rank shown: the role the last session's competitive games were in, or else the best one.
    var rank:CareerRank? {
        if let role=last?.role,(last?.competitive.played ?? 0) > 0,let rank=ranks.first(where:{ $0.role == role }) { return rank }
        return ranks.max { $0.standing < $1.standing }
    }
}

/// OverFast's answers, read.
enum OverFast {
    static let standard=URL(string:"https://overfast-api.tekrop.fr")!
    /// `/players/{id}/summary`: the profile's time (Unix seconds), its PC competitive ranks and season,
    /// and who the player is.
    static func summary(_ data:Data)->(updated:Int,ranks:[CareerRank],season:Int?,identity:CareerIdentity?)? {
        guard let json=try? JSONSerialization.jsonObject(with:data) as? [String:Any],let updated=json["last_updated_at"] as? Int else { return nil }
        let pc=(json["competitive"] as? [String:Any])?["pc"] as? [String:Any] ?? [:]
        let ranks=CareerRank.Role.allCases.compactMap { role -> CareerRank? in
            guard let entry=pc[role.rawValue] as? [String:Any],let division=entry["division"] as? String,let tier=entry["tier"] as? Int,
                  let icon=secure(entry["rank_icon"]) else { return nil }
            return CareerRank(role:role,division:division,tier:tier,icon:icon)
        }
        // The player's title, as the game gives it (already in the profile's language).
        let shown=(json["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let identity=(json["username"] as? String).map {
            CareerIdentity(name:$0,title:shown,
                           endorsement:(json["endorsement"] as? [String:Any])?["level"] as? Int,avatar:secure(json["avatar"]),namecard:secure(json["namecard"]))
        }
        return (updated,ranks,pc["season"] as? Int,identity)
    }
    /// `/players/{id}`: the PC totals of Quick Play and Competitive, from the career stats.
    static func profile(_ data:Data)->[String:ModeStats]? {
        guard let json=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              let pc=(json["stats"] as? [String:Any])?["pc"] as? [String:Any] else { return nil }
        var modes:[String:ModeStats]=[:]
        for mode in ["competitive","quickplay"] {
            let career=(pc[mode] as? [String:Any])?["career_stats"] as? [String:Any] ?? [:]
            /// A hero's (or all heroes') values in one category, the first of each key.
            func values(_ hero:String,_ category:String)->[String:Int] {
                let categories=career[hero] as? [[String:Any]] ?? []
                let stats=categories.first { $0["category"] as? String == category }?["stats"] as? [[String:Any]] ?? []
                return stats.reduce(into:[:]) { result,stat in
                    if let key=stat["key"] as? String,result[key] == nil,let value=(stat["value"] as? NSNumber)?.intValue { result[key]=value }
                }
            }
            let game=values("all-heroes","game"),combat=values("all-heroes","combat"),assists=values("all-heroes","assists")
            var stats=ModeStats(games:Tally(played:game["games_played"] ?? 0,won:game["games_won"] ?? 0,lost:game["games_lost"] ?? 0),
                                eliminations:combat["eliminations"] ?? 0,deaths:combat["deaths"] ?? 0,damage:combat["hero_damage_done"] ?? 0,
                                healing:assists["healing_done"] ?? 0,bests:values("all-heroes","best"))
            var heroGames:[String:Tally]=[:]
            for hero in career.keys where hero != "all-heroes" {
                let game=values(hero,"game")
                if let time=game["time_played"],time > 0 { stats.heroes[hero]=time }
                if let played=game["games_played"],played > 0 { heroGames[hero]=Tally(played:played,won:game["games_won"] ?? 0,lost:game["games_lost"] ?? 0) }
            }
            if !heroGames.isEmpty { stats.heroGames=heroGames }
            modes[mode]=stats
        }
        return modes
    }
    /// `/heroes`: each hero's name, portrait and role, by OverFast's key.
    static func heroes(_ data:Data)->[String:CareerHero]? {
        guard let list=try? JSONSerialization.jsonObject(with:data) as? [[String:Any]] else { return nil }
        return list.reduce(into:[:]) { result,entry in
            guard let key=entry["key"] as? String,let name=entry["name"] as? String else { return }
            result[key]=CareerHero(name:name,portrait:secure(entry["portrait"]),role:(entry["role"] as? String).flatMap(CareerRank.Role.init))
        }
    }
    /// A not-found answer's own wait (`next_check_at`, Unix seconds, or `retry_after`, seconds); OverFast
    /// doesn't look at that player again before it (about 90 minutes, seen October 25).
    static func notFoundUntil(_ data:Data,now:Date)->Date {
        let json=(try? JSONSerialization.jsonObject(with:data) as? [String:Any]) ?? [:]
        if let at=json["next_check_at"] as? Double,at > now.timeIntervalSince1970 { return Date(timeIntervalSince1970:at) }
        if let after=json["retry_after"] as? Double,after > 0 { return now.addingTimeInterval(after) }
        return now.addingTimeInterval(90*60)
    }
    /// Settings › Discord: an OverFast the player runs themselves. https, or http on this Mac only; nil for
    /// anything else (the BattleTag never travels unencrypted to another machine).
    static func server(_ text:String)->URL? {
        guard let url=URL(string:text.trimmingCharacters(in:.whitespaces)),let host=url.host,!host.isEmpty,url.query == nil,url.fragment == nil else { return nil }
        guard url.scheme == "https" || (url.scheme == "http" && ["localhost","127.0.0.1","::1"].contains(host)) else { return nil }
        return url
    }
    /// Images go to Discord only as https links.
    private static func secure(_ value:Any?)->URL? {
        (value as? String).flatMap(URL.init(string:)).flatMap { $0.scheme == "https" ? $0 : nil }
    }
}

/// Looks the player's profile up when it is time to, and keeps what it learned (in this Mac's
/// settings: the BattleTag's OverFast form, the profile's totals and header, the hero list, and the
/// log's match count since the totals were taken; never anything else). The changes over time go to
/// the history's own file.
final class CareerProfile {
    enum Status: Equatable {
        case none
        case looking
        case found(CareerRank?)
        /// Private, misspelt, or not yet seen by OverFast: it is asked again only after this.
        case notPublic(until:Date)
        case invalidTag
        /// OverFast didn't answer usefully; the next time the game opens it is asked again.
        case unavailable
    }
    struct Response { let status:Int;let headers:[String:String];let body:Data }
    /// One request; nil when there was no answer at all. Called on the profile's queue.
    typealias Fetch=(URL)->Response?
    /// One lookup in this long at most: OverFast's own cache time, so asking sooner learns nothing.
    static let fresh:TimeInterval=600
    /// The hero list is asked for again after this (new heroes come with seasons).
    static let heroesKept:TimeInterval=7*24*3600

    private struct Record: Codable {
        var player:String
        /// A summary was read: the card has something to show.
        var seen=false
        var updated:Int?
        var modes:[String:ModeStats]=[:]
        var ranks:[CareerRank]=[]
        var season:Int?
        var identity:CareerIdentity?
        var last:LastSession?
        /// Matches the log saw since the totals were taken; nil once a session went by without it.
        var matches:Int?
        var heroes:[String:CareerHero]=[:]
        var heroesAt:Date?
        var asked:Date?
        var waitUntil:Date?
        var notPublic=false
        var code:Int?
    }
    private let queue=DispatchQueue(label:"org.overwatch2mac.career-profile",qos:.utility)
    private var base:URL
    private let store:UserDefaults
    private let key:String
    private let fetch:Fetch
    /// What the looks found over time, and the game's runs (CareerHistory.swift).
    let history:CareerHistoryStore
    init(base:URL=OverFast.standard,store:UserDefaults = .standard,key:String="careerProfile",history:CareerHistoryStore=CareerHistoryStore(url:nil),fetch:Fetch?=nil) {
        self.base=base;self.store=store;self.key=key;self.history=history
        self.fetch=fetch ?? CareerProfile.request
    }
    /// Settings › Discord: another OverFast (one the player runs themselves), from the next look on.
    func use(base:URL) { queue.async { self.base=base } }
    /// The last answer's HTTP code, for the support report (never the BattleTag).
    var lastCode:Int? { queue.sync { record()?.code } }

    /// What the card can show from a record (nil before a summary was read).
    private static func card(_ record:Record)->CareerCard? {
        guard record.seen else { return nil }
        var page=URLComponents(string:"https://overwatch.blizzard.com/en-us/career/")!
        page.path+=record.player+"/"
        return CareerCard(identity:record.identity,ranks:record.ranks,season:record.season,last:record.last,
                          hero:record.last?.hero.flatMap { record.heroes[$0] },page:page.url,totals:record.modes,heroes:record.heroes)
    }
    /// What the last look found for this BattleTag, without asking again (Settings' preview), and when it was.
    /// `done` is called on the profile's queue.
    func kept(tag:String,done:@escaping (Status,CareerCard?,Date?)->Void) {
        queue.async {
            guard let player=BattleTag.playerID(tag) else { done(.invalidTag,nil,nil);return }
            guard let record=self.record(),record.player == player else { done(.none,nil,nil);return }
            let card=Self.card(record)
            if record.notPublic,let wait=record.waitUntil { done(.notPublic(until:wait),card,record.asked);return }
            done(record.seen ? .found(card?.rank) : .none,card,record.asked)
        }
    }
    /// Looks the player up if it is time to, and tells what the card can show. `done` is called on the
    /// profile's queue.
    func lookUp(tag:String,now:Date=Date(),done:@escaping (Status,CareerCard?)->Void) {
        queue.async {
            guard let player=BattleTag.playerID(tag) else { done(.invalidTag,nil);return }
            var record=self.record().flatMap { $0.player == player ? $0 : nil } ?? Record(player:player)
            // What was learned is kept before it is told.
            func finish(_ status:Status,_ card:CareerCard?) { self.save(record);done(status,card) }
            func card()->CareerCard? { Self.card(record) }
            if let wait=record.waitUntil,now < wait { finish(record.notPublic ? .notPublic(until:wait) : .unavailable,card());return }
            if let asked=record.asked,now.timeIntervalSince(asked) < Self.fresh,!record.notPublic {
                finish(record.seen ? .found(card()?.rank) : .unavailable,card());return
            }
            record.asked=now;record.waitUntil=nil;record.notPublic=false
            let answer=self.fetch(self.base.appendingPathComponent("players/\(player)/summary"))
            record.code=answer?.status
            guard let answer else { finish(.unavailable,card());return }
            switch answer.status {
            case 200:
                guard let summary=OverFast.summary(answer.body) else { finish(.unavailable,card());return }
                let ranksBefore=record.ranks
                record.seen=true;record.ranks=summary.ranks;record.identity=summary.identity ?? record.identity
                var change:ProfileChange?
                // The profile changed: the whole of it is looked at, and the change is the last session.
                if summary.updated != record.updated,let whole=self.fetch(self.base.appendingPathComponent("players/\(player)")),
                   whole.status == 200,let modes=OverFast.profile(whole.body) {
                    if !record.modes.isEmpty {
                        if record.heroesAt.map({ now.timeIntervalSince($0) > Self.heroesKept }) ?? true,
                           let list=self.fetch(self.base.appendingPathComponent("heroes")),list.status == 200,let heroes=OverFast.heroes(list.body) {
                            record.heroes=heroes;record.heroesAt=now
                        }
                        if var last=LastSession.between(record.modes,modes,heroes:record.heroes,matches:record.matches) {
                            // A rank moved in the same season only: a new season starts ranks over.
                            if summary.season == record.season { last.ranks(from:ranksBefore,to:summary.ranks) }
                            record.last=last
                            // Kept with the profile's own time (when the game closed), not the look's.
                            change=ProfileChange(at:Date(timeIntervalSince1970:TimeInterval(summary.updated)),season:summary.season,session:last,before:record.modes,after:modes)
                            if let moved=last.rank,let old=ranksBefore.first(where:{ $0.role == moved.role }) { change?.rankSteps=moved.steps(from:old) }
                        }
                    }
                    record.modes=modes;record.updated=summary.updated;record.matches=0
                }
                record.season=summary.season
                self.history.update { $0.looked(at:now,season:summary.season,ranks:summary.ranks,change:change) }
                finish(.found(card()?.rank),card())
            case 404:
                record.notPublic=true;record.waitUntil=OverFast.notFoundUntil(answer.body,now:now)
                finish(.notPublic(until:record.waitUntil!),nil)
            case 429,503:
                // Too many asks (OverFast's or Blizzard's): its Retry-After, and nothing before.
                let after=answer.headers.first { $0.key.lowercased() == "retry-after" }.flatMap { Double($0.value) } ?? Self.fresh
                record.waitUntil=now.addingTimeInterval(max(after,60))
                finish(.unavailable,card())
            default: finish(.unavailable,card())
            }
        }
    }
    /// A run of the game ended: it goes into the history (BattleTag or not), and its matches, or nil when the log
    /// wasn't followed (Normal, after which the next session's other modes can't be told), count toward the
    /// next session the profile tells.
    func sessionEnded(_ run:PlayedRun) {
        queue.async {
            self.history.update { $0.ran(run) }
            guard var record=self.record() else { return }
            record.matches=run.matches.flatMap { count in record.matches.map { $0+count } }
            self.save(record)
        }
    }
    /// The BattleTag changed or was cleared: what was kept for the old one goes (this Mac's runs stay).
    func forget() { queue.async { self.store.removeObject(forKey:self.key);self.history.update { $0.forgetProfile() } } }
    /// What Recall remembers › Erase: the history and the profile both. The ranks and all-time records come
    /// back with the next look; the sessions don't.
    func erase() { queue.async { self.eraseNow() } }
    /// The same at once, not after a look on its way (Recall quitting): the settings and the history's file are
    /// both safe to change from any thread.
    func eraseNow() { store.removeObject(forKey:key);history.erase() }

    private func record()->Record? { store.data(forKey:key).flatMap { try? JSONDecoder().decode(Record.self,from:$0) } }
    private func save(_ record:Record) { store.set(try? JSONEncoder().encode(record),forKey:key) }
    /// A request as UpdateService makes them: ephemeral, named, 15 seconds at most (30 for the whole profile).
    private static func request(_ url:URL)->Response? {
        var request=URLRequest(url:url,cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:url.path.hasSuffix("/summary") ? 15 : 30)
        request.setValue(Brand.name,forHTTPHeaderField:"User-Agent")
        let done=DispatchSemaphore(value:0)
        var result:Response?
        URLSession(configuration:.ephemeral).dataTask(with:request) { data,response,_ in
            if let http=response as? HTTPURLResponse {
                result=Response(status:http.statusCode,headers:http.allHeaderFields.reduce(into:[:]) { $0["\($1.key)"]="\($1.value)" },body:data ?? Data())
            }
            done.signal()
        }.resume()
        done.wait()
        return result
    }
}

// The card's words for the profile, in the app's language.
extension CareerRank {
    /// "Emerald 1".
    var name:String {
        let names=["bronze":L("Bronze"),"silver":L("Silver"),"gold":L("Gold"),"platinum":L("Platinum"),"emerald":L("Emerald"),
                   "diamond":L("Diamond"),"master":L("Master"),"grandmaster":L("Grandmaster"),"champion":L("Champion")]
        return "\(names[division] ?? division.capitalized) \(tier)"
    }
    /// "Tank: Emerald 1", or with other words after the role ("Tank: up to Emerald 1").
    func label(_ text:String?=nil)->String {
        let text=text ?? name
        // One phrase per role, so a role's name never shares a key with the same word elsewhere ("Support").
        switch role {
        case .tank: return L("Tank: {0}",text)
        case .damage: return L("Damage: {0}",text)
        case .support: return L("Support: {0}",text)
        // The career page's fourth row, which the game plays as 6v6 (seen October 25).
        case .open: return L("6v6: {0}",text)
        }
    }
}
extension LastSession {
    /// "Comp 2–1 · QP 1–0 · 1 other", short enough for the card's line 2, which Discord cuts at about 30
    /// characters; only other matches are counted ("3 matches").
    var summary:String {
        var parts:[String]=[]
        if competitive.played > 0 { parts.append(L("Comp {0}–{1}",String(competitive.won),String(competitive.lost))) }
        if quickplay.played > 0 { parts.append(L("QP {0}–{1}",String(quickplay.won),String(quickplay.lost))) }
        if parts.isEmpty { return played == 1 ? L("1 match") : L("{0} matches",String(played)) }
        if let other,other > 0 { parts.append(L("{0} other",String(other))) }
        return parts.joined(separator:" · ")
    }
    /// "38 eliminations, 9 deaths, 14,032 healing" (healing or damage, whichever there was more of).
    var stats:String? {
        guard eliminations+deaths+damage+healing > 0 else { return nil }
        let number={ (value:Int) in value.formatted(.number) }
        return healing > damage ? L("{0} eliminations, {1} deaths, {2} healing",number(eliminations),number(deaths),number(healing))
                                : L("{0} eliminations, {1} deaths, {2} damage",number(eliminations),number(deaths),number(damage))
    }
}
