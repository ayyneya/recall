import Foundation

// DiscordCardTemplate.swift and DiscordCardCatalog.swift: the card's design (Full's Default and the
// ready-made ones), each part's words from the profile, the history and the log, what shows in a match and
// in the group's voice, and the lists taking turns on one clock. A made-up player on a fixed calendar
// (October 2026 in UTC; the 26th is a Monday).
// Build and run:
//   swiftc -O -target arm64-apple-macos26.5 -parse-as-library app/Sources/Brand.swift app/Sources/Localization.swift \
//     app/Sources/DiscordPresence.swift app/Sources/CareerProfile.swift app/Sources/CareerHistory.swift \
//     app/Sources/DiscordCardTemplate.swift app/Sources/DiscordCardCatalog.swift app/Sources/DiscordCardCode.swift tests/DiscordCardTests.swift \
//     -o runtime/phase-3/discord-card-tests
//   runtime/phase-3/discord-card-tests

@main struct DiscordCardTests {
    static var calendar:Calendar={ var made=Calendar(identifier:.gregorian);made.timeZone=TimeZone(identifier:"UTC")!;made.firstWeekday=2;return made }()
    static func day(_ date:Int,_ hour:Double)->Date { calendar.date(from:DateComponents(year:2026,month:10,day:date))!.addingTimeInterval(hour*3600) }
    static let texts=PresenceTexts(menu:"In Menus",match:"In Match",voice:"In Group Voice",badge:"Playing on Mac with Recall")
    static func rank(_ role:CareerRank.Role,_ division:String,_ tier:Int,_ icon:String)->CareerRank { CareerRank(role:role,division:division,tier:tier,icon:URL(string:"https://x/\(icon).png")!) }
    static let tank=rank(.tank,"emerald",1,"emerald"),sixes=rank(.open,"emerald",1,"emerald6")

    /// pyxee: Support mostly (Juno, Ana), 42 hours in all; Tank up a division in today's session, with a new best.
    static func profile()->CareerCard {
        let heroes=["juno":CareerHero(name:"Juno",portrait:URL(string:"https://x/juno.png"),role:.support),"ana":CareerHero(name:"Ana",portrait:URL(string:"https://x/ana.png"),role:.support),
                    "reinhardt":CareerHero(name:"Reinhardt",portrait:URL(string:"https://x/rein.png"),role:.tank),"widowmaker":CareerHero(name:"Widowmaker",portrait:URL(string:"https://x/widow.png"),role:.damage),
                    "wuyang":CareerHero(name:"Wuyang",portrait:URL(string:"https://x/wuyang.png"),role:.support)]
        let competitive=ModeStats(games:Tally(played:98,won:46,lost:52),heroes:["reinhardt":25560,"widowmaker":21600,"ana":32040],
                                  bests:["eliminations_most_in_game":53,"all_damage_done_most_in_game":39448,"healing_done_most_in_game":16163,"kill_streak_best":27,"multikill_best":6])
        let quickplay=ModeStats(games:Tally(played:578,won:297,lost:281),heroes:["juno":55800,"wuyang":18000],bests:["eliminations_most_in_game":41],heroGames:["juno":Tally(played:40,won:22,lost:18)])
        return CareerCard(identity:CareerIdentity(name:"pyxee",title:":3",endorsement:5,avatar:URL(string:"https://x/avatar.png")),ranks:[tank,sixes],season:25,last:today().session,
                          hero:heroes["widowmaker"],page:URL(string:"https://overwatch.blizzard.com/en-us/career/pyxee-11248/"),totals:["competitive":competitive,"quickplay":quickplay],heroes:heroes)
    }
    /// Today's session, played this afternoon: Tank up a division, a new best, Juno past ten hours.
    static func today()->ProfileChange {
        var change=ProfileChange(at:day(28,13),season:25,session:LastSession(competitive:Tally(played:1,won:1),other:1,hero:"widowmaker",role:.tank,eliminations:31,deaths:7,damage:10623,
                                                                            best:CareerBest(key:"eliminations_most_in_game",value:53),rank:tank,promoted:true),before:[:],after:[:])
        change.rankSteps=1;change.seasonHigh=tank;change.milestone=ProfileChange.Milestone(hero:"juno",hours:10)
        return change
    }
    static func history()->CareerHistory {
        var history=CareerHistory()
        var monday=ProfileChange(at:day(26,22),season:25,session:LastSession(competitive:Tally(played:3,won:2,lost:1),other:0),before:[:],after:[:]);monday.heroes=["juno":3000]
        history.changes=[monday,today()]
        history.season=25;history.seasonSeen=day(20,18);history.seasonFirst=[rank(.tank,"gold",2,"gold")];history.seasonPeak=[tank,sixes];history.looked=day(28,19)
        history.runs=[PlayedRun(start:day(26,21),end:day(26,23),matches:3),PlayedRun(start:day(27,21),end:day(27,23),matches:2)]
        return history
    }
    /// Wednesday evening: the game opened at 19:00, it's 20:00 now, in the menus after two matches.
    static func inputs(_ place:PresenceState = .menu,profile:CareerCard?=profile(),history:CareerHistory=history(),voice:GroupVoice?=nil,matches:Int=2,now:Date=day(28,20))->CardInputs {
        CardInputs(place:place,voice:voice,profile:profile,history:history,tagName:"pyxee",launched:day(28,19),matches:matches,now:now,texts:texts,calendar:calendar)
    }
    static func text(_ piece:CardPiece,_ i:CardInputs=inputs(),rank:RankChoice = .lastPlayed)->String? { piece.text(i,rank:rank) }
    static func assets(_ card:[String:Any])->[String:String] { card["assets"] as? [String:String] ?? [:] }

