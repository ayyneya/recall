import Foundation
import Darwin

// Discord Rich Presence. Discord on a Mac finds games by their Mac executable, and Overwatch's is
// listed only as the Windows overwatch.exe, so it never sees the game run under Wine. Recall tells
// the Discord app on this Mac itself, over the local socket every Discord client listens on
// (the same one Discord's own game libraries use): no account, no sign-in, no network. What goes
// there is the card (game, "In Menus" or "In Match", a timer, a small Recall badge) and nothing
// else; Discord shows it, or not, by the player's own Activity Privacy setting.
//
// The only live signals are the process starting and ending, and the voice chat lines Overwatch
// writes to its own Overwatch.log (a file the game keeps for itself; reading it is all this does).
// Nothing reads the game's memory, its screen or its network traffic.

/// How much of the game the card shows.
enum DiscordPresenceLevel: String, CaseIterable, Identifiable {
    /// What a PC player gets: "Playing Overwatch" and the time since the game opened.
    case normal
    /// Adds whether the player is in the menus or in a match, the match's own timer, and the
    /// Recall badge. Everything comes from this Mac.
    case live
    var id:String { rawValue }
    static let standard=DiscordPresenceLevel.live
    var title:String {
        switch self {
        case .normal: return L("Normal")
        case .live: return L("Live")
        }
    }
    /// Settings › General's line under the choice.
    var detail:String {
        switch self {
        case .normal: return L("Shows Overwatch and how long you’ve played, as it does for players on a PC.")
        case .live: return L("Also shows whether you’re in the menus or in a match, a timer for the match, and a small {0} badge. It’s read on this Mac, and only your Discord app receives it.",Brand.name)
        }
    }
}

/// The voice channel the game talks in. Overwatch has the player in the team's channel in a match (and
/// in the Practice Range), in the group's (PARTY) from the moment a group forms, and in the MATCH
/// channel, with the other team too, on the screen after a match (the voting cards).
enum VoiceChannel: Equatable { case team,party,match,other }

/// A line of Overwatch.log that tells where the player is. Times are the log's own.
enum PresenceEvent: Equatable {
    /// The log was started over (the game opened again) or replaced.
    case reset
    /// The voice service came up: the main menu is reached ("Auto-Join Enabled Flags 0000 -> 0005").
    case voiceReady(Date)
    /// It went down again (flags back to 0000), as the game closes.
    case voiceClosed(Date)
    /// The channel the game talks in changed ("Notified Lobby of Active channel NONE -> TEAM"); nil is none.
    case channel(VoiceChannel?,Date)
    /// The match is over: "Channel Enabled Flags 0005 -> 0007" gains the match-wide chat the game opens
    /// when the match ends (the results and the voting cards). It comes seconds before the game moves to
    /// the MATCH channel (Quick Play) or while the team's stays open until the player leaves (Arcade: 52
    /// seconds), and the Practice Range never has it. The flags going back is not told.
    case matchOver(Date)
    /// Another player joined the channel ("MemberAdded … false"; the player's own entry says true).
    /// In a match the team's voices arrive within a second or two of the channel; in the Practice
    /// Range and with bots there are none.
    case member(Date)

