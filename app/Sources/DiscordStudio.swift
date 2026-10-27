import SwiftUI
import Observation

// Settings › Discord's state: the player's cards, the one being changed, and what the preview shows. The
// card in the preview is made by the same engine that makes Discord's (DiscordCardTemplate.swift), so what
// the player sees here is what their friends will. Every change applies at once (one that takes something away
// can be undone); a ready-made card is never changed itself: the first change saves a copy ("My card").

@MainActor @Observable final class DiscordStudio {
    enum Screen: Equatable { case home,editor,profile,history }
    /// The parts of the card Customize changes, in the rail's order (the game's name can't change).
    enum Slot: String, CaseIterable { case picture,badge,lineOne,lineTwo,timer,buttons,party }
    /// What the preview shows when the game isn't running: the menus or a match, in the group's voice or not.
    enum Scene: CaseIterable { case menus,match,menusVoice,matchVoice }
    enum Device { case desktop,phone }
    /// Line 2's topics, as Customize's tiles.
    enum Topic: String, CaseIterable { case highlights,moment,rank,record,hero,best,tonight,title }
    enum ImageTab: CaseIterable { case suggested,heroes,extra }
    /// What the player's profile allows: the card's profile lines need it public.
    enum ProfileState { case none,hidden,shown }
    /// Whether a line can say something now, and if not, why (the note after it).
    enum Availability { case ok,profile,match,news,later,locked }

    // MARK: what the app knows (AppModel keeps these current)
    var level:DiscordPresenceLevel = .standard
    var power=true
    var battleTag=""
    var profileState:ProfileState = .none
    var profile:CareerCard?
    var history=CareerHistory()
    var lookedUp:Date?
    var lookingUp=false
    /// A private profile: OverFast looks at it again only after this, so Look again learns nothing sooner.
    var lookAgainAt:Date?
    var texts=PresenceTexts.app
    /// The game's own facts while it runs: the preview follows them instead of the scene chosen here.
    var live:(place:PresenceState,voice:GroupVoice?,matches:Int,launched:Date)?
    /// The player's own picture on Discord, from Discord when Recall connects to it.
    var avatar:URL?

    // MARK: the cards
    var shelf:DiscordCardShelf { didSet { if shelf != oldValue { changed(shelf) } } }
    /// Called with every change to the cards, to keep and use them (AppModel).
    @ObservationIgnored var changed:(DiscordCardShelf)->Void={ _ in }

    // MARK: where the player is
    var screen:Screen = .home
    var gallery=false
    var galleryIndex:Int?
    var slot:Slot = .lineTwo
    var openLine:Int?
    var topic:Topic = .rank
    var hero:String?
    var mode:RecordMode = .competitive
    var winRate=false
    var allHeroes=false
    var imageTab:ImageTab = .suggested
    var role:CareerRank.Role = .tank
    var device:Device = .desktop { didSet { tips.phone=device == .phone } }
    var scene:Scene = .menus
    /// The scene before the Party part switched the preview to the group's voice.
    @ObservationIgnored private var sceneBeforeParty:Scene?
    var example=false
    /// A change shown on the card while the pointer rests on it, not yet made.
    var preview:DiscordCardDesign?
    /// Moments shown as if they had just happened (pointing at one).
    var previewNews=false
    /// The card held at a turn (an item clicked in a list), until something else is chosen.
    var held:Int?
    /// How far the preview's clock was moved on (a dot on the card was clicked).
    var shift:TimeInterval=0
    var toast:(text:String,undo:DiscordCardShelf?)?
    var sharing=false
    var importing=false
    var importDraft=""
    var importFailed=false
    var copied=false
    var renaming:String?
    var renameDraft=""
    // The pages: the BattleTag being typed, the profile row opened, erasing (with its ten seconds to undo).
    var tagEditing=false
    var tagDraft=""
    var tagError=false
    var openFact:Int?
    var erased:CareerHistory?
    /// How far a hold to erase has gone (0 to 1): the sessions are crossed out one after another.
    var eraseProgress:Double=0
    var undoLeft=0
    var exported=false
    var hoverSeen=UserDefaults.standard.bool(forKey:"discordHoverSeen") { didSet { UserDefaults.standard.set(hoverSeen,forKey:"discordHoverSeen") } }
    /// Earned lines the player has unlocked with their key.
    var unlocked=Set(UserDefaults.standard.stringArray(forKey:"discordUnlocked") ?? []) { didSet { UserDefaults.standard.set(Array(unlocked).sorted(),forKey:"discordUnlocked") } }
    /// The design's tooltips for these pages.
    @ObservationIgnored let tips=DesignTips()
    /// The easter eggs on the pop-out's picture and status line.
    @ObservationIgnored let profileFun=ProfileFun()
    /// When Settings opened: the preview's game opened 42:18 before it and its match 3:12 before it, so its timers
    /// read like a session's and run on, as the design's do.
    @ObservationIgnored private var opened=Date()
    var previewMatchStart:Date { opened.addingTimeInterval(-192) }
    func settingsOpened() { opened=Date() }
    @ObservationIgnored private var toastEnds:Task<Void,Never>?
    @ObservationIgnored private var pointing:Task<Void,Never>?
    @ObservationIgnored var eraseTimer:Task<Void,Never>?
    /// When the gallery's card started playing.
    private var galleryStart=Date()
    /// Customize just picked on Discord's tab: where its word is, for the sparks and the light that runs from it into
    /// the card (LevelFlow), and when.
    struct LevelFlowStart: Equatable { let id=UUID();let from:CGRect;let at:Date }
    var levelFlow:LevelFlowStart?
    /// Where the card is on Discord's tab, for the light to land on.
    @ObservationIgnored var cardFrame=CGRect.zero

    init(shelf:DiscordCardShelf=DiscordCardShelf()) {
        self.shelf=shelf
        tips.discordTipShown={ [weak self] in if self?.hoverSeen == false { self?.hoverSeen=true } }
    }

    // MARK: what the player asks of the app (AppModel answers)