    static func main() {
        words();defaultCard();inAMatch();groupVoice();turns();designs();codes()
        print("PASS: each piece's words, Full's card in the menus, in a match and in the group's voice, the lists taking turns, the designs, and their codes")
    }

    static func words() {
        // Rank: how the last session moved it (↑ one division; – the same), the season's climb and peak, every role.
        precondition(text(.rank(.current)) == "Tank ↑ Emerald 1" && text(.rank(.current),rank:.role(.open)) == "6v6 – Emerald 1")
        precondition(text(.rank(.climb)) == "Gold 2 → Emerald 1 this season" && text(.rank(.peak)) == "Season peak: Emerald 1")
        precondition(text(.rank(.all)) == "Tank ↑ Emerald 1 · 6v6 – Emerald 1" && text(.rank(.change)) == "Tank ↑ Emerald 1")
        precondition(text(.rank(.current),rank:.role(.support)) == nil && text(.rank(.climb),rank:.role(.open)) == nil,"no rank in that role; no climb without a first rank")
        var two=today();two.rankSteps=2
        var moved=history();moved.changes[1]=two
        precondition(text(.rank(.current),inputs(history:moved)) == "Tank ↟ Emerald 1")
        two.rankSteps = -1;two.session.promoted=false;moved.changes[1]=two
        precondition(text(.rank(.current),inputs(history:moved)) == "Tank ↓ Emerald 1")
        // Records: each period with its tag, the last session's other modes, both modes, a win rate; none with no games.
        precondition(text(.record(.last,.competitive,winRate:false)) == "Last · Comp 1–0 · 1 other" && text(.record(.today,.competitive,winRate:false)) == "Today · Comp 1–0")
        precondition(text(.record(.week,.competitive,winRate:false)) == "Week · Comp 3–1" && text(.record(.season,.competitive,winRate:false)) == "Season · Comp 3–1")
        precondition(text(.record(.all,.competitive,winRate:false)) == "All · Comp 46–52" && text(.record(.all,.both,winRate:false)) == "All · Comp 46–52 · QP 297–281")
        precondition(text(.record(.week,.competitive,winRate:true)) == "Week · Comp 3–1 · 75%" && text(.record(.week,.quickPlay,winRate:false)) == nil)
        precondition(text(.record(.today,.competitive,winRate:false),inputs(now:day(29,20))) == nil,"nothing yet today")
        // Heroes: "main" is earned by the most-played only; hours, role, win rate.
        precondition(text(.hero(nil,.main)) == "Juno main" && text(.hero("ana",.main)) == nil && text(.hero("ana",.hours)) == "Ana · 8h")
        precondition(text(.hero(nil,.role)) == "Support · Juno 15h" && text(.hero(nil,.winRate)) == "Juno · 55% wins" && text(.hero("ana",.winRate)) == nil)
        // Bests, over both modes; the new one only while it is news.
        precondition(text(.best(.eliminations)) == "Best: 53 elims in a game" && text(.best(.damage)) == "Best: 39,448 damage" && text(.best(.healing)) == "Best: 16,163 healing")
        precondition(text(.best(.killStreak)) == "Best: 27 kill streak" && text(.best(.multikill)) == "Best: 6-kill multikill" && text(.best(.new)) == "★ New best: 53 elims")
        // Tonight: from the log and the runs, no BattleTag needed.
        precondition(text(.tonight(.matches)) == "2 matches tonight" && text(.tonight(.matches),inputs(matches:1)) == "1 match tonight" && text(.tonight(.matches),inputs(matches:0)) == nil)
        precondition(text(.tonight(.matches),inputs(.match(since:day(28,19.9)),matches:3)) == "Match 3 tonight")
        precondition(text(.tonight(.nights),inputs(profile:nil)) == "3rd night in a row" && text(.tonight(.week),inputs(profile:nil)) == "Week · 5h played")
        // Titles earned from the hours (Support is 57%; no role under 20% for flex; Juno 36%; 42 hours).
        precondition(text(.title(.endorsement)) == "Endorsement 5" && text(.title(.hours)) == "42h in Overwatch" && text(.title(.roleMain)) == "Support main")
        precondition(text(.title(.flex)) == nil && text(.title(.oneTrick)) == nil && text(.title(.century)) == nil)
        // Moments: while they are news, in the menus.
        precondition(text(.moment(.rankChange)) == "Tank ↑ Emerald 1" && text(.moment(.newBest)) == "★ New best: 53 elims" && text(.moment(.seasonHigh)) == "★ Season high: Emerald 1")
        precondition(text(.moment(.milestone)) == "★ 10 hours on Juno" && text(.moment(.comeback)) == nil && text(.moment(.newSeason)) == nil)
        var played=history();played.runs.append(PlayedRun(start:day(28,15),end:day(28,17),matches:4))
        precondition(text(.moment(.rankChange),inputs(history:played)) == nil && text(.best(.new),inputs(history:played)) == nil,"a game since: no longer news")
        var away=history();away.runs=[PlayedRun(start:day(20,20),end:day(21,22),matches:2)]
        precondition(text(.moment(.comeback),inputs(profile:nil,history:away)) == "First game in 6 days")
        var season=history();season.seasonFollows=true;season.seasonSeen=day(28,19)
        precondition(text(.moment(.newSeason),inputs(history:season)) == "First game of the season" && text(.moment(.newSeason),inputs(profile:nil,history:season)) == nil)
        // Without the profile, only what the log and the runs say.
        for piece in [CardPiece.rank(.current),.record(.all,.competitive,winRate:false),.hero(nil,.hours),.best(.eliminations),.title(.endorsement),.moment(.rankChange)] {
            precondition(text(piece,inputs(profile:nil)) == nil,"\(piece)")
        }
        // An old look and matches played since: the rank may have moved, so it isn't shown.
        var stale=history();stale.looked=day(24,12);stale.runs.append(PlayedRun(start:day(25,20),end:day(25,22),matches:3))
        precondition(text(.rank(.current),inputs(history:stale)) == nil && text(.rank(.all),inputs(history:stale)) == nil && text(.record(.all,.competitive,winRate:false),inputs(history:stale)) != nil)
        // Line 1's words.
        let i=inputs()
        precondition(i.lineOne(.name,rank:.lastPlayed) == "pyxee" && i.lineOne(.nameAndTitle,rank:.lastPlayed) == "pyxee :3" && i.lineOne(.main,rank:.lastPlayed) == "Juno main")
        precondition(i.lineOne(.rank,rank:.lastPlayed) == "Tank ↑ Emerald 1" && inputs(.match(since:day(28,19.9))).lineOne(.rank,rank:.lastPlayed) == "pyxee" && i.lineOne(.placeOnly,rank:.lastPlayed) == nil)
        precondition(inputs(profile:nil).lineOne(.nameAndTitle,rank:.lastPlayed) == "pyxee","the BattleTag's name without a profile")
    }