    private static let stamps:ISO8601DateFormatter={
        let formatter=ISO8601DateFormatter();formatter.formatOptions=[.withInternetDateTime,.withFractionalSeconds];return formatter
    }()
    /// `[1752] [ALW] [VoiceChat] [External(0)] [External()] [2026-10-24T16:31:07.933Z]: ==[VC] Notified Lobby of Active channel NONE -> TEAM`
    static func parse(_ line:String)->PresenceEvent? {
        guard line.contains("[VoiceChat]"),let end=line.range(of:"Z]: "),let open=line[..<end.lowerBound].lastIndex(of:"["),
              let time=stamps.date(from:String(line[line.index(after:open)..<end.upperBound].dropLast(3))) else { return nil }
        let message=line[end.upperBound...].trimmingCharacters(in:.whitespacesAndNewlines)
        func words(after marker:String)->[String]? {
            message.range(of:marker).map { message[$0.upperBound...].split(separator:" ").map(String.init) }
        }
        if let parts=words(after:"Notified Lobby of Active channel ") {
            guard parts.count == 3,parts[1] == "->" else { return nil }
            switch parts[2] {
            case "NONE": return .channel(nil,time)
            case "TEAM": return .channel(.team,time)
            case "PARTY": return .channel(.party,time)
            case "MATCH": return .channel(.match,time)
            default: return .channel(.other,time)
            }
        }
        if let parts=words(after:"Channel Enabled Flags ") {
            guard parts.count == 3,parts[1] == "->",let before=Int(parts[0],radix:16),let after=Int(parts[2],radix:16) else { return nil }
            // Only the change that turns match-wide chat on; another flag changing while it stays on is not the end.
            return before & 0x2 == 0 && after & 0x2 != 0 ? .matchOver(time) : nil
        }
        if let parts=words(after:"MemberAdded ") {
            return parts.count == 5 && parts[4] == "false" ? .member(time) : nil
        }
        if let parts=words(after:"Auto-Join Enabled Flags ") {
            guard parts.count == 3,parts[1] == "->" else { return nil }
            let before=parts[0].allSatisfy { $0 == "0" },after=parts[2].allSatisfy { $0 == "0" }
            if before && !after { return .voiceReady(time) }
            if !before && after { return .voiceClosed(time) }
        }
        return nil
    }
}

/// Where the player is, as far as the log says.
enum PresenceState: Equatable {
    /// No signal (yet): the menus are not reached, or the player has voice chat off, so nothing is claimed.
    case unknown
    case menu
    /// In a group: Overwatch then keeps only the group's voice channel, and the log says nothing of
    /// menus or matches, so nothing more is claimed (seen with a group of two, October 25).
    case group
    case match(since:Date)
}

/// Follows the log's events. Pure: the clock comes in, so the tests can move it.
struct PresenceTracker {
    /// A team channel that closes sooner than this was a match loading and backing out, not a
    /// match: the log shows joins of two to seven seconds. The match's timer still starts at the join.
    static let hold:TimeInterval=10
    /// Lines older than this belong to an earlier run of the game (a log not yet started over).
    let notBefore:Date
    private(set) var voiceReady=false
    private(set) var channel:VoiceChannel?
    /// Another player's voice has joined since the channel before this one closed.
    private(set) var others=false
    /// The match's results are showing (the team's channel stays open a while longer).
    private(set) var over=false
    private var since:Date?
    init(notBefore:Date = .distantPast) { self.notBefore=notBefore }
    mutating func apply(_ event:PresenceEvent) {
        switch event {
        case .reset: voiceReady=false;channel=nil;since=nil;others=false;over=false
        case .voiceReady(let time): if time >= notBefore { voiceReady=true }
        case .voiceClosed(let time): if time >= notBefore { voiceReady=false;channel=nil;since=nil;others=false;over=false }
        case .matchOver(let time): if time >= notBefore && channel == .team { over=true }
        case .member(let time): if time >= notBefore { others=true }
        case .channel(let next,let time):
            // The same channel again keeps the first time. Another channel ends what the results said
            // (a group goes from its own channel to the team's for each match, and back after it).
            guard time >= notBefore else { return }
            if next != channel { channel=next;since=next == nil ? nil : time;over=false }
            if next == nil { others=false;over=false }
        }
    }
    func state(at now:Date)->PresenceState {
        switch channel {
        case .team?:
            // The results are showing: the match is over, whatever the channel still says.
            if over { return voiceReady ? .menu : .unknown }
            // A team channel with nobody else in it is the Practice Range or a game with bots: nothing is claimed.
            guard let since,now.timeIntervalSince(since) >= Self.hold else { return voiceReady ? .menu : .unknown }
            return others ? .match(since:since) : .unknown
        case .party?: return .group
        // The screen after a match: it is over, and the player is back in the menus' flow.
        case .match?: return voiceReady ? .menu : .unknown
        case .other?: return .unknown
        case nil: return voiceReady ? .menu : .unknown
        }
    }
    /// Seconds until a team channel that is not held long enough yet counts as a match.
    func nextChange(at now:Date)->TimeInterval? {
        guard channel == .team,let since else { return nil }
        let rest=Self.hold-now.timeIntervalSince(since)
        return rest > 0 ? rest : nil
    }
}

/// The words on the card, in the app's language (the caller passes them in through L).
struct PresenceTexts: Equatable {
    var menu:String
    var match:String
    var group:String
    /// The hover text of the small Recall badge.
    var badge:String
}

