import Foundation
import Darwin

// DiscordPresence.swift: the card Recall shows in Discord and where it gets it. Lines are shaped like
// the real Overwatch.log's, with the ids left out; Discord is a fake listener on a temporary socket.
// Build and run:
//   swiftc -O -target arm64-apple-macos26.5 -parse-as-library app/Sources/Brand.swift app/Sources/Localization.swift \
//     app/Sources/DiscordPresence.swift tests/DiscordPresenceTests.swift -o runtime/phase-3/discord-presence-tests
//   runtime/phase-3/discord-presence-tests

final class Collected<T> {
    private let lock=NSLock()
    private var items:[T]=[]
    func add(_ more:[T]) { lock.lock();items+=more;lock.unlock() }
    var all:[T] { lock.lock();defer { lock.unlock() };return items }
}

/// Waits for something that happens on another queue.
func wait(_ seconds:Double=5,_ done:()->Bool)->Bool {
    let end=Date().addingTimeInterval(seconds)
    while Date() < end { if done() { return true };Thread.sleep(forTimeInterval:0.02) }
    return done()
}
let stamper:ISO8601DateFormatter={ let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds];return f }()
func logLine(_ message:String,at date:Date)->String { "[1752] [ALW] [VoiceChat] [External(0)] [External()] [\(stamper.string(from:date))]: \(message)" }
let ready="#=[VC] Auto-Join Enabled Flags 0000 -> 0005",closed="#=[VC] Auto-Join Enabled Flags 0005 -> 0000"
let join="==[VC] Notified Lobby of Active channel NONE -> TEAM",leave="==[VC] Notified Lobby of Active channel TEAM -> NONE"
let teammate="#=[VC] MemberAdded 603564719 23f9aaaf 0d4cbeb2@4a95b6d2 22f891df false",yourself="#=[VC] MemberAdded 603564719 23f9aaaf 0d4cbeb2@4a95b6d2 22f891df true"
let partyJoin="==[VC] Notified Lobby of Active channel NONE -> PARTY",partyLeave="==[VC] Notified Lobby of Active channel PARTY -> NONE"

