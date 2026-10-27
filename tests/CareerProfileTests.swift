import Foundation

// CareerProfile.swift: the BattleTag, OverFast's answers, the last session (with the log's match count),
// when the profile is looked up (and when it is not), and the profile on the Discord card. CareerHistory.swift:
// the runs and changes kept over time, their periods, nights and moments, and the history's file. OverFast is
// a fake that counts what is asked; the answers are shaped like OverFast's own (October 25), with made-up
// players.
// Build and run:
//   swiftc -O -target arm64-apple-macos26.5 -parse-as-library app/Sources/Brand.swift app/Sources/Localization.swift \
//     app/Sources/DiscordPresence.swift app/Sources/CareerProfile.swift app/Sources/CareerHistory.swift \
//     app/Sources/DiscordCardTemplate.swift app/Sources/DiscordCardCatalog.swift tests/CareerProfileTests.swift -o runtime/phase-3/career-profile-tests
//   runtime/phase-3/career-profile-tests

func json(_ value:Any)->Data { try! JSONSerialization.data(withJSONObject:value) }
func summary(updated:Int,season:Int=25,tank:(String,Int)?=("emerald",1),support:(String,Int)?=nil,open:(String,Int)?=("gold",2))->Data {
    var pc:[String:Any]=["season":season,"damage":NSNull()]
    for (role,rank) in [("tank",tank),("support",support),("open",open)] {
        pc[role]=rank.map { ["division":$0.0,"tier":$0.1,"rank_icon":"https://static.playoverwatch.com/rank/\($0.0).png","role_icon":"https://x/\(role).svg"] } ?? NSNull()
    }
    return json(["username":"Player","avatar":"https://x/avatar.png","namecard":"https://x/card.png","title":"Shieldbreaker",
                 "endorsement":["level":4,"frame":"https://x/4.svg"],"competitive":["pc":pc,"console":NSNull()],"last_updated_at":updated])
}
/// One mode's career stats, as OverFast nests them: categories of key/value pairs, all heroes and each hero.
struct Mode { var played=0,won=0,lost=0,elims=0,deaths=0,damage=0,healing=0;var bests:[String:Int]=[:];var heroes:[String:Int]=[:] }
func career(_ mode:Mode)->[String:Any] {
    func category(_ name:String,_ values:[String:Int])->[String:Any] { ["category":name,"stats":values.map { ["key":$0.key,"label":$0.key,"value":$0.value] }] }
    var stats:[String:Any]=["all-heroes":[category("game",["games_played":mode.played,"games_won":mode.won,"games_lost":mode.lost,"time_played":mode.heroes.values.reduce(0,+)]),
                                          category("combat",["eliminations":mode.elims,"deaths":mode.deaths,"hero_damage_done":mode.damage,"damage_done":mode.damage]),
                                          category("assists",["healing_done":mode.healing]),category("best",mode.bests)]]
    for (hero,time) in mode.heroes { stats[hero]=[category("game",["time_played":time,"games_played":1])] }
    return ["career_stats":stats,"heroes_comparisons":[:]]
}
func wholeProfile(competitive:Mode,quickplay:Mode)->Data {
    json(["summary":[:],"stats":["pc":["competitive":career(competitive),"quickplay":career(quickplay)],"console":NSNull()]])
}
let heroList=json([["key":"ana","name":"Ana","portrait":"https://x/ana.png","role":"support"],["key":"reinhardt","name":"Reinhardt","portrait":"https://x/rein.png","role":"tank"],
                   ["key":"juno","name":"Juno","portrait":"https://x/juno.png","role":"support"]])

/// OverFast, played by the test: answers by path, and remembers what was asked.
final class FakeOverFast {
    private let lock=NSLock()
    private var asked:[String]=[]
    var answers:[String:CareerProfile.Response?]=[:]
    var requests:[String] { lock.lock();defer { lock.unlock() };return asked }
    func fetch(_ url:URL)->CareerProfile.Response? {
        let key=url.path+(url.query.map { "?"+$0 } ?? "")
        lock.lock();asked.append(key);lock.unlock()
        return answers[key] ?? nil
    }
    func ok(_ body:Data)->CareerProfile.Response { CareerProfile.Response(status:200,headers:[:],body:body) }
}

@main struct CareerProfileTests {
    static func main() {
        battleTags();answers();lastSession();cardText();lookUps();history();historyStore();servers()
        print("PASS: BattleTags, OverFast's answers, the last session and its words, when the profile is looked up, the history and its file, and the servers")
    }

