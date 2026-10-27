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
        // The bars move with the stage as one, so what comes in with another screen rides along at once (SwiftUI moves
        // each drawn view on its own, and a new one would show at its new place while the bar still moves).
        .overlay(alignment:.topLeading) {
            HStack(spacing:6) {
                DesignIcon("ic:baseline-discord",size:16).foregroundStyle(DiscordColors.ink(0.45))
                    .frame(width:26,height:26).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:8))
                controls
            }.padding(.leading,11).padding(.top,9).geometryGroup()
        }
        .overlay(alignment:.topTrailing) {
            HStack(spacing:4) {
                // Where the player is says nothing at Basic, and nothing runs while off.
                if studio.level != .normal && studio.power { SceneChip(studio:studio).transition(.identity) }
                if power { PowerButton(studio:studio).transition(.atOnce) }
            }.padding(.trailing,11).padding(.top,9).geometryGroup()
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
/// Discord's tab is dark, as its design is (its light look is still to come): while it shows, the whole app turns
/// dark, every window crossfading, and back as it goes (SettingsSheet).
@MainActor enum DiscordDark {
    /// The app's own appearance from before (nil: the system's), while the tab keeps it dark.
    private static var before:NSAppearance??
    static func set(_ on:Bool) {
        guard on != (before != nil) else { return }
        let next=on ? NSAppearance(named:.darkAqua) : before ?? nil
        before=on ? .some(NSApp.appearance) : nil
        let dark={ (appearance:NSAppearance?) in
            appearance.map { $0.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua } ?? (UserDefaults.standard.string(forKey:"AppleInterfaceStyle") == "Dark")
        }
        // A Mac that's dark already stays as it is.
        if dark(next) != dark(NSApp.effectiveAppearance) {
            for window in NSApp.windows where window.isVisible {
                guard let layer=window.contentView?.superview?.layer ?? window.contentView?.layer else { continue }
                let fade=CATransition();fade.type = .fade;fade.duration=0.35;fade.timingFunction=CAMediaTimingFunction(name:.easeInEaseOut)
                layer.add(fade,forKey:"discordDark")
            }
        }
        NSApp.appearance=next
    }
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
        // What comes in starts where it would have sat on the screen going, carried as the header folds or opens and the
        // stage grows or shrinks above it; then it rises or drops into place and fades in.
        let ride=studio.ride
        VStack(alignment:.leading,spacing:0) {
            DiscordPageHeader(studio:studio).frame(height:home ? 0 : 46,alignment:.top).clipped().allowsHitTesting(!home)
            // What leaves goes at once, as in the design (a removal keeps its view on screen as long as it lasts).
            switch studio.screen {
            case .profile,.history:
                Group { if studio.screen == .profile { ProfilePage(studio:studio) } else { HistoryPage(studio:studio) } }
                    .padding(.top,16).frame(maxHeight:.infinity,alignment:.top)
                    .transition(.asymmetric(insertion:.ride(ride.page).combined(with:.opacity).combined(with:.offset(y:22)),removal:Self.gone))
            case .home,.editor:
                // Over the page under it, which starts out under it as it grows.
                CardStage(studio:studio).padding(.top,14).zIndex(1)
                    .transition(.asymmetric(insertion:.ride(ride.header).combined(with:.opacity.combined(with:.offset(y:8)).animation(.timingCurve(0.22,1,0.36,1,duration:0.45))),
                                            removal:Self.gone))
                if home {
                    DiscordHome(studio:studio) { footer }
                        .transition(.asymmetric(insertion:.ride(ride.page).combined(with:.opacity).combined(with:.offset(y:-22)),removal:Self.gone))
                } else {
                    DiscordEditor(studio:studio)
                        .transition(.asymmetric(insertion:.ride(ride.page).combined(with:.opacity).combined(with:.offset(y:22)),removal:Self.gone))
                    // Customize's Done is there at once, where it stays.
                    EditorFooter(studio:studio).padding(.top,12).transition(.atOnce)
                }
            }
        }
        .animation(.timingCurve(0.22,1,0.36,1,duration:0.52),value:studio.screen)
        // Customize's sparks and light, across the tab.
        .overlay(alignment:.topLeading) { if let flow=studio.levelFlow { LevelFlow(flow:flow,studio:studio) } }
        .coordinateSpace(.discordTab)
    }
    private static var gone:AnyTransition { .opacity.animation(.linear(duration:0)) }
}
extension DiscordStudio {
    /// How far what comes in on this screen starts from where it ends (AnyTransition.ride): by the change in what the
    /// header takes (Settings' title and tabs on Discord's tab, the breadcrumb on the others); for the page under the
    /// stage, by the stage's change too while the stage stays, and not at all when the stage comes in with it (the
    /// stage's own way in takes it along).
    var ride:(header:CGFloat,page:CGFloat) {
        let reach={ (screen:Screen)->CGFloat in screen == .home ? HeaderFold.chrome : 46 },staged:Set<Screen>=[.home,.editor]
        let header=reach(came.screen)-reach(screen)
        guard staged.contains(screen) else { return (header,header) }
        guard staged.contains(came.screen) else { return (header,0) }
        return (header,header+CardStage.height(came.screen,gallery:came.gallery)-CardStage.height(screen,gallery:gallery))
    }
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
    /// Whether it shows. It stays where it is, on the card, so it moves with the card while it fades (in over 0.38 s
    /// after `delay`, out over 0.22 s), as the design's does; the dashes stop once it's gone.
    var on:Bool
    var delay:Double=0
    @State private var shown=false
    @State private var present=false
    @State private var phase:CGFloat=0
    var body:some View {
        GeometryReader { box in
            if present {
                let outline=CardOutline(inset:0.75,radius:7.25),period=outline.period(in:box.size)
                outline.stroke(LinearGradient(stops:CardOutline.colors,startPoint:.bottom,endPoint:.top),
                               style:StrokeStyle(lineWidth:1.5,lineCap:.round,dash:[period/2,period/2],dashPhase:phase*period))
                    // A period on from wherever the dashes are: the same march each time it comes back.
                    .onAppear { withAnimation(.linear(duration:1.2*period/10).repeatForever(autoreverses:false)) { phase-=1 } }
            }
        }
        // Coming back with Discord's tab, it shows on the card as the card still moves into place.
        .geometryGroup()
        .opacity(shown ? 0.9 : 0).allowsHitTesting(false)
        .onAppear { if on { show() } }
        .onChange(of:on) { _,on in
            if on { show();return }
            withAnimation(.linear(duration:0.22)) { shown=false } completion:{ if !shown { present=false } }
        }
    }
    private func show() {
        present=true
        withAnimation(.easeOut(duration:0.38).delay(delay)) { shown=true }
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
            .onGeometryChange(for:CGRect.self) { $0.frame(in:.named(LauncherStyle.sheetSpace)) } action:{ studio.foldFrames[.levelRow]=$0 }
        }.frame(height:34).padding(.leading,2)
    }
    private static let row="levelWords"
    /// Whether Customize's morph is bringing its word and line back here (StudioMorph carries them till it's done).
    private var comingBack:Bool { studio.fold.map { !$0.opening && $0.studio } ?? false }
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
                .onGeometryChange(for:CGRect.self) { $0.frame(in:.named(LauncherStyle.sheetSpace)) } action:{ if custom { studio.foldFrames[.customize]=$0 } }
                .opacity(custom && comingBack ? 0 : 1).animation(nil,value:comingBack)
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
            .opacity(to == .zero || comingBack ? 0 : 1).animation(nil,value:comingBack)
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