    static func defaultCard() {
        let design=DiscordCardDesign.standard
        // Something just happened: the rank moved in today's session. Highlights' picture is the last session's hero
        // (the rank is in the badge already); a Rank change line of its own brings the emblem.
        var card=design.activity(inputs())
        precondition(card["details"] as? String == "pyxee · In Menus" && card["state"] as? String == "Tank ↑ Emerald 1","\(card)")
        precondition(assets(card)["large_image"] == "https://x/widow.png")
        var news=design;news.lineTwo=[CardLine(piece:.moment(.rankChange))]
        precondition(assets(news.activity(inputs()))["large_image"] == "https://x/emerald.png" && assets(news.activity(inputs()))["large_text"] == "Tank: Emerald 1")
        precondition(assets(card)["small_image"] == "https://x/emerald.png" && assets(card)["small_text"] == "Tank ↑ Emerald 1 · 6v6 – Emerald 1 · Playing on Mac with Recall")
        precondition((card["timestamps"] as? [String:Int])?["start"] == Int(day(28,19).timeIntervalSince1970))
        precondition((card["buttons"] as? [[String:String]]) == [["label":"Get Recall","url":Brand.repository.absoluteString],
                                                                 ["label":"Career Profile","url":"https://overwatch.blizzard.com/en-us/career/pyxee-11248/"]])
        // A game since: the last session, with its hero and what was done on all heroes.
        var played=history();played.runs.append(PlayedRun(start:day(28,15),end:day(28,17),matches:4))
        card=design.activity(inputs(history:played))
        precondition(card["state"] as? String == "Last · Comp 1–0 · 1 other" && assets(card)["large_image"] == "https://x/widow.png")
        precondition(assets(card)["large_text"] == "Most played last session: Widowmaker · All heroes: 31 eliminations, 7 deaths, 10,623 damage")
        // A profile kept from before the history (an earlier Recall): its last session still shows.
        precondition(design.activity(inputs(history:CareerHistory()))["state"] as? String == "Last · Comp 1–0 · 1 other")
        // The first look, with no session yet: all-time; no profile: tonight's matches, the BattleTag's name, the Mac badge.
        var first=profile();first.last=nil;first.hero=nil
        card=design.activity(inputs(profile:first,history:CareerHistory()))
        precondition(card["state"] as? String == "All · Comp 46–52" && assets(card)["large_image"] == "https://x/avatar.png" && assets(card)["large_text"] == "pyxee · :3")
        card=design.activity(inputs(profile:nil))
        precondition(card["details"] as? String == "pyxee · In Menus" && card["state"] as? String == "2 matches tonight" && assets(card)["large_image"] == nil)
        precondition(assets(card)["small_image"] == Brand.macBadge.absoluteString && assets(card)["small_text"] == "Playing on Mac with Recall" && (card["buttons"] as? [[String:String]])?.count == 1)
        precondition(design.activity(inputs(profile:nil,matches:0))["state"] == nil)
        // Where the log can't tell where the player is: the name alone, nothing from the profile's news.
        card=design.activity(inputs(.unknown))
        precondition(card["details"] as? String == "pyxee" && card["state"] == nil && assets(card)["large_image"] == nil)
    }