    struct Actions {
        var level:(DiscordPresenceLevel)->Void={ _ in }
        var power:(Bool)->Void={ _ in }
        var battleTag:(String)->Void={ _ in }
        var lookAgain:()->Void={}
        var erase:()->Void={}
        var export:()->URL?={ nil }
    }
    @ObservationIgnored var actions=Actions()
    func setPower(_ on:Bool) { power=on;actions.power(on) }
    /// A level from the line under the card. Customize picked shows the card in use; picked again, it opens it in the
    /// editor.
    func choose(_ level:DiscordPresenceLevel) {
        if !power { setPower(true) }
        if self.level != level { self.level=level;actions.level(level) } else if level == .custom { openEditor() }
    }
    func openEditor() {
        screen = .editor;gallery=false;galleryIndex=nil;preview=nil;held=nil;openLine=nil;shift=0
        if level != .custom { level = .custom;actions.level(.custom) }
    }
    func closePage() {
        commitErase()
        screen = .home;gallery=false;preview=nil;held=nil;openLine=nil;sharing=false;importing=false;renaming=nil;shift=0
        if let before=sceneBeforeParty,live == nil { scene=before };sceneBeforeParty=nil
    }
    func openProfile() {
        screen = .profile;preview=nil;held=nil;openLine=nil;openFact=nil
        tagEditing=battleTag.isEmpty;tagDraft=battleTag;tagError=false
    }
    func openHistory() { screen = .history;exported=false }

    // MARK: the card shown

    /// The card being changed: the one in use.
    var design:DiscordCardDesign { shelf.inUse }
    /// What the preview shows: the gallery's card, a change being pointed at, or the card in use. Full shows Default.
    var shown:DiscordCardDesign {
        if gallery,let item=galleryItem { return item.design }
        if let preview { return preview }
        if screen == .home && level == .full { return .standard }
        return design
    }
    var usesExample:Bool { example && profileState != .shown }
    func inputs(at now:Date)->CardInputs {
        var inputs=CardInputs(launched:opened.addingTimeInterval(-2538),now:now,texts:texts)
        if let live {
            inputs.place=live.place;inputs.voice=live.voice;inputs.matches=live.matches;inputs.launched=live.launched
        } else {
            let match=scene == .match || scene == .matchVoice
            inputs.place=match ? .match(since:previewMatchStart) : .menu
            if scene == .menusVoice || scene == .matchVoice { inputs.voice=GroupVoice(count:3,channel:"preview",party:"preview") }
            inputs.matches=match ? 4 : 3
        }
        if usesExample { inputs.profile=Self.exampleProfile;inputs.history=Self.exampleHistory(now) }
        else { inputs.profile=profileState == .shown ? profile : nil;inputs.history=history }
        inputs.tagName=usesExample ? Self.exampleName : battleTag.split(separator:"#").first.map(String.init)
        if previewNews { inputs=withNews(inputs) }
        return inputs
    }
    /// What the lines would say in the menus, right after a session, with a public profile (the example's when
    /// there's none): Customize's lists show every line this way, so each says something.
    func sampleInputs(at now:Date)->CardInputs {
        var inputs=inputs(at:now)
        inputs.place = .menu;inputs.voice=nil
        if inputs.profile == nil { inputs.profile=Self.exampleProfile;inputs.history=Self.exampleHistory(now);inputs.tagName=inputs.tagName ?? Self.exampleName }
        return withNews(inputs)
    }
    /// The inputs with something that just happened: a rank up, a new best, a season high and a hero milestone.
    private func withNews(_ base:CardInputs)->CardInputs {
        guard let profile=base.profile,base.news == nil || base.news?.session.rank == nil else { return base }
        var inputs=base,session=profile.last ?? LastSession()
        let rank=profile.rank ?? profile.ranks.first
        session.rank=rank;session.promoted=true
        session.best=profile.totals.values.compactMap { $0.bests["eliminations_most_in_game"] }.max().map { CareerBest(key:"eliminations_most_in_game",value:$0) }
        var change=ProfileChange(at:base.launched.addingTimeInterval(-3600),season:profile.season,session:session,before:[:],after:[:])
        change.rankSteps=1;change.seasonHigh=rank
        if let top=inputs.topHeroes.first,let seconds=inputs.heroTime[top] {
            let hours=seconds/3600
            change.milestone=ProfileChange.Milestone(hero:top,hours:[100,50,25,10].first { $0 <= hours } ?? 10)
        }
        inputs.history.changes.append(change)
        inputs.history.runs.removeAll { $0.start > change.at }
        return inputs
    }
    /// The card at a moment, as Discord would get it; Basic and Live as they are. Off, the one it would get: Recall sends
    /// nothing, and the stage's cover goes over it.
    func activity(at now:Date)->[String:Any] {
        let inputs=inputs(at:now)
        switch screen == .home ? level : .custom {
        case .normal,.live:
            return PresenceCard.activity(facts:PresenceFacts(place:inputs.place,voice:inputs.voice),level:level,launched:inputs.launched,texts:texts)
        default: return shown.activity(inputs,turn:turn(at:now))
        }
    }

    // MARK: the clock

    /// The turn the preview shows: the held one, or the clock's (moved on by a click on the card's dots). In My
    /// cards the card plays sped up, a turn every 3 seconds, from its first.
    func turn(at now:Date)->Int {
        if let held { return held }
        if gallery { return Int(max(0,now.timeIntervalSince(galleryStart)))/Self.galleryPace }
        return shown.turn(at:now.addingTimeInterval(shift))
    }
    static let galleryPace=3
    /// How far through its turn the card is (1 while held), for the rings.
    func turnDone(at now:Date)->Double {
        guard held == nil else { return 1 }
        if gallery { return Double(Int(max(0,now.timeIntervalSince(galleryStart)))%Self.galleryPace+1)/Double(Self.galleryPace) }
        let pace=max(shown.pace,DiscordCardDesign.shortestPace)
        return Double(Int(now.addingTimeInterval(shift).timeIntervalSince1970)%pace+1)/Double(pace)
    }
    /// The turns before the card repeats itself: every list back where it started.
    func loopLength(at now:Date)->Int {
        let lists=DiscordCardDesign.Shown(shown,inputs(at:now),turn:turn(at:now))
        func gcd(_ a:Int,_ b:Int)->Int { b == 0 ? a : gcd(b,a%b) }
        return [lists.lineOne.count,lists.lineTwo.count,lists.pictures.count,lists.badges.count].filter { $0 > 0 }.reduce(1) { $0/gcd($0,$1)*$1 }
    }
    /// The card's dots: show the k-th turn of its loop (held while a list's item is held; the clock goes on from it otherwise).
    func jump(to k:Int,at now:Date) {
        let length=loopLength(at:now),now_=turn(at:now),target=now_+((k-now_%length)%length+length)%length
        if held != nil { held=target;return }
        if gallery { galleryStart=galleryStart.addingTimeInterval(-TimeInterval((target-now_)*Self.galleryPace));return }
        shift+=TimeInterval((target-now_)*max(shown.pace,DiscordCardDesign.shortestPace));preview=nil
    }
    /// Holds the card on the k-th item of a list of this many (the first turn from now that shows it).
    private func hold(_ k:Int,of count:Int) {
        guard count > 0 else { return }
        let now=turn(at:Date())
        held=(0..<count).map { now+$0 }.first { $0%count == k } ?? now;preview=nil
    }
    func hold(picture k:Int) { hold(k,of:design.pictures?.count ?? 0) }

