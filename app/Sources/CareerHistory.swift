import Foundation

// What Recall remembers between game sessions, so the card can tell how today, this week or this season
// went, how many nights in a row the player has played, and what happened since their last game (the
// moments). Two things are kept, each as it came:
// - the runs of the game this Mac saw: when each opened and closed, and the matches the log counted. None
//   of this needs a BattleTag (the card's Tonight lines come from it alone);
// - the profile's changes (Full): each time a look finds the profile changed, how it changed, dated by the
//   profile's own time, which is the second the game closed. A Monday night session first seen on Saturday
//   is Monday's, wherever the look happened.
// With them, each hero's hours as Recall counts them (HeroHours), which a new season doesn't take away.
// One small file in Recall's own Application Support folder, on this Mac only (never in the settings,
// which load at every launch). Both lists keep a little over a year; Erase removes the file.

/// One change of the profile: what the sessions between two looks did, and when they ended.
struct ProfileChange: Codable, Equatable {
    /// A hero that passed a milestone, and the hours it passed.
    struct Milestone: Codable, Equatable { let hero:String;let hours:Int }
    /// The profile's own time: the second the game closed after them.
    var at:Date
    var season:Int?
    var session:LastSession
    /// Seconds each hero was played, both modes together (OverFast's keys).
    var heroes:[String:Int]=[:]
    /// Divisions the last session's rank moved (LastSession.rank); nil when it didn't.
    var rankSteps:Int?
    /// Divisions each role's rank moved, by role (CareerRank.Role's raw value), for the roles that moved. Nil in a
    /// change kept before Recall kept these: it tells only the rank that moved most.
    var rankMoves:[String:Int]?
    /// A rank above the role's best so far this season (set as the change is kept; a season's first ranks are none).
    var seasonHigh:CareerRank?
    var milestone:Milestone?

    /// Hours on a hero worth telling: 10, 25 and 50, then every hundred.
    static func isMilestone(_ hours:Int)->Bool { [10,25,50].contains(hours) || (hours >= 100 && hours%100 == 0) }
    /// The change between two looks' totals.
    init(at:Date,season:Int?,session:LastSession,before:[String:ModeStats],after:[String:ModeStats]) {
        self.at=at;self.season=season;self.session=session
        func time(_ modes:[String:ModeStats])->[String:Int] {
            modes.values.reduce(into:[:]) { total,mode in for (hero,seconds) in mode.heroes { total[hero,default:0]+=seconds } }
        }
        let old=time(before),new=time(after)
        for (hero,seconds) in new where seconds > old[hero] ?? 0 { heroes[hero]=seconds-(old[hero] ?? 0) }
        // The highest milestone any hero passed (the first by name when two passed the same).
        for (hero,seconds) in new.sorted(by:{ $0.key < $1.key }) {
            let from=(old[hero] ?? 0)/3600,to=seconds/3600
            guard to > from,let passed=(from+1...to).reversed().first(where:Self.isMilestone),passed > (milestone?.hours ?? 0) else { continue }
            milestone=Milestone(hero:hero,hours:passed)
        }
    }
}

/// Each hero's time as Recall counts it. The profile holds Quick Play and this season's Competitive only, so on its own a
/// new season takes hours away: this starts from what the first look found, adds what each look after it gained, mode
/// by mode, and never goes down. Custom games are never on the profile, so never in here.
struct HeroHours: Codable, Equatable {
    /// The look that started the count.
    var since:Date
    /// Seconds per hero (OverFast's keys).
    var heroes:[String:Int]=[:]
    /// What the last look found in each mode, which the next look's gains are counted from: its games, and each
    /// hero's seconds.
    var seenGames:[String:Int]=[:]
    var seen:[String:[String:Int]]=[:]

    /// A look found these totals.
    mutating func count(_ modes:[String:ModeStats]) {
        for (mode,stats) in modes {
            let before=seen[mode] ?? [:]
            // A mode with fewer games or less time than before started over (Competitive, at a new season): all of
            // it is new.
            let over=stats.games.played < seenGames[mode] ?? 0 || stats.heroes.values.reduce(0,+) < before.values.reduce(0,+)
            for (hero,seconds) in stats.heroes {
                let gained=over ? seconds : seconds-(before[hero] ?? 0)
                if gained > 0 { heroes[hero,default:0]+=gained }
            }
            seen[mode]=stats.heroes;seenGames[mode]=stats.games.played
        }
    }
}