    static func inAMatch() {
        let since=day(28,19.9),design=DiscordCardDesign.standard
        // Nothing more on line 2 (Highlights says nothing in a match), the match's own timer, no picture, the badge.
        var card=design.activity(inputs(.match(since:since),matches:3))
        precondition(card["details"] as? String == "pyxee · In Match" && card["state"] == nil && assets(card)["large_image"] == nil)
        precondition((card["timestamps"] as? [String:Int])?["start"] == Int(since.timeIntervalSince1970) && assets(card)["small_image"] == Brand.macBadge.absoluteString)
        precondition(card["buttons"] != nil,"the buttons make no claim about the match")
        // A source that knows the match is competitive puts the rank on it.
        var known=inputs(.match(since:since));known.competitive=true
        precondition(assets(design.activity(known))["small_image"] == "https://x/emerald.png")
        // The session timer counts on through matches. Only lines that say nothing about the match show, and only if asked.
        var mine=DiscordCardDesign(id:"mine",name:"Mine",lineTwo:[CardLine(piece:.record(.week,.competitive,winRate:false)),CardLine(piece:.tonight(.matches)),CardLine(piece:.hero(nil,.hours),inMatch:false)],timer:.session)
        card=mine.activity(inputs(.match(since:since),matches:3))
        precondition(card["state"] as? String == "Match 3 tonight" && (card["timestamps"] as? [String:Int])?["start"] == Int(day(28,19).timeIntervalSince1970))
        // A second piece follows the first, when it has something to say there too.
        mine.lineTwo=[CardLine(piece:.tonight(.matches),second:.hero(nil,.hours))]
        precondition(mine.activity(inputs(.match(since:since),matches:3))["state"] as? String == "Match 3 tonight · Juno · 15h")
        mine.lineTwo=[CardLine(piece:.tonight(.matches),second:.record(.week,.competitive,winRate:false))]
        precondition(mine.activity(inputs(.match(since:since),matches:3))["state"] as? String == "Match 3 tonight")
        precondition(mine.activity(inputs(matches:3))["state"] as? String == "3 matches tonight · Week · Comp 3–1")
    }

