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
        ZStack {
            DotPattern().fill(.white.opacity(0.05)).allowsHitTesting(false)
            content.padding(.top,top).frame(maxWidth:.infinity,maxHeight:.infinity)
        }
        .frame(maxWidth:.infinity).frame(height:height)
        .overlay(alignment:.topLeading) {
            HStack(spacing:6) {
                DesignIcon("ic:baseline-discord",size:16).foregroundStyle(DiscordColors.ink(0.45))
                    .frame(width:26,height:26).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:8,style:.continuous))
                controls
            }.padding(.leading,10).padding(.top,8)
        }
        .overlay(alignment:.topTrailing) {
            HStack(spacing:4) {
                SceneChip(studio:studio)
                if power { PowerButton(studio:studio).transition(.afterMove) }
            }.padding(.trailing,10).padding(.top,8)
        }
        .overlay { if power && !studio.power { OffCover(studio:studio).transition(.opacity) } }
        .background(DiscordColors.stage)
        .clipShape(RoundedRectangle(cornerRadius:20,style:.continuous))
        .overlay { RoundedRectangle(cornerRadius:20,style:.continuous).strokeBorder(.white.opacity(0.06),lineWidth:1) }
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
                Text(studio.sceneName)
                if studio.sceneVoice {
                    Text(verbatim:"&").opacity(0.6)
                    DesignIcon("ph:users-three-fill",size:14)
                    Text(L("Voice"))
                }
            }
            .font(LauncherStyle.font(11.5,.semibold)).foregroundStyle(DiscordColors.ink(inside && studio.live == nil ? 0.85 : 0.5))
            .padding(.leading,8).padding(.trailing,9).frame(height:26)
            .background(inside && studio.live == nil ? .white.opacity(0.06) : .clear,in:RoundedRectangle(cornerRadius:8,style:.continuous))
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
                .frame(width:26,height:26).background(.white.opacity(studio.power ? 0.06 : 0.1),in:RoundedRectangle(cornerRadius:8,style:.continuous))
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
            Text(L("Discord card is off")).font(LauncherStyle.font(14,.semibold)).foregroundStyle(.white)
            Text(L("Recall stops reading the game log, disconnects from Discord and stops the timer. Nothing stays loaded."))
                .font(LauncherStyle.font(12)).lineHeight(1.5,size:12).foregroundStyle(DiscordColors.ink(0.62)).multilineTextAlignment(.center).frame(maxWidth:300)
            FillButton(title:L("Turn on"),height:30,size:12.5,radius:9) { studio.setPower(true) }.padding(.top,6)
        }
        .frame(maxWidth:.infinity,maxHeight:.infinity)
        .background(Color(red:23/255,green:24/255,blue:27/255).opacity(0.94))
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
                // The design's line height (1.4) around the line as well as between lines.
                Text(studio.power ? studio.level.detail : L("Off. Nothing runs until you turn it back on."))
                    .font(LauncherStyle.font(12.5)).lineHeight(1.4,size:12.5).foregroundStyle(DiscordColors.ink(0.62)).padding(.leading,4)
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
/// A fine dashed outline marching slowly around the card while it's the player's own: it can be edited.
struct MarchingOutline: View {
    @State private var phase:CGFloat=0
    var body:some View {
        RoundedRectangle(cornerRadius:7.25,style:.continuous).inset(by:0.75)
            .stroke(LinearGradient(stops:[.init(color:Color(red:1,green:184/255,blue:92/255),location:0),.init(color:Color(red:1,green:140/255,blue:70/255),location:0.3),
                                          .init(color:Color(red:1,green:112/255,blue:104/255),location:0.55),.init(color:Color(red:1,green:92/255,blue:138/255),location:0.8),
                                          .init(color:Color(red:214/255,green:98/255,blue:230/255),location:1)],startPoint:.bottom,endPoint:.top),
                    style:StrokeStyle(lineWidth:1.5,lineCap:.round,dash:[5,5],dashPhase:phase))
            .opacity(0.9).allowsHitTesting(false)
            .onAppear { withAnimation(.linear(duration:1.2).repeatForever(autoreverses:false)) { phase = -10 } }
    }
}

