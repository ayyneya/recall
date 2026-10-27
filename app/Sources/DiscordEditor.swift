import SwiftUI

// Customize, as the design lays it out: the card on its stage at the top, the card's parts down the left (in
// the card's own order), and the part being changed on the right. A click on the card picks a part too. The
// card's name opens My cards (DiscordGallery.swift), which takes over the stage.

struct DiscordEditor: View {
    @Bindable var studio:DiscordStudio
    var body:some View {
        VStack(alignment:.leading,spacing:0) {
            if !studio.gallery {
                HStack(alignment:.top,spacing:10) {
                    EditorRail(studio:studio).frame(width:158)
                    PanelScroller { EditorPanel(studio:studio).padding(.horizontal,2).padding(.bottom,12) }
                }
                .padding(.top,12).frame(maxHeight:.infinity,alignment:.top)
                .popIn(0.42).transition(.identity)
            }
            Spacer(minLength:0)
            EditorFooter(studio:studio).padding(.top,12)
        }
        .animation(.timingCurve(0.22,1,0.36,1,duration:0.52),value:studio.gallery)
    }
}

/// "Settings › Discord" over the page's title. In Customize the title is the card's name, which opens My cards.
struct DiscordPageHeader: View {
    @Bindable var studio:DiscordStudio
    var body:some View {
        VStack(alignment:.leading,spacing:2) {
            HStack(spacing:5) {
                LinkButton(title:L("Settings")) { studio.closePage() }
                DesignIcon("lucide:chevron-right",size:11).foregroundStyle(DiscordColors.ink(0.55))
                LinkButton(title:L("Discord")) { studio.closePage() }
            }
            HStack(spacing:8) {
                if studio.screen == .editor {
                    Button { studio.openGallery(!studio.gallery) } label: {
                        HStack(spacing:9) {
                            DesignIcon("rc:cards",size:18).foregroundStyle(DiscordColors.link)
                                .frame(width:30,height:30).background(DiscordColors.accent.opacity(studio.gallery ? 0.24 : 0.12),in:RoundedRectangle(cornerRadius:9))
                            Text(studio.gallery ? L("My cards") : studio.design.shownName).designFont(24,.bold).tracking(-0.7).lineLimit(1)
                                .foregroundStyle(DiscordColors.body).contentTransition(.opacity)
                            DesignIcon("lucide:chevron-down",size:16).foregroundStyle(DiscordColors.ink(0.45)).rotationEffect(.degrees(studio.gallery ? 180 : 0))
                        }.frame(height:32).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel(L("My cards")).accessibilityValue(studio.gallery ? L("Open") : L("Closed"))
                } else {
                    Text(studio.screen == .profile ? L("Your profile") : L("What Recall remembers")).designFont(24,.bold).tracking(-0.7).foregroundStyle(DiscordColors.body)
                }
            }.frame(minHeight:32)
        }
        .frame(height:46,alignment:.bottom)
        .animation(.timingCurve(0.22,1,0.36,1,duration:0.35),value:studio.gallery)
    }
}

/// The card on its stage: on Discord's tab as friends see it, in Discord's pop-out (a click on a part opens
/// Customize on it); in Customize as a computer or a phone shows it, with the part being changed marked; in My
/// cards, the gallery. One stage for all three, so going between them only changes its height.
struct CardStage: View {
    @Bindable var studio:DiscordStudio
    var body:some View {
        let home=studio.screen == .home
        DiscordStage(studio:studio,height:home ? 396 : studio.gallery ? 548 : 252,top:home ? 0 : 34,power:home) {
            if studio.gallery {
                DiscordGallery(studio:studio)
            } else {
                // Off, the card stays under the stage's cover, as the design shows it.
                TimelineView(.periodic(from:.now,by:1)) { context in
                    let activity=studio.activity(at:context.date)
                    // From now, not the timeline's tick (up to a second before it).
                    let outlineDelay:Double=studio.levelFlow.map { flow in max(0,0.88-Date().timeIntervalSince(flow.at)) } ?? 0
                    if home || studio.device == .desktop {
                        DiscordShell(profile:home,avatar:studio.avatar,fun:studio.profileFun) {
                            DiscordCardView(activity:activity,now:context.date,selected:home ? nil : studio.slot,
                                            pick:home ? (studio.power ? { studio.openEditor(at:$0) } : nil) : { studio.pick($0) },
                                            lineTwoTurn:home ? studio.homeLineTwoTurn(at:context.date) : nil,
                                            level:home ? studio.level : nil,turn:studio.turn(at:context.date))
                                .modifier(LevelReveal(level:studio.level,on:home))
                                .overlay {
                                    if home && studio.level == .custom {
                                        // After Customize's light has traced the card, when it's running.
                                        MarchingOutline(delay:outlineDelay)
                                            .transition(.asymmetric(insertion:.identity,removal:.opacity.animation(.linear(duration:0.22))))
                                    }
                                }
                                .overlay(alignment:.top) { if !home { TurnDots(studio:studio,now:context.date).offset(y:10).transition(.afterMove) } }
                                .onGeometryChange(for:CGRect.self) { $0.frame(in:.discordTab) } action:{ studio.cardFrame=$0 }
                        }
                        .frame(maxHeight:.infinity)
                    } else {
                        PhoneFrame {
                            DiscordCardView(activity:activity,now:context.date,phone:true,selected:studio.slot,pick:{ studio.pick($0) },turn:studio.turn(at:context.date))
                                .overlay(alignment:.top) { TurnDots(studio:studio,now:context.date).offset(y:10) }
                        }
                    }
                }
                .transition(.opacity)
            }
        } controls: {
            if !home && !studio.gallery { DeviceToggle(studio:studio).transition(.afterMove) }
        }
        .overlay(alignment:.topLeading) {
            if !home && !studio.gallery {
                if studio.device == .phone {
                    StageChip(icon:"lucide:smartphone",text:L("No hover or buttons"))
                        .designTip(L("Discord on phones shows the lines and the pictures, but no hover text and no buttons."),discord:true)
                        .padding(.leading,153).padding(.top,10).fadeIn(0.3).transition(.identity)
                } else if !studio.hoverSeen {
                    StageChip(icon:"lucide:mouse",text:L("Point at pictures"),nudge:true).allowsHitTesting(false)
                        .padding(.leading,164).padding(.top,10).fadeIn(0.5,delay:0.8).transition(.identity)
                }
            }
        }
        .overlay(alignment:studio.device == .phone ? .bottom : .bottomLeading) {
            if !home && studio.usesExample && !studio.gallery {
                Text(L("Example data")).designFont(11,.bold).foregroundStyle(Color(red:1,green:200/255,blue:130/255))
                    .padding(.horizontal,8).frame(height:18).background(Color(red:1,green:190/255,blue:92/255).opacity(0.14),in:RoundedRectangle(cornerRadius:6))
                    .padding(.leading,studio.device == .phone ? 0 : 13).padding(.bottom,studio.device == .phone ? 5 : 6)
                    .transition(.afterMove)
            }
        }
        .animation(.timingCurve(0.22,1,0.36,1,duration:0.52),value:studio.gallery)
        .animation(.easeOut(duration:0.3),value:studio.device)
    }
}
/// The card's box on Discord's tab when a level changes its height, as the design's: the parts inside take their new places
/// at once, and the box grows or shrinks to them over 0.32 s, clipping them.
private struct LevelReveal: ViewModifier {
    let level:DiscordPresenceLevel
    let on:Bool
    @State private var height:CGFloat?
    @State private var sized:DiscordPresenceLevel?
    func body(content:Content)->some View {
        if on {
            content
                .fixedSize(horizontal:false,vertical:true)
                .onGeometryChange(for:CGFloat.self) { $0.size.height } action:{ new in
                    if let sized,sized != level { withAnimation(.timingCurve(0.3,0.75,0.35,1,duration:0.32)) { height=new } } else { height=new }
                    sized=level
                }
                .frame(height:height,alignment:.top)
                .background(DiscordColors.card,in:RoundedRectangle(cornerRadius:8))
                .clipShape(RoundedRectangle(cornerRadius:8))
        } else {
            content
        }
    }
}
/// A quiet chip on the stage ("Point at pictures"), its icon nudging now and then: still most of 2.6 seconds, then
/// a point up and right, a point down and left and back, as the design's keyframes go.
private struct StageChip: View {
    let icon:String
    let text:String
    var nudge=false
    var body:some View {
        HStack(spacing:6) {
            DesignIcon(icon,size:12).foregroundStyle(Color(red:1,green:170/255,blue:120/255))
                .keyframeAnimator(initialValue:CGSize.zero,repeating:nudge) { view,offset in view.offset(offset) } keyframes:{ _ in
                    KeyframeTrack(\.self) {
                        LinearKeyframe(CGSize.zero,duration:1.82)
                        LinearKeyframe(CGSize(width:1,height:-1),duration:0.26,timingCurve:.easeInOut)
                        LinearKeyframe(CGSize(width:-1,height:1),duration:0.26,timingCurve:.easeInOut)
                        LinearKeyframe(CGSize.zero,duration:0.26,timingCurve:.easeInOut)
                    }
                }
            Text(text).designFont(11,.semibold)
        }
        .foregroundStyle(DiscordColors.ink(0.62))
        .padding(.leading,7).padding(.trailing,9).frame(height:24)
        .background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:7))
        .environment(\.colorScheme,.dark)
    }
}
/// Desktop or phone.
private struct DeviceToggle: View {
    @Bindable var studio:DiscordStudio
    var body:some View {
        HStack(spacing:2) {
            button(.desktop,icon:"lucide:monitor",name:L("Desktop"))
            button(.phone,icon:"lucide:smartphone",name:L("Phone"))
        }.padding(2).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:8))
    }
    private func button(_ device:DiscordStudio.Device,icon:String,name:String)->some View {
        let on=studio.device == device
        return Button { withAnimation(.timingCurve(0.22,1,0.36,1,duration:0.4)) { studio.device=device } } label: {
            HStack(spacing:5) { DesignIcon(icon,size:13);if on { Text(name).designFont(11.5,.semibold).transition(.opacity) } }
                .foregroundStyle(on ? .white : DiscordColors.ink(0.45))
                .padding(.leading,on ? 7 : 6).padding(.trailing,on ? 9 : 6).frame(height:22)
                .background(on ? .white.opacity(0.16) : .clear,in:RoundedRectangle(cornerRadius:6))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(name).accessibilityAddTraits(on ? .isSelected : [])
    }
}
/// A phone's top edge and notch around the card, running past the stage's bottom.
struct PhoneFrame<Content:View>: View {
    @ViewBuilder var content:Content
    var body:some View {
        // The design's phone: 393 points wide, 42 below the stage's inside, the screen and its notch inside a
        // five-point edge, a little left of the middle (its -197 margin), running out under the stage's bottom.
        VStack(spacing:0) { content }
            .padding(.top,36).padding(.horizontal,16)
            .frame(maxHeight:.infinity,alignment:.top)
            .overlay(alignment:.top) { Capsule().fill(.black).frame(width:120,height:26).padding(.top,9) }
            .padding([.top,.horizontal],5)
            .frame(width:393)
            .background(Color(red:26/255,green:27/255,blue:30/255))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius:44,topTrailingRadius:44))
            .overlay { PhoneEdge().stroke(Color(red:58/255,green:60/255,blue:66/255),lineWidth:5) }
            .offset(x:-0.5)
            .padding(.top,43-34).padding(.bottom,-30)
            .environment(\.colorScheme,.dark)
    }
}
/// The phone's edge: its sides and top, rounded, open at the bottom.
private struct PhoneEdge: Shape {
    func path(in rect:CGRect)->Path {
        let r=rect.insetBy(dx:2.5,dy:2.5),radius:CGFloat=44-2.5
        var path=Path()
        path.move(to:CGPoint(x:r.minX,y:rect.maxY))
        path.addLine(to:CGPoint(x:r.minX,y:r.minY+radius))
        path.addArc(center:CGPoint(x:r.minX+radius,y:r.minY+radius),radius:radius,startAngle:.degrees(180),endAngle:.degrees(270),clockwise:false)
        path.addLine(to:CGPoint(x:r.maxX-radius,y:r.minY))
        path.addArc(center:CGPoint(x:r.maxX-radius,y:r.minY+radius),radius:radius,startAngle:.degrees(270),endAngle:.degrees(0),clockwise:false)
        path.addLine(to:CGPoint(x:r.maxX,y:rect.maxY))
        return path
    }
}
/// The card's turns, as dots at its top: the one showing fills as its time passes; a click shows another.
struct TurnDots: View {
    @Bindable var studio:DiscordStudio
    let now:Date
    var label:String?=nil
    var body:some View {
        let length=studio.loopLength(at:now),turn=studio.turn(at:now),k=turn%max(1,length),done=studio.turnDone(at:now)
        if length > 1 {
            HStack(spacing:0) {
                ForEach(0..<length,id:\.self) { index in
                    let on=index == k
                    Capsule().fill(on ? .white.opacity(0.2) : index < k ? DiscordColors.accent.opacity(0.55) : .white.opacity(0.24))
                        .overlay(alignment:.leading) { if on { Capsule().fill(DiscordColors.accent).frame(width:20*done).animation(done < 0.1 ? nil : .linear(duration:1),value:done) } }
                        .frame(width:on ? 20 : 6,height:6).clipShape(Capsule())
                        .shadow(color:on ? Color(red:1,green:140/255,blue:90/255).opacity(0.4) : .clear,radius:4)
                        .padding(.horizontal,2.5).frame(height:18).contentShape(Rectangle())
                        .onTapGesture { withAnimation(.timingCurve(0.22,1,0.36,1,duration:0.5)) { studio.jump(to:index,at:now) } }
                }
            }
            .overlay(alignment:.top) {
                let text=label ?? (studio.held != nil ? L("Holding {0} of {1} while you edit",String(k+1),String(length)) : nil)
                if let text {
                    Text(text).designFont(10.5,.semibold).monospacedDigit().foregroundStyle(DiscordColors.ink(0.85)).fixedSize()
                        .padding(.horizontal,7).frame(height:19).background(Color(red:17/255,green:18/255,blue:20/255).opacity(0.92),in:RoundedRectangle(cornerRadius:6))
                        .offset(y:-24).transition(.opacity.combined(with:.offset(y:3))).allowsHitTesting(false)
                }
            }
            .opacity(studio.preview != nil ? 0.35 : 1)
            .animation(.timingCurve(0.22,1,0.36,1,duration:0.5),value:k)
            .environment(\.colorScheme,.dark)
        }
    }
}