    static func battleTags() {
        precondition(BattleTag.playerID("Player#1234") == "Player-1234" && BattleTag.playerID(" Player#12345 ") == "Player-12345")
        precondition(BattleTag.playerID("Jöhn#11248") == "Jöhn-11248" && BattleTag.playerID("한국어이름#3123") == "한국어이름-3123")
        // Never sent: no #, a name too short or too long or starting with a digit, a short number, other characters.
        for bad in ["Player1234","Pl#1234","ThirteenChars#1234","1Player#1234","Player#12","Play er#1234","Player#12a4","Player-1234",""] {
            precondition(BattleTag.playerID(bad) == nil,bad)
        }
    }

    static func answers() {
        let read=OverFast.summary(summary(updated:1_792_941_113,support:("champion",3)))!
        precondition(read.updated == 1_792_941_113 && read.season == 25 && read.ranks.map(\.role) == [.tank,.support,.open])
        precondition(read.ranks[0] == CareerRank(role:.tank,division:"emerald",tier:1,icon:URL(string:"https://static.playoverwatch.com/rank/emerald.png")!))
        precondition(read.identity == CareerIdentity(name:"Player",title:"Shieldbreaker",endorsement:4,avatar:URL(string:"https://x/avatar.png"),namecard:URL(string:"https://x/card.png")))
        // A profile with no competitive rank, or a rank whose icon isn't https, shows none.
        precondition(OverFast.summary(json(["competitive":NSNull(),"last_updated_at":5]))!.ranks.isEmpty)
        var plain=try! JSONSerialization.jsonObject(with:summary(updated:5)) as! [String:Any]
        var competitive=plain["competitive"] as! [String:Any],pc=competitive["pc"] as! [String:Any],tank=pc["tank"] as! [String:Any]
        tank["rank_icon"]="http://example.com/rank.png";pc["tank"]=tank;competitive["pc"]=pc;plain["competitive"]=competitive;plain["avatar"]="http://x/a.png";plain["namecard"]="http://x/c.png"
        let insecure=OverFast.summary(json(plain))!
        precondition(insecure.ranks.map(\.role) == [.open] && insecure.identity?.avatar == nil && insecure.identity?.namecard == nil)
        precondition(OverFast.summary(json(["error":"Player not found"])) == nil && OverFast.summary(Data("<html>".utf8)) == nil)
        // The whole profile: each mode's totals, records and heroes' time.
        let modes=OverFast.profile(wholeProfile(competitive:Mode(played:98,won:45,lost:52,elims:1760,deaths:588,damage:739031,healing:594755,bests:["eliminations_most_in_game":46],heroes:["ana":10615,"juno":12822]),
                                                quickplay:Mode(played:578,won:297,lost:281,heroes:["juno":42800])))!
        precondition(modes["competitive"] == ModeStats(games:Tally(played:98,won:45,lost:52),heroes:["ana":10615,"juno":12822],eliminations:1760,deaths:588,damage:739031,healing:594755,bests:["eliminations_most_in_game":46],
                                                       heroGames:["ana":Tally(played:1),"juno":Tally(played:1)]))
        precondition(modes["quickplay"]?.games == Tally(played:578,won:297,lost:281) && modes["quickplay"]?.heroes == ["juno":42800] && modes["quickplay"]?.heroGames == ["juno":Tally(played:1)])
        precondition(OverFast.profile(json(["summary":[:],"stats":NSNull()])) == nil)
        let heroes=OverFast.heroes(heroList)!
        precondition(heroes["ana"] == CareerHero(name:"Ana",portrait:URL(string:"https://x/ana.png"),role:.support) && heroes.count == 3)
        // OverFast's own wait for a player it couldn't find: its next check, its retry, or about 90 minutes.
        let now=Date(timeIntervalSince1970:1_800_000_000)
        precondition(OverFast.notFoundUntil(json(["next_check_at":1_800_005_400,"retry_after":5400]),now:now) == Date(timeIntervalSince1970:1_800_005_400))
        precondition(OverFast.notFoundUntil(json(["retry_after":600]),now:now) == now.addingTimeInterval(600))
        precondition(OverFast.notFoundUntil(Data(),now:now) == now.addingTimeInterval(5400))
    }

