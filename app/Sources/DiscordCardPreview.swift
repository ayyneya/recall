import SwiftUI
import AppKit

// Discord's card, drawn from the very activity Recall sends Discord (SET_ACTIVITY's), so the preview can't
// say something the real card wouldn't. Discord's own colours and sizes, as the design has them; on a phone,
// Discord shows the lines and pictures but no hover text and no buttons.

enum DiscordColors {
    static let popout=Color(red:35/255,green:36/255,blue:40/255)
    static let card=Color(red:71/255,green:71/255,blue:77/255)
    static let phoneCard=Color(red:43/255,green:45/255,blue:49/255)
    static let title=Color(red:242/255,green:243/255,blue:245/255)
    static let text=Color(red:219/255,green:222/255,blue:225/255)
    static let muted=Color(red:181/255,green:186/255,blue:193/255)
    static let timer=Color(red:134/255,green:197/255,blue:153/255)
    static let button=Color(red:97/255,green:98/255,blue:106/255)
    static let tile=Color(red:43/255,green:45/255,blue:49/255)
    static let stage=Color(red:30/255,green:31/255,blue:34/255)
    static let online=Color(red:35/255,green:165/255,blue:90/255)
    /// The part being changed, outlined on the card.
    static let pick=Color(red:1,green:128/255,blue:64/255)
}

/// Pictures from the web (heroes, ranks, the player's icon), kept once loaded. Discord loads the same ones.
@MainActor final class RemoteImages {
    static let shared=RemoteImages()
    private var images:[URL:NSImage]=[:]
    private var loading:Set<URL>=[]
    private var waiting:[URL:[()->Void]]=[:]
    func image(_ url:URL)->NSImage? { images[url] ?? bundled(url) }
    /// The Mac badge is the app's own copy: the same file Discord loads, there before it's on the main branch.
    private func bundled(_ url:URL)->NSImage? {
        guard url == Brand.macBadge,let image=Bundle.main.url(forResource:"MacBadge",withExtension:"png").flatMap(NSImage.init(contentsOf:)) else { return nil }
        images[url]=image
        return image
    }
    func load(_ url:URL,done:@escaping ()->Void) {
        if image(url) != nil { done();return }
        waiting[url,default:[]].append(done)
        guard !loading.contains(url) else { return }
        loading.insert(url)
        var request=URLRequest(url:url,cachePolicy:.returnCacheDataElseLoad,timeoutInterval:15)
        request.setValue(Brand.name,forHTTPHeaderField:"User-Agent")
        URLSession.shared.dataTask(with:request) { data,_,_ in
            let image=data.flatMap(NSImage.init(data:))
            Task { @MainActor in
                self.loading.remove(url);if let image { self.images[url]=image }
                self.waiting.removeValue(forKey:url)?.forEach { $0() }
            }
        }.resume()
    }
    /// Loads them all, for a picture of the window taken at once (the tests' renders).
    func preload(_ urls:[URL]) async {
        await withCheckedContinuation { (done:CheckedContinuation<Void,Never>) in
            var left=Set(urls).count
            if left == 0 { done.resume();return }
            for url in Set(urls) { load(url) { left-=1;if left == 0 { done.resume() } } }
        }
    }
    /// The game's own picture, which Discord shows when Recall sends none: the icon Discord keeps for
    /// Overwatch, looked up once from Discord's public application record.
    private(set) var gameIcon:URL?
    private var lookingUp=false
    func lookUpGameIcon(done:@escaping ()->Void={}) {
        guard gameIcon == nil,!lookingUp,let record=URL(string:"https://discord.com/api/v10/applications/\(Brand.discordApplicationID)/rpc") else { done();return }
        lookingUp=true
        URLSession.shared.dataTask(with:URLRequest(url:record,cachePolicy:.returnCacheDataElseLoad,timeoutInterval:15)) { data,_,_ in
            let icon=(data.flatMap { try? JSONSerialization.jsonObject(with:$0) } as? [String:Any])?["icon"] as? String
            Task { @MainActor in
                self.lookingUp=false
                if let icon,!icon.isEmpty,icon.allSatisfy({ $0.isASCII && $0.isHexDigit }) { self.gameIcon=URL(string:"https://cdn.discordapp.com/app-icons/\(Brand.discordApplicationID)/\(icon).png?size=256") }
                done()
            }
        }.resume()
    }
}
struct RemoteImage<Placeholder:View>: View {
    let url:URL?
    var fill=true
    @ViewBuilder var placeholder:Placeholder
    @State private var loaded:NSImage?
    var body:some View {
        Group {
            if let image=loaded ?? url.flatMap({ RemoteImages.shared.image($0) }) {
                Image(nsImage:image).resizable().interpolation(.high).aspectRatio(contentMode:fill ? .fill : .fit)
            } else { placeholder }
        }
        .task(id:url) {
            guard let url else { loaded=nil;return }
            if let image=RemoteImages.shared.image(url) { loaded=image;return }
            RemoteImages.shared.load(url) { loaded=RemoteImages.shared.image(url) }
        }
    }
}
/// Overwatch's own picture, as Discord shows it when the card sends none.
struct GameIcon: View {
    @State private var url=RemoteImages.shared.gameIcon
    var body:some View {
        RemoteImage(url:url) { Color.clear }
            .task { RemoteImages.shared.lookUpGameIcon { url=RemoteImages.shared.gameIcon } }
    }
}