    // MARK: changing the card

    /// Changes the card in use; a ready-made one is copied first ("My card"). With `said`, or a copy made, the
    /// toast says what happened and offers to undo it.
    func edit(_ change:(inout DiscordCardDesign)->Void,said:String?=nil) {
        pointing?.cancel()
        let before=shelf
        var card=shelf.inUse,copied:String?=nil
        if card.readyMade {
            copied=card.shownName
            card.name=card.id == "default" ? L("My card") : L("My {0}",card.shownName)
            card.id=UUID().uuidString
        }
        change(&card)
        if let index=shelf.mine.firstIndex(where:{ $0.id == card.id }) { shelf.mine[index]=card } else { shelf.mine.append(card) }
        shelf.chosen=card.id;preview=nil;previewNews=false
        if let copied { say(L("Saved as “{0}”. {1} stays as it is.",card.name,copied),undo:before) } else if let said { say(said,undo:before) }
    }
    func undo() { if let before=toast?.undo { shelf=before };say(L("Undone")) }
    func say(_ text:String,undo:DiscordCardShelf?=nil) {
        toast=(text,undo);toastEnds?.cancel()
        toastEnds=Task { [weak self] in try? await Task.sleep(for:.seconds(4.5));if !Task.isCancelled { self?.toast=nil } }
    }
    /// Shows a change on the card once the pointer rests on it (sooner while another change shows).
    func point(news:Bool=false,_ change:@escaping (inout DiscordCardDesign)->Void) {
        pointing?.cancel()
        let wait=preview == nil ? 320 : 90
        pointing=Task { [weak self] in
            try? await Task.sleep(for:.milliseconds(wait))
            guard let self,!Task.isCancelled else { return }
            var card=self.design;change(&card);self.preview=card;self.previewNews=news
        }
    }
    func stopPointing() {
        pointing?.cancel()
        pointing=Task { [weak self] in
            try? await Task.sleep(for:.milliseconds(170))
            guard let self,!Task.isCancelled else { return }
            self.preview=nil;self.previewNews=false
        }
    }

    /// A part picked on the card or in the rail. The party's part shows the group's voice while it's open.
    func pick(_ slot:Slot) {
        guard !gallery else { return }
        if slot == .party,self.slot != .party,live == nil,scene == .menus || scene == .match {
            sceneBeforeParty=scene;scene=scene == .match ? .matchVoice : .menusVoice
        } else if slot != .party,let before=sceneBeforeParty,live == nil { scene=before;sceneBeforeParty=nil }
        self.slot=slot;openLine=nil;held=nil;preview=nil
    }

    // Line 2: a click makes a line the only one (or changes the open one); holding adds it, or takes it out.
    func onlyLine(_ piece:CardPiece) {
        if let open=openLine,open < design.lineTwo.count { edit { $0.lineTwo[open].piece=piece };return }
        guard !(design.lineTwo.count == 1 && design.lineTwo[0].piece == piece) else { return }
        let several=design.lineTwo.count > 1
        edit({ $0.lineTwo=[CardLine(piece:piece)] },said:several ? L("Now only “{0}”. Hold a line to add it instead.",piece.label) : nil)
    }
    func toggleLine(_ piece:CardPiece) {
        if let index=design.lineTwo.firstIndex(where:{ $0.piece == piece }) {
            edit { $0.lineTwo.remove(at:index);if $0.lineTwo.isEmpty { $0.lineTwo=[CardLine(piece:.highlights)] } }
        } else if design.lineTwo.count < 6 { edit { $0.lineTwo.append(CardLine(piece:piece)) } }
    }
    func removeLine(_ index:Int) {
        guard design.lineTwo.indices.contains(index) else { return }
        edit({ $0.lineTwo.remove(at:index);if $0.lineTwo.isEmpty { $0.lineTwo=[CardLine(piece:.highlights)] } },said:L("Removed it"))
        openLine=nil;held=nil
    }
    func moveLine(from:Int,to:Int) {
        let lines=design.lineTwo.indices
        guard from != to,lines.contains(from),lines.contains(to) else { return }
        edit { $0.lineTwo.move(fromOffsets:IndexSet(integer:from),toOffset:to > from ? to+1 : to) }
        // The open line stays open wherever it went, and the card stays on it.
        if let open=openLine { openLine=Self.moved(open,from:from,to:to);holdOpenLine() }
    }
    /// Where an item of a list is after another one moved from one place to another.
    static func moved(_ index:Int,from:Int,to:Int)->Int {
        if index == from { return to }
        if from < index && index <= to { return index-1 }
        if to <= index && index < from { return index+1 }
        return index
    }
    /// Holds the card on the open line, wherever it is in the list now.
    private func holdOpenLine() {
        guard let open=openLine,design.lineTwo.indices.contains(open) else { return }
        let now=Date(),shown=DiscordCardDesign.Shown(design,inputs(at:now),turn:turn(at:now)),piece=design.lineTwo[open].piece
        if let place=shown.lineTwo.firstIndex(where:{ $0.piece == piece }) { hold(place,of:shown.lineTwo.count) } else { held=nil }
    }
    func setSecond(_ piece:CardPiece?,line index:Int) { edit { $0.lineTwo[index].second=piece } }
    /// Opens a line in the list (and holds the card on it), or closes it again.
    func openLineToggle(_ index:Int,shown:DiscordCardDesign.Shown) {
        if openLine == index { closeLine();return }
        openLine=index;preview=nil
        let piece=design.lineTwo[index].piece
        topic=piece.topic
        if case .hero(let key,_)=piece { hero=key }
        if case .record(_,let mode,let rate)=piece { self.mode=mode;winRate=rate }
        if let place=shown.lineTwo.firstIndex(where:{ $0.piece == piece }) { hold(place,of:shown.lineTwo.count) } else { held=nil }
    }
    func closeLine() { openLine=nil;held=nil;preview=nil }
    /// A hero for the Hero lines (nil: the most played); an open hero line changes with it.
    func chooseHero(_ key:String?) {
        hero=key
        if let open=openLine,design.lineTwo.indices.contains(open),case .hero(_,let line)=design.lineTwo[open].piece { edit { $0.lineTwo[open].piece = .hero(key,line) } }
    }
    /// A record's modes or win rate; an open record line changes with them.
    func setRecord(mode:RecordMode,winRate:Bool) {
        self.mode=mode;self.winRate=winRate
        if let open=openLine,design.lineTwo.indices.contains(open),case .record(let period,_,_)=design.lineTwo[open].piece {
            edit { $0.lineTwo[open].piece = .record(period,mode,winRate:winRate && mode != .both) }
        }
    }
    func unlock(_ piece:CardPiece,_ sample:CardInputs) {
        unlocked.insert(piece.key)
        say(L("Unlocked “{0}”. Click to use it, or hold to add it.",sampleText(piece,sample)))
    }