// MARK: the header folding

/// Settings' title and tabs folding into Customize's (or a page's) breadcrumb, and back, as the design's header morph:
/// "Settings" and the tab's "Discord" travel as real text from the header to the breadcrumb's links (their size and
/// spacing changing as they go, never scaled, so they stay sharp and land exactly), the other tabs slip away to the
/// sides one after another and the chosen tab fades, then the breadcrumb's chevron and the title come in; closing, all
/// the other way. DiscordStudio.fold says which way, FoldClock when.
enum HeaderFold {
    /// The header's title and tab label, the breadcrumb's links; Customize's word and its row, the card's title, and
    /// the card as Discord's tab and Customize show it (StudioMorph).
    enum Text: Hashable { case title,tab,settings,discord,customize,levelRow,cardTitle,shellHome,shellEditor }
    /// The header's height, which the breadcrumb moves with as it folds (SettingsSheet).
    static let chrome:CGFloat=102
    static let length=0.52
    /// How long it all plays, the last tab coming back included.
    static let total=0.62
    static func ease(_ t:Double)->Double { DesignEase.bezier(min(1,max(0,t)),0.22,1,0.36,1) }
    static func out(_ t:Double)->Double { DesignEase.bezier(min(1,max(0,t)),0.33,0,0.67,1) }
    /// A tab's look `t` seconds in, by its place from the chosen tab: how opaque, how far to its side, and whether its
    /// label shows (the chosen one's travels as a copy).
    static func tab(_ place:Int,_ fold:DiscordStudio.Fold,at t:Double)->(opacity:Double,shift:CGFloat,label:Bool) {
        let away=Double(abs(place)),side=CGFloat(place.signum())
        if fold.opening {
            if place == 0 { return (1-out((t-0.04)/0.22),0,false) }
            let q=out((t-(away-1)*0.024)/0.24)
            return (1-q,side*12*q,true)
        }
        if place == 0 { return (ease((t-0.14)/0.26),0,false) }
        let q=ease((t-0.16-(away-1)*0.024)/0.34)
        return (q,side*12*(1-q),true)
    }
    /// The breadcrumb's chevron.
    static func chevron(_ fold:DiscordStudio.Fold,at t:Double)->Double { fold.opening ? ease((t-0.24)/0.26) : 1-out(t/0.16) }
    /// The title under the breadcrumb: how opaque, how far below its place.
    static func title(_ fold:DiscordStudio.Fold,at t:Double)->(opacity:Double,rise:CGFloat) {
        if fold.opening { let q=ease((t-0.09)/0.44);return (q,10*(1-q)) }
        let q=out(t/0.16)
        return (1-q,6*q)
    }
}

