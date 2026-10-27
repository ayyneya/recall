import SwiftUI

// Settings › Discord, as the design lays it out: the card as friends see it, on Discord's profile pop-out;
// how much it shows (Basic, Live, Full, or the player's own card: Customize); the BattleTag; and what Recall
// remembers. A click on the card opens Customize (DiscordEditor.swift) on the part clicked.

/// The dark stage the card sits on, with its corners: Discord's mark (and, in Customize, the device) on the
/// left; on the right, where the player is (a click shows the next state while the game isn't running) and
/// the power. Off, it says so and nothing runs.
struct DiscordStage<Content:View,Controls:View>: View {
    @Bindable var studio:DiscordStudio
    var height:CGFloat
    var top:CGFloat=0
    var power=true
    @ViewBuilder var content:Content
    @ViewBuilder var controls:Controls
    var body:some View {
        // The dots and the corners sit inside the stage's one-point border, as the design's do.
        ZStack {
            DotPattern().fill(.white.opacity(0.05)).padding(1).allowsHitTesting(false)
            content.padding(.top,top).frame(maxWidth:.infinity,maxHeight:.infinity)
        }
        .frame(maxWidth:.infinity).frame(height:height)
        .overlay(alignment:.topLeading) {
            HStack(spacing:6) {
                DesignIcon("ic:baseline-discord",size:16).foregroundStyle(DiscordColors.ink(0.45))
                    .frame(width:26,height:26).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:8))
                controls
            }.padding(.leading,11).padding(.top,9)
        }
        .overlay(alignment:.topTrailing) {
            HStack(spacing:4) {
                // Where the player is says nothing at Basic, and nothing runs while off.
                if studio.level != .normal && studio.power { SceneChip(studio:studio).transition(.identity) }
                if power { PowerButton(studio:studio).transition(.afterMove) }
            }.padding(.trailing,11).padding(.top,9)
        }
        .overlay { if power && !studio.power { OffCover(studio:studio).transition(.opacity) } }
        .background(DiscordColors.stage)
        .clipShape(RoundedRectangle(cornerRadius:20))
        .overlay { RoundedRectangle(cornerRadius:20).strokeBorder(.white.opacity(0.06),lineWidth:1) }
        .environment(\.colorScheme,.dark)
        .animation(.timingCurve(0.22,1,0.36,1,duration:0.52),value:height)
        .animation(.easeOut(duration:0.3),value:studio.power)
    }
}
extension DiscordStage where Controls == EmptyView {
    init(studio:DiscordStudio,height:CGFloat,top:CGFloat=0,power:Bool=true,@ViewBuilder content:()->Content) {
        self.init(studio:studio,height:height,top:top,power:power,content:content) { EmptyView() }
    }
}
/// Dots every 14 points, like a design canvas.
struct DotPattern: Shape {
    func path(in rect:CGRect)->Path {
        var path=Path()
        for x in stride(from:7,to:rect.width,by:14) { for y in stride(from:7,to:rect.height,by:14) { path.addEllipse(in:CGRect(x:x-1,y:y-1,width:2,height:2)) } }
        return path
    }
}
/// Where the player is in the preview: the game's own state while it runs (a green dot), or one to try.
struct SceneChip: View {
    @Bindable var studio:DiscordStudio
    @State private var inside=false
    @State private var pulse=false
    var body:some View {
        let match=studio.sceneName == studio.texts.match
        Button { studio.nextScene() } label: {
            HStack(spacing:6) {
                if studio.live != nil {
                    Circle().fill(DiscordColors.online).frame(width:6,height:6).opacity(pulse ? 0.45 : 1)
                        .onAppear { withAnimation(.easeInOut(duration:0.8).repeatForever()) { pulse=true } }
                }
                DesignIcon(match ? "ph:sword-fill" : "ph:squares-four-fill",size:match ? 12.5 : 14)
                Text(studio.sceneName).designFont(11.5,.semibold)
                if studio.sceneVoice {
                    Text(verbatim:"&").designFont(11.5,.semibold).opacity(0.6)
                    DesignIcon("ph:users-three-fill",size:14)
                    Text(L("Voice")).designFont(11.5,.semibold)
                }
            }
            .foregroundStyle(DiscordColors.ink(inside && studio.live == nil ? 0.85 : 0.5))
            .padding(.leading,8).padding(.trailing,9).frame(height:26)
            .background(inside && studio.live == nil ? .white.opacity(0.06) : .clear,in:RoundedRectangle(cornerRadius:8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { inside=$0 }
        .accessibilityLabel(studio.live != nil ? L("Following the game") : L("Show the next state"))
        .animation(.easeOut(duration:0.25),value:inside)
    }
}
private struct PowerButton: View {
    @Bindable var studio:DiscordStudio
    var body:some View {
        Button { studio.setPower(!studio.power) } label: {
            DesignIcon("lucide:power",size:14)
                .foregroundStyle(studio.power ? Color(red:90/255,green:220/255,blue:140/255) : DiscordColors.ink(0.6))
                .frame(width:26,height:26).background(.white.opacity(studio.power ? 0.06 : 0.1),in:RoundedRectangle(cornerRadius:8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .designTip(studio.power ? L("Discord card is on. Turn it off to unload it entirely: while on, it uses well under 0.1% of your CPU.") : L("Turn the Discord card back on."))
        .accessibilityLabel(L("Discord card on or off"))
    }
}
/// The stage while the card is off.
private struct OffCover: View {
    @Bindable var studio:DiscordStudio
    var body:some View {
        VStack(spacing:8) {
            DesignIcon("lucide:power-off",size:22).foregroundStyle(DiscordColors.ink(0.6))
            Text(L("Discord card is off")).designFont(14,.semibold).foregroundStyle(DiscordColors.body)
            Text(L("Recall stops reading the game log, disconnects from Discord and stops the timer. Nothing stays loaded."))
                .designFont(12,line:12*1.5).foregroundStyle(DiscordColors.ink(0.62)).multilineTextAlignment(.center).frame(maxWidth:300)
            FillButton(title:L("Turn on"),height:30,size:12.5,radius:9,padding:14,weight:.bold) { studio.setPower(true) }.padding(.top,6)
        }
        .frame(maxWidth:.infinity,maxHeight:.infinity)
        .background(Color(red:23/255,green:24/255,blue:27/255).opacity(0.94))
    }
}

extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
    /// Discord's tab, for what's drawn across it (LevelFlow).
    static var discordTab:NamedCoordinateSpace { .named("discordTab") }
}
/// Settings › Discord as one column: its own page (DiscordHome), Customize and the two pages. Going to Customize or a
/// page folds Settings' title and tabs away (SettingsSheet) as the breadcrumb opens here, and the card's stage
/// stays where it is, only changing height.
struct DiscordTab<Footer:View>: View {
    @Bindable var studio:DiscordStudio
    /// Settings' own Uninstall and Done, under the tab's page.
    @ViewBuilder var footer:Footer
    var body:some View {
        let home=studio.screen == .home
        VStack(alignment:.leading,spacing:0) {
            DiscordPageHeader(studio:studio).frame(height:home ? 0 : 46,alignment:.top).clipped().allowsHitTesting(!home)
            // What leaves goes at once, as in the design (a removal keeps its view on screen as long as it lasts).
            switch studio.screen {
            case .profile,.history:
                Group { if studio.screen == .profile { ProfilePage(studio:studio) } else { HistoryPage(studio:studio) } }
                    .padding(.top,16).frame(maxHeight:.infinity,alignment:.top)
                    .transition(.asymmetric(insertion:.opacity.combined(with:.offset(y:22)),removal:Self.gone))
            case .home,.editor:
                // Over what's under it: a new view shows at its final place at once, so Customize, coming in while the
                // stage still shrinks, slides out from under the stage rather than over it.
                CardStage(studio:studio).padding(.top,14).zIndex(1)
                    .transition(.asymmetric(insertion:.opacity.combined(with:.offset(y:8)).animation(.timingCurve(0.22,1,0.36,1,duration:0.45)),removal:Self.gone))
                if home {
                    DiscordHome(studio:studio) { footer }
                        .transition(.asymmetric(insertion:.opacity.combined(with:.offset(y:-22)),removal:Self.gone))
                } else {
                    DiscordEditor(studio:studio)
                        .transition(.asymmetric(insertion:.opacity.combined(with:.offset(y:22)),removal:Self.gone))
                }
            }
        }
        .animation(.timingCurve(0.22,1,0.36,1,duration:0.52),value:studio.screen)
        // Customize's sparks and light, across the tab.
        .overlay(alignment:.topLeading) { if let flow=studio.levelFlow { LevelFlow(flow:flow,studio:studio) } }
        .coordinateSpace(.discordTab)
    }
    private static var gone:AnyTransition { .opacity.animation(.linear(duration:0.06)) }
}
/// The tab's own page under the card: the level, the BattleTag and what Recall remembers; off, all dimmed.
struct DiscordHome<Footer:View>: View {
    @Bindable var studio:DiscordStudio
    @ViewBuilder var footer:Footer
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            VStack(alignment:.leading,spacing:10) {
                LevelWords(studio:studio)
                Text(studio.power ? studio.level.detail : L("Off. Nothing runs until you turn it back on."))
                    .designFont(12.5,line:12.5*1.45).foregroundStyle(DiscordColors.ink(0.62)).padding(.leading,4)
                // The rows sit at the bottom, taking what room there is (DiscordRows).
                Spacer(minLength:0)
                DiscordRows(studio:studio).layoutPriority(1)
            }
            .opacity(studio.power ? 1 : 0.28).allowsHitTesting(studio.power)
            .animation(.easeOut(duration:0.35),value:studio.power)
            .frame(maxHeight:.infinity,alignment:.top)
            footer
        }
        .padding(.top,14)
    }
}
/// A fine dashed outline marching slowly round the card while it's the player's own: it can be edited. As the design's,
/// its dashes divide the outline exactly (no seam where it starts, the bottom's middle); it fades in (after
/// Customize's light has traced the card, when that's running) and goes in a fifth of a second.
struct MarchingOutline: View {
    var delay:Double=0
    @State private var shown=false
    @State private var phase:CGFloat=0
    var body:some View {
        GeometryReader { box in
            let outline=CardOutline(inset:0.75,radius:7.25),period=outline.period(in:box.size)
            outline.stroke(LinearGradient(stops:CardOutline.colors,startPoint:.bottom,endPoint:.top),
                           style:StrokeStyle(lineWidth:1.5,lineCap:.round,dash:[period/2,period/2],dashPhase:phase*period))
                .onAppear { withAnimation(.linear(duration:1.2*period/10).repeatForever(autoreverses:false)) { phase = -1 } }
        }
        .opacity(shown ? 0.9 : 0).allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration:0.38).delay(delay)) { shown=true } }
    }
}
/// The card's edge as the design draws round it: from the bottom's middle along the bottom to the left, up, across and
/// down (`inset` inside the card, with corners of `radius`); or one side of that up to the top's middle (`side`: -1 the
/// left, 1 the right), as the light's two strokes run.
struct CardOutline: Shape {
    var inset:CGFloat=0
    var radius:CGFloat=8
    var side=0
    /// Amber at the bottom to violet at the top.
    static let colors:[Gradient.Stop]=[.init(color:Color(red:1,green:184/255,blue:92/255),location:0),.init(color:Color(red:1,green:140/255,blue:70/255),location:0.3),
                                       .init(color:Color(red:1,green:112/255,blue:104/255),location:0.55),.init(color:Color(red:1,green:92/255,blue:138/255),location:0.8),
                                       .init(color:Color(red:214/255,green:98/255,blue:230/255),location:1)]
    func path(in rect:CGRect)->Path {
        let r=radius,left=rect.minX+inset,top=rect.minY+inset,right=rect.maxX-inset,bottom=rect.maxY-inset,middle=rect.midX
        var path=Path()
        path.move(to:CGPoint(x:middle,y:bottom))
        if side == 1 {
            path.addLine(to:CGPoint(x:right-r,y:bottom))
            path.addArc(tangent1End:CGPoint(x:right,y:bottom),tangent2End:CGPoint(x:right,y:bottom-r),radius:r)
            path.addLine(to:CGPoint(x:right,y:top+r))
            path.addArc(tangent1End:CGPoint(x:right,y:top),tangent2End:CGPoint(x:right-r,y:top),radius:r)
            path.addLine(to:CGPoint(x:middle,y:top))
            return path
        }
        path.addLine(to:CGPoint(x:left+r,y:bottom))
        path.addArc(tangent1End:CGPoint(x:left,y:bottom),tangent2End:CGPoint(x:left,y:bottom-r),radius:r)
        path.addLine(to:CGPoint(x:left,y:top+r))
        path.addArc(tangent1End:CGPoint(x:left,y:top),tangent2End:CGPoint(x:left+r,y:top),radius:r)
        if side == -1 { path.addLine(to:CGPoint(x:middle,y:top));return path }
        path.addLine(to:CGPoint(x:right-r,y:top))
        path.addArc(tangent1End:CGPoint(x:right,y:top),tangent2End:CGPoint(x:right,y:top+r),radius:r)
        path.addLine(to:CGPoint(x:right,y:bottom-r))
        path.addArc(tangent1End:CGPoint(x:right,y:bottom),tangent2End:CGPoint(x:right-r,y:bottom),radius:r)
        path.closeSubpath()
        return path
    }
    /// The dashes' period: about ten points, dividing the whole outline exactly.
    func period(in size:CGSize)->CGFloat {
        let length=2*(size.width-2*inset-2*radius)+2*(size.height-2*inset-2*radius)+2*CGFloat.pi*radius
        return length/max(1,(length/10).rounded())
    }
}