    static func groupVoice() {
        let voice=GroupVoice(count:3,channel:"P",party:"party-id")
        func party(_ card:[String:Any])->[String:AnyHashable]? { card["party"] as? [String:AnyHashable] }
        var design=DiscordCardDesign.standard
        // Said on Line 2, with Discord's own count after it ("In Group Voice (3 of 6)").
        var card=design.activity(inputs(voice:voice))
        precondition(card["state"] as? String == "In Group Voice" && party(card)?["id"] == AnyHashable("party-id") && party(card)?["size"] == AnyHashable([3,6]))
        // Line 2 kept, the count added; and Line 2 alone.
        design.party = .addCount
        card=design.activity(inputs(voice:voice))
        precondition(card["state"] as? String == "Tank ↑ Emerald 1" && party(card) != nil)
        precondition(design.activity(inputs(.unknown,voice:voice))["state"] as? String == "In Group Voice","nothing to keep: the voice")
        design.party = .noCount
        card=design.activity(inputs(voice:voice))
        precondition(card["state"] as? String == "Tank ↑ Emerald 1" && party(card) == nil)
        // A group of more than six counts six.
        precondition(party(DiscordCardDesign.standard.activity(inputs(voice:GroupVoice(count:9,channel:"P",party:"p"))))?["size"] == AnyHashable([6,6]))
    }