/// The times the card's records cover. All time is the profile's own totals (CareerCard), not the history's.
enum CareerPeriod: String, Codable, CaseIterable { case last,today,week,season,all }

struct CareerHistory: Codable, Equatable {
    /// Runs and changes are kept this long.
    static let kept:TimeInterval=400*24*3600
    /// The rank is not shown once matches were played after the last look and that look is older than this:
    /// the rank may have moved since, and a holiday with no games keeps it.
    static let stale:TimeInterval=2*24*3600
    /// A game after this long without one is a comeback.
    static let away:TimeInterval=3*24*3600
    /// A night runs until four in the morning: a game at one belongs to the evening before.
    static let nightEnds:TimeInterval=4*3600
    var runs:[PlayedRun]=[]
    var changes:[ProfileChange]=[]
    /// The season Recall last saw, when it first saw it, and whether Recall had seen the one before.
    var season:Int?
    var seasonSeen:Date?
    var seasonFollows=false
    /// This season's first rank and best rank in each role.
    var seasonFirst:[CareerRank]=[]
    var seasonPeak:[CareerRank]=[]
    /// The last look that found the profile.
    var looked:Date?
    /// Each hero's time as Recall has counted it; nil until a look has (and in what an older Recall kept).
    var hours:HeroHours?

    /// A run of the game ended.
    mutating func ran(_ run:PlayedRun) {
        runs.append(run);runs.sort { $0.start < $1.start }
        runs.removeAll { run.end.timeIntervalSince($0.end) > Self.kept }
    }
    /// A look found the profile: its season and ranks, and how it changed since the look before, if it did.
    mutating func looked(at time:Date,season:Int?,ranks:[CareerRank],change:ProfileChange?) {
        if season != self.season {
            seasonFollows=self.season != nil && season != nil
            self.season=season;seasonSeen=time;seasonFirst=[];seasonPeak=[]
        }
        if var change {
            change.seasonHigh=ranks.filter { new in seasonPeak.contains { $0.role == new.role && new.standing > $0.standing } }.max { $0.standing < $1.standing }
            changes.append(change);changes.sort { $0.at < $1.at }
            let newest=changes.last!.at
            changes.removeAll { newest.timeIntervalSince($0.at) > Self.kept }
        }
        for rank in ranks {
            if !seasonFirst.contains(where:{ $0.role == rank.role }) { seasonFirst.append(rank) }
            if let index=seasonPeak.firstIndex(where:{ $0.role == rank.role }) {
                if rank.standing > seasonPeak[index].standing { seasonPeak[index]=rank }
            } else { seasonPeak.append(rank) }
        }
        looked=time
    }
    /// A look found the profile with these totals: their hours are counted (from these, at the first).
    mutating func count(_ modes:[String:ModeStats],at time:Date) {
        guard !modes.isEmpty else { return }
        var hours=self.hours ?? HeroHours(since:time)
        hours.count(modes);self.hours=hours
    }
    /// The runs since the last change the profile told (all of them before one was), whose records come with the
    /// next look that finds it changed. A run the profile changed during belongs to that change.
    var waiting:[PlayedRun] { let last=changes.last?.at ?? .distantPast;return runs.filter { $0.start > last } }
    /// The runs a change covers: those overlapping the time since the change before it, so a run the profile changed
    /// during (Blizzard updates it after a match, maybe before the game closes) counts for it.
    func runs(for change:ProfileChange)->[PlayedRun] {
        let before=changes.last { $0.at < change.at }?.at ?? .distantPast
        return runs.filter { $0.start <= change.at && $0.end > before }
    }
    /// The BattleTag changed: what the old profile said goes, and this Mac's runs stay.
    mutating func forgetProfile() {
        changes=[];season=nil;seasonSeen=nil;seasonFollows=false;seasonFirst=[];seasonPeak=[];looked=nil;hours=nil
    }