    // The picture: following Line 2, or a list of its own.
    func followLineTwo() { edit { $0.pictures=nil } }
    func ownPictures() { edit { $0.pictures=$0.pictures ?? [.playerIcon] } }
    func onlyPicture(_ picture:CardPicture) { if design.pictures != [picture] { edit { $0.pictures=[picture] } } }
    func togglePicture(_ picture:CardPicture) {
        edit { card in
            var list=card.pictures ?? []
            if let index=list.firstIndex(of:picture) { if list.count > 1 { list.remove(at:index) } } else if list.count < 6 { list.append(picture) }
            card.pictures=list.isEmpty ? [picture] : list
        }
    }
    func movePicture(from:Int,to:Int) {
        guard let pictures=design.pictures,from != to,pictures.indices.contains(from),pictures.indices.contains(to) else { return }
        let shownBefore=held.map { $0%pictures.count }
        edit { $0.pictures?.move(fromOffsets:IndexSet(integer:from),toOffset:to > from ? to+1 : to) }
        // A picture the card was held on stays on the card.
        if let shownBefore { hold(picture:Self.moved(shownBefore,from:from,to:to)) }
    }

    // The badge, line 1, the pace.
    func onlyBadge(_ badge:CardBadge) { if design.badges != [badge] { edit { $0.badges=[badge] } } }
    func toggleBadge(_ badge:CardBadge) {
        edit { card in
            if let index=card.badges.firstIndex(of:badge) { if card.badges.count > 1 { card.badges.remove(at:index) } } else { card.badges.append(badge) }
        }
    }
    func onlyLineOne(_ item:LineOne) { if design.lineOne != [item] { edit { $0.lineOne=[item] } } }
    func toggleLineOne(_ item:LineOne) {
        edit { card in
            if let index=card.lineOne.firstIndex(of:item) { if card.lineOne.count > 1 { card.lineOne.remove(at:index) } } else if card.lineOne.count < 5 { card.lineOne.append(item) }
        }
    }
    func nextPace() {
        let paces=DiscordCardDesign.paces,index=paces.firstIndex(of:design.pace) ?? 0
        edit { $0.pace=paces[(index+1)%paces.count] }
    }

    // MARK: what the lists say