/// Customize picked on Discord's tab, as the design plays it, over the whole tab: seven sparks pop out of its word; a
/// light leaves the word and curves into the bottom of the card (0.44 s); from there two strokes run round both
/// sides of the card and meet at the top (half a second) while the outline glows and fades (0.95 s).
struct LevelFlow: View {
    let flow:DiscordStudio.LevelFlowStart
    let studio:DiscordStudio
    var body:some View {
        TimelineView(.animation) { context in
            let time=context.date.timeIntervalSince(flow.at)
            Canvas { canvas,_ in
                sparks(canvas,time)
                if time < 0.44 { light(canvas,time/0.44) } else if time < 1.44 { trace(canvas,time-0.44) }
            }
        }
        .allowsHitTesting(false)
        .task(id:flow.id) {
            try? await Task.sleep(for:.seconds(1.5))
            if studio.levelFlow?.id == flow.id { studio.levelFlow=nil }
        }
    }
    /// The sparks' own chance, the same at every frame: four numbers for each.
    private var chance:[Double] {
        var seed=UInt64(truncatingIfNeeded:flow.id.hashValue)
        return (0..<28).map { _ in seed=seed &* 6364136223846793005 &+ 1442695040888963407;return Double(seed>>11)/Double(1 << 53) }
    }
    private func sparks(_ canvas:GraphicsContext,_ time:Double) {
        let colors=[Color(red:1,green:184/255,blue:92/255),Color(red:236/255,green:106/255,blue:46/255),Color(red:1,green:92/255,blue:138/255),Color(red:214/255,green:98/255,blue:230/255)]
        let chance=chance,center=CGPoint(x:flow.from.midX,y:flow.from.midY)
        for index in 0..<7 {
            let angle=Double(index)/7*2*Double.pi+chance[index*4]*0.6,distance=18+chance[index*4+1]*14,size=3+chance[index*4+2]*2.5
            let progress=min(1,time/(0.52+chance[index*4+3]*0.16))
            guard progress < 1 else { continue }
            let eased=DesignEase.bezier(progress,0.2,0.7,0.3,1),scale=1-0.8*eased,color=colors[index%colors.count]
            let at=CGPoint(x:center.x+cos(angle)*distance*1.6*eased,y:center.y+sin(angle)*distance*eased)
            var layer=canvas
            layer.opacity=1-eased
            layer.addFilter(.shadow(color:color,radius:3))
            layer.fill(Path(ellipseIn:CGRect(x:at.x-size*scale/2,y:at.y-size*scale/2,width:size*scale,height:size*scale)),with:.color(color))
        }
    }
    /// The light, from the top of the word to the bottom of the card: quick out sideways, easing in and out upwards.
    private func light(_ canvas:GraphicsContext,_ progress:Double) {
        let card=studio.cardFrame,start=CGPoint(x:flow.from.midX,y:flow.from.minY),end=CGPoint(x:card.midX,y:card.maxY)
        let across=1-pow(1-progress,2.4),up=progress < 0.5 ? 4*pow(progress,3) : 1-pow(-2*progress+2,3)/2
        let at=CGPoint(x:start.x+(end.x-start.x)*across,y:start.y+(end.y-start.y)*up),size=8*(1-0.25*progress)
        var layer=canvas
        layer.addFilter(.shadow(color:Color(red:236/255,green:106/255,blue:46/255),radius:7))
        layer.addFilter(.shadow(color:Color(red:1,green:184/255,blue:92/255),radius:2.5))
        layer.fill(Path(ellipseIn:CGRect(x:at.x-size/2,y:at.y-size/2,width:size,height:size)),with:.color(Color(red:1,green:226/255,blue:190/255)))
    }
    private func trace(_ canvas:GraphicsContext,_ time:Double) {
        let card=studio.cardFrame
        guard card.width > 0 else { return }
        let drawn=DesignEase.bezier(min(1,time/0.5),0.4,0,0.2,1),fading=DesignEase.bezier(min(1,time/0.95),0.42,0,1,1)
        var layer=canvas
        layer.opacity=fading < 0.5 ? 1 : 2*(1-fading)
        layer.addFilter(.shadow(color:Color(red:1,green:150/255,blue:90/255).opacity(0.9),radius:2))
        layer.addFilter(.shadow(color:Color(red:1,green:92/255,blue:138/255).opacity(0.5),radius:6))
        let shading=GraphicsContext.Shading.linearGradient(Gradient(stops:CardOutline.colors),startPoint:CGPoint(x:card.midX,y:card.maxY),endPoint:CGPoint(x:card.midX,y:card.minY))
        for side in [-1,1] {
            layer.stroke(CardOutline(radius:8,side:side).path(in:card).trimmedPath(from:0,to:drawn),with:shading,style:StrokeStyle(lineWidth:2,lineCap:.round))
        }
    }
}