enum PresenceCard {
    /// The card Discord shows for the state. Normal is what Discord shows a PC player; Live adds the
    /// state line and the badge. Times are Unix seconds. The player's own Discord decides whether
    /// anyone sees it.
    static func activity(state:PresenceState,level:DiscordPresenceLevel,launched:Date,texts:PresenceTexts)->[String:Any] {
        var card:[String:Any]=["type":0,"timestamps":["start":Int(launched.timeIntervalSince1970)]]
        guard level == .live else { return card }
        switch state {
        case .unknown: break
        case .menu: card["details"]=texts.menu
        case .group: card["details"]=texts.group
        case .match(let since): card["details"]=texts.match;card["timestamps"]=["start":Int(since.timeIntervalSince1970)]
        }
        card["assets"]=["small_image":Brand.discordBadge.absoluteString,"small_text":texts.badge]
        return card
    }
}

/// Discord's local protocol: each frame is a 4-byte opcode and a 4-byte length, both little-endian,
/// and then that many bytes of JSON.
enum DiscordFrame {
    static let handshake:UInt32=0,frame:UInt32=1,close:UInt32=2,ping:UInt32=3,pong:UInt32=4
    static func encode(_ opcode:UInt32,_ payload:Any)->Data? {
        guard JSONSerialization.isValidJSONObject(payload),let body=try? JSONSerialization.data(withJSONObject:payload) else { return nil }
        var data=Data()
        for value in [opcode,UInt32(body.count)] { withUnsafeBytes(of:value.littleEndian) { data.append(contentsOf:$0) } }
        data.append(body)
        return data
    }
}

/// Cuts the bytes read from the socket into frames; a frame can arrive in pieces or several at once.
struct DiscordFrameReader {
    struct Frame: Equatable { let opcode:UInt32;let body:Data }
    /// Discord's frames are small; a longer one is not Discord speaking.
    static let longest=1<<20
    private var bytes:[UInt8]=[]
    private(set) var broken=false
    mutating func feed(_ data:Data)->[Frame] {
        bytes+=data
        var frames:[Frame]=[]
        while bytes.count >= 8 {
            func word(_ at:Int)->UInt32 { UInt32(bytes[at])|UInt32(bytes[at+1])<<8|UInt32(bytes[at+2])<<16|UInt32(bytes[at+3])<<24 }
            let length=Int(word(4))
            if length > Self.longest { broken=true;bytes=[];break }
            guard bytes.count >= 8+length else { break }
            frames.append(Frame(opcode:word(0),body:Data(bytes[8..<8+length])))
            bytes.removeFirst(8+length)
        }
        return frames
    }
}

/// The connection to the Discord app on this Mac. Every call is safe from any thread; the socket is
/// used on one queue. Discord listens on discord-ipc-0 to -9 in the temporary folder (one per
/// running client); the first that answers is used. With no Discord open, or one that goes away, it
/// tries again every half minute for as long as there is a card to show.
final class DiscordIPC {
    private let queue=DispatchQueue(label:"org.overwatch2mac.discord-presence",qos:.utility)
    private let paths:[String]
    private let applicationID:String
    private let pid:Int32
    /// Discord accepts five updates in twenty seconds. Updates keep to that as a burst, so a change the
    /// player asks for (the Settings control) shows at once, with a short gap so that the several
    /// changes one event brings are one update.
    private let spacing:TimeInterval
    private let burst:Int
    private let window:TimeInterval
    private let retryDelay:TimeInterval
    private var descriptor:Int32 = -1
    private var source:DispatchSourceRead?
    private var reader=DiscordFrameReader()
    private var ready=false
    private var active=false
    /// What the card should be; nil takes it down.
    private var wanted:[String:Any]?
    private var pending=false
    /// When the updates of the last window were sent, oldest first.
    private var sent:[Date]=[]
    private var timer:DispatchWorkItem?
    private var handshakeTimeout:DispatchWorkItem?
    /// A try again is waiting: one at a time, however many cards come meanwhile.
    private var retrying=false
    private var tries=0
    private let lock=NSLock()
    private var connectedFlag=false,acceptedFlag=false
    /// Whether Discord has answered, for the support report.
    var connected:Bool { lock.lock();defer { lock.unlock() };return connectedFlag }
    /// Whether Discord took the last card sent (it answers each one, with an error when it refuses it).
    var accepted:Bool { lock.lock();defer { lock.unlock() };return acceptedFlag }
    /// How many times the sockets were looked for, for the tests.
    var attempts:Int { queue.sync { tries } }