    func availability(_ piece:CardPiece,_ i:CardInputs)->Availability {
        if piece.topic == .moment {
            if i.profile == nil && piece != .moment(.comeback) { return .profile }
            if i.inMatch { return .match }
            return piece.text(i,rank:design.rank) == nil ? .news : .ok
        }
        if piece.needsProfile && i.profile == nil { return .profile }
        if let progress=piece.progress(i),progress.done < 1 { return .locked }
        if i.inMatch && !piece.safeInMatch { return .match }
        return piece.text(i,rank:design.rank) == nil ? .later : .ok
    }
    func note(_ availability:Availability)->(text:String,icon:String)? {
        switch availability {
        case .ok: return nil
        case .profile: return (profileState == .hidden ? L("Profile is private") : battleTag.isEmpty ? L("Needs your BattleTag") : L("Not found yet"),"lucide:lock")
        case .match: return (L("Not in a match"),"lucide:swords")
        case .news: return (L("When it happens"),"rc:live")
        case .later: return (L("After a session"),"lucide:hourglass")
        case .locked: return (L("Not earned yet"),"lucide:lock")
        }
    }
    /// What a line of the card's list says: now, or what it would say (Highlights is just its name then).
    func lineText(_ line:CardLine,_ i:CardInputs)->String {
        let rank=design.rank
        if availability(line.piece,i) == .ok,let text=line.piece.text(i,rank:rank) {
            return line.second.flatMap { $0.text(i,rank:rank) }.map { text+" · "+$0 } ?? text
        }
        if line.piece == .highlights { return L("Highlights") }
        let sample=sampleInputs(at:i.now),text=sampleText(line.piece,sample)
        return line.second.map { text+" · "+sampleText($0,sample) } ?? text
    }
    /// What a line would say, from the sample inputs (a comeback or a new season can't be made up from them).
    func sampleText(_ piece:CardPiece,_ sample:CardInputs)->String {
        if let text=piece.text(sample,rank:design.rank) { return text }
        switch piece {
        case .moment(.comeback): return L("First game in {0} days","6")
        case .moment(.newSeason): return L("First game of the season")
        default: return piece.label
        }
    }
    /// Under a line in the list: what it is, and the piece after it.
    func explain(_ line:CardLine)->String {
        let about=line.piece.about
        return line.second.map { L("{0}, plus {1}",about,$0.label.lowercased()) } ?? about
    }
    func portrait(_ key:String?,_ i:CardInputs)->URL? {
        guard let key else { return nil }
        return i.profile?.heroes[key]?.portrait ?? sampleInputs(at:i.now).profile?.heroes[key]?.portrait
    }
    /// Pieces that fit after a line: Discord shows about 30 characters of Line 2.
    func seconds(for piece:CardPiece,main:String,inputs:CardInputs)->[(piece:CardPiece,text:String)] {
        let candidates:[CardPiece]=[.rank(.current),.hero(nil,.main),.tonight(.matches),.title(.endorsement)]
        return candidates.filter { $0.topic != piece.topic }.compactMap { second in
            guard let text=second.text(inputs,rank:design.rank),main.count+3+text.count <= 30 else { return nil }
            return (second,text)
        }
    }
    var topicNote:String? {
        switch topic {
        case .record: return L("“Today” means earlier today, up to this launch.")
        case .rank: return L("The marks show how your last session went: ↑ up a division, ↟ two or more, – no change, ↓ down, ↡ two or more down.")
        default: return nil
        }
    }
    struct HighlightStep { let icon:String;let color:Color;let when:String;let text:String;let applies:Bool }
    /// Highlights' order, each with what it would say and whether it applies right now.
    func highlightSteps(_ inputs:CardInputs)->[HighlightStep] {
        let moment=CardMoment.allCases.lazy.compactMap { CardPiece.moment($0).text(inputs,rank:self.design.rank) }.first
        let sample=sampleInputs(at:inputs.now)
        let last=(inputs.profile ?? sample.profile)?.last.map { L("Last · {0}",$0.summary) }
        let all=CardPiece.record(.all,.competitive,winRate:false).text(inputs.profile == nil ? sample : inputs,rank:design.rank)
        var tonight=inputs;tonight.place = .menu
        let rankNews=CardPiece.moment(.rankChange).text(sample,rank:design.rank)
        let cyan=Color(red:96/255,green:206/255,blue:222/255)
        return [HighlightStep(icon:"ph:users-three-fill",color:cyan,when:L("In the group’s voice chat"),text:"\(texts.voice) (\(L("{0} of {1}","3","6")))",
                              applies:inputs.voice != nil && design.party == .sayVoice),
                HighlightStep(icon:"rc:live",color:Color(red:1,green:110/255,blue:110/255),when:L("Something just happened"),text:moment ?? rankNews ?? L("A rank change, a new best…"),applies:moment != nil),
                HighlightStep(icon:"ph:sword-fill",color:Color(red:110/255,green:170/255,blue:1),when:L("You played before"),text:last ?? L("Your last session"),applies:inputs.profile?.last != nil),
                HighlightStep(icon:"ph:medal-fill",color:Color(red:94/255,green:214/255,blue:160/255),when:L("Your first session"),text:all ?? L("Your all-time record"),
                              applies:inputs.profile != nil && all != nil),
                HighlightStep(icon:"rc:moon-fill",color:cyan,when:L("No profile yet"),text:CardPiece.tonight(.matches).text(tonight,rank:design.rank) ?? "",applies:true)]
    }
    /// The heroes, most played first, then the rest by name.
    func heroOrder(_ i:CardInputs)->[String] { i.topHeroes+(i.profile?.heroes.keys.sorted().filter { i.heroTime[$0] == nil } ?? []) }
    func heroCaption(_ key:String,_ i:CardInputs)->String {
        let name=i.heroName(key)
        return i.heroTime[key].map { L("{0} · {1} played",name,i.hours($0)) } ?? name
    }
    func heroesOfRole(_ i:CardInputs)->[String] { heroOrder(i).filter { i.profile?.heroes[$0]?.role == role } }
    /// The pictures a tab offers, with what each is (the caption when pointed at).
    func imageChoices(_ i:CardInputs)->[(picture:CardPicture,name:String)] {
        switch imageTab {
        case .suggested:
            // The role mains, then the most played, without the last hero: Last hero already shows them.
            let mains=[CareerRank.Role.tank,.damage,.support].compactMap { role in i.topHeroes.first { i.profile?.heroes[$0]?.role == role } }
            var heroes:[String]=[]
            for key in mains+i.topHeroes.prefix(6) where !heroes.contains(key) && key != i.profile?.last?.hero { heroes.append(key) }
            let fixed:[(picture:CardPicture,name:String)]=[(.playerIcon,L("Player icon")),(.overwatch,L("Overwatch")),(.lastHero,L("Last hero: follows who you played last"))]
            return fixed+heroes.map { key in
                    var name=heroCaption(key,i)
                    if mains.contains(key),let role=i.profile?.heroes[key]?.role {
                        switch role {
                        case .tank: name=L("{0} · your tank main",name)
                        case .damage: name=L("{0} · your damage main",name)
                        default: name=L("{0} · your support main",name)
                        }
                    }
                    return (CardPicture.hero(key),name)
                }
        case .heroes:
            let all=heroesOfRole(i)
            return (allHeroes ? all : Array(all.prefix(10))).map { (CardPicture.hero($0),heroCaption($0,i)) }
        case .extra:
            return [(.rankEmblem,i.rank(design.rank).map { L("Rank emblem · {0}",$0.name) } ?? L("Rank emblem")),(.recall,L("Recall’s icon"))]
        }
    }
    func badgeAbout(_ badge:CardBadge,_ i:CardInputs)->String {
        switch badge {
        case .rank: return i.rank(design.rank).map { L("{0} · from your profile",i.rankText($0)) } ?? L("From your profile")
        case .mac: return texts.badge
        case .recall: return L("Recall’s icon")
        }
    }
    func buttonAbout(_ button:SecondButton?,hasLabel:Bool)->String {
        switch button {
        case .careerProfile: return L("Your Blizzard career page")
        case .heroPage: return L("Follows the hero in the image")
        case .patchNotes: return L("The latest Overwatch patch")
        case nil: return L("No second button")
        }
    }
    /// The card as it would be with a change, right now (the panels' small previews).
    func sample(_ inputs:CardInputs,_ change:(inout DiscordCardDesign)->Void)->[String:Any] {
        var card=design;change(&card)
        return card.activity(inputs,turn:0)
    }

    // MARK: the rail

    /// What each part shows now, under its name in the rail.
    func railSummary(_ slot:Slot,at now:Date)->String {
        let inputs=inputs(at:now),design=shown,turn=turn(at:now),lists=DiscordCardDesign.Shown(design,inputs,turn:turn)
        switch slot {
        case .picture:
            guard inputs.menus else { return L("Overwatch logo") }
            guard let pictures=design.pictures,!pictures.isEmpty else { return L("From Line 2") }
            return pictures[turn%pictures.count].name
        case .badge:
            let badge=lists.badges.isEmpty ? CardBadge.mac : lists.badges[turn%lists.badges.count]
            return badge.railName
        case .lineOne: return design.lineOne.isEmpty ? LineOne.name.railName : design.lineOne[turn%design.lineOne.count].railName
        case .lineTwo:
            if inputs.voice != nil && design.party == .sayVoice { return L("Group voice count") }
            if lists.lineTwo.isEmpty { return inputs.inMatch ? L("Empty in a match") : L("Nothing right now") }
            return lists.lineTwo[turn%lists.lineTwo.count].piece.label
        case .timer: return design.timer == .match ? L("Each match") : L("Whole session")
        case .buttons: return design.button.map { L("+ {0}",$0.name) } ?? L("Only Get Recall")
        case .party:
            switch design.party {
            case .sayVoice: return L("Count on Line 2")
            case .addCount: return L("Count after Line 2")
            case .noCount: return L("No count")
            }
        }
    }
    /// How many take turns in a part (shown as a count with a ring in the rail).
    func railCount(_ slot:Slot,at now:Date)->Int {
        let inputs=inputs(at:now),design=shown
        switch slot {
        case .picture: return inputs.menus ? (design.pictures?.count ?? DiscordCardDesign.Shown(design,inputs,turn:0).lineTwo.count) : 1
        case .badge: return inputs.menus ? design.badges.count : 1
        case .lineOne: return design.lineOne.count
        case .lineTwo: return design.lineTwo.count
        default: return 1
        }
    }

    // MARK: the cards (My cards)