/// Discord's side of the socket, for one test.
final class FakeDiscord {
    let path:String
    private let listener:Int32
    init() {
        let folder=NSTemporaryDirectory()+"ow2-discord-\(getpid())-\(UInt32.random(in:0..<1_000_000))/"
        try! FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
        path=folder+"discord-ipc-0"
        listener=socket(AF_UNIX,SOCK_STREAM,0)
        var address=sockaddr_un()
        address.sun_family=sa_family_t(AF_UNIX)
        let capacity=MemoryLayout.size(ofValue:address.sun_path)
        withUnsafeMutablePointer(to:&address.sun_path) { $0.withMemoryRebound(to:CChar.self,capacity:capacity) { _ = strlcpy($0,path,capacity) } }
        let bound=withUnsafePointer(to:&address) { $0.withMemoryRebound(to:sockaddr.self,capacity:1) { Darwin.bind(listener,$0,socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        precondition(bound == 0 && Darwin.listen(listener,4) == 0)
    }
    deinit {
        Darwin.close(listener)
        try? FileManager.default.removeItem(atPath:(path as NSString).deletingLastPathComponent)
    }
    func accept(_ milliseconds:Int32=5000)->Int32? {
        var poller=pollfd(fd:listener,events:Int16(POLLIN),revents:0)
        guard poll(&poller,1,milliseconds) > 0 else { return nil }
        let fd=Darwin.accept(listener,nil,nil)
        return fd >= 0 ? fd : nil
    }
    private func read(_ fd:Int32,_ count:Int,_ milliseconds:Int32)->[UInt8]? {
        var bytes=[UInt8]()
        while bytes.count < count {
            var poller=pollfd(fd:fd,events:Int16(POLLIN),revents:0)
            guard poll(&poller,1,milliseconds) > 0 else { return nil }
            var chunk=[UInt8](repeating:0,count:count-bytes.count)
            let n=Darwin.read(fd,&chunk,chunk.count)
            guard n > 0 else { return nil }
            bytes+=chunk[0..<n]
        }
        return bytes
    }
    func frame(_ fd:Int32,_ milliseconds:Int32=5000)->(opcode:UInt32,json:[String:Any])? {
        guard let head=read(fd,8,milliseconds) else { return nil }
        let length=Int(head[4])|Int(head[5])<<8|Int(head[6])<<16|Int(head[7])<<24
        guard let body=read(fd,length,milliseconds),let json=try? JSONSerialization.jsonObject(with:Data(body)) as? [String:Any] else { return nil }
        return (UInt32(head[0])|UInt32(head[1])<<8|UInt32(head[2])<<16|UInt32(head[3])<<24,json)
    }
    func send(_ fd:Int32,_ opcode:UInt32,_ json:[String:Any]) {
        let data=DiscordFrame.encode(opcode,json)!
        _ = data.withUnsafeBytes { Darwin.write(fd,$0.baseAddress!,data.count) }
    }
    /// Discord answers the opening with READY, and the client then sends its card.
    func welcome(_ fd:Int32)->[String:Any]? {
        guard let hello=frame(fd),hello.opcode == DiscordFrame.handshake else { return nil }
        send(fd,DiscordFrame.frame,["cmd":"DISPATCH","evt":"READY","data":["v":1]])
        return hello.json
    }
    /// The card in a SET_ACTIVITY frame; an NSNull when the card is taken down.
    func card(_ fd:Int32,_ milliseconds:Int32=5000)->Any?? {
        guard let message=frame(fd,milliseconds),message.opcode == DiscordFrame.frame,message.json["cmd"] as? String == "SET_ACTIVITY",
              let args=message.json["args"] as? [String:Any] else { return nil }
        return .some(args["activity"])
    }
    func closed(_ fd:Int32)->Bool {
        var poller=pollfd(fd:fd,events:Int16(POLLIN),revents:0)
        var byte:UInt8=0
        return poll(&poller,1,5000) > 0 && Darwin.read(fd,&byte,1) == 0
    }
}
func details(_ card:Any??)->String? { ((card ?? nil) as? [String:Any])?["details"] as? String }

@main struct DiscordPresenceTests {
    static func main() {
        frames();parsing();tracker();cards();processStart();location();tail();connection();reconnect();absent();rate();spam();endToEnd()
        print("PASS: Discord frames, Overwatch.log lines, match tracking, the card at each level, following the log, the Discord socket and the whole path")
    }

    static func frames() {
        let body=["cmd":"SET_ACTIVITY"]
        let one=DiscordFrame.encode(DiscordFrame.frame,body)!
        // 4-byte opcode, 4-byte length, both little-endian, then the JSON.
        precondition(Array(one[0..<4]) == [1,0,0,0] && Int(one[4]) == one.count-8 && one[5] == 0)
        var reader=DiscordFrameReader()
        // A frame in pieces, then two frames in one read.
        var got:[DiscordFrameReader.Frame]=[]
        for byte in one { got+=reader.feed(Data([byte])) }
        precondition(got.count == 1 && got[0].opcode == 1 && (try! JSONSerialization.jsonObject(with:got[0].body) as! [String:String]) == body)
        let ping=DiscordFrame.encode(DiscordFrame.ping,["n":1])!
        got=reader.feed(ping+one)
        precondition(got.map(\.opcode) == [3,1])
        // Something that is not Discord speaking is cut off.
        var bad=DiscordFrameReader()
        _ = bad.feed(Data([1,0,0,0,0,0,0,0x7f]))
        precondition(bad.broken)
        precondition(DiscordFrame.encode(1,["a":Date()]) == nil)
    }

    static func parsing() {
        let t=Date(timeIntervalSince1970:1_792_000_000.25)
        func at(_ e:PresenceEvent?)->Date? {
            switch e { case .channel(_,let d)?,.voiceReady(let d)?,.voiceClosed(let d)?: return d;default: return nil }
        }
        let joined=PresenceEvent.parse(logLine(join,at:t))
        precondition(joined == .channel(.team,joined.flatMap(at)!) && abs(at(joined)!.timeIntervalSince(t)) < 0.002)
        let time=at(joined)!
        precondition(PresenceEvent.parse(logLine(leave,at:t)) == .channel(nil,time))
        precondition(PresenceEvent.parse(logLine(partyJoin,at:t)) == .channel(.party,time))
        precondition(PresenceEvent.parse(logLine(partyLeave,at:t)) == .channel(nil,time))
        precondition(PresenceEvent.parse(logLine("==[VC] Notified Lobby of Active channel PARTY -> TEAM",at:t)) == .channel(.team,time))
        precondition(PresenceEvent.parse(logLine("==[VC] Notified Lobby of Active channel TEAM -> NONE",at:t)) == .channel(nil,time))
        // After a match the game moves everyone to the MATCH channel (the voting cards).
        precondition(PresenceEvent.parse(logLine("==[VC] Notified Lobby of Active channel NONE -> MATCH",at:t)) == .channel(.match,time))
        precondition(PresenceEvent.parse(logLine("==[VC] Notified Lobby of Active channel NONE -> LOBBY",at:t)) == .channel(.other,time))
        // The match is over when match-wide chat is enabled (flags gain 0x2), and not when they go back.
        precondition(PresenceEvent.parse(logLine("#=[VC] Channel Enabled Flags 0005 -> 0007",at:t)) == .matchOver(time))
        precondition(PresenceEvent.parse(logLine("#=[VC] Channel Enabled Flags 0007 -> 0005",at:t)) == nil)
        precondition(PresenceEvent.parse(logLine("#=[VC] Channel Enabled Flags 0000 -> 0005",at:t)) == nil)
        precondition(PresenceEvent.parse(logLine("#=[VC] Channel Enabled Flags 0005 -> zz",at:t)) == nil)
        // Another player's voice (false) is told; the player's own (true) is not.
        precondition(PresenceEvent.parse(logLine(teammate,at:t)) == .member(time) && PresenceEvent.parse(logLine(yourself,at:t)) == nil)
        precondition(PresenceEvent.parse(logLine("#=[VC] MemberAdded 603564719 23f9aaaf false",at:t)) == nil)
        precondition(PresenceEvent.parse(logLine(ready,at:t)) == .voiceReady(time))
        precondition(PresenceEvent.parse(logLine(closed,at:t)) == .voiceClosed(time))
        // The game writes Windows line endings.
        precondition(PresenceEvent.parse(logLine(join,at:t)+"\r") == joined && PresenceEvent.parse(logLine(ready,at:t)+"\r") == .voiceReady(time))
        // Everything else the log says, as it appears in a real one, says nothing about where the player is.
        let others=["#=[VC] Auto-Join Enabled Flags 0005 -> 0007","#=[VC] Auto-Join Enabled Flags 0000 -> 0000",
                    "==[VC] OnJoinChannel NONE -> TEAM","==[VC] OnJoinChannel NONE -> PARTY","==[VC] Notified Lobby of Active channel TEAM -> NONE and more",
                    "==[VC] Notified Lobby of Active channel","==[VC] JoinVoiceChannel() _?__95g==__?_ - PARTY - active = 1","#=[VC] ChatSystem switching to new PARTY channel: _?__95g==__?_",
                    "==[VC] Request login 0a1b2c","#=[VC] ResponseMuteMember 7 0(0:0c0dc0)","==[VC] Member identity updated 1f2e3d","#=[VC] MemberAdded 603564719 23f9aaaf 0d4cbeb2@4a95b6d2 22f891df true"]
        for message in others { precondition(PresenceEvent.parse(logLine(message,at:t)) == nil,message) }
        precondition(PresenceEvent.parse("[1752] [ALW] [Engine] [External(0)] [External()] [2026-10-24T16:30:03.522Z]: prism: Info: Display 0") == nil)
        precondition(PresenceEvent.parse("") == nil && PresenceEvent.parse("[VoiceChat] Notified Lobby of Active channel NONE -> TEAM") == nil)
    }

    static func tracker() {
        let t0=Date(timeIntervalSince1970:1_792_000_000)
        func after(_ s:Double)->Date { t0.addingTimeInterval(s) }
        var tracker=PresenceTracker()
        // Nothing said yet, or voice chat off: nothing is claimed.
        precondition(tracker.state(at:after(500)) == .unknown && tracker.nextChange(at:after(500)) == nil)
        tracker.apply(.voiceReady(after(26)))
        precondition(tracker.state(at:after(30)) == .menu)
        // A team channel that opens and closes in seconds is a match that was backed out of.
        tracker.apply(.member(after(60)));tracker.apply(.channel(.team,after(60.5)))
        precondition(tracker.state(at:after(63)) == .menu && tracker.nextChange(at:after(63))! > 7.4 && tracker.nextChange(at:after(63))! < 7.6)
        tracker.apply(.channel(nil,after(64)))
        precondition(tracker.state(at:after(200)) == .menu && tracker.nextChange(at:after(200)) == nil && !tracker.others)
        // One that holds, with the team's voices in it (they join as the channel opens), is a match, timed from the join.
        tracker.apply(.member(after(299.5)));tracker.apply(.channel(.team,after(300)));tracker.apply(.member(after(301)))
        precondition(tracker.state(at:after(309)) == .menu && tracker.state(at:after(310)) == .match(since:after(300)))
        // The same channel said again keeps the first one's time.
        tracker.apply(.channel(.team,after(400)))
        precondition(tracker.state(at:after(500)) == .match(since:after(300)))
        // The results showing ends the match at once, though the team's channel stays open (an Arcade game kept it 52 s).
        tracker.apply(.channel(nil,after(850)));tracker.apply(.member(after(851)));tracker.apply(.channel(.team,after(852)))
        precondition(tracker.state(at:after(870)) == .match(since:after(852)))
        tracker.apply(.matchOver(after(880)))
        precondition(tracker.state(at:after(881)) == .menu && tracker.state(at:after(890)) == .menu)
        tracker.apply(.channel(nil,after(897)))
        precondition(tracker.state(at:after(898)) == .menu && !tracker.over)
        // The mark means nothing with no team channel open, and is not carried to the next match.
        tracker.apply(.matchOver(after(899)));tracker.apply(.member(after(899.5)));tracker.apply(.channel(.team,after(900)))
        precondition(tracker.state(at:after(911)) == .match(since:after(900)))
        tracker.apply(.channel(nil,after(920)))
        // The screen after the match (the voting cards) is the end of it.
        tracker.apply(.channel(nil,after(900)));tracker.apply(.channel(.match,after(902)))
        precondition(tracker.state(at:after(905)) == .menu)
        tracker.apply(.channel(nil,after(920)))
        precondition(tracker.state(at:after(921)) == .menu)
        // A team channel with nobody else in it (the Practice Range, a game with bots) claims nothing once it has held.
        tracker.apply(.channel(.team,after(1000)))
        precondition(tracker.state(at:after(1005)) == .menu && tracker.state(at:after(1011)) == .unknown && tracker.state(at:after(5000)) == .unknown)
        // Another player's voice arriving later makes it a match from the join.
        tracker.apply(.member(after(1100)))
        precondition(tracker.state(at:after(1101)) == .match(since:after(1000)))
        tracker.apply(.channel(nil,after(1200)))
        precondition(tracker.state(at:after(1201)) == .menu && !tracker.others)
        // In a group the game keeps only the group's channel and says nothing more: no claim of menus or a match.
        tracker.apply(.channel(.party,after(1300)))
        precondition(tracker.state(at:after(1301)) == .group && tracker.state(at:after(9000)) == .group && tracker.nextChange(at:after(1301)) == nil)
        tracker.apply(.channel(nil,after(1500)))
        precondition(tracker.state(at:after(1501)) == .menu)
        // A group that moves to the team's channel for a match, and back to the group's after it.
        tracker.apply(.channel(.party,after(1600)));tracker.apply(.member(after(1699)));tracker.apply(.channel(.team,after(1700)))
        precondition(tracker.state(at:after(1705)) == .menu && tracker.state(at:after(1710)) == .match(since:after(1700)))
        tracker.apply(.channel(.party,after(2400)))
        precondition(tracker.state(at:after(2401)) == .group)
        // A channel nobody has seen is not guessed at.
        tracker.apply(.channel(.other,after(2500)))
        precondition(tracker.state(at:after(2501)) == .unknown)
        // The voice service going down (the game closing) and the log starting over clear everything.
        tracker.apply(.channel(.team,after(2550)));tracker.apply(.voiceClosed(after(2600)))
        precondition(tracker.state(at:after(2700)) == .unknown && !tracker.others)
        tracker.apply(.voiceReady(after(2800)));tracker.apply(.member(after(2805)));tracker.apply(.channel(.team,after(2810)));tracker.apply(.reset)
        precondition(tracker.state(at:after(2900)) == .unknown && !tracker.others)
        // A join with no menu line before it (the line was missed) still counts as a match, with the team in it.
        tracker.apply(.channel(.team,after(3000)));tracker.apply(.member(after(3001)))
        precondition(tracker.state(at:after(3100)) == .match(since:after(3000)))
        // Lines from before the game opened are an earlier run's.
        var late=PresenceTracker(notBefore:after(1000))
        late.apply(.voiceReady(after(900)));late.apply(.member(after(949)));late.apply(.channel(.team,after(950)));late.apply(.channel(.party,after(960)))
        precondition(late.state(at:after(2000)) == .unknown && !late.others)
        late.apply(.voiceReady(after(1026)));late.apply(.channel(.team,after(1100)));late.apply(.member(after(1101)))
        precondition(late.state(at:after(2000)) == .match(since:after(1100)))
    }

    static func cards() {
        let texts=PresenceTexts(menu:"In Menus",match:"In Match",group:"In a Group",badge:"Playing on Mac with Recall")
        let launched=Date(timeIntervalSince1970:1_792_000_000),since=Date(timeIntervalSince1970:1_792_000_600)
        func start(_ card:[String:Any])->Int? { (card["timestamps"] as? [String:Int])?["start"] }
        // Normal is what a PC player gets, whatever the log says: the game, and the time since it opened.
        for state in [PresenceState.unknown,.menu,.group,.match(since:since)] {
            let card=PresenceCard.activity(state:state,level:.normal,launched:launched,texts:texts)
            precondition(card["type"] as? Int == 0 && start(card) == 1_792_000_000 && card["details"] == nil && card["assets"] == nil)
        }
        let unknown=PresenceCard.activity(state:.unknown,level:.live,launched:launched,texts:texts)
        precondition(unknown["details"] == nil && start(unknown) == 1_792_000_000)
        let menu=PresenceCard.activity(state:.menu,level:.live,launched:launched,texts:texts)
        precondition(menu["details"] as? String == "In Menus" && start(menu) == 1_792_000_000)
        let match=PresenceCard.activity(state:.match(since:since),level:.live,launched:launched,texts:texts)
        precondition(match["details"] as? String == "In Match" && start(match) == 1_792_000_600)
        let group=PresenceCard.activity(state:.group,level:.live,launched:launched,texts:texts)
        precondition(group["details"] as? String == "In a Group" && start(group) == 1_792_000_000)
        // The Recall badge, loaded from the repository's icon, on every Live card.
        for card in [unknown,menu,group,match] {
            let assets=card["assets"] as? [String:String]
            precondition(assets?["small_image"] == Brand.discordBadge.absoluteString && assets?["small_text"] == "Playing on Mac with Recall" && assets?["large_image"] == nil)
        }
        precondition(Brand.discordBadge.scheme == "https" && Brand.discordApplicationID == "356875221078245376")
        precondition(JSONSerialization.isValidJSONObject(match))
        // Discord wants two characters at least in a line, and no more than 128.
        precondition((2...128).contains((menu["details"] as! String).count) && (2...128).contains((match["details"] as! String).count) && (2...128).contains((group["details"] as! String).count))
        precondition(DiscordPresenceLevel.allCases == [.normal,.live] && DiscordPresenceLevel(rawValue:"gone") == nil && DiscordPresenceLevel.standard == .live)
    }

    static func processStart() {
        // The test's own process: started in the last minute, and not in the future. A pid that is gone has none.
        let started=DiscordPresence.startTime(of:getpid())
        precondition(started != nil && Date().timeIntervalSince(started!) >= 0 && Date().timeIntervalSince(started!) < 120)
        precondition(DiscordPresence.startTime(of:99_999_999) == nil)
    }

    static func location() {
        let root=URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("ow2-root-\(getpid())")
        defer { try? FileManager.default.removeItem(at:root) }
        let fm=FileManager.default,users=root.appendingPathComponent("environment/drive_c/users")
        precondition(OverwatchLogTail.logURL(root:root) == nil)
        try! fm.createDirectory(at:users.appendingPathComponent("Public"),withIntermediateDirectories:true)
        precondition(OverwatchLogTail.logURL(root:root) == nil)
        try! fm.createDirectory(at:users.appendingPathComponent("crossover"),withIntermediateDirectories:true)
        precondition(OverwatchLogTail.logURL(root:root)?.path.hasSuffix("users/crossover/Documents/Overwatch/Logs/Overwatch.log") == true)
        try! fm.createDirectory(at:users.appendingPathComponent("zed/Documents/Overwatch/Logs"),withIntermediateDirectories:true)
        precondition(OverwatchLogTail.logURL(root:root)?.path.contains("users/zed/") == true)
    }

    static func folder()->URL {
        let url=URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("ow2-log-\(getpid())-\(UInt32.random(in:0..<1_000_000))")
        try! FileManager.default.createDirectory(at:url,withIntermediateDirectories:true)
        return url
    }
    static func append(_ text:String,to url:URL) {
        let handle=try! FileHandle(forWritingTo:url)
        handle.seekToEndOfFile();handle.write(Data(text.utf8));try? handle.close()
    }
    static func kinds(_ events:[PresenceEvent])->[String] {
        events.map { switch $0 { case .reset:return "reset";case .voiceReady:return "ready";case .voiceClosed:return "closed"
                                 case .channel(.team?,_):return "joined";case .channel(.party?,_):return "party";case .channel(.other?,_):return "other";case .channel(.match?,_):return "postgame";case .channel(nil,_):return "left";case .member:return "member";case .matchOver:return "over" } }
    }

    static func tail() {
        let dir=folder(),log=dir.appendingPathComponent("Overwatch.log"),now=Date()
        defer { try? FileManager.default.removeItem(at:dir) }
        // Opened in the middle of a game: what is already there is read first.
        try! (logLine("prism: Info: GPU 0",at:now)+"\r\n"+logLine(ready,at:now)+"\r\n"+logLine(join,at:now)+"\r\n").write(to:log,atomically:true,encoding:.utf8)
        let seen=Collected<PresenceEvent>()
        let follower=OverwatchLogTail(url:log,queue:DispatchQueue(label:"test-tail")) { seen.add($0) }
        follower.start()
        precondition(wait { kinds(seen.all) == ["ready","joined"] },"replay: \(kinds(seen.all))")
        // What is added is read as it comes; a line is told only when it is whole.
        append(logLine(leave,at:now),to:log)
        Thread.sleep(forTimeInterval:0.3)
        precondition(kinds(seen.all) == ["ready","joined"])
        append("\r\n",to:log)
        precondition(wait { kinds(seen.all) == ["ready","joined","left"] },"append: \(kinds(seen.all))")
        // The game starts the log over when it opens again: shorter, same file.
        try! (logLine(ready,at:now)+"\r\n").write(to:log,atomically:false,encoding:.utf8)
        precondition(wait { kinds(seen.all) == ["ready","joined","left","reset","ready"] },"truncated: \(kinds(seen.all))")
        // Or it is another file.
        try? FileManager.default.removeItem(at:log)
        try! (logLine("prism: Info: GPU 0",at:now)+"\r\n"+logLine(ready,at:now)+"\r\n"+logLine(join,at:now)+"\r\n").write(to:log,atomically:true,encoding:.utf8)
        precondition(wait { kinds(seen.all).suffix(3) == ["reset","ready","joined"] },"replaced: \(kinds(seen.all))")
        follower.stop()
        append(logLine(leave,at:now)+"\r\n",to:log)
        Thread.sleep(forTimeInterval:0.3)
        precondition(kinds(seen.all).last == "joined","a stopped follower says nothing more")

        // A log that is not there yet (the game's first run) is picked up when it appears.
        let later=dir.appendingPathComponent("later")
        try! FileManager.default.createDirectory(at:later,withIntermediateDirectories:true)
        let newLog=later.appendingPathComponent("Overwatch.log")
        let fresh=Collected<PresenceEvent>()
        let waiting=OverwatchLogTail(url:newLog,queue:DispatchQueue(label:"test-tail-2")) { fresh.add($0) }
        waiting.start()
        Thread.sleep(forTimeInterval:0.2)
        try! (logLine(ready,at:now)+"\r\n").write(to:newLog,atomically:true,encoding:.utf8)
        precondition(wait { kinds(fresh.all).contains("ready") },"created: \(kinds(fresh.all))")
        waiting.stop()
    }

    static func connection() {
        let server=FakeDiscord()
        let client=DiscordIPC(applicationID:"1234",paths:[server.path],pid:4242,spacing:0.5,burst:100,retry:0.3)
        client.set(["type":0,"details":"In Menus"])
        guard let fd=server.accept(),let hello=server.welcome(fd) else { preconditionFailure("no handshake") }
        precondition(hello["v"] as? Int == 1 && hello["client_id"] as? String == "1234")
        guard let first=server.frame(fd) else { preconditionFailure("no card") }
        precondition(first.opcode == DiscordFrame.frame && first.json["cmd"] as? String == "SET_ACTIVITY" && !(first.json["nonce"] as? String ?? "").isEmpty)
        let args=first.json["args"] as! [String:Any]
        precondition(args["pid"] as? Int == 4242 && (args["activity"] as! [String:Any])["details"] as? String == "In Menus")
        precondition(wait { client.connected })
        // Discord's ping is answered, or it hangs up.
        server.send(fd,DiscordFrame.ping,["nonce":"x"])
        precondition(server.frame(fd)?.opcode == DiscordFrame.pong)
        // Updates faster than the spacing are one: the last.
        client.set(["details":"one"]);client.set(["details":"two"])
        let asked=Date()
        precondition(details(server.card(fd)) == "two" && Date().timeIntervalSince(asked) > 0.05)
        // Taking the card down says so and closes.
        client.stop()
        precondition((server.card(fd) ?? nil) is NSNull && server.closed(fd) && !client.connected)
    }

    static func reconnect() {
        let server=FakeDiscord()
        let client=DiscordIPC(applicationID:"1234",paths:[server.path],spacing:0.1,burst:100,retry:0.3)
        client.set(["details":"A"])
        guard let first=server.accept(),server.welcome(first) != nil else { preconditionFailure("no handshake") }
        precondition(details(server.card(first)) == "A")
        // Discord closes (it was restarted); what is wanted when it is back is the latest card.
        Darwin.close(first)
        client.set(["details":"B"])
        guard let second=server.accept(),server.welcome(second) != nil else { preconditionFailure("no second handshake") }
        precondition(details(server.card(second)) == "B")
        client.stop()
    }

    static func absent() {
        // No Discord open: nothing to talk to, and nothing goes wrong.
        let client=DiscordIPC(paths:["/tmp/ow2-no-such-discord-\(getpid())/discord-ipc-0"],spacing:0.1,retry:0.2)
        client.set(["details":"A"])
        Thread.sleep(forTimeInterval:0.5)
        precondition(!client.connected)
        client.stop()
    }

    /// Discord's five updates in twenty seconds: a burst goes at once (spaced a little), the next waits for the window.
    static func rate() {
        let server=FakeDiscord()
        let client=DiscordIPC(applicationID:"1234",paths:[server.path],spacing:0.05,burst:3,window:1.5,retry:0.3)
        client.set(["details":"0"])
        guard let fd=server.accept(),server.welcome(fd) != nil,server.card(fd) != nil else { preconditionFailure("no handshake") }
        let start=Date()
        for n in 1...3 { client.set(["details":"\(n)"]);Thread.sleep(forTimeInterval:0.15) }
        // The first of the burst went at the start; two more by 0.5 s; the next only once the window has passed it.
        precondition(details(server.card(fd)) == "1" && details(server.card(fd)) == "2" && Date().timeIntervalSince(start) < 1.0)
        precondition(details(server.card(fd,3000)) == "3" && Date().timeIntervalSince(start) > 1.2,"the fourth update in a window waits for it")
        client.stop()
    }

    /// A player pressing the Settings control over and over: Discord gets no more than its allowance, and what it
    /// ends up showing is the last choice.
    static func spam() {
        let server=FakeDiscord(),dir=folder(),log=dir.appendingPathComponent("Overwatch.log")
        defer { try? FileManager.default.removeItem(at:dir) }
        let texts=PresenceTexts(menu:"In Menus",match:"In Match",group:"In a Group",badge:"Playing on Mac")
        let opened=Date().addingTimeInterval(-90)
        try! (logLine(ready,at:opened.addingTimeInterval(26))+"\r\n").write(to:log,atomically:true,encoding:.utf8)
        let presence=DiscordPresence(level:.live,texts:texts,ipc:DiscordIPC(applicationID:"1234",paths:[server.path],spacing:0.05,burst:3,window:1.5,retry:0.3))
        presence.begin(logURL:log,launched:opened)
        guard let fd=server.accept(),server.welcome(fd) != nil,details(server.card(fd)) == "In Menus" else { preconditionFailure("no first card") }
        let start=Date()
        for n in 0..<60 { presence.update(level:n % 2 == 0 ? .normal : .live,texts:texts) }
        // 60 changes; the last (n = 59) is Live.
        var seen:[String?]=[]
        while let card=server.card(fd,2500) { seen.append(details(card));if Date().timeIntervalSince(start) > 6 { break } }
        precondition(seen.count <= 3,"60 presses became \(seen.count) updates")
        precondition(seen.last as? String == "In Menus","the last choice (Live) is what ends up shown: \(seen)")
        presence.end()
    }

    static func endToEnd() {
        let server=FakeDiscord(),dir=folder(),log=dir.appendingPathComponent("Overwatch.log")
        defer { try? FileManager.default.removeItem(at:dir) }
        let texts=PresenceTexts(menu:"In Menus",match:"In Match",group:"In a Group",badge:"Playing on Mac")
        let opened=Date().addingTimeInterval(-90)
        try! (logLine("prism: Info: GPU 0",at:opened)+"\r\n").write(to:log,atomically:true,encoding:.utf8)
        let presence=DiscordPresence(level:.live,texts:texts,ipc:DiscordIPC(applicationID:"1234",paths:[server.path],spacing:0.1,burst:100,retry:0.3))
        presence.begin(logURL:log,launched:opened)
        guard let fd=server.accept(),server.welcome(fd) != nil else { preconditionFailure("no handshake") }
        // Before the menus: the game and a timer, and the badge, with no claim about where the player is.
        var card=(server.card(fd) ?? nil) as! [String:Any]
        precondition(card["details"] == nil && card["assets"] != nil && (card["timestamps"] as! [String:Int])["start"] == Int(opened.timeIntervalSince1970))
        append(logLine(ready,at:opened.addingTimeInterval(26))+"\r\n",to:log)
        precondition(details(server.card(fd)) == "In Menus")
        // A match that is backed out of while loading never shows.
        let blip=Date()
        append(logLine(join,at:blip)+"\r\n"+logLine(leave,at:blip.addingTimeInterval(2))+"\r\n",to:log)
        let backedOut=server.card(fd,1200)
        precondition(backedOut == nil || details(backedOut) != "In Match")
        // One that holds is a match, timed from its start, and menus again after.
        let started=Date().addingTimeInterval(-30)
        append(logLine(teammate,at:started)+"\r\n"+logLine(join,at:started)+"\r\n",to:log)
        let shown=server.card(fd)
        // The log keeps milliseconds; the card the second.
        let logged=stamper.date(from:stamper.string(from:started))!
        precondition(details(shown) == "In Match" && (((shown ?? nil) as! [String:Any])["timestamps"] as! [String:Int])["start"] == Int(logged.timeIntervalSince1970))
        append(logLine(leave,at:Date())+"\r\n",to:log)
        precondition(details(server.card(fd)) == "In Menus")
        // A group: the game keeps only the group's channel, so neither menus nor a match is claimed.
        append(logLine(partyJoin,at:Date())+"\r\n",to:log)
        precondition(details(server.card(fd)) == "In a Group")
        append(logLine(partyLeave,at:Date())+"\r\n",to:log)
        precondition(details(server.card(fd)) == "In Menus")
        // Normal says nothing the game says.
        presence.update(level:.normal,texts:texts)
        card=(server.card(fd) ?? nil) as! [String:Any]
        precondition(card["details"] == nil && card["assets"] == nil)
        presence.update(level:.live,texts:texts)
        // The log is read again before anything is shown: the first card is the right one, with no empty one before it.
        precondition(details(server.card(fd,2000)) == "In Menus","back at Live the log is read again from the start")
        precondition(server.card(fd,400) == nil,"and nothing else follows")
        // The game closing takes the card down.
        presence.end()
        precondition((server.card(fd) ?? nil) is NSNull && server.closed(fd))
    }
}