    static func turns() {
        // Three lines, 45 seconds each, on one clock: the turn is the time over the pace.
        var design=DiscordCardDesign(id:"mine",name:"Mine",lineTwo:[CardLine(piece:.record(.week,.competitive,winRate:false)),CardLine(piece:.tonight(.matches)),CardLine(piece:.hero(nil,.hours))])
        let start=Date(timeIntervalSince1970:TimeInterval(design.turn(at:day(28,20))*45))
        func state(_ at:Date)->String? { design.activity(inputs(now:at))["state"] as? String }
        let order=["Week · Comp 3–1","2 matches tonight","Juno · 15h"]
        let first=order.firstIndex(of:state(start)!)!
        for k in 0..<6 { precondition(state(start.addingTimeInterval(TimeInterval(k*45)+10)) == order[(first+k)%3],"turn \(k)") }
        precondition(state(start.addingTimeInterval(44)) == state(start),"the same turn, the same card")
        precondition(design.nextTurn(inputs(now:start.addingTimeInterval(10))) == start.addingTimeInterval(45))
        // A line with nothing to say takes no turn: two lines left.
        precondition(Set((0..<4).compactMap { k in design.activity(inputs(matches:0,now:start.addingTimeInterval(TimeInterval(k*45))))["state"] as? String }) == ["Week · Comp 3–1","Juno · 15h"])
        // One line, one picture, one badge: nothing turns, so no refresh is asked for; the top heroes turn within one picture.
        precondition(DiscordCardDesign.standard.nextTurn(inputs()) == nil)
        var top=DiscordCardDesign.standard;top.pictures=[.topHeroes]
        precondition(top.nextTurn(inputs()) != nil && top.nextTurn(inputs(.match(since:day(28,19.9)))) == nil)
        precondition(Set((0..<5).compactMap { k in assets(top.activity(inputs(now:start.addingTimeInterval(TimeInterval(k*45)))))["large_image"] }).count == 5)
        // The pictures' own list and the badges turn with the lines; Overwatch's own picture is none.
        design.lineTwo=[CardLine(piece:.tonight(.matches))];design.pictures=[.playerIcon,.hero("ana"),.overwatch];design.badges=[.rank,.mac]
        let shown=(0..<4).map { k -> (String?,String?) in
            let card=design.activity(inputs(now:start.addingTimeInterval(TimeInterval(k*45))))
            return (assets(card)["large_image"],assets(card)["small_image"])
        }
        precondition(Set(shown.map(\.0)) == ["https://x/avatar.png","https://x/ana.png"] && Set(shown.map(\.1)) == ["https://x/emerald.png",Brand.macBadge.absoluteString],"\(shown)")
        precondition(design.nextTurn(inputs()) != nil)
        // In a match the rank badge sits out, and the Recall badge stands in when it's the only other.
        design.badges=[.rank,.recall]
        precondition(assets(design.activity(inputs(.match(since:day(28,19.9)))))["small_image"] == Brand.discordBadge.absoluteString)
        // A pace below Discord's comfort is taken as 20 seconds.
        design.pace=5
        precondition(design.turn(at:Date(timeIntervalSince1970:100)) == 5)
    }