    struct GalleryItem: Equatable {
        let design:DiscordCardDesign
        var readyMade:Bool { design.readyMade }
        var name:String { design.shownName }
    }
    /// The player's own cards first, then the ready-made ones that aren't hidden.
    var galleryItems:[GalleryItem] {
        shelf.mine.map(GalleryItem.init)+DiscordCardDesign.readyMade.filter { !shelf.hidden.contains($0.id) }.map(GalleryItem.init)
    }
    var galleryPlace:Int {
        let items=galleryItems
        return min(max(0,galleryIndex ?? items.firstIndex { $0.design.id == shelf.inUse.id } ?? 0),max(0,items.count-1))
    }
    var galleryItem:GalleryItem? { galleryItems.indices.contains(galleryPlace) ? galleryItems[galleryPlace] : nil }
    func openGallery(_ open:Bool) {
        gallery=open;galleryIndex=nil;sharing=false;importing=false;renaming=nil;preview=nil;held=nil;openLine=nil;copied=false;shift=0;galleryStart=Date()
        if open,let before=sceneBeforeParty,live == nil { scene=before;sceneBeforeParty=nil;slot = .lineTwo }
    }
    func galleryStep(_ by:Int) {
        let next=galleryPlace+by
        guard by != 0,galleryItems.indices.contains(next) else { return }
        galleryIndex=next;renaming=nil;copied=false;shift=0;galleryStart=Date()
    }
    func use(_ item:GalleryItem) {
        shelf.chosen=item.design.id;gallery=false;galleryIndex=nil;sharing=false;importing=false;renaming=nil;held=nil;shift=0
        say(L("Now using “{0}”",item.name))
    }
    func duplicate(_ item:GalleryItem) {
        var copy=item.design
        copy.id=UUID().uuidString;copy.name=String(L("{0} 2",item.name).prefix(24))
        shelf.mine.append(copy);galleryIndex=galleryItems.firstIndex { $0.design.id == copy.id };sharing=false;renaming=nil;shift=0;galleryStart=Date()
        say(L("Duplicated as “{0}”",copy.name))
    }
    /// Your only card can't go (Default counts as yours until it's hidden); the other ready-made cards are only
    /// hidden (Bring back shows them again).
    func canDelete(_ item:GalleryItem)->Bool {
        if item.readyMade && item.design.id != "default" { return true }
        return shelf.mine.count+(shelf.hidden.contains("default") ? 0 : 1) > 1
    }
    func delete(_ item:GalleryItem) {
        guard canDelete(item) else { return }
        let before=shelf,wasInUse=item.design.id == shelf.inUse.id,place=galleryPlace
        if item.readyMade { shelf.hidden.append(item.design.id) } else { shelf.mine.removeAll { $0.id == item.design.id } }
        if wasInUse { shelf.chosen=galleryItems.first?.design.id ?? "default" }
        galleryIndex=min(place,max(0,galleryItems.count-1));sharing=false;renaming=nil;shift=0;galleryStart=Date()
        say(wasInUse ? L("Deleted “{0}”. Now using “{1}”.",item.name,shelf.inUse.shownName) : L("Deleted “{0}”",item.name),undo:before)
    }
    var hiddenCount:Int { shelf.hidden.count }
    func bringBack() { shelf.hidden=[];galleryIndex=nil;shift=0;galleryStart=Date();say(L("The System cards are back")) }
    func startRename(_ item:GalleryItem) {
        guard !item.readyMade else { return }
        renaming=item.design.id;renameDraft=item.design.name;sharing=false;importing=false
    }
    func finishRename() {
        guard let id=renaming else { return }
        renaming=nil
        let name=Self.cardName(renameDraft)
        guard !name.isEmpty,let index=shelf.mine.firstIndex(where:{ $0.id == id }) else { return }
        shelf.mine[index].name=name
    }
    /// A card's name as My cards keeps it: one line, 24 characters at most (a pasted name or a code can bring
    /// line breaks, or a longer one).
    static func cardName(_ text:String)->String {
        let breaks:[Unicode.GeneralCategory]=[.control,.lineSeparator,.paragraphSeparator]
        let line=String(String.UnicodeScalarView(text.unicodeScalars.filter { !breaks.contains($0.properties.generalCategory) }))
        return String(line.trimmingCharacters(in:.whitespaces).prefix(24))
    }
    /// The card as a code to share: the code is the card itself (DiscordCardCode.swift).
    func code(_ item:GalleryItem)->String {
        var card=item.design
        if card.readyMade { card.name=card.shownName }
        return DiscordCardCode.encode(card)
    }
    func importCode() {
        guard var card=DiscordCardCode.decode(importDraft) else { importFailed=true;return }
        card.name=Self.cardName(card.name)
        if card.name.isEmpty { card.name=card.lineTwo.first.map { $0.piece.label } ?? L("Shared card") }
        if galleryItems.contains(where:{ $0.name == card.name }) { card.name=String(L("{0} 2",card.name).prefix(24)) }
        shelf.mine.append(card)
        galleryIndex=galleryItems.firstIndex { $0.design.id == card.id };importing=false;importDraft="";importFailed=false;shift=0;galleryStart=Date()
        say(L("Added “{0}” to your cards",card.name))
    }
    /// What a card shows, under its name in My cards.
    func galleryDescription(_ item:GalleryItem)->String {
        switch item.design.id {
        case "climber": return L("Your rank, how far you climbed this season, and your peak.")
        case "main": return L("Your main hero: who, how long, and in which role.")
        case "grinder": return L("This week’s record, tonight’s matches, and nights in a row.")
        case "showoff": return L("Your career bests, one after another.")
        case "default": return L("Recall picks the most interesting thing on its own: a rank change, a new best, or your last session.")
        default:
            let lines=item.design.lineTwo
            if lines.count > 1 { return L("{0} lines take turns: {1}.",String(lines.count),lines.map { $0.piece.label }.joined(separator:", ")) }
            return L("One line: {0}.",lines.first?.piece.label ?? L("Highlights"))
        }
    }

    // MARK: example data