    init(applicationID:String=Brand.discordApplicationID,paths:[String]?=nil,pid:Int32=getpid(),spacing:TimeInterval=0.5,burst:Int=5,window:TimeInterval=20,retry:TimeInterval=30) {
        self.applicationID=applicationID;self.pid=pid;self.spacing=spacing;self.burst=burst;self.window=window;self.retryDelay=retry
        self.paths=paths ?? Self.defaultPaths()
    }
    /// Where Discord's sockets are on a Mac: this user's own temporary folder, which no other account can
    /// write to. Not /tmp, where anyone could plant a socket for Recall to talk to.
    static func defaultPaths()->[String] {
        let folder=NSTemporaryDirectory()
        return (0..<10).map { (folder.hasSuffix("/") ? folder : folder+"/")+"discord-ipc-\($0)" }
    }
    /// Shows the card, or takes it down with nil. Until Discord is there it waits.
    func set(_ activity:[String:Any]?) {
        queue.async {
            self.wanted=activity;self.pending=true;self.active=true
            if self.ready { self.flush() } else if self.descriptor < 0 { self.connect() }
        }
    }
    /// Takes the card down and closes. Nothing more is sent until set is called again.
    func stop() {
        queue.sync {
            if ready { send(DiscordFrame.frame,activityCommand(nil)) }
            active=false;pending=false;wanted=nil
            timer?.cancel();timer=nil
            disconnect()
        }
    }