/// The card's parts, in the card's order: the image and its badge, the game's name (fixed), the lines, the
/// timer, the buttons and the party. Each shows what it is now; a ring and a count when several take turns.
struct EditorRail: View {
    @Bindable var studio:DiscordStudio
    var body:some View {
        TimelineView(.seconds) { context in
            let now=context.date
            VStack(alignment:.leading,spacing:1) {
                item(.picture,title:L("Image"),now:now) { picture(now) }
                item(.badge,title:L("Badge"),now:now,height:36,leading:38,child:true,nameSize:12) { badge(now) }
                // The icons in the middle of the row, the two words on one baseline, as the design's row sets them.
                HStack(spacing:9) {
                    DesignIcon("ph:game-controller-fill",size:12).foregroundStyle(DiscordColors.ink(0.35)).frame(width:14,height:14).padding(.trailing,-5)
                    HStack(alignment:.firstTextBaseline,spacing:4) {
                        Text(L("Game")).designFont(11,.semibold).foregroundStyle(DiscordColors.ink(0.42)).fixedSize()
                        Text(verbatim:"Overwatch").designFont(11).foregroundStyle(DiscordColors.ink(0.5)).fixedSize()
                    }.frame(maxWidth:.infinity,alignment:.leading)
                    DesignIcon("lucide:lock",size:11).foregroundStyle(DiscordColors.ink(0.35))
                }
                .padding(.leading,17).padding(.trailing,9).frame(height:26)
                .designTip(L("Always shown. Discord takes the name from the game."))
                item(.lineOne,title:L("Line 1"),now:now) { icon("rc:line1") }
                item(.lineTwo,title:L("Line 2"),now:now) { icon("rc:line2") }
                item(.timer,title:L("Timer"),now:now) { icon("ph:timer-fill") }
                item(.buttons,title:L("Buttons"),now:now) { icon("rc:buttons") }
                item(.party,title:L("Party"),now:now) { icon("ph:users-three-fill") }
            }
            .glider(studio.slot,style:.rows,axis:.vertical) { RoundedRectangle(cornerRadius:11).fill(.white.opacity(0.07)) }
        }
    }
    private func item<Tile:View>(_ slot:DiscordStudio.Slot,title:String,now:Date,height:CGFloat=42,leading:CGFloat=11,child:Bool=false,nameSize:CGFloat=12.5,@ViewBuilder tile:()->Tile)->some View {
        let on=studio.slot == slot,count=studio.railCount(slot,at:now)
        return Button { studio.pick(slot) } label: {
            HStack(spacing:9) {
                tile()
                VStack(alignment:.leading,spacing:1) {
                    Text(title).designFont(nameSize,.semibold).lineLimit(1)
                        .animation(.cssEase(0.25)) { $0.foregroundStyle(on ? DiscordColors.bright : DiscordColors.ink(0.75)) }
                    Text(studio.railSummary(slot,at:now)).designFont(11).foregroundStyle(DiscordColors.ink(0.5)).lineLimit(1)
                }.frame(maxWidth:.infinity,alignment:.leading)
                if count > 1 {
                    HStack(spacing:3) {
                        ZStack {
                            Circle().stroke(.white.opacity(0.13),lineWidth:2)
                            Circle().trim(from:0,to:studio.turnDone(at:now)).stroke(DiscordColors.accent,style:StrokeStyle(lineWidth:2,lineCap:.round)).rotationEffect(.degrees(-90))
                        }.frame(width:10,height:10).padding(1.5)
                        Text("\(count)").designFont(10.5,.bold).monospacedDigit()
                    }.foregroundStyle(DiscordColors.ink(0.55))
                }
            }
            .padding(.leading,leading).padding(.trailing,9).frame(height:height)
            .glideItem(slot)
            .overlay(alignment:.topLeading) { if child { Connector().stroke(.white.opacity(0.13),lineWidth:1.5).frame(width:11.5,height:23.5).offset(x:24,y:-6).allowsHitTesting(false) } }
            .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
    }
    private func icon(_ name:String)->some View {
        DesignIcon(name,size:14).foregroundStyle(DiscordColors.ink(0.65))
            .frame(width:26,height:26).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:8))
    }
    private func picture(_ now:Date)->some View {
        let url=(studio.activity(at:now)["assets"] as? [String:String])?["large_image"].flatMap(URL.init(string:))
        return Group { if let url { RemoteImage(url:url) { DiscordColors.tile } } else { GameIcon().padding(2.6) } }
            .frame(width:26,height:26).background(url == nil ? .clear : DiscordColors.tile).clipShape(RoundedRectangle(cornerRadius:8))
    }
    private func badge(_ now:Date)->some View {
        let url=(studio.activity(at:now)["assets"] as? [String:String])?["small_image"].flatMap(URL.init(string:)) ?? Brand.macBadge
        return BadgeImage(url:url,size:20,back:DiscordColors.stage,inset:0.86)
    }
}
/// The line from the image down to its badge, in the rail: the design's left and bottom borders (1.5 points
/// outside a box 10 by 22, rounded 7 at their corner), drawn along their middles.
private struct Connector: Shape {
    func path(in rect:CGRect)->Path {
        var path=Path()
        path.move(to:CGPoint(x:rect.minX+0.75,y:rect.minY))
        path.addArc(tangent1End:CGPoint(x:rect.minX+0.75,y:rect.maxY-0.75),tangent2End:CGPoint(x:rect.maxX,y:rect.maxY-0.75),radius:6.25)
        path.addLine(to:CGPoint(x:rect.maxX,y:rect.maxY-0.75))
        return path
    }
}