    static func lastSession() {
        let heroes=OverFast.heroes(heroList)!
        let before=["competitive":ModeStats(games:Tally(played:96,won:46,lost:50),heroes:["ana":10000,"reinhardt":5000],eliminations:1700,deaths:580,damage:700000,healing:590000,
                                            bests:["eliminations_most_in_game":40,"healing_done_most_in_game":16000]),
                    "quickplay":ModeStats(games:Tally(played:500,won:250,lost:250),heroes:["juno":40000],eliminations:9000,deaths:3000,damage:900000,healing:800000)]
        var after=before
        // Nothing played: no session to tell, unless the log saw matches outside the two modes.
        precondition(LastSession.between(before,after) == nil && LastSession.between([:],after) == nil)
        precondition(LastSession.between(before,after,matches:2) == LastSession(other:2))
        // Two Competitive games on Reinhardt and a Quick Play one on Juno, a record beaten, and the log saw four matches.
        after["competitive"]=ModeStats(games:Tally(played:98,won:47,lost:51),heroes:["ana":10100,"reinhardt":6200],eliminations:1730,deaths:590,damage:715000,healing:590500,
                                       bests:["eliminations_most_in_game":40,"healing_done_most_in_game":17000])
        after["quickplay"]=ModeStats(games:Tally(played:501,won:251,lost:250),heroes:["juno":40900],eliminations:9012,deaths:3004,damage:901000,healing:806000)
        let session=LastSession.between(before,after,heroes:heroes,matches:4)!
        precondition(session.competitive == Tally(played:2,won:1,lost:1) && session.quickplay == Tally(played:1,won:1,lost:0) && session.other == 1 && session.played == 4)
        precondition(session.hero == "reinhardt" && session.role == .tank,"the hero played longest over both modes; the role of Competitive's")
        precondition(session.eliminations == 42 && session.deaths == 14 && session.damage == 16000 && session.healing == 6500)
        precondition(session.best == CareerBest(key:"healing_done_most_in_game",value:17000))
        // A log that saw fewer matches than the profile missed some: it tells nothing about other modes.
        precondition(LastSession.between(before,after,heroes:heroes,matches:2)?.other == nil && LastSession.between(before,after,heroes:heroes)?.other == nil)
        // A rank that moved, the most; a role with no rank before moves nothing.
        let icon=URL(string:"https://x/r.png")!
        var moved=session
        moved.ranks(from:[CareerRank(role:.tank,division:"gold",tier:1,icon:icon),CareerRank(role:.open,division:"gold",tier:2,icon:icon)],
                    to:[CareerRank(role:.tank,division:"platinum",tier:5,icon:icon),CareerRank(role:.open,division:"gold",tier:4,icon:icon),CareerRank(role:.support,division:"gold",tier:1,icon:icon)])
        precondition(moved.rank?.role == .tank && moved.promoted)
        moved.ranks(from:[CareerRank(role:.open,division:"gold",tier:2,icon:icon)],to:[CareerRank(role:.open,division:"gold",tier:4,icon:icon)])
        precondition(moved.rank?.role == .open && !moved.promoted)
        moved.ranks(from:[],to:[CareerRank(role:.open,division:"gold",tier:4,icon:icon)])
        precondition(moved.rank == nil)
    }

    static func cardText() {
        let icon=URL(string:"https://x/r.png")!
        let tank=CareerRank(role:.tank,division:"emerald",tier:1,icon:icon),support=CareerRank(role:.support,division:"gold",tier:3,icon:icon)
        precondition(tank.label() == "Tank: Emerald 1" && CareerRank(role:.open,division:"novel",tier:2,icon:icon).label() == "6v6: Novel 2")
        precondition(tank.standing > support.standing && CareerRank(role:.damage,division:"gold",tier:1,icon:icon).standing > support.standing)
        // The rank shown: the role of the last session's competitive games, or else the best.
        precondition(CareerCard(ranks:[support,tank]).rank == tank)
        precondition(CareerCard(ranks:[support,tank],last:LastSession(competitive:Tally(played:3,won:2,lost:1),role:.support)).rank == support)
        precondition(CareerCard(ranks:[support,tank],last:LastSession(quickplay:Tally(played:3,won:2,lost:1),role:.support)).rank == tank)
        precondition(CareerCard().rank == nil)
        // The session's words.
        precondition(LastSession(competitive:Tally(played:3,won:2,lost:1),quickplay:Tally(played:1,won:1),other:1).summary == "Comp 2–1 · QP 1–0 · 1 other")
        precondition(LastSession(competitive:Tally(played:1,won:0,lost:1)).summary == "Comp 0–1")
        precondition(LastSession(other:3).summary == "3 matches" && LastSession(other:1).summary == "1 match")
        precondition(LastSession(competitive:Tally(played:1),eliminations:38,deaths:9,damage:4000,healing:14032).stats == "38 eliminations, 9 deaths, 14,032 healing")
        precondition(LastSession(competitive:Tally(played:1),eliminations:20,deaths:5,damage:12500,healing:0).stats == "20 eliminations, 5 deaths, 12,500 damage")
        precondition(LastSession(other:1).stats == nil)
    }