extension EnvironmentValues {
    /// Seconds into the fold playing (HeaderFold), as FoldClock counts them; its whole length once none is.
    @Entry var foldTime:Double=HeaderFold.total
}
/// SwiftUI's own clock for the fold, handing its time down (foldTime): an animation from one fold's count to the next,
/// linear over the fold's length. Started by the change that starts the fold, it begins when SwiftUI's animations in
/// that change do, once the change is built however long that takes (Customize takes more than a frame), so the fold
/// keeps step with the layout moving under it, as the design's starts once the page is in. Two clocks take turns, so a
/// fold started while the last one plays starts from its beginning as the design's does; one clock would add the two.
private struct FoldClock: ViewModifier, Animatable {
    var odd:Double,even:Double
    let count:Int
    init(_ count:Int) { self.count=count;odd=Double((count+1)/2);even=Double(count/2) }
    var animatableData:AnimatablePair<Double,Double> { get { AnimatablePair(odd,even) } set { odd=newValue.first;even=newValue.second } }
    func body(content:Content)->some View {
        let played=count%2 == 1 ? odd-Double((count+1)/2-1) : even-Double(count/2-1)
        content.environment(\.foldTime,min(1,max(0,played))*HeaderFold.total)
    }
}
extension View {
    /// The fold's clock over this view, counting the studio's folds. What changes in it as a fold starts doesn't
    /// animate with the clock (nor with anything else then): its looks come from the time.
    func foldClock(_ count:Int)->some View {
        transaction(value:count) { $0.animation=nil }
            .modifier(FoldClock(count))
            .animation(.linear(duration:HeaderFold.total),value:count)
    }
}
/// Its content, given the fold's time (foldTime).
struct FoldTime<Content:View>: View {
    @Environment(\.foldTime) private var time
    @ViewBuilder let content:(Double)->Content
    var body:some View { content(time) }
}