/// The panel's scroll: no scroll bars; the edges fade where there's more, and a bobbing arrow at the bottom
/// scrolls on when there is.
struct PanelScroller<Content:View>: View {
    @ViewBuilder var content:Content
    @State private var above=false
    @State private var below=false
    @State private var position=ScrollPosition()
    @State private var offset:CGFloat=0
    @State private var page:CGFloat=0
    var body:some View {
        ScrollView { content }
            .scrollIndicators(.never)
            .scrollPosition($position)
            .onScrollGeometryChange(for:[CGFloat].self) { [$0.contentOffset.y,$0.contentSize.height,$0.containerSize.height] } action:{ _,value in
                offset=value[0];page=value[2]
                above=value[0] > 2;below=value[0]+value[2] < value[1]-2
            }
            .mask {
                VStack(spacing:0) {
                    LinearGradient(colors:[.black.opacity(above ? 0 : 1),.black],startPoint:.top,endPoint:.bottom).frame(height:18)
                    Color.black
                    LinearGradient(colors:[.black,.black.opacity(below ? 0 : 1)],startPoint:.top,endPoint:.bottom).frame(height:28)
                }
            }
            .overlay(alignment:.bottom) {
                if below {
                    Button { withAnimation(.smooth) { position.scrollTo(y:offset+page*0.7) } } label: { BobbingChevron() }
                        .buttonStyle(.plain).accessibilityLabel(L("Scroll down")).transition(.opacity)
                }
            }
            .animation(.easeOut(duration:0.25),value:below)
    }
}
private struct BobbingChevron: View {
    @State private var down=false
    var body:some View {
        DesignIcon("lucide:chevron-down",size:15).foregroundStyle(DiscordColors.ink(0.7))
            .offset(y:down ? 2 : -1).frame(width:30,height:20).contentShape(Rectangle())
            .onAppear { withAnimation(.easeInOut(duration:0.8).repeatForever()) { down=true } }
    }
}

