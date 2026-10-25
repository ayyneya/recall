import Foundation

// CareerProfile.swift: the BattleTag, OverFast's answers, the last session (with the log's match count),
// when the profile is looked up (and when it is not), and the profile on the Discord card. OverFast is a
// fake that counts what is asked; the answers are shaped like OverFast's own (October 25), with made-up
// players.
// Build and run:
//   swiftc -O -target arm64-apple-macos26.5 -parse-as-library app/Sources/Brand.swift app/Sources/Localization.swift \
//     app/Sources/DiscordPresence.swift app/Sources/CareerProfile.swift tests/CareerProfileTests.swift -o runtime/phase-3/career-profile-tests
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
        battleTags();answers();lastSession();cardText();lookUps();onTheCard()
        print("PASS: BattleTags, OverFast's answers, the last session, when the profile is looked up, and the profile on the card")
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
        precondition(read.identity == CareerIdentity(name:"Player",title:"Shieldbreaker",endorsement:4,avatar:URL(string:"https://x/avatar.png")))
        // A profile with no competitive rank, or a rank whose icon isn't https, shows none.
        precondition(OverFast.summary(json(["competitive":NSNull(),"last_updated_at":5]))!.ranks.isEmpty)
        var plain=try! JSONSerialization.jsonObject(with:summary(updated:5)) as! [String:Any]
        var competitive=plain["competitive"] as! [String:Any],pc=competitive["pc"] as! [String:Any],tank=pc["tank"] as! [String:Any]
        tank["rank_icon"]="http://example.com/rank.png";pc["tank"]=tank;competitive["pc"]=pc;plain["competitive"]=competitive;plain["avatar"]="http://x/a.png"
        let insecure=OverFast.summary(json(plain))!
        precondition(insecure.ranks.map(\.role) == [.open] && insecure.identity?.avatar == nil)
        precondition(OverFast.summary(json(["error":"Player not found"])) == nil && OverFast.summary(Data("<html>".utf8)) == nil)
        // The whole profile: each mode's totals, records and heroes' time.
        let modes=OverFast.profile(wholeProfile(competitive:Mode(played:98,won:45,lost:52,elims:1760,deaths:588,damage:739031,healing:594755,bests:["eliminations_most_in_game":46],heroes:["ana":10615,"juno":12822]),
                                                quickplay:Mode(played:578,won:297,lost:281,heroes:["juno":42800])))!
        precondition(modes["competitive"] == ModeStats(games:Tally(played:98,won:45,lost:52),heroes:["ana":10615,"juno":12822],eliminations:1760,deaths:588,damage:739031,healing:594755,bests:["eliminations_most_in_game":46]))
        precondition(modes["quickplay"]?.games == Tally(played:578,won:297,lost:281) && modes["quickplay"]?.heroes == ["juno":42800])
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
        precondition(LastSession(rank:tank,promoted:true).rankNews == "⬆️ Tank: up to Emerald 1" && LastSession(rank:support).rankNews == "⬇️ Support: down to Gold 3")
        precondition(LastSession(best:CareerBest(key:"eliminations_most_in_game",value:46)).bestNews == "🏅 New best: 46 eliminations in a game")
        precondition(LastSession(best:CareerBest(key:"kill_streak_best",value:12)).bestNews == "🏅 New best: a kill streak of 12" && LastSession(best:CareerBest(key:"unknown",value:1)).bestNews == nil)
        // All of it on the card's lines: the rank shown first, then the others, a line each with its role's sign
        // (this season's only); the hero, or the player; the player's name for line 1.
        let session=LastSession(competitive:Tally(played:2,won:1,lost:1),other:1,role:.support,eliminations:38,deaths:9,damage:4000,healing:14032,best:CareerBest(key:"eliminations_most_in_game",value:46))
        let card=CareerCard(identity:CareerIdentity(name:"Player",title:"Shieldbreaker",endorsement:4,avatar:URL(string:"https://x/avatar.png")),
                            ranks:[tank,support],season:25,last:session,hero:CareerHero(name:"Ana",portrait:URL(string:"https://x/ana.png"),role:.support),
                            page:URL(string:"https://overwatch.blizzard.com/en-us/career/Player-1234/"))
        let lines=CareerLines(card)
        precondition(lines.rankIcon == icon && lines.ranks == "➕ Support: Gold 3 · 🛡️ Tank: Emerald 1" && lines.name == "Player")
        precondition(lines.picture == URL(string:"https://x/ana.png") && lines.pictureText == "Most played last session: Ana · All heroes: 38 eliminations, 9 deaths, 14,032 healing")
        precondition(lines.news == ["🏅 New best: 46 eliminations in a game","🎮 Comp 1–1 · 1 other"])
        precondition(lines.buttonLabel == "Career Profile" && lines.page?.absoluteString == "https://overwatch.blizzard.com/en-us/career/Player-1234/")
        // No session yet: the player's own icon, name and title (the endorsement level isn't for the card).
        let first=CareerLines(CareerCard(identity:card.identity,ranks:[tank],season:25))
        precondition(first.picture == URL(string:"https://x/avatar.png") && first.pictureText == "Player · Shieldbreaker" && first.news.isEmpty)
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
        // The first look: the summary, and the whole profile to tell the next session by. No session yet.
        answer(updated:100,played:20,won:10)
        var (status,card)=look(profile,"Player#1234",t0)
        precondition(fake.requests == [summaryPath,whole],"\(fake.requests)")
        precondition(status == .found(card?.rank) && card?.rank?.role == .tank && card?.last == nil && card?.identity?.name == "Player")
        precondition(card?.page?.absoluteString == "https://overwatch.blizzard.com/en-us/career/Player-1234/" && profile.lastCode == 200)
        // Within ten minutes nothing is asked: the same answer, from what was kept.
        (status,card)=look(profile,"Player#1234",at(9))
        precondition(fake.requests.count == 2 && card?.rank?.role == .tank)
        // Later, an unchanged profile asks the summary only.
        (status,card)=look(profile,"Player#1234",at(11))
        precondition(fake.requests.count == 3 && card?.last == nil)
        // The game ran twice meanwhile; the log saw 3 matches, then 1.
        profile.sessionEnded(matches:3);profile.sessionEnded(matches:1);settle(profile)
        // The profile changed (three Competitive games, up a tier): the session is told, with the hero list asked for once.
        answer(updated:200,played:23,won:12,tank:("diamond",5))
        (status,card)=look(profile,"Player#1234",at(22))
        precondition(Array(fake.requests.suffix(3)) == [summaryPath,whole,heroes],"\(fake.requests)")
        precondition(card?.last?.competitive == Tally(played:3,won:2,lost:1) && card?.last?.other == 1 && card?.last?.hero == "reinhardt",String(describing:card?.last))
        precondition(card?.hero?.name == "Reinhardt" && card?.last?.rank?.division == "diamond" && card?.last?.promoted == true)
        // Kept across restarts of the app: a new profile on the same settings knows it, and asks nothing yet.
        let again=CareerProfile(base:URL(string:"https://overfast.test")!,store:store,fetch:fake.fetch)
        (status,card)=look(again,"Player#1234",at(25))
        precondition(fake.requests.count == 6 && card?.last?.played == 4)
        // A session the log wasn't read in (Normal): the next session's other modes can't be told. The hero list is kept a week.
        again.sessionEnded(matches:nil);again.sessionEnded(matches:5);settle(again)
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
        profile.forget()
        (status,card)=look(profile,"Other#5678",at(224))
        precondition(status == .found(nil) && card?.ranks.isEmpty == true && card?.last == nil && fake.requests.count == 14)
        fake.answers["/players/Other-5678"]=fake.ok(wholeProfile(competitive:Mode(played:1,won:1),quickplay:Mode(played:1,won:1)))
        (status,card)=look(profile,"Other#5678",at(235))
        precondition(fake.requests.count == 16 && card?.last == nil,"the totals are taken now, there being none before")
    }

    static func onTheCard() {
        let texts=PresenceTexts(menu:"In Menus",match:"In Match",voice:"In Group Voice",badge:"Playing on Mac with Recall")
        let launched=Date(timeIntervalSince1970:1_792_000_000)
        let career=CareerLines(rankIcon:URL(string:"https://x/emerald.png"),ranks:"🛡️ Tank: Emerald 1 · 👥 6v6: Emerald 1",name:"Player",picture:URL(string:"https://x/ana.png"),
                               pictureText:"Most played last session: Ana · All heroes: 38 eliminations, 9 deaths, 14,032 healing",
                               news:["Tank: up to Emerald 1","New best: 46 eliminations in a game","Comp 2–1"],
                               buttonLabel:"Career Profile",page:URL(string:"https://overwatch.blizzard.com/en-us/career/Player-1234/"))
        func card(_ place:PresenceState,_ level:DiscordPresenceLevel,voice:GroupVoice?=nil,competitive:Bool?=nil)->[String:Any] {
            PresenceCard.activity(facts:PresenceFacts(place:place,voice:voice,competitive:competitive,career:career),level:level,launched:launched,texts:texts)
        }
        func assets(_ card:[String:Any])->[String:String] { card["assets"] as? [String:String] ?? [:] }
        // Menus at Full: the rank in the badge's place with all ranks in its hover; the hero as the large picture;
        // line 2 the first piece of news (a rank that moved comes before a record and the session); the button.
        let menu=card(.menu,.full)
        precondition(assets(menu)["small_image"] == "https://x/emerald.png" && assets(menu)["small_text"] == "🛡️ Tank: Emerald 1 · 👥 6v6: Emerald 1 · Playing on Mac with Recall")
        precondition(assets(menu)["large_image"] == "https://x/ana.png" && assets(menu)["large_text"] == "Most played last session: Ana · All heroes: 38 eliminations, 9 deaths, 14,032 healing")
        precondition(menu["details"] as? String == "Player · In Menus" && menu["state"] as? String == "Tank: up to Emerald 1")
        precondition((menu["buttons"] as? [[String:String]]) == [["label":"Career Profile","url":"https://overwatch.blizzard.com/en-us/career/Player-1234/"]])
        // The group's voice comes first.
        precondition(card(.menu,.full,voice:GroupVoice(count:2,channel:"P",party:"p"))["state"] as? String == "In Group Voice")
        // In a match: nothing more on line 2 (the log can't tell its mode, the profile not its result yet), the badge,
        // no picture (it would read as the hero being played now).
        let match=card(.match(since:launched),.full)
        precondition(match["state"] == nil && assets(match)["small_image"] == Brand.discordBadge.absoluteString && assets(match)["large_image"] == nil)
        precondition(match["buttons"] != nil,"the profile's button is no claim about the match")
        // A source that knows the match is competitive (a screen reader, one day) puts the rank on it.
        precondition(assets(card(.match(since:launched),.full,competitive:true))["small_image"] == "https://x/emerald.png")
        precondition(assets(card(.match(since:launched),.full,competitive:false))["small_image"] == Brand.discordBadge.absoluteString)
        // Where the log can't say where the player is: neither the profile's news nor its pictures.
        let unknown=card(.unknown,.full)
        precondition(unknown["details"] as? String == "Player" && card(.match(since:launched),.full)["details"] as? String == "Player · In Match")
        precondition(unknown["state"] == nil && assets(unknown)["large_image"] == nil && assets(unknown)["small_image"] == Brand.discordBadge.absoluteString)
        // Live and Normal show nothing from the profile.
        let live=card(.match(since:launched),.live)
        precondition(live["state"] == nil && live["buttons"] == nil && card(.menu,.live)["state"] == nil && assets(card(.menu,.live))["large_image"] == nil)
        precondition(card(.menu,.normal)["assets"] == nil)
        // Full with nothing found yet is Live.
        let none=PresenceCard.activity(facts:PresenceFacts(place:.menu),level:.full,launched:launched,texts:texts)
        precondition(assets(none)["small_image"] == Brand.discordBadge.absoluteString && none["state"] == nil && none["buttons"] == nil)
        // Discord's limit on a line or hover text: 128 characters.
        let long=PresenceCard.activity(facts:PresenceFacts(place:.menu,career:CareerLines(rankIcon:URL(string:"https://x/r.png"),ranks:String(repeating:"Tank: Emerald 1 · ",count:12))),
                                       level:.full,launched:launched,texts:texts)
        precondition(assets(long)["small_text"]!.count == 128 && JSONSerialization.isValidJSONObject(menu))
    }
}