    static func designs() {
        // The ready-made designs: Full's Default and the four Customize starts from, each a working card.
        precondition(DiscordCardDesign.readyMade.map(\.id) == ["default","climber","main","grinder","showoff"] && DiscordCardDesign.standard.readyMade)
        let main=DiscordCardDesign.readyMade[2]
        let card=main.activity(inputs())
        precondition(["Juno main","Juno · 15h","Support · Juno 15h"].contains(card["state"] as? String ?? ""),"\(card)")
        let buttons=card["buttons"] as? [[String:String]]
        precondition(buttons?.last == ["label":"Juno’s page","url":"https://overwatch.blizzard.com/en-us/heroes/juno/"],"\(String(describing:buttons))")
        var notes=DiscordCardDesign.standard;notes.button = .patchNotes
        precondition((notes.activity(inputs())["buttons"] as? [[String:String]])?.last?["label"] == "Patch notes")
        notes.button=nil
        precondition((notes.activity(inputs())["buttons"] as? [[String:String]])?.count == 1)
        // Kept in the settings: the player's own, and the one in use (an unknown one is Default).
        let suite="discord-card-tests-\(getpid())",store=UserDefaults(suiteName:suite)!
        defer { store.removePersistentDomain(forName:suite) }
        precondition(DiscordCardShelf.load(store) == DiscordCardShelf() && DiscordCardShelf().inUse == .standard)
        var shelf=DiscordCardShelf()
        var mine=DiscordCardDesign(id:UUID().uuidString,name:"Late nights",lineOne:[.name,.rank],lineTwo:[CardLine(piece:.record(.today,.both,winRate:true),second:.tonight(.nights),inMatch:false)],
                                   pictures:[.topHeroes,.hero("ana")],badges:[.recall],timer:.session,button:nil,party:.addCount,pace:120,rank:.role(.open))
        shelf.mine=[mine];shelf.chosen=mine.id;shelf.save(store)
        precondition(DiscordCardShelf.load(store).inUse == mine && !mine.readyMade && mine.shownName == "Late nights")
        mine.name="Other";shelf.chosen="gone"
        precondition(shelf.inUse == .standard)
        // Cards kept by another Recall still read: what one didn't have takes its default (no second button is no
        // key at all), and a card with a part this Recall doesn't know is left out, not all of them.
        let kept=#"{"chosen":"x","mine":[{"id":"y","name":"Odd","lineTwo":[{"piece":{"nonsense":{}}}]},{"id":"x","name":"Old","pace":120}]}"#
        let read=try! JSONDecoder().decode(DiscordCardShelf.self,from:Data(kept.utf8))
        precondition(read.chosen == "x" && read.hidden.isEmpty && read.mine.count == 1,"\(read)")
        precondition(read.mine[0].name == "Old" && read.mine[0].pace == 120 && read.mine[0].button == nil && read.mine[0].lineTwo == DiscordCardDesign.standard.lineTwo
                     && read.mine[0].rank == DiscordCardDesign.standard.rank,"\(read.mine[0])")
        // Discord's limit on a hover text: 128 characters.
        var long=profile();long.identity?.title=String(repeating:"Shieldbreaker ",count:12)
        var icon=DiscordCardDesign.standard;icon.pictures=[.playerIcon]
        precondition(assets(icon.activity(inputs(profile:long)))["large_text"]?.count == 128)
    }

    /// A seeded generator, so a failing card can be found again.
    struct Dice {
        var seed:UInt64
        mutating func next()->UInt64 { seed^=seed<<13;seed^=seed>>7;seed^=seed<<17;return seed }
        mutating func int(_ count:Int)->Int { Int(next()%UInt64(count)) }
        mutating func coin()->Bool { int(2) == 1 }
        mutating func pick<T>(_ list:[T])->T { list[int(list.count)] }
    }
    static func randomHero(_ dice:inout Dice)->String? {
        switch dice.int(4) { case 0: return nil;case 1: return "new-hero-\(dice.int(99))";default: return dice.pick(DiscordCardCode.heroes) }
    }
    static func randomPiece(_ dice:inout Dice)->CardPiece {
        switch dice.int(8) {
        case 0: return .highlights
        case 1: return .moment(dice.pick(CardMoment.allCases))
        case 2: return .rank(dice.pick(RankLine.allCases))
        case 3: return .record(dice.pick(CareerPeriod.allCases),dice.pick(RecordMode.allCases),winRate:dice.coin())
        case 4: return .hero(randomHero(&dice),dice.pick(HeroLine.allCases))
        case 5: return .best(dice.pick(BestLine.allCases))
        case 6: return .tonight(dice.pick(TonightLine.allCases))
        default: return .title(dice.pick(TitleLine.allCases))
        }
    }
    static func randomDesign(_ dice:inout Dice)->DiscordCardDesign {
        let names=["","Late nights","Climber 2","Über ✨ card","한국어 카드","a-b'c.d,e!f?g&h:i(j)k/l+m#n*o_p~","🔥🔥🔥","Tank & Spank","x","ALL CAPS 99"]
        var design=DiscordCardDesign(id:"x",name:dice.pick(names))
        design.lineOne=(0..<dice.int(6)).map { _ in dice.pick(LineOne.allCases) }
        design.lineTwo=(0..<dice.int(8)).map { _ in CardLine(piece:randomPiece(&dice),second:dice.coin() ? randomPiece(&dice) : nil,inMatch:dice.coin()) }
        if dice.coin() {
            design.pictures=(0..<dice.int(8)).map { _ in
                dice.int(8) == 7 ? .hero(randomHero(&dice) ?? "ana") : dice.pick([CardPicture.playerIcon,.lastHero,.overwatch,.rankEmblem,.recall,.roleMain,.topHeroes])
            }
        }
        design.badges=(0..<dice.int(4)).map { _ in dice.pick(CardBadge.allCases) }
        design.timer=dice.coin() ? .session : .match
        design.button=dice.pick([nil,SecondButton.careerProfile,.heroPage,.patchNotes])
        design.party=dice.pick([PartyChoice.sayVoice,.addCount,.noCount])
        design.pace=dice.coin() ? dice.pick(DiscordCardDesign.paces) : 20+dice.int(480)
        design.rank=dice.pick([RankChoice.role(.tank),.role(.damage),.role(.support),.role(.open),.highest,.lastPlayed])
        return design
    }