// MARK: the design's tooltips

/// The design's own tooltips: a dark bubble 200 ms after the pointer stops on something, above it (or below),
/// kept inside the sheet. Discord's (what friends see when they point at the card) wear Discord's mark and font;
/// they don't exist on a phone.
@MainActor @Observable final class DesignTips {
    nonisolated static let space="discordSheet"
    struct Tip: Equatable { let text:String;let discord:Bool;let frame:CGRect;let below:Bool }
    var tip:Tip?
    /// The preview shows a phone: Discord's tips don't show.
    var phone=false
    @ObservationIgnored var discordTipShown:()->Void={}
    @ObservationIgnored private var waiting:Task<Void,Never>?
    func show(_ tip:Tip) {
        guard !(tip.discord && phone) else { return }
        waiting?.cancel()
        waiting=Task { [weak self] in
            try? await Task.sleep(for:.milliseconds(200))
            guard let self,!Task.isCancelled else { return }
            self.tip=tip
            if tip.discord { self.discordTipShown() }
        }
    }
    func hide(_ text:String?=nil) {
        waiting?.cancel()
        if text == nil || tip?.text == text { tip=nil }
    }
}
extension View {
    /// A tooltip in the design's style (needs a DesignTipLayer above it); nil or empty shows none.
    func designTip(_ text:String?,discord:Bool=false,below:Bool=false)->some View { modifier(DesignTipped(text:text,discord:discord,below:below)) }
}
private struct DesignTipped: ViewModifier {
    let text:String?
    let discord:Bool
    let below:Bool
    @Environment(DesignTips.self) private var tips:DesignTips?
    @State private var frame=CGRect.zero
    func body(content:Content)->some View {
        content
            .onGeometryChange(for:CGRect.self) { $0.frame(in:.named(DesignTips.space)) } action:{ frame=$0 }
            .onHover { inside in
                guard let tips,let text,!text.isEmpty else { return }
                if inside { tips.show(.init(text:text,discord:discord,frame:frame,below:below)) } else { tips.hide(text) }
            }
            .onDisappear { if let text { tips?.hide(text) } }
    }
}
/// Where the tooltips show: the sheet, with its own coordinate space.
struct DesignTipLayer<Content:View>: View {
    let tips:DesignTips
    @ViewBuilder var content:Content
    @State private var size=CGSize.zero
    var body:some View {
        content
            .coordinateSpace(.named(DesignTips.space))
            .environment(tips)
            .overlay(alignment:.topLeading) {
                GeometryReader { sheet in
                    if let tip=tips.tip {
                        bubble(tip)
                            .onGeometryChange(for:CGSize.self) { $0.size } action:{ size=$0 }
                            .offset(place(tip,in:sheet.size))
                            .transition(.asymmetric(insertion:.opacity.combined(with:.offset(y:tip.below ? -3 : 3)),removal:.opacity))
                            .id(tip.text)
                    }
                }.allowsHitTesting(false)
            }
            .animation(.easeOut(duration:0.16),value:tips.tip)
    }
    private func bubble(_ tip:DesignTips.Tip)->some View {
        HStack(alignment:.top,spacing:7) {
            if tip.discord { DesignIcon("ic:baseline-discord",size:13).foregroundStyle(Color(red:150/255,green:160/255,blue:1)).padding(.top,2) }
            Text(tip.text).font(tip.discord ? .discord(13,500) : LauncherStyle.font(11.5,.medium))
                .lineHeight(1.4,tip.discord ? DiscordFont.nsFont(13,500) : NSFont.systemFont(ofSize:11.5,weight:.medium))
                .fixedSize(horizontal:false,vertical:true)
        }
        .foregroundStyle(DiscordColors.ink(0.92))
        .padding(.horizontal,tip.discord ? 10 : 9).padding(.vertical,tip.discord ? 7 : 6)
        .frame(maxWidth:260,alignment:.leading).fixedSize(horizontal:true,vertical:false)
        .background(Color(red:17/255,green:18/255,blue:20/255).opacity(0.95),in:RoundedRectangle(cornerRadius:8,style:.continuous))
        .overlay { RoundedRectangle(cornerRadius:8,style:.continuous).strokeBorder(.white.opacity(0.07),lineWidth:1) }
        // One shadow for the whole bubble, not one for each line of text in it.
        .compositingGroup().shadow(color:.black.opacity(0.5),radius:14,y:10)
        .environment(\.colorScheme,.dark)
    }
    /// Centred on what it's about, above it (below when asked, or when there's no room), inside the sheet.
    private func place(_ tip:DesignTips.Tip,in sheet:CGSize)->CGSize {
        let x=min(max(10,tip.frame.midX-size.width/2),sheet.width-size.width-10)
        var y=tip.below ? tip.frame.maxY+8 : tip.frame.minY-size.height-8
        if y < 10 || y+size.height > sheet.height-10 { y=tip.below ? tip.frame.minY-size.height-8 : tip.frame.maxY+8 }
        return CGSize(width:x,height:y)
    }
}