    /// What the changes in a period add up to; nil when none falls in it. All time gives nil: the profile's
    /// totals tell it.
    func session(_ period:CareerPeriod,now:Date,calendar:Calendar = .current)->LastSession? {
        let picked:[ProfileChange]
        switch period {
        case .last: picked=changes.suffix(1)
        case .today: picked=changes.filter { calendar.isDate($0.at,inSameDayAs:now) }
        case .week: let week=calendar.dateInterval(of:.weekOfYear,for:now);picked=changes.filter { week?.contains($0.at) == true }
        case .season: picked=season == nil ? [] : changes.filter { $0.season == season }
        case .all: return nil
        }
        guard var total=picked.first?.session else { return nil }
        for change in picked.dropFirst() { total.add(change.session) }
        // The hero of the period: the one played longest over its changes.
        if picked.count > 1 {
            let time=picked.reduce(into:[String:Int]()) { sum,change in for (hero,seconds) in change.heroes { sum[hero,default:0]+=seconds } }
            total.hero=time.sorted { $0.key < $1.key }.max { $0.value < $1.value }?.key
        }
        return total
    }
    /// Nights in a row with a game, tonight's included (the game running counts for tonight).
    func nightsInARow(now:Date,playing:Bool,calendar:Calendar = .current)->Int {
        func night(_ date:Date)->Date { calendar.startOfDay(for:date.addingTimeInterval(-Self.nightEnds)) }
        var nights=Set(runs.map { night($0.start) })
        if playing { nights.insert(night(now)) }
        var day=night(now),count=0
        while nights.contains(day),let before=calendar.date(byAdding:.day,value:-1,to:day) { count+=1;day=before }
        return count
    }
    /// Time played this week (from the first day of the week the Mac's calendar uses), the run going on included.
    func playedThisWeek(now:Date,current start:Date?,calendar:Calendar = .current)->TimeInterval {
        guard let week=calendar.dateInterval(of:.weekOfYear,for:now) else { return 0 }
        var total=runs.reduce(0) { $0+max(0,min($1.end,week.end).timeIntervalSince(max($1.start,week.start))) }
        if let start { total+=max(0,now.timeIntervalSince(max(start,week.start))) }
        return total
    }
    /// The time since the last game, when the game opening at `start` comes after three days or more without one.
    func away(before start:Date)->TimeInterval? {
        guard let last=runs.last(where:{ $0.end <= start }) else { return nil }
        let gap=start.timeIntervalSince(last.end)
        return gap >= Self.away ? gap : nil
    }
    /// The latest change while it is news: no game has opened between the one it came from and the game
    /// opening at `start` (moments show the first time the player plays after them).
    func news(before start:Date)->ProfileChange? {
        guard let change=changes.last,!runs.contains(where:{ $0.start > change.at && $0.start < start }) else { return nil }
        return change
    }
    /// A new season, while it is news: Recall saw the season before it, and no game has opened since.
    func newSeason(before start:Date)->Int? {
        guard seasonFollows,let season,let seen=seasonSeen,!runs.contains(where:{ $0.start >= seen && $0.start < start }) else { return nil }
        return season
    }
    /// Matches were played since the last look, and that look is old: the rank shown may be wrong.
    func rankStale(now:Date)->Bool {
        guard let looked,now.timeIntervalSince(looked) > Self.stale else { return false }
        return runs.contains { $0.start >= looked && ($0.matches ?? 1) > 0 }
    }
    /// This season's first rank and best rank in a role, for the season's climb and peak.
    func first(_ role:CareerRank.Role)->CareerRank? { seasonFirst.first { $0.role == role } }
    func peak(_ role:CareerRank.Role)->CareerRank? { seasonPeak.first { $0.role == role } }
}