/// What was just done, with its Undo; and Done.
struct EditorFooter: View {
    @Bindable var studio:DiscordStudio
    var body:some View {
        HStack(spacing:0) {
            if let toast=studio.toast {
                HStack(spacing:8) {
                    DesignIcon("lucide:check",size:14).foregroundStyle(DiscordColors.fill)
                    Text(toast.text).designFont(12).foregroundStyle(DiscordColors.bright).lineLimit(1).truncationMode(.tail)
                    if toast.undo != nil {
                        Button { studio.undo() } label: {
                            Text(L("Undo")).designFont(12,.semibold).foregroundStyle(.white)
                                .padding(.horizontal,11).frame(height:26).background(.white.opacity(0.12),in:RoundedRectangle(cornerRadius:8))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.trailing,12).popIn(0.36).id(toast.text).transition(.identity)
            }
            Spacer(minLength:0)
            FillButton(title:L("Done")) { studio.closePage() }.keyboardShortcut(.cancelAction)
        }
        .frame(height:30)
        .animation(.timingCurve(0.22,1,0.36,1,duration:0.36),value:studio.toast?.text)
    }
}
/// The design's orange button, a little lighter while pointed at.
struct FillButton: View {
    let title:String
    var icon:String?=nil
    var height:CGFloat=30
    var size:CGFloat=13
    var radius:CGFloat?=nil
    var padding:CGFloat=16
    var weight:Font.Weight = .semibold
    let action:()->Void
    @State private var inside=false
    var body:some View {
        Button(action:action) {
            HStack(spacing:6) {
                if let icon { DesignIcon(icon,size:13) }
                Text(title).designFont(size,weight)
            }
            .foregroundStyle(.white).padding(.horizontal,padding).frame(height:height)
            .background(inside ? DiscordColors.fillHover : DiscordColors.fill,in:RoundedRectangle(cornerRadius:radius ?? height/2))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { inside=$0 }
    }
}