// MARK: the card

/// What takes turns, pinned on the card (My cards): how many pictures, badges, Line 1s and Line 2s.
struct CardPins: Equatable { var picture=0,badge=0,lineOne=0,lineTwo=0 }

/// The card, as Discord draws it (desktop or phone).
struct DiscordCardView: View {
    let activity:[String:Any]
    var now=Date()
    var phone=false
    /// The part being changed (Customize), outlined; a click on a part picks it.
    var selected:DiscordStudio.Slot?
    var pick:((DiscordStudio.Slot)->Void)?
    /// Counts of what takes turns, pinned to the parts (My cards).
    var pins:CardPins?
    /// Line 2's place in its turn while lines take turns (Settings › Discord), as a small ring after it.
    var lineTwoTurn:(done:Double,label:String)?
    private var assets:[String:String] { activity["assets"] as? [String:String] ?? [:] }
    private var details:String? { activity["details"] as? String }
    private var state:String? {
        guard let state=activity["state"] as? String else { return nil }
        // Discord puts the party's size after line 2.
        if let size=(activity["party"] as? [String:Any])?["size"] as? [Int],size.count == 2 { return "\(state) (\(L("{0} of {1}",String(size[0]),String(size[1]))))" }
        return state
    }
    private var buttons:[String] { (activity["buttons"] as? [[String:String]] ?? []).compactMap { $0["label"] } }
    private var elapsed:String {
        let start=(activity["timestamps"] as? [String:Int])?["start"] ?? Int(now.timeIntervalSince1970)
        return Self.clock(max(0,Int(now.timeIntervalSince1970)-start))
    }
    static func clock(_ seconds:Int)->String {
        let hours=seconds/3600
        return hours > 0 ? String(format:"%d:%02d:%02d",hours,seconds/60%60,seconds%60) : String(format:"%d:%02d",seconds/60,seconds%60)
    }
    var body:some View {
        Group { if phone { phoneCard } else { desktopCard } }
            .overlayPreferenceValue(CardPartBounds.self) { bounds in
                if let selected,let anchor=bounds[selected] { PartHighlight(slot:selected,anchor:anchor).transition(.afterMove) }
            }
            .environment(\.colorScheme,.dark)
    }
    private var desktopCard:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Text(L("Playing")).font(.discord(13,700)).foregroundStyle(DiscordColors.title)
                Spacer()
                DesignIcon("mdi:dots-horizontal",size:18).foregroundStyle(DiscordColors.text)
            }.frame(height:18)
            HStack(alignment:.center,spacing:12) {
                pictures(size:64,radius:8,badge:28,inner:22,badgeBack:DiscordColors.card)
                VStack(alignment:.leading,spacing:1) {
                    Text(verbatim:"Overwatch").font(.discord(16,600)).foregroundStyle(DiscordColors.title).frame(height:20)
                        .designTip(phone ? nil : L("Always shown. Discord takes the name from the game."))
                    lines(height:18,pinned:true)
                }.font(.discord(14)).foregroundStyle(DiscordColors.text).frame(maxWidth:.infinity,alignment:.leading)
            }
            if !buttons.isEmpty {
                part(.buttons) {
                    HStack(spacing:8) {
                        ForEach(buttons,id:\.self) { label in
                            Text(verbatim:label).font(.discord(14,500)).foregroundStyle(.white).lineLimit(1)
                                .frame(maxWidth:.infinity).frame(height:32).background(DiscordColors.button,in:RoundedRectangle(cornerRadius:8,style:.continuous))
                        }
                    }
                }
            }
        }
        .padding(EdgeInsets(top:10,leading:12,bottom:12,trailing:12))
        .background(DiscordColors.card,in:RoundedRectangle(cornerRadius:8,style:.continuous))
    }
    private var phoneCard:some View {
        VStack(alignment:.leading,spacing:12) {
            Text(L("Playing")).font(.discord(14,700)).foregroundStyle(DiscordColors.title)
            HStack(alignment:.center,spacing:14) {
                pictures(size:76,radius:10,badge:30,inner:24,badgeBack:DiscordColors.phoneCard)
                VStack(alignment:.leading,spacing:0) {
                    Text(verbatim:"Overwatch").font(.discord(17,600)).foregroundStyle(DiscordColors.title).frame(height:22)
                    lines(height:20,pinned:false)
                }.font(.discord(15)).foregroundStyle(DiscordColors.text).frame(maxWidth:.infinity,alignment:.leading)
            }
        }
        .padding(14)
        .background(DiscordColors.phoneCard,in:RoundedRectangle(cornerRadius:14,style:.continuous))
    }
    /// Line 1, Line 2 and the timer.
    @ViewBuilder private func lines(height:CGFloat,pinned:Bool)->some View {
        if let details {
            HStack(spacing:7) {
                part(.lineOne,text:true) { Text(verbatim:details).lineLimit(1) }
                if pinned,let count=pins?.lineOne,count > 1 { Pin(count:count) }
            }.frame(height:height)
        }
        if let state {
            HStack(spacing:7) {
                part(.lineTwo,text:true) { Text(verbatim:state).lineLimit(1) }
                if pinned,let count=pins?.lineTwo,count > 1 { Pin(count:count) }
                if pinned,let turn=lineTwoTurn { TurnRing(done:turn.done).accessibilityLabel(turn.label) }
            }.frame(height:height)
        }
        part(.timer,text:true) {
            HStack(spacing:5) { DesignIcon("mdi:controller",size:16);Text(verbatim:elapsed).monospacedDigit() }.foregroundStyle(DiscordColors.timer)
        }.frame(height:height)
    }
    /// The large picture with its badge.
    private func pictures(size:CGFloat,radius:CGFloat,badge:CGFloat,inner:CGFloat,badgeBack:Color)->some View {
        let large=assets["large_image"].flatMap(URL.init(string:)),small=assets["small_image"].flatMap(URL.init(string:))
        return part(.picture,text:false) {
            Group {
                if let large { RemoteImage(url:large) { DiscordColors.tile } } else { GameIcon() }
            }
            .frame(width:size,height:size).background(large == nil ? .clear : DiscordColors.tile)
            .clipShape(RoundedRectangle(cornerRadius:radius,style:.continuous))
            .designTip(phone ? nil : assets["large_text"],discord:true,below:true)
        }
        .overlay(alignment:.topLeading) { if let count=pins?.picture,count > 1 { Pin(count:count).offset(x:-7,y:-7) } }
        .overlay(alignment:.bottomTrailing) {
            if let small {
                part(.badge,text:false) {
                    BadgeImage(url:small,size:inner,back:phone ? DiscordColors.stage : DiscordColors.tile)
                        .frame(width:badge,height:badge).background(badgeBack,in:Circle())
                        .designTip(phone ? nil : assets["small_text"],discord:true,below:true)
                }
                .offset(x:6,y:6)
                .overlay(alignment:.topLeading) { if let count=pins?.badge,count > 1 { Pin(count:count).offset(x:-(size-24-badge+6),y:-(size-30-badge+6)) } }
            }
        }
    }
    /// A part of the card: its bounds for the outline, and a click picks it (Customize).
    private func part<Content:View>(_ slot:DiscordStudio.Slot,text:Bool=true,@ViewBuilder _ content:()->Content)->some View {
        content()
            .anchorPreference(key:CardPartBounds.self,value:.bounds) { [slot:$0] }
            .contentShape(Rectangle())
            .onTapGesture { pick?(slot) }
            .pointerStyle(pick == nil ? nil : .link)
    }
}