extension CareerHistory {
    /// What Recall remembers › Export: everything kept, as a spreadsheet (CSV, UTF-8 with its mark, so Numbers
    /// and Excel both read Korean and Chinese). One row for each run of the game and each profile change, oldest
    /// first, times as this Mac shows them.
    func csv(heroes:[String:CareerHero],timeZone:TimeZone = .current)->String {
        let format=DateFormatter();format.locale=Locale(identifier:"en_US_POSIX");format.timeZone=timeZone;format.dateFormat="yyyy-MM-dd HH:mm"
        func tally(_ t:Tally)->String { t.played > 0 ? L("{0}–{1}",String(t.won),String(t.lost)) : "" }
        // A hero's name comes from OverFast: one that starts as a formula would (=, +, -, @) stays text in a spreadsheet.
        func name(_ text:String)->String { text.first.map { "=+-@".contains($0) } == true ? "'"+text : text }
        var rows:[(at:Date,fields:[String])]=runs.map { run in
            (run.end,[format.string(from:run.start),format.string(from:run.end),L("Played on this Mac"),run.matches.map(String.init) ?? "","","","","",""])
        }
        for change in changes {
            let session=change.session
            rows.append((change.at,["",format.string(from:change.at),L("Profile change"),String(session.played),tally(session.competitive),tally(session.quickplay),
                                    session.hero.map { name(heroes[$0]?.name ?? $0) } ?? "",session.rank?.label() ?? "",change.rankSteps.map { $0 > 0 ? "+\($0)" : String($0) } ?? ""]))
        }
        // A field with a comma, a quote or a line break is quoted, its quotes doubled.
        func field(_ text:String)->String {
            text.contains(where:{ $0 == "," || $0 == "\"" || $0.isNewline }) ? "\"\(text.replacingOccurrences(of:"\"",with:"\"\""))\"" : text
        }
        let head=[L("Started"),L("Ended"),L("What"),L("Matches"),L("Competitive"),L("Quick Play"),L("Hero"),L("Rank"),L("Divisions")]
        let lines=[head]+rows.sorted { $0.at < $1.at }.map(\.fields)
        return "\u{FEFF}"+lines.map { $0.map(field).joined(separator:",") }.joined(separator:"\r\n")+"\r\n"
    }
}
extension Tally {
    static func +(a:Tally,b:Tally)->Tally { Tally(played:a.played+b.played,won:a.won+b.won,lost:a.lost+b.lost) }
}
extension LastSession {
    /// Another change's games and totals added to these. Other modes are told only when every change told them;
    /// the best, the rank and the hero are the latest's (the period's hero is worked out from the time).
    mutating func add(_ later:LastSession) {
        competitive=competitive+later.competitive;quickplay=quickplay+later.quickplay
        other=other.flatMap { count in later.other.map { count+$0 } }
        eliminations+=later.eliminations;deaths+=later.deaths;damage+=later.damage;healing+=later.healing
        best=later.best ?? best;hero=later.hero ?? hero;role=later.role ?? role
        if later.rank != nil { rank=later.rank;promoted=later.promoted }
    }
}
extension CareerRank {
    /// Divisions between two ranks (Gold 1 to Platinum 5 is one, Gold 3 to Gold 1 is two); positive is up.
    func steps(from old:CareerRank)->Int { place-old.place }
    /// The divisions each role moved between two looks' ranks, for the roles ranked in both that moved.
    static func moves(from before:[CareerRank],to after:[CareerRank])->[String:Int] {
        after.reduce(into:[:]) { moves,new in
            if let old=before.first(where:{ $0.role == new.role }),new.steps(from:old) != 0 { moves[new.role.rawValue]=new.steps(from:old) }
        }
    }
    private var place:Int { (Self.divisions.firstIndex(of:division) ?? -1)*5+(5-tier) }
}

/// Keeps the history in its file: read once, written whole after each change (it is small). Safe from any
/// thread. Without a file it keeps the history in memory only (the tests, a preview).
final class CareerHistoryStore {
    /// Recall's own folder in Application Support, not the game's data folder (which can be on another drive).
    static var standardURL:URL {
        FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("org.overwatch2mac.launcher/career-history.json")
    }
    private let url:URL?
    private let lock=NSLock()
    private var history:CareerHistory?
    init(url:URL?) { self.url=url }
    var current:CareerHistory { lock.lock();defer { lock.unlock() };return loaded() }
    func update(_ change:(inout CareerHistory)->Void) {
        lock.lock();defer { lock.unlock() }
        var value=loaded();change(&value);history=value
        guard let url else { return }
        try? FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        if let data=try? Self.encoder.encode(value) { try? data.write(to:url,options:.atomic) }
    }
    /// What Recall remembers › Erase: everything goes, the file too.
    func erase() {
        lock.lock();defer { lock.unlock() }
        history=CareerHistory()
        if let url { try? FileManager.default.removeItem(at:url) }
    }
    private func loaded()->CareerHistory {
        if let history { return history }
        let value=url.flatMap { try? Data(contentsOf:$0) }.flatMap { try? Self.decoder.decode(CareerHistory.self,from:$0) } ?? CareerHistory()
        history=value
        return value
    }
    // Dates as text, so the file reads plainly to anyone who opens it.
    private static let encoder:JSONEncoder={ let coder=JSONEncoder();coder.dateEncodingStrategy = .iso8601;return coder }()
    private static let decoder:JSONDecoder={ let coder=JSONDecoder();coder.dateDecodingStrategy = .iso8601;return coder }()
}