    /// What the preview shows with no public profile and "Preview with example data" on.
    /// The example player's name, in the app's language.
    static var exampleName:String { L("Player") }
    static let exampleProfile:CareerCard={
        let base="https://d15f34w2p8l1cc.cloudfront.net/overwatch/"
        func hero(_ name:String,_ file:String,_ role:CareerRank.Role)->CareerHero { CareerHero(name:name,portrait:URL(string:base+file+".png"),role:role) }
        let heroes=["mercy":hero("Mercy","3bfb8bd8ec827e53d870f1238ab73d8aa1f5dbfbcfaaf7f96ffcd35b5c6102ab",.support),
                    "kiriko":hero("Kiriko","408603fe037e8576078eaac5eab2fb251489ced4003b11f5f522776d43d0b83d",.support),
                    "winston":hero("Winston","46a10db3aa908c590ddc4e7606376a88143d1f1306ecfbea043263040f9529a5",.tank),
                    "tracer":hero("Tracer","4504f6f15cb3feaa92ecd38e01dcf751cb5abdac2e0bb52d0555727e53277502",.damage)]
        let competitive=ModeStats(games:Tally(played:98,won:46,lost:52),heroes:["winston":25560,"tracer":21600,"kiriko":32040],
                                  bests:["eliminations_most_in_game":53,"all_damage_done_most_in_game":39448,"healing_done_most_in_game":16163,"kill_streak_best":27,"multikill_best":6])
        let quickplay=ModeStats(games:Tally(played:578,won:297,lost:281),heroes:["mercy":55800],heroGames:["mercy":Tally(played:40,won:22,lost:18)])
        // Blizzard's own emblem for Emerald, as OverFast gives it.
        let emblem=URL(string:"https://static.playoverwatch.com/images/pages/career/icons/rank/Rank_EmeraldTier.d82e76cb2deeac6d1f4d4cf4d8914517d903eeeb.png")!
        let ranks=[CareerRank(role:.tank,division:"emerald",tier:1,icon:emblem),CareerRank(role:.open,division:"emerald",tier:1,icon:emblem)]
        return CareerCard(identity:CareerIdentity(name:exampleName,title:nil,endorsement:3,avatar:nil),ranks:ranks,season:nil,
                          last:LastSession(competitive:Tally(played:1,won:1),other:1,hero:"tracer",role:.tank,eliminations:31,deaths:7,damage:10623),
                          hero:heroes["tracer"],page:URL(string:"https://overwatch.blizzard.com/en-us/career/"),totals:["competitive":competitive,"quickplay":quickplay],heroes:heroes)
    }()
    static func exampleHistory(_ now:Date)->CareerHistory {
        var history=CareerHistory()
        let day:TimeInterval=24*3600
        var change=ProfileChange(at:now.addingTimeInterval(-day),season:nil,session:LastSession(competitive:Tally(played:4,won:3,lost:1)),before:[:],after:[:])
        change.heroes=["mercy":3600]
        history.changes=[change]
        history.runs=[PlayedRun(start:now.addingTimeInterval(-2*day),end:now.addingTimeInterval(-2*day+7200),matches:5),
                      PlayedRun(start:now.addingTimeInterval(-day-7200),end:now.addingTimeInterval(-day),matches:4)]
        return history
    }
}

// MARK: words for the editor

extension DiscordStudio.Topic {
    var name:String {
        switch self {
        case .highlights: return L("Highlights")
        case .moment: return L("Moments")
        case .rank: return L("Rank")
        case .record: return L("Record")
        case .hero: return L("Hero")
        case .best: return L("Best")
        case .tonight: return L("Tonight")
        case .title: return L("You")
        }
    }
    /// The design's icon for the topic.
    var icon:String {
        switch self {
        case .highlights: return "rc:pick"
        case .moment: return "rc:live"
        case .rank: return "ph:medal-fill"
        case .record: return "ph:sword-fill"
        case .hero: return "rc:user-fill"
        case .best: return "ph:trophy-fill"
        case .tonight: return "rc:moon-fill"
        case .title: return "rc:id-fill"
        }
    }
    var color:Color {
        switch self {
        case .highlights: return Color(red:1,green:152/255,blue:104/255)
        case .moment: return Color(red:1,green:110/255,blue:110/255)
        case .rank: return Color(red:94/255,green:214/255,blue:160/255)
        case .record: return Color(red:110/255,green:170/255,blue:1)
        case .hero: return Color(red:196/255,green:140/255,blue:1)
        case .best: return Color(red:1,green:206/255,blue:84/255)
        case .tonight: return Color(red:96/255,green:206/255,blue:222/255)
        case .title: return Color(red:1,green:128/255,blue:170/255)
        }
    }
    var about:String {
        switch self {
        case .highlights: return L("One line that picks itself: Recall shows the first of these that applies right now.")
        case .moment: return L("Lines that appear only when something happens, the next time you play after it.")
        case .rank: return L("Your rank from your profile. The role you pick here is the one every rank line and the badge show.")
        case .record: return L("Wins and losses from your profile, for the time you pick.")
        case .hero: return L("Pick a hero, then what to say. “Main” is earned: it goes to your most-played hero.")
        case .best: return L("Your best games ever, from your profile.")
        case .tonight: return L("“Tonight” is this session: since you opened Overwatch. Recall counts it from the game’s log, so it needs no BattleTag.")
        case .title: return L("Titles you earn from your hours. Each bar fills as you play; reach the key to unlock it.")
        }
    }
    /// The lines the topic offers.
    func catalog(hero:String?,mode:RecordMode,winRate:Bool)->[CardPiece] {
        switch self {
        case .highlights: return [.highlights]
        case .moment: return CardMoment.allCases.map { .moment($0) }
        case .rank: return [RankLine.current,.climb,.peak,.all].map { .rank($0) }
        case .record: return [CareerPeriod.last,.today,.week,.season,.all].map { .record($0,mode,winRate:winRate && mode != .both) }
        case .hero: return HeroLine.allCases.map { .hero(hero,$0) }
        case .best: return [BestLine.eliminations,.damage,.healing,.killStreak,.multikill].map { .best($0) }
        case .tonight: return TonightLine.allCases.map { .tonight($0) }
        case .title: return TitleLine.allCases.map { .title($0) }
        }
    }
}