/// The badge: the rank's emblem, whole, or Recall's icon, filling the circle.
struct BadgeImage: View {
    let url:URL
    let size:CGFloat
    var back:Color=DiscordColors.tile
    var body:some View {
        let icon=url == Brand.discordBadge
        RemoteImage(url:url,fill:icon) { back }
            .scaleEffect(icon ? 1.25 : 1)
            .frame(width:size,height:size).background(back).clipShape(Circle())
    }
}
/// "⟳ 3": a list of this many takes turns here.
struct Pin: View {
    let count:Int
    var body:some View {
        HStack(spacing:2) { DesignIcon("lucide:repeat",size:9);Text("\(count)").monospacedDigit() }
            .font(LauncherStyle.font(10,.heavy)).foregroundStyle(Color(red:28/255,green:28/255,blue:32/255))
            .padding(.leading,4).padding(.trailing,5).frame(height:16)
            .background(DiscordColors.accent,in:Capsule())
            .overlay { Capsule().strokeBorder(DiscordColors.card,lineWidth:2).padding(-2) }
            .allowsHitTesting(false)
    }
}
/// How far Line 2 is through its turn, as a ring.
struct TurnRing: View {
    let done:Double
    var body:some View {
        ZStack {
            Circle().stroke(.white.opacity(0.16),lineWidth:2.6)
            Circle().trim(from:0,to:done).stroke(DiscordColors.fill,lineWidth:2.6).rotationEffect(.degrees(-90))
        }.frame(width:9.4,height:9.4).frame(width:12,height:12).animation(.linear(duration:1),value:done)
    }
}