    /// Waits for one lookup's answer.
    static func look(_ profile:CareerProfile,_ tag:String,_ now:Date)->(CareerProfile.Status,CareerCard?) {
        let done=DispatchSemaphore(value:0)
        var result:(CareerProfile.Status,CareerCard?)=(.none,nil)
        profile.lookUp(tag:tag,now:now) { result=($0,$1);done.signal() }
        done.wait()
        return result
    }
    /// Waits until the profile's queue has done what was asked before.
    static func settle(_ profile:CareerProfile) { _ = profile.lastCode }

    static func lookUps() {
        let suite="career-profile-tests-\(getpid())"
        let store=UserDefaults(suiteName:suite)!
        defer { store.removePersistentDomain(forName:suite) }
        let fake=FakeOverFast()
        let profile=CareerProfile(base:URL(string:"https://overfast.test")!,store:store,fetch:fake.fetch)
        let t0=Date(timeIntervalSince1970:1_800_000_000)
        func at(_ minutes:Double)->Date { t0.addingTimeInterval(minutes*60) }
        let summaryPath="/players/Player-1234/summary",whole="/players/Player-1234",heroes="/heroes"
        func answer(updated:Int,played:Int,won:Int,tank:(String,Int)=("emerald",1)) {
            fake.answers[summaryPath]=fake.ok(summary(updated:updated,tank:tank))
            fake.answers[whole]=fake.ok(wholeProfile(competitive:Mode(played:played,won:won,lost:played-won,elims:played*10,deaths:played*3,healing:played*1000,heroes:["reinhardt":played*600]),
                                                     quickplay:Mode(played:10,won:5,lost:5,heroes:["juno":6000])))
        }
        fake.answers[heroes]=fake.ok(heroList)

        // A tag that isn't one is never sent.
        precondition(look(profile,"Player",t0).0 == .invalidTag && fake.requests.isEmpty)
        // The first look: the summary, the hero list (for the pictures), and the whole profile to tell the next session
        // by. No session yet.
        answer(updated:100,played:20,won:10)
        var (status,card)=look(profile,"Player#1234",t0)
        precondition(fake.requests == [summaryPath,heroes,whole],"\(fake.requests)")
        precondition(card?.heroes["reinhardt"]?.name == "Reinhardt","the heroes' names and portraits from the first look")
        precondition(status == .found(card?.rank) && card?.rank?.role == .tank && card?.last == nil && card?.identity?.name == "Player")
        precondition(card?.page?.absoluteString == "https://overwatch.blizzard.com/en-us/career/Player-1234/" && profile.lastCode == 200)
        // Within ten minutes nothing is asked: the same answer, from what was kept.
        (status,card)=look(profile,"Player#1234",at(9))
        precondition(fake.requests.count == 3 && card?.rank?.role == .tank)
        // Later, an unchanged profile asks the summary only.
        (status,card)=look(profile,"Player#1234",at(11))
        precondition(fake.requests.count == 4 && card?.last == nil)
        // The game ran twice meanwhile; the log saw 3 matches, then 1.
        profile.sessionEnded(PlayedRun(start:at(12),end:at(14),matches:3));profile.sessionEnded(PlayedRun(start:at(15),end:at(18),matches:1));settle(profile)
        precondition(profile.history.current.runs.map(\.matches) == [3,1],"every run goes into the history")
        // The profile changed (three Competitive games, up a tier): the session is told; the hero list is still fresh.
        answer(updated:200,played:23,won:12,tank:("diamond",5))
        (status,card)=look(profile,"Player#1234",at(22))
        precondition(Array(fake.requests.suffix(2)) == [summaryPath,whole] && fake.requests.count == 6,"\(fake.requests)")
        precondition(card?.last?.competitive == Tally(played:3,won:2,lost:1) && card?.last?.other == 1 && card?.last?.hero == "reinhardt",String(describing:card?.last))
        precondition(card?.hero?.name == "Reinhardt" && card?.last?.rank?.division == "diamond" && card?.last?.promoted == true)
        // The change goes into the history at the profile's own time (when the game closed), with the totals and heroes on the card.
        precondition(profile.history.current.changes.map(\.at) == [Date(timeIntervalSince1970:200)] && profile.history.current.changes[0].heroes == ["reinhardt":1800],"\(profile.history.current.changes)")
        precondition(profile.history.current.looked == at(22) && profile.history.current.seasonPeak.first?.division == "diamond")
        precondition(profile.history.current.changes[0].rankSteps == 1 && profile.history.current.changes[0].rankMoves == ["tank":1],"each role's move is kept with the change")
        precondition(card?.totals["competitive"]?.games.played == 23 && card?.heroes["reinhardt"]?.role == .tank)
        // Kept across restarts of the app: a new profile on the same settings knows it, and asks nothing yet.
        let again=CareerProfile(base:URL(string:"https://overfast.test")!,store:store,fetch:fake.fetch)
        (status,card)=look(again,"Player#1234",at(25))
        precondition(fake.requests.count == 6 && card?.last?.played == 4)
        // A session the log wasn't read in (Normal): the next session's other modes can't be told. The hero list is kept a week.
        again.sessionEnded(PlayedRun(start:at(26),end:at(30),matches:nil));again.sessionEnded(PlayedRun(start:at(31),end:at(35),matches:5));settle(again)
        answer(updated:300,played:24,won:12)
        (status,card)=look(again,"Player#1234",at(40))
        precondition(fake.requests.count == 8 && card?.last?.competitive.played == 1 && card?.last?.other == nil)

        // A profile OverFast couldn't find: its wait is kept, and nothing is asked before it.
        fake.answers[summaryPath]=CareerProfile.Response(status:404,headers:[:],body:json(["error":"Player not found","retry_after":5400]))
        (status,card)=look(profile,"Player#1234",at(60))
        precondition(status == .notPublic(until:at(150)) && fake.requests.count == 9)
        (status,_)=look(profile,"Player#1234",at(149))
        precondition(status == .notPublic(until:at(150)) && fake.requests.count == 9)
        // Too many asks (OverFast's or Blizzard's): its Retry-After, and nothing before it.
        fake.answers[summaryPath]=CareerProfile.Response(status:503,headers:["Retry-After":"3600"],body:Data())
        (status,_)=look(profile,"Player#1234",at(151))
        precondition(status == .unavailable && fake.requests.count == 10)
        (status,card)=look(profile,"Player#1234",at(210))
        precondition(status == .unavailable && fake.requests.count == 10 && card?.rank?.role == .tank,"what was kept still shows")
        // A server error, or no answer: asked again at the next lookup after ten minutes, never in a loop.
        fake.answers[summaryPath]=CareerProfile.Response(status:500,headers:[:],body:Data())
        (status,_)=look(profile,"Player#1234",at(212))
        precondition(status == .unavailable && fake.requests.count == 11 && profile.lastCode == 500)
        fake.answers[summaryPath]=nil
        (status,_)=look(profile,"Player#1234",at(223))
        precondition(status == .unavailable && fake.requests.count == 12 && profile.lastCode == nil)
        // Another BattleTag starts over. A whole profile that didn't come leaves the totals to be taken next time,
        // and the summary still shows.
        fake.answers["/players/Other-5678/summary"]=fake.ok(summary(updated:300,tank:nil,open:nil))
        profile.forget();settle(profile)
        precondition(profile.history.current.changes.isEmpty && profile.history.current.season == nil && profile.history.current.runs.count == 2,"this Mac's runs stay")
        (status,card)=look(profile,"Other#5678",at(224))
        precondition(status == .found(nil) && card?.ranks.isEmpty == true && card?.last == nil && fake.requests.count == 15,"its own hero list: \(fake.requests.count)")
        fake.answers["/players/Other-5678"]=fake.ok(wholeProfile(competitive:Mode(played:1,won:1),quickplay:Mode(played:1,won:1)))
        (status,card)=look(profile,"Other#5678",at(235))
        precondition(fake.requests.count == 17 && card?.last == nil,"the totals are taken now, there being none before")
        // Erased as Recall quits: the profile and the history go at once, without waiting on the profile's queue.
        precondition(store.object(forKey:"careerProfile") != nil && profile.history.current != CareerHistory())
        profile.eraseNow()
        precondition(store.object(forKey:"careerProfile") == nil && profile.history.current == CareerHistory())
    }