/// Where "Settings" and "Discord" travel as the header folds, over the whole sheet, with the fold's clock: the fold
/// is over (and forgotten) once its time has run.
struct HeaderFoldLayer: View {
    @Bindable var studio:DiscordStudio
    var body:some View {
        FoldTime { t in
            ZStack(alignment:.topLeading) {
                if let fold=studio.fold {
                    HeaderFoldTexts(studio:studio,fold:fold,t:t)
                    if fold.studio { StudioMorph(studio:studio,fold:fold,t:t) }
                }
            }
            .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
            .allowsHitTesting(false)
            .onChange(of:t >= HeaderFold.total,initial:true) { _,over in
                if over,studio.fold?.count == studio.folds { studio.fold=nil }
            }
        }
        .foldClock(studio.folds)
    }
}
/// "Settings" and "Discord" on their way between the header and the breadcrumb (HeaderFold): each as two layers, the
/// header's look and the breadcrumb's, at the same size and spacing on the way, the one giving way to the other; where
/// the breadcrumb is, it moves with the bar as the header above it shrinks.
struct HeaderFoldTexts: View {
    @Bindable var studio:DiscordStudio
    let fold:DiscordStudio.Fold
    let t:Double
    private struct Look { let size:CGFloat;let tracking:CGFloat;let weight:Int;let color:Color }
    private static let title=Look(size:28,tracking:-0.8,weight:700,color:DiscordColors.body)
    private static let tab=Look(size:12,tracking:0,weight:600,color:DiscordColors.bright)
    private static let link=Look(size:12,tracking:0,weight:600,color:DiscordColors.link)
    var body:some View {
        ZStack(alignment:.topLeading) {
            text(L("Settings"),header:.title,Self.title,link:.settings)
            text(L("Discord"),header:.tab,Self.tab,link:.discord)
        }
    }
    @ViewBuilder private func text(_ words:String,header:HeaderFold.Text,_ look:Look,link:HeaderFold.Text)->some View {
        if let top=studio.foldFrames[header],let folded=studio.foldFrames[link] {
            let p=min(1,max(0,t/HeaderFold.length)),e=HeaderFold.ease(p),k=min(1,max(0,(p-0.12)/0.6))
            // Opening, the breadcrumb comes up with the bar as the header shrinks; closing, it starts where it was.
            let from=fold.opening ? top : folded,to=fold.opening ? folded.offsetBy(dx:0,dy:HeaderFold.chrome*(1-e)) : top
            let a=fold.opening ? look : Self.link,b=fold.opening ? Self.link : look
            let x=from.minX+(to.minX-from.minX)*e,y=from.midY+(to.midY-from.midY)*e
            let size=a.size+(b.size-a.size)*e,tracking=a.tracking+(b.tracking-a.tracking)*e
            ZStack(alignment:.topLeading) {
                layer(words,a,size:size,tracking:tracking).opacity(1-k)
                layer(words,b,size:size,tracking:tracking).opacity(k)
            }
            .frame(width:0,height:0,alignment:.leading).position(x:x,y:y)
        }
    }
    /// A layer's text, its leading edge at the middle of a frame with no size, its middle across it. Its size goes in
    /// steps of a 16th of a point, too small to see, so the fonts made on the way are kept for the next fold.
    private func layer(_ words:String,_ look:Look,size:CGFloat,tracking:CGFloat)->some View {
        let size=(size*16).rounded()/16
        return SwiftUI.Text(words).font(look.weight == 700 ? LauncherStyle.font(size,.bold) : Font(SystemFont.nsFont(size,look.weight)))
            .tracking(tracking).foregroundStyle(look.color).fixedSize()
            .frame(width:0,height:0,alignment:.leading)
    }
}