/// The parts' places on the card, for the outline.
struct CardPartBounds: PreferenceKey {
    static let defaultValue:[DiscordStudio.Slot:Anchor<CGRect>]=[:]
    static func reduce(value:inout [DiscordStudio.Slot:Anchor<CGRect>],nextValue:()->[DiscordStudio.Slot:Anchor<CGRect>]) { value.merge(nextValue()) { $1 } }
}
/// The outline around the part being changed: it glides to another part, then quiets down after a moment.
private struct PartHighlight: View {
    let slot:DiscordStudio.Slot
    let anchor:Anchor<CGRect>
    @State private var quiet=false
    /// It glides only from one part to another: where it first shows, it just appears.
    @State private var placed=false
    var body:some View {
        GeometryReader { proxy in
            let bounds=proxy[anchor],text=[.lineOne,.lineTwo,.timer].contains(slot)
            let padX:CGFloat=text ? 6 : 4,padY:CGFloat=text ? 1 : 4,radius:CGFloat=slot == .badge ? (bounds.height+padY*2)/2 : text ? 5 : 10
            RoundedRectangle(cornerRadius:radius,style:.continuous)
                .fill(DiscordColors.pick.opacity(quiet ? 0 : 0.13))
                .overlay { RoundedRectangle(cornerRadius:radius,style:.continuous).strokeBorder(DiscordColors.pick.opacity(quiet ? 0.32 : 0.8),lineWidth:1.5) }
                .frame(width:bounds.width+padX*2,height:bounds.height+padY*2)
                .offset(x:bounds.minX-padX,y:bounds.minY-padY)
                .transaction { if !placed { $0.animation=nil } }
                .animation(placed ? .timingCurve(0.33,1,0.68,1,duration:0.3) : nil,value:bounds)
        }
        .allowsHitTesting(false)
        .onAppear { DispatchQueue.main.async { placed=true } }
        .task(id:slot) {
            withAnimation(.easeOut(duration:0.2)) { quiet=false }
            try? await Task.sleep(for:.milliseconds(1300))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration:0.9)) { quiet=true }
        }
    }
}