    private func activityCommand(_ activity:[String:Any]?)->[String:Any] {
        ["cmd":"SET_ACTIVITY","args":["pid":pid,"activity":activity.map { $0 as Any } ?? NSNull()],"nonce":UUID().uuidString]
    }
    private func flush() {
        guard ready,pending else { return }
        let now=Date()
        sent.removeAll { now.timeIntervalSince($0) >= window }
        var wait=spacing-now.timeIntervalSince(sent.last ?? .distantPast)
        if sent.count >= burst { wait=max(wait,window-now.timeIntervalSince(sent[sent.count-burst])) }
        if wait > 0 {
            guard timer == nil else { return }
            let work=DispatchWorkItem { [weak self] in self?.timer=nil;self?.flush() }
            timer=work;queue.asyncAfter(deadline:.now()+wait,execute:work)
            return
        }
        pending=false;sent.append(now)
        if !send(DiscordFrame.frame,activityCommand(wanted)) { disconnect();scheduleRetry() }
    }
    private func connect() {
        guard active,descriptor < 0 else { return }
        tries+=1
        for path in paths {
            let fd=socket(AF_UNIX,SOCK_STREAM,0)
            guard fd >= 0 else { continue }
            var on:Int32=1
            setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&on,socklen_t(MemoryLayout<Int32>.size))
            var address=sockaddr_un()
            address.sun_family=sa_family_t(AF_UNIX)
            let capacity=MemoryLayout.size(ofValue:address.sun_path)
            guard path.utf8.count < capacity else { close(fd);continue }
            withUnsafeMutablePointer(to:&address.sun_path) { $0.withMemoryRebound(to:CChar.self,capacity:capacity) { _ = strlcpy($0,path,capacity) } }
            let result=withUnsafePointer(to:&address) { $0.withMemoryRebound(to:sockaddr.self,capacity:1) { Darwin.connect(fd,$0,socklen_t(MemoryLayout<sockaddr_un>.size)) } }
            guard result == 0 else { close(fd);continue }
            // Only a program of this user's own is Discord for this purpose.
            var owner:uid_t=0,group:gid_t=0
            guard getpeereid(fd,&owner,&group) == 0,owner == getuid() else { close(fd);continue }
            _ = fcntl(fd,F_SETFL,fcntl(fd,F_GETFL)|O_NONBLOCK)
            descriptor=fd;reader=DiscordFrameReader();ready=false
            let reading=DispatchSource.makeReadSource(fileDescriptor:fd,queue:queue)
            reading.setEventHandler { [weak self] in self?.readable() }
            // Closed only once the source has let go of it, so a new socket never gets its number meanwhile.
            reading.setCancelHandler { close(fd) }
            reading.resume();source=reading
            guard send(DiscordFrame.handshake,["v":1,"client_id":applicationID]) else { disconnect();continue }
            // Discord answers with READY; one that does not within a few seconds is not usable.
            let timeout=DispatchWorkItem { [weak self] in
                guard let self,!self.ready else { return }
                self.disconnect();self.scheduleRetry()
            }
            handshakeTimeout=timeout;queue.asyncAfter(deadline:.now()+5,execute:timeout)
            return
        }
        scheduleRetry()
    }
    private func readable() {
        var buffer=[UInt8](repeating:0,count:4096)
        let count=read(descriptor,&buffer,buffer.count)
        if count == 0 || (count < 0 && errno != EAGAIN && errno != EINTR) { disconnect();scheduleRetry();return }
        guard count > 0 else { return }
        let frames=reader.feed(Data(buffer[0..<count]))
        if reader.broken { disconnect();scheduleRetry();return }
        for frame in frames {
            switch frame.opcode {
            case DiscordFrame.ping: send(DiscordFrame.pong,(try? JSONSerialization.jsonObject(with:frame.body)) ?? [String:Any]())
            case DiscordFrame.close: disconnect();scheduleRetry();return
            case DiscordFrame.frame:
                guard let message=try? JSONSerialization.jsonObject(with:frame.body) as? [String:Any] else { break }
                if message["evt"] as? String == "READY" {
                    handshakeTimeout?.cancel();ready=true;pending=true
                    lock.lock();connectedFlag=true;lock.unlock()
                    flush()
                } else if message["cmd"] as? String == "SET_ACTIVITY" {
                    let taken=message["evt"] as? String != "ERROR"
                    lock.lock();acceptedFlag=taken;lock.unlock()
                }
            default: break
            }
        }
    }
    @discardableResult private func send(_ opcode:UInt32,_ payload:Any)->Bool {
        guard descriptor >= 0,let data=DiscordFrame.encode(opcode,payload) else { return false }
        var sent=0
        let ok=data.withUnsafeBytes { raw -> Bool in
            while sent < data.count {
                let n=write(descriptor,raw.baseAddress!+sent,data.count-sent)
                if n > 0 { sent+=n } else if n < 0 && (errno == EINTR) { continue } else { return false }
            }
            return true
        }
        return ok
    }
    private func disconnect() {
        // The source closes the socket (its cancel handler); one is always made with it.
        source?.cancel();source=nil;descriptor = -1
        handshakeTimeout?.cancel();handshakeTimeout=nil
        ready=false
        lock.lock();connectedFlag=false;acceptedFlag=false;lock.unlock()
    }
    private func scheduleRetry() {
        guard active,!retrying else { return }
        retrying=true
        queue.asyncAfter(deadline:.now()+retryDelay) { [weak self] in
            guard let self else { return }
            self.retrying=false
            guard self.active,self.descriptor < 0 else { return }
            self.pending=true;self.connect()
        }
    }
}

/// Follows Overwatch.log while the game runs, and tells what each new line means. It reads the file
/// once when it starts (so Recall opened in the middle of a game still knows where the player is),
/// then only what is added, when the system says the file or its folder changed: nothing polls. The
/// game starts the log over each time it opens, and the follower notices (the file is shorter, or
/// another file) and says so with a reset. Nothing in the game's folders is written or created.
final class OverwatchLogTail {
    private let url:URL
    private let queue:DispatchQueue
    private let handler:([PresenceEvent])->Void
    private var descriptor:Int32 = -1
    private var identity:UInt64=0
    private var offset:off_t=0
    private var partial:[UInt8]=[]
    private var fileSource:DispatchSourceFileSystemObject?
    private var folderSource:DispatchSourceFileSystemObject?
    private var stopped=true
    /// What is read into, kept from one read to the next.
    private var chunk=[UInt8](repeating:0,count:65536)
    /// Marks the queue with its own identity, so stop can tell it is called from this queue's own work
    /// (the owner's, which stops one follower to start another) and not wait for itself; another
    /// follower's queue is not this one.
    private static let onQueue=DispatchSpecificKey<ObjectIdentifier>()
    private var onOwnQueue:Bool { DispatchQueue.getSpecific(key:Self.onQueue) == ObjectIdentifier(queue) }
    init(url:URL,queue:DispatchQueue,handler:@escaping ([PresenceEvent])->Void) {
        self.url=url;self.queue=queue;self.handler=handler
        queue.setSpecific(key:Self.onQueue,value:ObjectIdentifier(queue))
    }