/// "Friends see  Basic  Live  Full  Customize ›": the chosen one bright, with a line under it, white (or the design's
/// moving ribbon of colour under Customize), that glides to another as the design's does: the leading edge runs
/// ahead, stretching the line, and the rest catches up with a spring. The word picked springs; Customize, picked,
/// sends sparks and a light into the card (LevelFlow), and picked again opens the card in Customize.
struct LevelWords: View {
    @Bindable var studio:DiscordStudio
    @State private var inside:DiscordPresenceLevel?
    /// Where each word's text is, in the row (for the line) and on the tab (for the light).
    @State private var words:[DiscordPresenceLevel:CGRect]=[:]
    @State private var customOnTab=CGRect.zero
    /// Where the line glides from, and a count of glides and of each word's springs, which start them.
    @State private var glideFrom:CGRect?
    @State private var glides=0
    @State private var springs:[DiscordPresenceLevel:Int]=[:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        HStack(spacing:14) {
            Text(L("Friends see")).designFont(13).foregroundStyle(DiscordColors.ink(0.42))
            HStack(spacing:18) {
                ForEach(DiscordPresenceLevel.allCases) { level in word(level) }
            }
            .background(alignment:.topLeading) { line }
            .coordinateSpace(.named(Self.row))
        }.frame(height:34).padding(.leading,2)
    }
    private static let row="levelWords"
    private func word(_ level:DiscordPresenceLevel)->some View {
        let on=studio.level == level,custom=level == .custom
        return Button { pick(level) } label: {
            HStack(spacing:5) {
                Group {
                    if custom { RibbonText(text:level.title,weight:on ? 700 : 650) }
                    else {
                        // Its colour changes over 0.35 s, its weight at once, as the design's do.
                        Text(level.title).designFont(14,on ? .bold : .medium)
                            .animation(.cssEase(0.35)) { $0.foregroundStyle(on ? DiscordColors.bright : DiscordColors.ink(0.55)) }
                    }
                }
                .onGeometryChange(for:CGRect.self) { $0.frame(in:.named(Self.row)) } action:{ words[level]=$0 }
                .onGeometryChange(for:CGRect.self) { $0.frame(in:.discordTab) } action:{ if custom { customOnTab=$0 } }
                .keyframeAnimator(initialValue:1.0,trigger:springs[level] ?? 0) { word,progress in
                    word.scaleEffect(1.14-0.14*DesignEase.outElastic(progress))
                } keyframes:{ _ in
                    MoveKeyframe(0.0)
                    LinearKeyframe(1.0,duration:0.52)
                }
                if custom && on {
                    DesignIcon("lucide:chevron-right",size:14).foregroundStyle(Color(red:1,green:150/255,blue:120/255).opacity(0.8)).padding(.leading,-2)
                        .transition(.asymmetric(insertion:.opacity.combined(with:.offset(y:8)).animation(.timingCurve(0.25,0.1,0.25,1,duration:0.35)),removal:.identity))
                }
            }
            .frame(height:34)
            .brightness(inside == level ? 0.15 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { inside=$0 ? level : nil }
        .accessibilityLabel(custom && on ? L("Edit your card") : level.title).accessibilityAddTraits(on ? .isSelected : [])
    }
    private func pick(_ level:DiscordPresenceLevel) {
        if studio.level != level && !reduceMotion {
            glideFrom=words[studio.level];glides+=1
            if level == .custom { studio.levelFlow=DiscordStudio.LevelFlowStart(from:customOnTab,at:Date()) } else { springs[level,default:0]+=1 }
        }
        // Customize again opens the editor, with the screen's own move.
        if studio.level == level && level == .custom { withAnimation(.timingCurve(0.22,1,0.36,1,duration:0.52)) { studio.choose(level) } } else { studio.choose(level) }
    }
    /// The line under the chosen word: three points high, a point above the row's bottom.
    private var line:some View {
        let to=words[studio.level] ?? .zero,custom=studio.level == .custom
        return Underline(custom:custom)
            .keyframeAnimator(initialValue:1.0,trigger:glides) { bar,progress in
                let from=glideFrom ?? to,at=GlideStyle.words.span(from:(from.minX,from.width),to:(to.minX,to.width),at:progress)
                bar.frame(width:max(0,at.length),height:3).scaleEffect(y:at.squash).offset(x:at.start,y:30)
            } keyframes:{ _ in
                MoveKeyframe(0.0)
                LinearKeyframe(1.0,duration:GlideStyle.words.duration)
            }
            .opacity(to == .zero ? 0 : 1)
    }
}
/// The level's line: white, or under Customize the ribbon with an orange glow, changing over 0.45 s.
private struct Underline: View {
    let custom:Bool
    var body:some View {
        let glow=custom ? Color(red:1,green:140/255,blue:80/255).opacity(0.38) : DiscordColors.ink(0.16)
        ZStack {
            DiscordColors.ink(1).opacity(custom ? 0 : 1)
            RibbonLine(rounded:false).opacity(custom ? 1 : 0)
        }
        .clipShape(RoundedRectangle(cornerRadius:2))
        .shadow(color:glow,radius:5).shadow(color:glow,radius:1.5)
        .animation(.timingCurve(0.25,0.1,0.25,1,duration:0.45),value:custom)
    }
}
/// Customize's word: the design's ribbon of colour moving through the letters.
private struct RibbonText: View {
    let text:String
    let weight:Int
    var body:some View {
        Text(text).designFont(14,weight).foregroundStyle(.clear)
            .overlay { RibbonLine(rounded:false).mask { Text(text).designFont(14,weight) } }
    }
}

/// The BattleTag (with the rank it shows) at Full and Customize, and What Recall remembers, each opening its page.
struct DiscordRows: View {
    @Bindable var studio:DiscordStudio
    var body:some View {
        ShrinkingColumn {
            if studio.level == .full || studio.level == .custom {
                RowButton(height:44) { studio.openProfile() } label: {
                    DesignIcon("simple-icons:battledotnet",size:15).foregroundStyle(DiscordColors.ink(0.55))
                    if studio.battleTag.isEmpty {
                        Text(L("Add your BattleTag")).designFont(13,.semibold).foregroundStyle(DiscordColors.body).fixedSize()
                        Text(L("for ranks and records")).designFont(11.5).foregroundStyle(DiscordColors.ink(0.5)).lineLimit(1).frame(maxWidth:.infinity,alignment:.leading)
                    } else {
                        Text(verbatim:studio.battleTag).designFont(13,.semibold).foregroundStyle(DiscordColors.body).fixedSize()
                        if let chip=studio.tagChip {
                            HStack(spacing:5) {
                                if let icon=chip.icon { RemoteImage(url:icon,fill:false) { Color.clear }.frame(width:16,height:16) } else { DesignIcon("lucide:lock",size:12) }
                                Text(chip.text).designFont(11.5,.semibold)
                            }
                            .foregroundStyle(DiscordColors.ink(0.85))
                            .padding(.leading,chip.icon == nil ? 7 : 5).padding(.trailing,9).frame(height:24)
                            .background(DiscordColors.veil(0.06),in:RoundedRectangle(cornerRadius:7)).fixedSize()
                        }
                        Text(studio.tagNote).designFont(11.5).foregroundStyle(DiscordColors.ink(0.5)).lineLimit(1).frame(maxWidth:.infinity,alignment:.leading)
                    }
                    DesignIcon("lucide:chevron-right",size:14).foregroundStyle(DiscordColors.ink(0.4))
                }
                Rectangle().fill(DiscordColors.veil(0.06)).frame(height:1).padding(.horizontal,12)
            }
            RowButton(height:40) { studio.openHistory() } label: {
                DesignIcon("lucide:database",size:14).foregroundStyle(DiscordColors.ink(0.55))
                Text(L("What Recall remembers")).designFont(12.5,.medium).foregroundStyle(DiscordColors.body).frame(maxWidth:.infinity,alignment:.leading)
                Text(studio.historyNote).designFont(11.5).foregroundStyle(DiscordColors.ink(0.45)).lineLimit(1)
                DesignIcon("lucide:chevron-right",size:14).foregroundStyle(DiscordColors.ink(0.4))
            }
        }
        // Inside its one-point border, as the design's box is.
        .padding(1)
        .background(DiscordColors.veil(0.04),in:RoundedRectangle(cornerRadius:13))
        .clipShape(RoundedRectangle(cornerRadius:13))
        .overlay { RoundedRectangle(cornerRadius:13).strokeBorder(DiscordColors.veil(0.06),lineWidth:1) }
    }
}
/// A column whose rows give up height in proportion to their own when the room is short of them all, as the
/// design's flexbox shrinks them: the BattleTag's and What Recall remembers' rows, under a long level description.
struct ShrinkingColumn: Layout {
    func sizeThatFits(proposal:ProposedViewSize,subviews:Subviews,cache:inout ())->CGSize {
        let ideal=subviews.reduce(0) { $0+$1.sizeThatFits(ProposedViewSize(width:proposal.width,height:nil)).height }
        return CGSize(width:proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0,height:min(ideal,proposal.height ?? ideal))
    }
    func placeSubviews(in bounds:CGRect,proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) {
        let ideals=subviews.map { $0.sizeThatFits(ProposedViewSize(width:bounds.width,height:nil)).height }
        let total=ideals.reduce(0,+),scale=total > bounds.height && total > 0 ? bounds.height/total : 1
        var y=bounds.minY
        for (subview,ideal) in zip(subviews,ideals) {
            subview.place(at:CGPoint(x:bounds.minX,y:y),proposal:ProposedViewSize(width:bounds.width,height:ideal*scale))
            y+=ideal*scale
        }
    }
}
/// A row that opens a page, faintly lit while pointed at.
struct RowButton<Label:View>: View {
    /// Its height when there's room (ShrinkingColumn gives it less when there isn't).
    var height:CGFloat
    let action:()->Void
    @ViewBuilder var label:Label
    @State private var inside=false
    var body:some View {
        Button(action:action) {
            HStack(spacing:10) { label }
                .padding(.leading,13).padding(.trailing,12).frame(minHeight:0,idealHeight:height,maxHeight:height).frame(maxWidth:.infinity)
                .background(inside ? DiscordColors.veil(0.04) : .clear).contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { inside=$0 }
    }
}

extension DiscordStudio {
    var sceneName:String {
        if let live { if case .match=live.place { return texts.match };return texts.menu }
        return scene == .match || scene == .matchVoice ? texts.match : texts.menu
    }
    var sceneVoice:Bool { live.map { $0.voice != nil } ?? (scene == .menusVoice || scene == .matchVoice) }
    func nextScene() {
        guard live == nil else { return }
        let all=Scene.allCases
        scene=all[(all.firstIndex(of:scene)!+1)%all.count];held=nil
    }
    /// A part clicked on the home page's card: Customize, on that part.
    func openEditor(at slot:Slot) {
        openEditor();pick(slot)
    }
    /// The ring after Line 2 on the home page, while lines take turns there.
    func homeLineTwoTurn(at now:Date)->(done:Double,label:String)? {
        let inputs=inputs(at:now),lists=DiscordCardDesign.Shown(shown,inputs,turn:turn(at:now))
        guard level == .full || level == .custom,lists.lineTwo.count > 1,inputs.menus,inputs.voice == nil || shown.party == .noCount else { return nil }
        let k=turn(at:now)%lists.lineTwo.count
        return (turnDone(at:now),L("Line {0} of {1}",String(k+1),String(lists.lineTwo.count)))
    }
    /// The chip after the BattleTag: the rank it shows (with its emblem), or that the profile is private.
    var tagChip:(text:String,icon:URL?)? {
        switch profileState {
        case .none: return nil
        case .hidden: return (L("Private"),nil)
        case .shown: return CardInputs(profile:profile,history:history,launched:Date(),now:Date(),texts:texts).rank(.lastPlayed).map { ($0.name,$0.icon) }
        }
    }
    var tagNote:String {
        if lookingUp { return L("Looking up…") }
        switch profileState {
        case .none: return L("Not found yet")
        case .hidden: return L("Ranks and records hidden")
        case .shown: return lookedUp.map { L("Looked up {0}",$0.formatted(.relative(presentation:.named))) } ?? ""
        }
    }
    var historyNote:String {
        let count=history.runs.count
        return count == 0 ? L("Nothing kept") : count == 1 ? L("1 session on this Mac") : L("{0} sessions on this Mac",String(count))
    }
}