/// The card on Discord's profile pop-out: on the home page with its banner and the player's own picture; in
/// Customize just the card (the banner and the picture fold away).
struct DiscordShell<Card:View>: View {
    var profile=true
    var avatar:URL?
    @ViewBuilder var card:Card
    var body:some View {
        VStack(alignment:.leading,spacing:0) {
            // The design's banner: a 115° sweep from indigo through violet to pink, lit cyan near the top right.
            ZStack {
                LinearGradient(stops:[.init(color:Color(red:72/255,green:58/255,blue:154/255),location:0),.init(color:Color(red:144/255,green:58/255,blue:178/255),location:0.55),
                                      .init(color:Color(red:202/255,green:68/255,blue:154/255),location:1)],startPoint:UnitPoint(x:0.06,y:-0.81),endPoint:UnitPoint(x:0.94,y:1.81))
                EllipticalGradient(colors:[Color(red:38/255,green:183/255,blue:211/255).opacity(0.55),.clear],center:UnitPoint(x:0.85,y:0),startRadiusFraction:0,endRadiusFraction:1.4)
            }
            .frame(height:profile ? 58 : 0).clipShape(UnevenRoundedRectangle(topLeadingRadius:10,topTrailingRadius:10,style:.continuous))
            ZStack(alignment:.topLeading) {
                Text(L("You")).font(.discord(18,700)).foregroundStyle(DiscordColors.title).shadow(color:.black.opacity(0.55),radius:1.5,y:1)
                    .frame(height:22).padding(.leading,98).padding(.top,2)
                RemoteImage(url:avatar) {
                    Circle().fill(Color(red:88/255,green:101/255,blue:242/255)).overlay { DesignIcon("ic:baseline-discord",size:34).foregroundStyle(.white) }
                }
                .frame(width:66,height:66).clipShape(Circle())
                .frame(width:76,height:76).background(DiscordColors.popout,in:Circle())
                .overlay(alignment:.bottomTrailing) { Circle().fill(DiscordColors.online).frame(width:14,height:14).padding(4).background(DiscordColors.popout,in:Circle()).offset(x:1,y:1) }
                .offset(x:12,y:-36)
            }
            .frame(height:profile ? 52 : 10,alignment:.top).opacity(profile ? 1 : 0).allowsHitTesting(profile)
            card.padding([.horizontal,.bottom],10)
        }
        .frame(width:372)
        .background(DiscordColors.popout,in:RoundedRectangle(cornerRadius:10,style:.continuous))
        // The pop-out's own shadow, not one under each line inside it.
        .compositingGroup().shadow(color:.black.opacity(0.45),radius:16,y:12)
        .environment(\.colorScheme,.dark)
    }
}