    /// The log of the Overwatch under this data folder: the Windows user's Documents, in the
    /// engine's prefix (the user is named by the engine, not by Recall, so the folders are looked at).
    static func logURL(root:URL)->URL? {
        let users=root.appendingPathComponent("environment/drive_c/users")
        let names=((try? FileManager.default.contentsOfDirectory(atPath:users.path)) ?? []).filter { $0 != "Public" && !$0.hasPrefix(".") }.sorted()
        func log(_ name:String)->URL { users.appendingPathComponent(name).appendingPathComponent("Documents/Overwatch/Logs/Overwatch.log") }
        return names.first { FileManager.default.fileExists(atPath:log($0).deletingLastPathComponent().path) }.map(log) ?? names.first.map(log)
    }

    /// From the owner's own queue it reads what is there before it returns, so the owner shows the
    /// right card at once and not an empty one first.
    func start() {
        let begin={ self.stopped=false;self.watchFolder();self.check() }
        if onOwnQueue { begin() } else { queue.async(execute:begin) }
    }
    func stop() {
        let teardown={
            self.stopped=true
            self.folderSource?.cancel();self.folderSource=nil
            self.closeFile()
        }
        if onOwnQueue { teardown() } else { queue.sync(execute:teardown) }
    }

    /// Watches the Logs folder. A first launch has none until the game makes it (which can take a
    /// while), so until then the nearest folder above it that is there is watched, and the watch
    /// moves down as each folder appears.
    private func watchFolder() {
        guard folderSource == nil,!stopped else { return }
        let logs=url.deletingLastPathComponent()
        var folder=logs,fd=open(folder.path,O_EVTONLY)
        while fd < 0 && folder.path != "/" { folder.deleteLastPathComponent();fd=open(folder.path,O_EVTONLY) }
        guard fd >= 0 else { return }
        let waiting=folder.path != logs.path
        let source=DispatchSource.makeFileSystemObjectSource(fileDescriptor:fd,eventMask:.write,queue:queue)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            if waiting { self.folderSource?.cancel();self.folderSource=nil;self.watchFolder() }
            self.check()
        }
        source.setCancelHandler { close(fd) }
        source.resume();folderSource=source
        // The next folder down may have appeared before the watch was set up (the game makes them all at once).
        if waiting,FileManager.default.fileExists(atPath:folder.appendingPathComponent(logs.pathComponents[folder.pathComponents.count]).path) {
            source.cancel();folderSource=nil;watchFolder()
        }
    }
    private func closeFile() {
        // The file's source closes it (its cancel handler); one is always made with it.
        fileSource?.cancel();fileSource=nil;descriptor = -1
        offset=0;partial=[]
    }
    /// The file may be new, gone or another file than the one followed.
    private func check() {
        guard !stopped else { return }
        var status=stat()
        guard stat(url.path,&status) == 0 else {
            if descriptor >= 0 { closeFile();handler([.reset]) }
            return
        }
        if descriptor >= 0 && UInt64(status.st_ino) != identity { closeFile();handler([.reset]) }
        if descriptor < 0 {
            let fd=open(url.path,O_RDONLY|O_CLOEXEC)
            guard fd >= 0 else { return }
            descriptor=fd;identity=UInt64(status.st_ino);offset=0;partial=[]
            let source=DispatchSource.makeFileSystemObjectSource(fileDescriptor:fd,eventMask:[.write,.extend,.delete,.rename],queue:queue)
            source.setEventHandler { [weak self] in
                guard let self else { return }
                if source.data.contains(.delete) || source.data.contains(.rename) { self.check() } else { self.readNew() }
            }
            source.setCancelHandler { close(fd) }
            source.resume();fileSource=source
        }
        readNew()
    }
    private func readNew() {
        guard descriptor >= 0 else { return }
        var events:[PresenceEvent]=[]
        var status=stat()
        if fstat(descriptor,&status) == 0,status.st_size < offset { offset=0;partial=[];events.append(.reset) }
        while true {
            let count=pread(descriptor,&chunk,chunk.count,offset)
            guard count > 0 else { break }
            offset+=off_t(count);partial+=chunk[0..<count]
            // Each whole line, then what is read is dropped once (not line by line, which moves the rest each time).
            var start=partial.startIndex
            while let end=partial[start...].firstIndex(of:10) {
                if let event=PresenceEvent.parse(String(decoding:partial[start..<end],as:UTF8.self)) { events.append(event) }
                start=end+1
            }
            partial.removeSubrange(..<start)
        }
        if !events.isEmpty { handler(events) }
    }
}