/// "Friends see  Basic  Live  Full  Customize ›": the chosen one bright, with a line under it that glides to
/// another (white, or the design's moving ribbon of colour under Customize).
struct LevelWords: View {
    @Bindable var studio:DiscordStudio
    @Namespace private var line
    @State private var inside:DiscordPresenceLevel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        HStack(spacing:14) {
            Text(L("Friends see")).font(LauncherStyle.font(13)).foregroundStyle(DiscordColors.ink(0.42))
            HStack(spacing:18) {
                ForEach(DiscordPresenceLevel.allCases) { level in
                    let on=studio.level == level,custom=level == .custom
                    Button {
                        withAnimation(reduceMotion ? nil : .timingCurve(0.22,1,0.36,1,duration:0.45)) { studio.choose(level) }
                    } label: {
                        HStack(spacing:5) {
                            Group {
                                if custom { RibbonText(text:level.title,weight:on ? .bold : .semibold) }
                                else { Text(level.title).font(LauncherStyle.font(14,on ? .bold : .regular)).foregroundStyle(on ? DiscordColors.bright : DiscordColors.ink(0.55)) }
                            }
                            if custom && on { DesignIcon("lucide:chevron-right",size:14).foregroundStyle(Color(red:1,green:150/255,blue:120/255).opacity(0.8)).padding(.leading,-2).transition(.scale.combined(with:.opacity)) }
                        }
                        .frame(height:34)
                        .overlay(alignment:.bottom) {
                            if on {
                                Group { if custom { RibbonLine() } else { Capsule().fill(DiscordColors.ink(1)) } }
                                    .frame(height:3).clipShape(Capsule())
                                    .shadow(color:custom ? Color(red:1,green:140/255,blue:80/255).opacity(0.38) : DiscordColors.ink(0.16),radius:5)
                                    .padding(.bottom,1).padding(.trailing,custom ? 19 : 0)
                                    .matchedGeometryEffect(id:"underline",in:line)
                            }
                        }
                        .brightness(inside == level ? 0.15 : 0)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).onHover { inside=$0 ? level : nil }
                    .accessibilityLabel(custom && on ? L("Edit your card") : level.title).accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }.frame(height:34).padding(.leading,2)
    }
}
/// Customize's word: the design's ribbon of colour moving through the letters.
private struct RibbonText: View {
    let text:String
    let weight:Font.Weight
    var body:some View {
        Text(text).font(LauncherStyle.font(14,weight)).foregroundStyle(.clear)
            .overlay { RibbonLine().mask { Text(text).font(LauncherStyle.font(14,weight)) } }
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
                        Text(L("Add your BattleTag")).font(LauncherStyle.font(13,.semibold)).foregroundStyle(DiscordColors.bright).fixedSize()
                        Text(L("for ranks and records")).font(LauncherStyle.font(11.5)).normalLines(size:11.5).foregroundStyle(DiscordColors.ink(0.5)).lineLimit(1).frame(maxWidth:.infinity,alignment:.leading)
                    } else {
                        Text(verbatim:studio.battleTag).font(LauncherStyle.font(13,.semibold)).foregroundStyle(DiscordColors.bright).fixedSize()
                        if let chip=studio.tagChip {
                            HStack(spacing:5) {
                                if let icon=chip.icon { RemoteImage(url:icon,fill:false) { Color.clear }.frame(width:16,height:16) } else { DesignIcon("lucide:lock",size:12) }
                                Text(chip.text)
                            }
                            .font(LauncherStyle.font(11.5,.semibold)).foregroundStyle(DiscordColors.ink(0.85))
                            .padding(.leading,chip.icon == nil ? 7 : 5).padding(.trailing,9).frame(height:24)
                            .background(DiscordColors.veil(0.06),in:RoundedRectangle(cornerRadius:7,style:.continuous)).fixedSize()
                        }
                        Text(studio.tagNote).font(LauncherStyle.font(11.5)).normalLines(size:11.5).foregroundStyle(DiscordColors.ink(0.5)).lineLimit(1).frame(maxWidth:.infinity,alignment:.leading)
                    }
                    DesignIcon("lucide:chevron-right",size:14).foregroundStyle(DiscordColors.ink(0.4))
                }
                Rectangle().fill(DiscordColors.veil(0.06)).frame(height:1).padding(.horizontal,12)
            }
            RowButton(height:40) { studio.openHistory() } label: {
                DesignIcon("lucide:database",size:14).foregroundStyle(DiscordColors.ink(0.55))
                Text(L("What Recall remembers")).font(LauncherStyle.font(12.5,.medium)).foregroundStyle(DiscordColors.bright).frame(maxWidth:.infinity,alignment:.leading)
                Text(studio.historyNote).font(LauncherStyle.font(11.5)).normalLines(size:11.5).foregroundStyle(DiscordColors.ink(0.45)).lineLimit(1)
                DesignIcon("lucide:chevron-right",size:14).foregroundStyle(DiscordColors.ink(0.4))
            }
        }
        // Inside its one-point border, as the design's box is.
        .padding(1)
        .background(DiscordColors.veil(0.04),in:RoundedRectangle(cornerRadius:13,style:.continuous))
        .clipShape(RoundedRectangle(cornerRadius:13,style:.continuous))
        .overlay { RoundedRectangle(cornerRadius:13,style:.continuous).strokeBorder(DiscordColors.veil(0.06),lineWidth:1) }
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