    static func history() {
        var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(identifier:"UTC")!;calendar.firstWeekday=2
        /// October 2026, in UTC: the 26th is a Monday.
        func day(_ date:Int,_ hour:Double)->Date { calendar.date(from:DateComponents(year:2026,month:10,day:date))!.addingTimeInterval(hour*3600) }
        let icon=URL(string:"https://x/r.png")!
        func rank(_ role:CareerRank.Role,_ division:String,_ tier:Int)->CareerRank { CareerRank(role:role,division:division,tier:tier,icon:icon) }
        func change(_ at:Date,season:Int?=25,comp:Tally=Tally(),quick:Tally=Tally(),other:Int?=0,heroes:[String:Int]=[:])->ProfileChange {
            var made=ProfileChange(at:at,season:season,session:LastSession(competitive:comp,quickplay:quick,other:other),before:[:],after:[:])
            made.heroes=heroes
            return made
        }

        // Divisions moved: Gold 1 to Platinum 5 is one, Gold 3 to Gold 1 two, and down is negative.
        precondition(rank(.tank,"platinum",5).steps(from:rank(.tank,"gold",1)) == 1 && rank(.tank,"gold",1).steps(from:rank(.tank,"gold",3)) == 2)
        precondition(rank(.tank,"gold",1).steps(from:rank(.tank,"platinum",5)) == -1)
        // A change between two looks' totals: each hero's time, and the highest milestone passed (10, 25, 50, then every hundred).
        let before=["competitive":ModeStats(heroes:["juno":34200,"ana":342000]),"quickplay":ModeStats(heroes:["reinhardt":3600*24])]
        let after=["competitive":ModeStats(heroes:["juno":36720,"ana":363600]),"quickplay":ModeStats(heroes:["reinhardt":3600*51])]
        let made=ProfileChange(at:day(26,22),season:25,session:LastSession(),before:before,after:after)
        precondition(made.heroes == ["juno":2520,"ana":21600,"reinhardt":97200] && made.milestone == ProfileChange.Milestone(hero:"ana",hours:100),"\(made)")
        precondition(ProfileChange(at:day(26,22),season:25,session:LastSession(),before:["quickplay":before["quickplay"]!],after:["quickplay":after["quickplay"]!]).milestone?.hours == 50)
        precondition(ProfileChange(at:day(26,22),season:25,session:LastSession(),before:after,after:after).milestone == nil && [10,25,50,100,300].allSatisfy(ProfileChange.isMilestone) && !ProfileChange.isMilestone(150))

        // The season's first and best ranks, and a change that set a new best of the season.
        var history=CareerHistory()
        history.looked(at:day(20,18),season:25,ranks:[rank(.tank,"gold",2)],change:nil)
        precondition(history.first(.tank)?.tier == 2 && history.peak(.tank)?.tier == 2 && !history.seasonFollows && history.seasonSeen == day(20,18))
        history.looked(at:day(24,23),season:25,ranks:[rank(.tank,"platinum",5),rank(.support,"gold",4)],change:change(day(24,21),comp:Tally(played:3,won:3)))
        precondition(history.changes.last?.seasonHigh == rank(.tank,"platinum",5) && history.peak(.tank)?.division == "platinum" && history.first(.support)?.tier == 4)
        history.looked(at:day(26,23),season:25,ranks:[rank(.tank,"gold",1),rank(.support,"gold",4)],change:change(day(26,22),comp:Tally(played:3,won:2,lost:1),heroes:["juno":3000,"ana":600]))
        precondition(history.changes.last?.seasonHigh == nil && history.peak(.tank)?.division == "platinum" && history.first(.tank)?.division == "gold")
        // A Monday night session first seen on Wednesday is Monday's: the profile's time dates it, not the look.
        history.looked(at:day(28,19),season:25,ranks:[rank(.tank,"gold",1)],change:change(day(28,13),comp:Tally(played:1,won:1),quick:Tally(played:2,won:1,lost:1),other:nil,heroes:["ana":2000]))

        // The periods (now: Wednesday the 28th, 20:00; the week starts on Monday): the last, today, this week, this season.
        let now=day(28,20)
        precondition(history.session(.last,now:now,calendar:calendar)?.competitive == Tally(played:1,won:1))
        precondition(history.session(.today,now:now,calendar:calendar)?.quickplay == Tally(played:2,won:1,lost:1))
        precondition(history.session(.today,now:day(26,12),calendar:calendar)?.competitive == Tally(played:3,won:2,lost:1),"Monday's, seen on Wednesday")
        let week=history.session(.week,now:now,calendar:calendar)!
        precondition(week.competitive == Tally(played:4,won:3,lost:1) && week.quickplay == Tally(played:2,won:1,lost:1) && week.other == nil,"\(week)")
        precondition(week.hero == "juno","the hero played longest over the week's changes")
        precondition(history.session(.season,now:now,calendar:calendar)?.competitive == Tally(played:7,won:6,lost:1))
        precondition(history.session(.today,now:day(29,12),calendar:calendar) == nil && history.session(.all,now:now,calendar:calendar) == nil)

        // A new season: the climb starts over, and its first look is news.
        var next=history
        next.looked(at:day(30,18),season:26,ranks:[rank(.tank,"silver",3)],change:change(day(30,17),season:26,comp:Tally(played:1,won:1)))
        precondition(next.seasonFollows && next.first(.tank)?.division == "silver" && next.changes.last?.seasonHigh == nil)
        precondition(next.session(.season,now:day(30,20),calendar:calendar)?.competitive == Tally(played:1,won:1))
        precondition(next.newSeason(before:day(30,20)) == 26 && history.newSeason(before:now) == nil,"the first season Recall sees is no news")
        next.ran(PlayedRun(start:day(30,19),end:day(30,21),matches:2))
        precondition(next.newSeason(before:day(31,20)) == nil,"once a game has been played in it")

        // Tonight: nights in a row (a game at half past midnight is the night before's), time this week, a comeback.
        var runs=CareerHistory()
        for (start,end) in [(day(19,20),day(19,23)),(day(26,21),day(26,23)),(day(27,23.5),day(28,1)),(day(29,0.5),day(29,2))] { runs.ran(PlayedRun(start:start,end:end,matches:2)) }
        precondition(runs.nightsInARow(now:day(29,21),playing:true,calendar:calendar) == 4,"Monday, Tuesday, Wednesday (at 00:30) and tonight")
        precondition(runs.nightsInARow(now:day(29,21),playing:false,calendar:calendar) == 0 && runs.nightsInARow(now:day(29,1),playing:true,calendar:calendar) == 3)
        precondition(runs.playedThisWeek(now:day(29,21),current:day(29,20),calendar:calendar) == 6*3600,"2h + 1.5h + 1.5h this week, and the hour going on")
        var span=CareerHistory();span.ran(PlayedRun(start:day(25,23),end:day(26,1),matches:1))
        precondition(span.playedThisWeek(now:day(26,12),current:nil,calendar:calendar) == 3600,"only the part inside this week")
        precondition(runs.away(before:day(23,20)) == 4*24*3600-3*3600 && runs.away(before:day(27,20)) == nil && CareerHistory().away(before:now) == nil)
        // A change is news until a game opens after the one it came from.
        var news=history
        precondition(news.news(before:day(28,21))?.at == day(28,13))
        news.ran(PlayedRun(start:day(28,14),end:day(28,16),matches:1))
        precondition(news.news(before:day(28,21)) == nil && news.news(before:day(28,14)) != nil)
        // The rank is not shown once matches were played after a look more than two days old; a break with none keeps it.
        var stale=CareerHistory();stale.looked(at:day(20,12),season:25,ranks:[rank(.tank,"gold",1)],change:nil)
        precondition(!stale.rankStale(now:day(23,12)))
        stale.ran(PlayedRun(start:day(21,20),end:day(21,21),matches:0))
        precondition(!stale.rankStale(now:day(23,12)),"a run with no match changes nothing")
        stale.ran(PlayedRun(start:day(22,20),end:day(22,21),matches:3))
        precondition(stale.rankStale(now:day(23,12)) && !stale.rankStale(now:day(22,11)))
        // Another BattleTag: the profile's history goes, this Mac's runs stay. Old runs and changes leave after about a year.
        var other=history;other.ran(PlayedRun(start:day(1,20),end:day(1,21),matches:1));other.forgetProfile()
        precondition(other.changes.isEmpty && other.seasonPeak.isEmpty && other.looked == nil && other.runs.count == 1)
        other.ran(PlayedRun(start:day(1,20).addingTimeInterval(CareerHistory.kept+3600),end:day(1,21).addingTimeInterval(CareerHistory.kept+3600),matches:1))
        precondition(other.runs.count == 1)
        // Export: everything kept, oldest first, a run's times and matches, a change's games, hero, rank and divisions.
        var export=CareerHistory()
        var moved=change(day(27,22),comp:Tally(played:3,won:2,lost:1),quick:Tally(played:2,won:1,lost:1),other:1)
        moved.session.hero="ana";moved.session.rank=rank(.support,"gold",1);moved.rankSteps=2
        export.changes=[moved]
        export.ran(PlayedRun(start:day(27,20),end:day(27,21.5),matches:5));export.ran(PlayedRun(start:day(28,20),end:day(28,21),matches:nil))
        let csv=export.csv(heroes:["ana":CareerHero(name:"Ana, \"the\" sniper",portrait:nil,role:.support)],timeZone:calendar.timeZone)
        precondition(csv.hasPrefix("\u{FEFF}") && csv.hasSuffix("\r\n"))
        let rows=csv.dropFirst().split(separator:"\r\n").map(String.init)
        precondition(rows == ["Started,Ended,What,Matches,Competitive,Quick Play,Hero,Rank,Divisions",
                              "2026-10-27 20:00,2026-10-27 21:30,Played on this Mac,5,,,,,",
                              ",2026-10-27 22:00,Profile change,6,2–1,1–1,\"Ana, \"\"the\"\" sniper\",Support: Gold 1,+2",
                              "2026-10-28 20:00,2026-10-28 21:00,Played on this Mac,,,,,,"],"\(rows)")
        // A name that a spreadsheet would work out as a formula is kept as text.
        let formula=export.csv(heroes:["ana":CareerHero(name:"=HYPERLINK(\"x\")",portrait:nil,role:.support)],timeZone:calendar.timeZone)
        precondition(formula.contains(",\"'=HYPERLINK(\"\"x\"\")\",Support: Gold 1,"),formula)
    }