/// The card for the game that is running: starts and stops with the game, follows the log (at
/// Live), and keeps Discord's card current. Safe to call from any thread.
final class DiscordPresence {
    private let ipc:DiscordIPC
    private let queue=DispatchQueue(label:"org.overwatch2mac.discord-presence-state",qos:.utility)
    private var level:DiscordPresenceLevel
    private var texts:PresenceTexts
    private var logURL:URL?
    private var launched=Date()
    private var tracker=PresenceTracker()
    private var tail:OverwatchLogTail?
    private var running=false
    private var shown:NSDictionary?
    private var promotion:DispatchWorkItem?
    init(level:DiscordPresenceLevel,texts:PresenceTexts,ipc:DiscordIPC=DiscordIPC()) { self.level=level;self.texts=texts;self.ipc=ipc }
    /// Whether Discord has answered, and whether it took the last card (for the support report).
    var connected:Bool { ipc.connected }
    var accepted:Bool { ipc.accepted }
    /// When a process started, from the system's own record. macOS gives no launch date for Overwatch's
    /// app (it is started by Wine, not by the Finder), and the timer on the card counts from the start.
    static func startTime(of pid:pid_t)->Date? {
        var info=proc_bsdinfo()
        guard proc_pidinfo(pid,PROC_PIDTBSDINFO,0,&info,Int32(MemoryLayout<proc_bsdinfo>.size)) == Int32(MemoryLayout<proc_bsdinfo>.size) else { return nil }
        return Date(timeIntervalSince1970:TimeInterval(info.pbi_start_tvsec)+TimeInterval(info.pbi_start_tvusec)/1_000_000)
    }

    /// The game is running. `launched` is when it opened; nil when that is not known, which counts from now.
    func begin(logURL:URL?,launched:Date?) {
        queue.async {
            guard !self.running else { return }
            self.running=true;self.logURL=logURL;self.launched=launched ?? Date()
            self.tracker=PresenceTracker(notBefore:launched.map { $0.addingTimeInterval(-5) } ?? .distantPast)
            self.followLog();self.refresh()
        }
    }
    /// The game closed: the card comes down.
    func end() {
        // All in one step on the queue, Discord's included, so a begin from another thread comes
        // wholly before or wholly after (the connection's queue never waits for this one).
        queue.sync {
            guard running else { return }
            running=false
            tail?.stop();tail=nil
            promotion?.cancel();promotion=nil
            shown=nil
            ipc.stop()
        }
    }
    func update(level:DiscordPresenceLevel,texts:PresenceTexts) {
        queue.async {
            let changed=level != self.level
            self.level=level;self.texts=texts
            if changed && self.running { self.followLog() }
            self.refresh()
        }
    }

    /// Only Live reads the log; Normal shows nothing the game says.
    private func followLog() {
        tail?.stop();tail=nil
        tracker=PresenceTracker(notBefore:tracker.notBefore)
        guard level == .live,let logURL else { return }
        let tail=OverwatchLogTail(url:logURL,queue:queue) { [weak self] events in
            guard let self,self.running else { return }
            for event in events { self.tracker.apply(event) }
            self.refresh()
        }
        self.tail=tail;tail.start()
    }
    private func refresh() {
        guard running else { return }
        let now=Date()
        let card=PresenceCard.activity(state:tracker.state(at:now),level:level,launched:launched,texts:texts)
        if shown != card as NSDictionary { shown=card as NSDictionary;ipc.set(card) }
        promotion?.cancel();promotion=nil
        if let wait=tracker.nextChange(at:now) {
            let work=DispatchWorkItem { [weak self] in self?.refresh() }
            promotion=work;queue.asyncAfter(deadline:.now()+wait+0.05,execute:work)
        }
    }
}