extension CardPiece {
    /// The topic a line belongs to.
    var topic:DiscordStudio.Topic {
        switch self {
        case .highlights: return .highlights
        case .moment,.rank(.change),.best(.new): return .moment
        case .rank: return .rank
        case .record: return .record
        case .hero: return .hero
        case .best: return .best
        case .tonight: return .tonight
        case .title: return .title
        }
    }
    /// Its short name ("Week record", "Juno hours").
    var label:String {
        switch self {
        case .highlights: return L("Highlights")
        case .moment(let moment):
            switch moment {
            case .rankChange: return L("Rank change")
            case .newBest: return L("New best")
            case .seasonHigh: return L("Season high")
            case .milestone: return L("Hero milestone")
            case .comeback: return L("Comeback")
            case .newSeason: return L("New season")
            }
        case .rank(let line):
            switch line {
            case .current: return L("Rank")
            case .climb: return L("Climb")
            case .peak: return L("Peak")
            case .all: return L("All ranks")
            case .change: return L("Rank news")
            }
        case .record(let period,let mode,_):
            let time:String
            switch period {
            case .last: time=L("Last session")
            case .today: time=L("Today")
            case .week: time=L("This week")
            case .season: time=L("This season")
            case .all: time=L("All time")
            }
            switch mode {
            case .competitive: return time
            case .quickPlay: return L("QP, {0}",time)
            case .both: return L("{0}, both modes",time)
            }
        case .hero(let key,let line):
            let name=key.map { DiscordStudio.heroName($0) } ?? L("Your main")
            switch line {
            case .main: return L("{0} main",name)
            case .hours: return L("{0} hours",name)
            case .role: return L("{0} with role",name)
            case .winRate: return L("{0} wins",name)
            }
        case .best(let line):
            switch line {
            case .eliminations: return L("Best elims")
            case .damage: return L("Best damage")
            case .healing: return L("Best healing")
            case .killStreak: return L("Best streak")
            case .multikill: return L("Best multikill")
            case .new: return L("Best news")
            }
        case .tonight(let line):
            switch line {
            case .matches: return L("Match count")
            case .nights: return L("Nights in a row")
            case .week: return L("Hours this week")
            }
        case .title(let line):
            switch line {
            case .endorsement: return L("Endorsement")
            case .hours: return L("Hours played")
            case .roleMain: return L("Role main")
            case .flex: return L("Flex")
            case .oneTrick: return L("One-trick")
            case .century: return L("Century")
            }
        }
    }
    /// What it is, in plain words, under the line in Line 2's list.
    var about:String {
        switch self {
        case .highlights: return L("Recall picks what to show")
        case .moment(let moment): return moment.when
        case .rank(let line):
            switch line {
            case .current: return L("Your rank, and how last session moved it")
            case .climb: return L("How far you climbed this season")
            case .peak: return L("Your best rank this season")
            case .all: return L("Your rank in every role")
            case .change: return L("Only when your rank moves")
            }
        case .record(let period,let mode,let winRate):
            let modes:String
            switch mode {
            case .competitive: modes=L("Comp")
            case .quickPlay: modes=L("Quick Play")
            case .both: modes=L("Comp and QP")
            }
            var text:String
            switch period {
            case .last: text=mode == .competitive ? L("Last session’s Comp record, and other modes") : L("Last session’s {0} record",modes)
            case .today: text=L("{0} record, today",modes)
            case .week: text=L("{0} record, this week",modes)
            case .season: text=L("{0} record, this season",modes)
            case .all: text=L("{0} record, all time",modes)
            }
            if winRate && mode != .both { text=L("{0}, with win rate",text) }
            return text
        case .hero(let key,let line):
            let name=key.map { DiscordStudio.heroName($0) } ?? L("your most-played hero")
            switch line {
            case .main: return L("{0} is your most-played hero",name)
            case .hours: return L("Your hours on {0}",name)
            case .role: return L("{0}’s role, and your hours",name)
            case .winRate: return L("Your win rate on {0}",name)
            }
        case .best(let line): return line == .new ? L("When a game beats one of your bests") : L("Your best game ever")
        case .tonight(let line):
            switch line {
            case .matches: return L("Matches since you opened Overwatch")
            case .nights: return L("Days in a row you’ve played")
            case .week: return L("Hours played this week")
            }
        case .title(let line):
            switch line {
            case .endorsement: return L("Your endorsement level")
            case .hours: return L("Your total hours")
            case .century: return L("Earned at 100 hours")
            default: return L("Earned from your hours")
            }
        }
    }
    /// Lines that need the profile (all but Highlights, Tonight and a comeback).
    var needsProfile:Bool {
        switch self {
        case .highlights,.tonight,.moment(.comeback): return false
        default: return true
        }
    }
    /// The key an unlocked line is kept by.
    var key:String { String(describing:self) }
}

extension CardMoment {
    /// When a moment shows.
    var when:String {
        switch self {
        case .rankChange: return L("When your rank moves (↑ one, ↟ two+)")
        case .newBest: return L("When a game beats one of your bests")
        case .seasonHigh: return L("Your best rank yet this season")
        case .milestone: return L("At 10, 25, 50, 100… hours on a hero")
        case .comeback: return L("First game after 3+ days away")
        case .newSeason: return L("First game of a new season")
        }
    }
}
extension CardPicture {
    var name:String {
        switch self {
        case .playerIcon: return L("Player icon")
        case .lastHero: return L("Last hero")
        case .overwatch: return L("Overwatch")
        case .rankEmblem: return L("Rank emblem")
        case .recall: return L("Recall")
        case .roleMain: return L("Role main")
        case .topHeroes: return L("Top heroes")
        case .hero(let key): return DiscordStudio.heroName(key)
        }
    }
    /// What it shows now: the hero it brings, or its name.
    func shownName(_ i:CardInputs,rank:RankChoice)->String {
        image(i,rank:rank,turn:0)?.hero.map { i.heroName($0) } ?? name
    }
    /// A hero's role and time, under it in the list.
    func heroSub(_ i:CardInputs)->String? {
        guard case .hero(let key)=self else { return nil }
        let role=i.profile?.heroes[key]?.role?.label
        let time=i.heroTime[key].map { L("{0} played",i.hours($0)) }
        return [role,time].compactMap { $0 }.joined(separator:" · ").nilIfEmpty
    }
}
extension CardBadge {
    var name:String {
        switch self {
        case .rank: return L("Your rank")
        case .mac: return L("Mac badge")
        case .recall: return L("Recall")
        }
    }
    var railName:String { self == .recall ? L("Recall’s icon") : name }
}
extension LineOne {
    var name:String {
        switch self {
        case .name: return L("Your name")
        case .nameAndTitle: return L("Name and title")
        case .main: return L("Your main")
        case .rank: return L("Your rank")
        case .placeOnly: return L("Just where you are")
        }
    }
    var railName:String { self == .placeOnly ? L("Where you are") : name }
}
extension SecondButton {
    var name:String {
        switch self {
        case .careerProfile: return L("Career Profile")
        case .heroPage: return L("Hero’s page")
        case .patchNotes: return L("Patch notes")
        }
    }
}
extension PartyChoice {
    var name:String {
        switch self {
        case .sayVoice: return L("Say you’re in group voice")
        case .addCount: return L("Keep Line 2, add the count")
        case .noCount: return L("Keep Line 2, no count")
        }
    }
}
extension DiscordStudio.ImageTab {
    var name:String {
        switch self {
        case .suggested: return L("Suggested")
        case .heroes: return L("Heroes")
        case .extra: return L("Extra")
        }
    }
}

extension DiscordStudio {
    /// A hero's name from the profile's list (set as the profile arrives, on the main thread), or its key made readable.
    nonisolated(unsafe) static var heroNames:[String:String]=[:]
    nonisolated static func heroName(_ key:String)->String { heroNames[key] ?? key.split(separator:"-").map { $0.capitalized }.joined(separator:" ") }
}

extension DiscordCardShelf {
    /// Two cards are the same card when their ids are.
    func contains(_ design:DiscordCardDesign)->Bool { all.contains { $0.id == design.id } }
}