    static func historyStore() {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("career-history-tests-\(getpid())")
        defer { try? FileManager.default.removeItem(at:folder) }
        let file=folder.appendingPathComponent("org.overwatch2mac.launcher/career-history.json")
        let start=Date(timeIntervalSince1970:1_800_000_000)
        let store=CareerHistoryStore(url:file)
        precondition(store.current == CareerHistory() && !FileManager.default.fileExists(atPath:file.path))
        store.update { $0.ran(PlayedRun(start:start,end:start.addingTimeInterval(3600),matches:4)) }
        // Written as plain JSON (dates as text), and read back by the next launch.
        let text=String(decoding:try! Data(contentsOf:file),as:UTF8.self)
        precondition(text.contains("2027-01-15T08:00:00Z"),text)
        precondition(CareerHistoryStore(url:file).current.runs == [PlayedRun(start:start,end:start.addingTimeInterval(3600),matches:4)])
        // A file that isn't one is a fresh start.
        try! Data("not json".utf8).write(to:file)
        precondition(CareerHistoryStore(url:file).current == CareerHistory())
        // Erase: the file goes.
        store.erase()
        precondition(store.current == CareerHistory() && !FileManager.default.fileExists(atPath:file.path))
        // In memory only (the tests, a preview): nothing is written.
        let memory=CareerHistoryStore(url:nil)
        memory.update { $0.ran(PlayedRun(start:start,end:start,matches:nil)) }
        precondition(memory.current.runs.count == 1)
    }

    static func servers() {
        precondition(OverFast.server("https://overfast.example.com")?.absoluteString == "https://overfast.example.com")
        precondition(OverFast.server(" http://localhost:8000/ ")?.host == "localhost" && OverFast.server("http://127.0.0.1:8080") != nil)
        // The BattleTag never travels unencrypted to another machine, nor to something that isn't a server.
        for bad in ["http://overfast.example.com","ftp://x","overfast.example.com","https://x/?q=1","","https://"] { precondition(OverFast.server(bad) == nil,bad) }
    }
}