/// Customize's own morph, with the header's fold (the design's studio morph, 560 ms). Opening, its word travels to the
/// card's title, its size, spacing and colour becoming the title's on the way (the two crossfading as the header's
/// texts do), hidden behind the card where it crosses it; the line under the word stays where it was and fades in the
/// last quarter. Closing, the title travels back to the word, and the line comes back in the last quarter.
struct StudioMorph: View {
    @Bindable var studio:DiscordStudio
    let fold:DiscordStudio.Fold
    let t:Double
    static let length=0.56
    private enum Look { case word,title }
    var body:some View {
        // Where its parts were as the fold started, with the moves since worked out on the fold's own clock.
        let frames=fold.frames
        if let word=frames[.customize],let title=frames[.cardTitle],let row=frames[.levelRow] {
            let p=min(1,max(0,t/Self.length)),e=HeaderFold.ease(p),k=min(1,max(0,(p-0.12)/0.6))
            // How far the layout still has to go (its moves take the header's time and curve): the title rides the
            // bar as the header folds, and rises in; the word, coming back, rides the tab's page as the header opens
            // and the stage grows, and drops in (DiscordTab).
            let left=1-HeaderFold.ease(t/HeaderFold.length),back=(studio.ride.page-22)*left
            let to=fold.opening ? title.offsetBy(dx:0,dy:HeaderFold.chrome*left+HeaderFold.title(fold,at:t).rise) : word.offsetBy(dx:0,dy:back)
            let from=fold.opening ? word : title
            let x=from.minX+(to.minX-from.minX)*e,y=from.midY+(to.midY-from.midY)*e
            let a:Look=fold.opening ? .word : .title,b:Look=fold.opening ? .title : .word
            let size=size(a)+(size(b)-size(a))*e,tracking=tracking(a)+(tracking(b)-tracking(a))*e
            let line=CGRect(x:word.minX,y:row.minY+30,width:word.width,height:3)
            ZStack(alignment:.topLeading) {
                ZStack(alignment:.topLeading) {
                    layer(a,size:size,tracking:tracking).opacity(1-k)
                    layer(b,size:size,tracking:tracking).opacity(k)
                }
                .frame(width:0,height:0,alignment:.leading).position(x:x,y:y)
                // Hidden where the card is now, as it moves.
                .mask { BehindCard(card:studio.foldFrames[studio.screen == .home ? .shellHome : .shellEditor]).fill(style:FillStyle(eoFill:true)) }
                if fold.opening {
                    MorphFrame().frame(width:line.width,height:line.height).position(x:line.midX,y:line.midY)
                        .opacity(1-min(1,max(0,(p-0.74)/0.26)))
                } else {
                    let q=min(1,max(0,(p-0.74)/0.26))
                    Underline(custom:true).frame(width:line.width,height:line.height).position(x:line.midX,y:line.midY+back).opacity(q*q*(3-2*q))
                }
            }
        }
    }
    private func size(_ look:Look)->CGFloat { look == .word ? 14 : 24 }
    private func tracking(_ look:Look)->CGFloat { look == .word ? 0 : -0.7 }
    /// A layer's text, its leading edge at the middle of a frame with no size, its middle across it, its size in a 16th of
    /// a point's steps (HeaderFoldTexts). The word keeps its ribbon: as it was when the word left, or moving as the
    /// word's own does when it's coming back.
    @ViewBuilder private func layer(_ look:Look,size:CGFloat,tracking:CGFloat)->some View {
        let font=Font(SystemFont.nsFont((size*16).rounded()/16,700))
        Group {
            if look == .word {
                let words=DiscordPresenceLevel.custom.title
                SwiftUI.Text(words).font(font).tracking(tracking).foregroundStyle(.clear)
                    .overlay { RibbonLine(rounded:false,still:fold.opening ? fold.at : nil).mask { SwiftUI.Text(words).font(font).tracking(tracking) } }
            } else {
                SwiftUI.Text(fold.title).font(font).tracking(tracking).foregroundStyle(DiscordColors.body)
            }
        }
        .fixedSize().frame(width:0,height:0,alignment:.leading)
    }
}
/// Everywhere but the card (filled even-odd): what passes behind it.
private struct BehindCard: Shape {
    let card:CGRect?
    func path(in rect:CGRect)->Path {
        var path=Path(rect)
        if let card { path.addRect(card) }
        return path
    }
}
/// The design's gradient frame (its ring ghost): a point and a half wide, amber through violet, glowing.
private struct MorphFrame: View {
    var body:some View {
        RoundedRectangle(cornerRadius:2).strokeBorder(LinearGradient(stops:DiscordColors.frame,startPoint:.leading,endPoint:.trailing),lineWidth:1.5)
            .shadow(color:Color(red:1,green:120/255,blue:90/255).opacity(0.3),radius:5)
    }
}