    static func codes() {
        func back(_ design:DiscordCardDesign)->DiscordCardDesign? { DiscordCardCode.decode(DiscordCardCode.encode(design)).map { var read=$0;read.id=design.id;return read } }
        // Every choice and the name come back exactly, for thousands of cards made at random (and the ready-made ones).
        var dice=Dice(seed:0x9E3779B97F4A7C15)
        for design in DiscordCardDesign.readyMade+(0..<5000).map({ _ in randomDesign(&dice) }) {
            precondition(DiscordCardCode.fits(design),"\(design)")
            precondition(back(design) == design,"\(design)\n\(String(describing:back(design)))\n\(DiscordCardCode.encode(design))")
        }
        // Short: Default is five characters; a card with three lines and a short name about fifteen.
        precondition(DiscordCardCode.encode(.standard).count == 5,DiscordCardCode.encode(.standard))
        var grinder=DiscordCardDesign.readyMade[3];grinder.name="Grind"
        let code=DiscordCardCode.encode(grinder)
        precondition(code.filter { $0 != "-" }.count <= 15 && code.allSatisfy { DiscordCardCode.alphabet.contains($0) || $0 == "-" },code)
        // Read the way people type: any case, without the dashes or with spaces, O for 0 and I or L for 1.
        let plain=code.replacingOccurrences(of:"-",with:"")
        let sloppy=plain.lowercased().replacingOccurrences(of:"0",with:"o").replacingOccurrences(of:"1",with:"l")
        precondition(back(DiscordCardCode.decode(sloppy) ?? .standard)?.lineTwo == grinder.lineTwo && DiscordCardCode.decode(plain.map { String($0) }.joined(separator:" ")) != nil)
        // A mistyped character is refused, wherever it is and whatever it became: never another card.
        for (position,character) in plain.enumerated() {
            for other in DiscordCardCode.alphabet where other != character {
                var typo=Array(plain);typo[position]=other
                precondition(DiscordCardCode.decode(String(typo)) == nil,"\(plain) → \(String(typo))")
            }
        }
        // A character missing or one too many: refused.
        precondition(DiscordCardCode.decode(String(plain.dropLast())) == nil && DiscordCardCode.decode(String(plain.dropFirst())) == nil)
        for bad in ["","U","hello world","0","\(plain)Z"] { precondition(DiscordCardCode.decode(bad) == nil,bad) }
        precondition(DiscordCardCode.group("ABCDEFGHJ") == "ABCD-EFGHJ" && DiscordCardCode.group("ABCDEFGH") == "ABCD-EFGH" && DiscordCardCode.group("ABC") == "ABC")
    }
}
