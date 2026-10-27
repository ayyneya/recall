import SwiftUI
import AppKit

// Settings › Discord's two pages, as the design has them. Your profile: the BattleTag, whether the profile is
// public, everything Recall reads from it and where it shows on the card. What Recall remembers: the sessions
// kept on this Mac (only the BattleTag ever leaves it), where they come from, holding to erase them (ten seconds
// to undo), and exporting them.

// MARK: your profile

struct ProfilePage: View {
    @Bindable var studio:DiscordStudio
    @FocusState private var typing:Bool
    var body:some View {
        let state=studio.profileState
        // The design's column: when the rows don't fit, the BattleTag's card and both boxes give up height (the
        // list scrolling inside its box), as its flexbox shrinks them.
        FlexColumn(spacing:12) {
            Text(state == .none ? L("Recall can read your public career profile from your BattleTag. Full and Customize use it for ranks, records and heroes. Only the BattleTag is sent, to OverFast.")
                                : L("Everything Recall reads from your BattleTag, and where it shows on your card. It looks again after you quit Overwatch."))
                .designFont(12.5,line:12.5*1.5,wraps:true).foregroundStyle(DiscordColors.ink(0.65)).fixedSize(horizontal:false,vertical:true)
            // The card comes back at once, as the design's does.
            if studio.tagEditing { tagField } else if !studio.battleTag.isEmpty { tagCard.transition(.identity) }
            if studio.tagEditing && !studio.battleTag.isEmpty {
                HStack(spacing:10) {
                    Text(L("Or stop using a BattleTag. Full and Customize then show only what the game’s log knows."))
                        .designFont(11.5,line:11.5*1.4).foregroundStyle(DiscordColors.ink(0.5)).frame(maxWidth:.infinity,alignment:.leading)
                    PageButton(title:L("Remove"),danger:true) { studio.removeBattleTag() }
                }.padding(.leading,14).padding(.trailing,8).padding(.top,-4).popIn(0.28).transition(.identity)
            }
            if state == .hidden && !studio.battleTag.isEmpty { privateNotice }
            SectionLabel(text:state == .shown ? L("WHAT RECALL READS") : state == .hidden ? L("WHAT IT WOULD READ") : L("WHAT IT CAN READ"))
            ScrollView { factList }.scrollIndicators(.never)
                .background(DiscordColors.surface,in:RoundedRectangle(cornerRadius:16))
                .clipShape(RoundedRectangle(cornerRadius:16)).flexShrink()
            SectionLabel(text:L("NOT ON THE CARD"))
            FactRow(studio:studio,row:studio.notOnCard(),index:nil)
                .frame(minHeight:0,alignment:.top)
                .background(DiscordColors.surface,in:RoundedRectangle(cornerRadius:16))
                .clipShape(RoundedRectangle(cornerRadius:16)).flexShrink()
            Color.clear.flexGrow()
            HStack { Spacer();PageButton(title:L("Done")) { studio.closePage() }.keyboardShortcut(.cancelAction) }
        }
        .animation(.timingCurve(0.22,1,0.36,1,duration:0.3),value:studio.tagEditing)
        .animation(.timingCurve(0.22,1,0.36,1,duration:0.3),value:studio.openFact)
    }
    private var factList:some View {
        VStack(spacing:0) {
            ForEach(Array(studio.profileFacts().enumerated()),id:\.offset) { index,row in FactRow(studio:studio,row:row,index:index) }
        }
    }
    /// The BattleTag, whether the profile shows, and when Recall last looked.
    private var tagCard:some View {
        HStack(spacing:12) {
            Group {
                if studio.profileState == .hidden { DesignIcon("lucide:lock",size:18).foregroundStyle(DiscordColors.ink(0.55)) }
                else { RemoteImage(url:studio.profile?.identity?.avatar) { DesignIcon("rc:user-fill",size:20).foregroundStyle(DiscordColors.ink(0.4)) } }
            }
            .frame(width:40,height:40).background(DiscordColors.tile).clipShape(RoundedRectangle(cornerRadius:10))
            VStack(alignment:.leading,spacing:2) {
                Text(verbatim:studio.battleTag).designFont(15,.bold).foregroundStyle(DiscordColors.body)
                Text(studio.profileStatus).designFont(11.5).foregroundStyle(DiscordColors.ink(0.55)).lineLimit(1)
            }.frame(maxWidth:.infinity,alignment:.leading)
            PageButton(title:L("Look again"),small:true) { studio.actions.lookAgain() }.disabled(studio.lookingUp)
            PageButton(title:L("Change"),small:true) { studio.tagDraft=studio.battleTag;studio.tagError=false;studio.tagEditing=true }
        }
        .padding(.leading,12).padding(.trailing,10).frame(minHeight:40,idealHeight:62,maxHeight:62)
        .background(DiscordColors.surface,in:RoundedRectangle(cornerRadius:16)).flexShrink()
    }
    /// Typing the BattleTag: Look up (or Return) checks it's a BattleTag and looks the profile up.
    private var tagField:some View {
        HStack(spacing:8) {
            DesignIcon("simple-icons:battledotnet",size:15).foregroundStyle(DiscordColors.ink(0.55))
            TextField(L("Name#1234"),text:$studio.tagDraft)
                .textFieldStyle(.plain).font(LauncherStyle.font(13,.semibold)).autocorrectionDisabled()
                .focused($typing).onAppear { typing=true }
                .onSubmit { studio.saveBattleTag() }.onExitCommand { studio.cancelBattleTag() }
                .onChange(of:studio.tagDraft) { studio.tagError=false }
            if studio.tagError { Text(L("Name#1234")).designFont(11.5).foregroundStyle(Color(red:1,green:130/255,blue:118/255)) }
            Button(L("Cancel")) { studio.cancelBattleTag() }.buttonStyle(QuietButtonStyle())
            FillButton(title:L("Look up"),height:30,size:12,radius:8,padding:12,weight:.bold) { studio.saveBattleTag() }
        }
        .padding(.leading,14).padding(.trailing,8).frame(height:52)
        .background(DiscordColors.surface,in:RoundedRectangle(cornerRadius:16))
        .overlay { RoundedRectangle(cornerRadius:16).strokeBorder(studio.tagError ? Color(red:1,green:99/255,blue:88/255).opacity(0.7) : DiscordColors.pick.opacity(0.55),lineWidth:1) }
        .popIn(0.28).transition(.identity)
    }
    private var privateNotice:some View {
        HStack(alignment:.top,spacing:10) {
            DesignIcon("lucide:eye-off",size:15).foregroundStyle(Color(red:1,green:200/255,blue:120/255)).padding(.top,1)
            VStack(alignment:.leading,spacing:3) {
                Text(L("Overwatch keeps this profile private")).designFont(12,.semibold,line:12*1.45).foregroundStyle(DiscordColors.body)
                Text(L("So ranks, records and heroes can’t show. Your card still shows what the game’s log knows. To make it public, in Overwatch: Options › Social › Career Profile Visibility › Public. Then Look again."))
                    .foregroundStyle(DiscordColors.ink(0.65)).cssLines(NSFont.systemFont(ofSize:12),12*1.45,wraps:true).fixedSize(horizontal:false,vertical:true)
            }.font(LauncherStyle.font(12))
        }
        // The design's padding inside its one-point border.
        .padding(.horizontal,14).padding(.vertical,12).frame(maxWidth:.infinity,alignment:.leading)
        .background(Color(red:1,green:196/255,blue:92/255).opacity(0.08),in:RoundedRectangle(cornerRadius:14))
        .overlay { RoundedRectangle(cornerRadius:14).strokeBorder(Color(red:1,green:196/255,blue:92/255).opacity(0.18),lineWidth:1) }
    }
}
/// "WHAT RECALL READS": a small heading over a box.
struct SectionLabel: View {
    let text:String
    var body:some View {
        Text(text).designFont(10.5,.bold).tracking(10.5*0.05).foregroundStyle(DiscordColors.ink(0.4))
            .padding(.horizontal,4).padding(.bottom,-4)
    }
}
/// A page's quiet button (Look again, Change, Done), or a red one (Remove).
struct PageButton: View {
    let title:String
    var small=false
    var danger=false
    let action:()->Void
    @State private var inside=false
    var body:some View {
        Button(action:action) {
            Text(title).designFont(small || danger ? 12 : 13,small || danger ? .semibold : .medium)
                .foregroundStyle(danger ? Color(red:1,green:110/255,blue:100/255) : small ? DiscordColors.bright.opacity(0.88) : DiscordColors.bright)
                .padding(.horizontal,small || danger ? 10 : 16).frame(height:small || danger ? 26 : 30)
                .background(danger ? Color(red:1,green:69/255,blue:58/255).opacity(inside ? 0.18 : 0.12) : DiscordColors.veil(small ? (inside ? 0.13 : 0.08) : 0.1),
                            in:RoundedRectangle(cornerRadius:small || danger ? 7 : 15))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { inside=$0 }
    }
}
private struct QuietButtonStyle: ButtonStyle {
    @State private var inside=false
    func makeBody(configuration:Configuration)->some View {
        configuration.label.designFont(12,.semibold).foregroundStyle(inside ? DiscordColors.bright : DiscordColors.ink(0.7))
            .padding(.horizontal,10).frame(height:30).background(inside ? DiscordColors.veil(0.08) : .clear,in:RoundedRectangle(cornerRadius:8))
            .contentShape(Rectangle()).onHover { inside=$0 }
    }
}

/// One thing Recall reads: where it shows on the card, what it says now (a line that fades out at its end);
/// open, every fact, what the marks mean, and how it reads on the card.
struct ProfileFact {
    struct Fact { var text:String;var mark:String?=nil;var markColor:Color?=nil;var after:String?=nil;var sub:String?=nil;var image:URL?=nil }
    let icon:String
    var image:URL?=nil
    let name:String
    var places:[String]=[]
    let facts:[Fact]
    var legend:String?=nil
    var sample:String?=nil
    var sampleLabel:String?=nil
}
private struct FactRow: View {
    @Bindable var studio:DiscordStudio
    let row:ProfileFact
    /// Its place in the list (nil: the "not on the card" box, which doesn't open).
    let index:Int?
    var body:some View {
        let shown=studio.profileState == .shown,open=index != nil && studio.openFact == index
        VStack(alignment:.leading,spacing:0) {
            Button { if shown,let index { studio.openFact=studio.openFact == index ? nil : index } } label: {
                HStack(spacing:12) {
                    Group {
                        if shown,let image=row.image { RemoteImage(url:image) { Color.clear } } else { DesignIcon(row.icon,size:15).foregroundStyle(DiscordColors.ink(0.7)) }
                    }.frame(width:28,height:28).background(DiscordColors.veil(0.06)).clipShape(RoundedRectangle(cornerRadius:8))
                    VStack(alignment:.leading,spacing:3) {
                        HStack(spacing:5) {
                            Text(row.name).designFont(12.5,.semibold).foregroundStyle(DiscordColors.body).fixedSize()
                            Spacer(minLength:0)
                            ForEach(row.places,id:\.self) { place in
                                Text(place).designFont(10,.semibold).foregroundStyle(DiscordColors.ink(0.55))
                                    .padding(.horizontal,6).frame(height:17).background(DiscordColors.veil(0.06),in:RoundedRectangle(cornerRadius:5))
                            }
                        }
                        if shown {
                            // Open, the line folds away (its gap stays), as the design's does.
                            factLine.frame(height:open ? 0 : 18,alignment:.top).clipped()
                                .animation(.timingCurve(0.25,0.1,0.25,1,duration:0.25)) { $0.opacity(open ? 0 : 1) }
                        } else {
                            HStack(spacing:4) {
                                if studio.profileState == .hidden { DesignIcon("lucide:lock",size:11) }
                                Text(studio.profileState == .hidden ? L("Hidden by Overwatch") : studio.battleTag.isEmpty ? L("Needs your BattleTag") : L("Not found yet")).designFont(11.5)
                            }.foregroundStyle(DiscordColors.ink(0.4))
                        }
                    }
                    if shown && index != nil {
                        DesignIcon("lucide:chevron-down",size:14).foregroundStyle(DiscordColors.ink(0.4)).rotationEffect(.degrees(open ? 180 : 0))
                    }
                }
                .padding(.leading,14).padding(.trailing,12).padding(.vertical,7).frame(minHeight:52).contentShape(Rectangle())
            }.buttonStyle(.plain).allowsHitTesting(shown && index != nil)
            if open {
                details.popIn(0.32).transition(.identity)
            }
        }
        .opacity(shown ? 1 : 0.7)
        // Each row has the design's one-point line over it (clear over the first).
        .padding(.top,1)
        .overlay(alignment:.top) { if let index,index > 0 { Rectangle().fill(DiscordColors.veil(0.05)).frame(height:1) } }
    }
    /// Every fact on one line, fading out where it runs over (the line never widens the page).
    private var factLine:some View {
        Color.clear.frame(height:18).frame(maxWidth:.infinity)
            .overlay(alignment:.leading) {
                factText.discordFont(12,line:18).foregroundStyle(DiscordColors.ink(0.62)).lineLimit(1).fixedSize()
            }
            .clipped()
            .mask { HStack(spacing:0) { Color.black;LinearGradient(colors:[.black,.clear],startPoint:.leading,endPoint:.trailing).frame(width:44) } }
    }
    /// The facts as one run of text, as the browser sets the design's line of them: its gaps (4 points, and 2 more
    /// each side of a dot) don't round to the pixel one by one as separate views' widths would, drifting along.
    private var factText:Text {
        func gap(_ width:CGFloat)->Text { Text(Image(size:CGSize(width:width,height:1)) { _ in }) }
        var line=Text(verbatim:"")
        for (index,fact) in row.facts.enumerated() {
            if index > 0 { line=line.followed(by:gap(6)).followed(by:Text(verbatim:"·").foregroundStyle(DiscordColors.ink(0.62*0.4))).followed(by:gap(6)) }
            line=line.followed(by:Text(verbatim:fact.text))
            if let mark=fact.mark { line=line.followed(by:gap(4)).followed(by:Text(verbatim:mark).font(.discord(11)).tracking(-1).foregroundStyle(fact.markColor ?? DiscordColors.ink(0.45))) }
            if let after=fact.after { line=line.followed(by:gap(4)).followed(by:Text(verbatim:after)) }
            if let sub=fact.sub { line=line.followed(by:gap(4)).followed(by:Text(verbatim:sub).foregroundStyle(DiscordColors.ink(0.62*0.55))) }
        }
        return line
    }
    private var details:some View {
        VStack(alignment:.leading,spacing:9) {
            FlowLayout(spacing:5) {
                ForEach(Array(row.facts.enumerated()),id:\.offset) { _,fact in
                    HStack(spacing:5) {
                        if let image=fact.image { RemoteImage(url:image) { DiscordColors.tile }.frame(width:19,height:19).background(DiscordColors.tile).clipShape(Circle()) }
                        Text(verbatim:fact.text).discordFont(12.5)
                        if let mark=fact.mark { Text(verbatim:mark).discordFont(11).tracking(-1).foregroundStyle(fact.markColor ?? DiscordColors.ink(0.45)) }
                        if let after=fact.after { Text(verbatim:after).discordFont(12.5) }
                        if let sub=fact.sub { Text(verbatim:sub).designFont(10.5).foregroundStyle(DiscordColors.ink(0.45)) }
                    }
                    .foregroundStyle(DiscordColors.text)
                    .padding(.leading,fact.image == nil ? 9 : 4).padding(.trailing,9).frame(height:26)
                    .background(DiscordColors.veil(0.055),in:RoundedRectangle(cornerRadius:8))
                }
            }
            if let legend=row.legend { Text(legend).designFont(11,line:11*1.45,wraps:true).foregroundStyle(DiscordColors.ink(0.45)).fixedSize(horizontal:false,vertical:true) }
            if let sample=row.sample {
                HStack(spacing:8) {
                    Text(row.sampleLabel ?? L("On your card")).designFont(11).foregroundStyle(DiscordColors.ink(0.45)).fixedSize()
                    Text(verbatim:sample).discordFont(12.5).foregroundStyle(DiscordColors.text).lineLimit(1)
                        .padding(.horizontal,9).frame(height:24).background(DiscordColors.card,in:RoundedRectangle(cornerRadius:6))
                }
            }
        }
        .padding(.leading,54).padding(.trailing,14).padding(.bottom,13)
    }
}

// MARK: what Recall remembers

struct HistoryPage: View {
    @Bindable var studio:DiscordStudio
    var body:some View {
        let rows=studio.sessionRows()
        // As the profile's page: the two boxes give up height when the sessions don't fit.
        FlexColumn(spacing:12) {
            Text(L("Sessions stay on this Mac so your card can say how today or this week went. Only your BattleTag ever leaves it."))
                .designFont(12.5,line:12.5*1.5,wraps:true).foregroundStyle(DiscordColors.ink(0.65)).fixedSize(horizontal:false,vertical:true)
            HStack {
                Text(L("SESSIONS")).designFont(10.5,.bold).tracking(10.5*0.05).foregroundStyle(DiscordColors.ink(0.4)).padding(.horizontal,4)
                Spacer()
                if studio.erased != nil {
                    UndoEraseButton(studio:studio)
                } else if rows.isEmpty {
                    HStack(spacing:5) { DesignIcon("lucide:trash-2",size:12);Text(L("Nothing to erase")).designFont(11.5,.semibold) }
                        .foregroundStyle(DiscordColors.ink(0.35))
                        .padding(.leading,8).padding(.trailing,10).frame(height:24).background(DiscordColors.veil(0.04),in:RoundedRectangle(cornerRadius:7))
                } else {
                    HoldToErase(studio:studio,rows:rows.count)
                }
            }.frame(height:24).padding(.bottom,-4)
            if rows.isEmpty {
                VStack(spacing:4) {
                    DesignIcon("lucide:shield-check",size:20).foregroundStyle(DiscordColors.ink(0.5)).padding(.bottom,2)
                    Text(L("Nothing kept on this Mac")).designFont(13,.semibold).foregroundStyle(DiscordColors.body)
                    Text(studio.erased != nil ? L("Ranks and all-time records come back at the next look.") : L("New sessions show up here after you play."))
                        .designFont(11.5).foregroundStyle(DiscordColors.ink(0.5))
                }
                .frame(maxWidth:.infinity).frame(height:96)
                .background(DiscordColors.surface,in:RoundedRectangle(cornerRadius:16))
                .transition(.scale(scale:0.96).combined(with:.opacity))
            } else {
                SessionList(studio:studio,rows:rows).flexShrink()
            }
            SectionLabel(text:L("WHERE IT COMES FROM"))
            // The design's one-point top edge on each row: clear on the first, which it makes 51 tall; a line on the
            // second (a button), inside its 50.
            VStack(spacing:0) {
                sourceRow(icon:"lucide:file-text",name:L("The game’s log"),sub:L("When you played and how many matches; never where you are."),opens:false).padding(.top,1)
                Button { studio.openProfile() } label: {
                    sourceRow(icon:"simple-icons:battledotnet",name:L("Your public profile"),sub:L("Records, heroes and rank. Only your BattleTag is sent."),opens:true,height:49)
                        .padding(.top,1).overlay(alignment:.top) { Rectangle().fill(DiscordColors.veil(0.05)).frame(height:1) }
                }.buttonStyle(.plain)
            }
            .frame(minHeight:0,alignment:.top)
            .background(DiscordColors.surface,in:RoundedRectangle(cornerRadius:16)).clipShape(RoundedRectangle(cornerRadius:16)).flexShrink()
            Color.clear.flexGrow()
            HStack(spacing:8) {
                ExportButton(studio:studio,enabled:!rows.isEmpty)
                Spacer()
                PageButton(title:L("Done")) { studio.closePage() }.keyboardShortcut(.cancelAction)
            }
        }
        .animation(.timingCurve(0.22,1,0.36,1,duration:0.4),value:rows.isEmpty)
    }
    private func sourceRow(icon:String,name:String,sub:String,opens:Bool,height:CGFloat=50)->some View {
        HStack(spacing:12) {
            DesignIcon(icon,size:15).foregroundStyle(DiscordColors.ink(0.6)).frame(width:30,height:30).background(DiscordColors.veil(0.06),in:RoundedRectangle(cornerRadius:8))
            VStack(alignment:.leading,spacing:1) {
                Text(name).designFont(13,.semibold).foregroundStyle(DiscordColors.body)
                Text(sub).designFont(11.5).foregroundStyle(DiscordColors.ink(0.55)).lineLimit(1)
            }.frame(maxWidth:.infinity,alignment:.leading)
            if opens { DesignIcon("lucide:chevron-right",size:14).foregroundStyle(DiscordColors.ink(0.4)) }
        }
        .padding(.horizontal,14).frame(height:height).contentShape(Rectangle())
        .rowHover(0,veil:opens ? 0.03 : 0,enabled:opens)
    }
}
/// A session in the list: when, what was played, how the rank moved; a mark for each source it came from.
struct SessionRow: Identifiable {
    let id:Int
    let when:String
    let what:String
    let result:String
    var resultMove=0
    let image:URL?
    let fromLog:Bool
    let fromProfile:Bool
}
private struct SessionList: View {
    @Bindable var studio:DiscordStudio
    let rows:[SessionRow]
    @State private var crossed:Double=0
    var body:some View {
        ScrollView {
            VStack(spacing:0) {
                ForEach(Array(rows.enumerated()),id:\.element.id) { index,row in
                    let struck=max(0,min(1,studio.eraseProgress*(Double(rows.count)+0.6)-Double(index)*0.9))
                    HStack(spacing:12) {
                        Group { if let image=row.image { RemoteImage(url:image) { DiscordColors.tile } } else { GameIcon() } }
                            .frame(width:30,height:30).background(row.image == nil ? .clear : DiscordColors.tile).clipShape(RoundedRectangle(cornerRadius:8))
                        VStack(alignment:.leading,spacing:1) {
                            Text(row.when).designFont(13,.semibold).foregroundStyle(DiscordColors.body)
                            Text(row.what).designFont(11.5).foregroundStyle(DiscordColors.ink(0.55)).lineLimit(1)
                        }.frame(maxWidth:.infinity,alignment:.leading)
                        HStack(spacing:3) {
                            if row.fromLog { source("lucide:file-text").designTip(L("From the game’s log")) }
                            if row.fromProfile { source("simple-icons:battledotnet").designTip(L("From your public profile")) }
                        }.frame(width:43,alignment:.trailing)
                        Text(row.result).designFont(12,row.resultMove == 0 ? .medium : .bold).monospacedDigit()
                            .foregroundStyle(row.resultMove > 0 ? Color(red:120/255,green:225/255,blue:160/255) : row.resultMove < 0 ? Color(red:1,green:120/255,blue:108/255) : DiscordColors.ink(0.45))
                            .frame(width:88,alignment:.trailing).lineLimit(1)
                    }
                    .opacity(1-0.5*struck)
                    .overlay(alignment:.leading) {
                        Capsule().fill(Color(red:1,green:69/255,blue:58/255)).frame(height:1.5).shadow(color:Color(red:1,green:69/255,blue:58/255).opacity(0.6),radius:3)
                            .scaleEffect(x:struck,anchor:.leading).padding(.horizontal,-2)
                    }
                    .padding(.horizontal,14).frame(height:50)
                    // The design's one-point line over each row (clear over the first).
                    .padding(.top,1)
                    .overlay(alignment:.top) { if index > 0 { Rectangle().fill(DiscordColors.veil(0.05)).frame(height:1) } }
                    .transition(.asymmetric(insertion:.scale(scale:0.97).combined(with:.opacity),removal:.offset(x:-36).combined(with:.opacity)))
                }
            }
        }
        .scrollIndicators(.never).scrollBounceBehavior(.basedOnSize)
        .background(DiscordColors.surface,in:RoundedRectangle(cornerRadius:16)).clipShape(RoundedRectangle(cornerRadius:16))
    }
    private func source(_ icon:String)->some View {
        DesignIcon(icon,size:11).foregroundStyle(DiscordColors.ink(0.6)).frame(width:20,height:20).background(DiscordColors.veil(0.06),in:RoundedRectangle(cornerRadius:6))
    }
}
/// Hold for two seconds: a red fill sweeps across (the button trembles harder as it nears the end) and a red line
/// crosses out each session in turn; letting go puts it all back.
private struct HoldToErase: View {
    @Bindable var studio:DiscordStudio
    let rows:Int
    @State private var start:Date?
    var body:some View {
        TimelineView(.animation(paused:start == nil)) { context in
            let progress=start.map { min(1,context.date.timeIntervalSince($0)/2) } ?? 0
            let shake=start == nil ? 0 : sin(context.date.timeIntervalSinceReferenceDate*1000/22)*min(1.6,progress*progress*2.4)
            label(progress < 0.06 ? L("Hold to erase") : L("Keep holding…"),fore:Color(red:1,green:110/255,blue:100/255))
                .background(Color(red:1,green:69/255,blue:58/255).opacity(0.12))
                .overlay(alignment:.leading) {
                    label(progress < 0.06 ? L("Hold to erase") : L("Keep holding…"),fore:.white).background(Color(red:1,green:69/255,blue:58/255))
                        .mask(alignment:.leading) { GeometryReader { box in Rectangle().frame(width:box.size.width*progress) } }
                }
                .clipShape(RoundedRectangle(cornerRadius:7))
                .offset(x:shake)
                .onChange(of:progress) { _,value in
                    studio.eraseProgress=value
                    if value >= 1 { start=nil;studio.eraseProgress=0;withAnimation(.timingCurve(0.5,0,0.75,0,duration:0.5)) { studio.eraseHistory() } }
                }
        }
        .gesture(DragGesture(minimumDistance:0).onChanged { _ in if start == nil { start=Date() } }.onEnded { _ in
            start=nil;withAnimation(.timingCurve(0.22,1,0.36,1,duration:0.3)) { studio.eraseProgress=0 }
        })
        .designTip(L("Hold for two seconds. Ranks and all-time records come back at the next look; sessions don’t."))
        .accessibilityLabel(L("Hold to erase")).accessibilityAction { studio.eraseHistory() }
    }
    private func label(_ text:String,fore:Color)->some View {
        HStack(spacing:5) { DesignIcon("lucide:trash-2",size:12);Text(text).designFont(11.5,.semibold) }
            .foregroundStyle(fore)
            .padding(.leading,8).padding(.trailing,10).frame(minWidth:112).frame(height:24)
    }
}
/// "Erased · Undo 9s", its line shrinking with the seconds left.
private struct UndoEraseButton: View {
    @Bindable var studio:DiscordStudio
    var body:some View {
        Button { withAnimation(.timingCurve(0.22,1,0.36,1,duration:0.42)) { studio.undoErase() } } label: {
            HStack(spacing:5) {
                DesignIcon("lucide:undo-2",size:12)
                Text(L("Erased · Undo")).designFont(11.5,.semibold)
                Text(L("{0}s",String(studio.undoLeft))).designFont(11.5,.semibold).foregroundStyle(DiscordColors.ink(0.5)).monospacedDigit()
            }
            .foregroundStyle(DiscordColors.bright)
            .padding(.leading,8).padding(.trailing,10).frame(height:24)
            .background(DiscordColors.veil(0.08),in:RoundedRectangle(cornerRadius:7))
            .overlay(alignment:.bottomLeading) {
                GeometryReader { box in
                    Rectangle().fill(Color(red:1,green:69/255,blue:58/255)).frame(width:box.size.width*Double(studio.undoLeft)/10,height:2)
                        .frame(maxHeight:.infinity,alignment:.bottom).animation(.linear(duration:1),value:studio.undoLeft)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius:7))
        }.buttonStyle(.plain)
    }
}
private struct ExportButton: View {
    @Bindable var studio:DiscordStudio
    let enabled:Bool
    @State private var inside=false
    var body:some View {
        Button { studio.exportSessions() } label: {
            HStack(spacing:6) { DesignIcon(studio.exported ? "lucide:check" : "lucide:download",size:14);Text(studio.exported ? L("Saved to Downloads") : L("Export…")).designFont(13,.medium) }
                .foregroundStyle(DiscordColors.ink(!enabled ? 0.3 : studio.exported ? 0.6 : 0.75))
                .padding(.leading,10).padding(.trailing,12).frame(height:30)
                .background(inside && enabled ? DiscordColors.veil(0.06) : .clear,in:Capsule()).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!enabled).onHover { inside=$0 }
    }
}

extension DiscordColors {
    /// The pages' boxes.
    static let surface=Color(nsColor:NSColor(name:nil) { $0.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? NSColor(srgbRed:36/255,green:37/255,blue:41/255,alpha:1) : .white })
}

extension DiscordStudio {
    var profileStatus:String {
        if lookingUp { return L("Looking up…") }
        let ago=lookedUp.map { $0.formatted(.relative(presentation:.named)) }
        switch profileState {
        case .hidden:
            if let at=lookAgainAt,at > Date() { return L("Private profile · OverFast looks again at {0}",at.formatted(date:.omitted,time:.shortened)) }
            return ago.map { L("Private profile · looked up {0}",$0) } ?? L("Private profile")
        case .shown: return ago.map { L("Public profile · looked up {0}",$0) } ?? L("Public profile")
        case .none: return ago.map { L("Not found yet · looked up {0}",$0) } ?? L("Not found yet")
        }
    }
    /// Look up (or Return): a BattleTag the profile can be looked up by (BattleTag.playerID: a letter, 3 to 12
    /// letters and digits, #, the number), else the field says what it should look like.
    func saveBattleTag() {
        let tag=tagDraft.trimmingCharacters(in:.whitespaces)
        guard BattleTag.playerID(tag) != nil else { tagError=true;return }
        tagEditing=false;tagError=false
        actions.battleTag(tag)
    }
    func cancelBattleTag() {
        tagEditing=false;tagError=false
        if battleTag.isEmpty { closePage() }
    }
    func removeBattleTag() { actions.battleTag("");tagDraft="";tagEditing=true }

    /// What Recall reads from the profile, row by row, with where it shows on the card. Without a public profile
    /// the rows say why not.
    func profileFacts()->[ProfileFact] {
        let inputs=CardInputs(profile:profile,history:history,launched:Date(),now:Date(),texts:texts),card=profile
        let marks:[String:Color]=["↑":Color(red:94/255,green:214/255,blue:160/255),"↟":Color(red:94/255,green:214/255,blue:160/255),
                                  "↓":Color(red:1,green:120/255,blue:110/255),"↡":Color(red:1,green:120/255,blue:110/255)]
        let ranks=inputs.allRanks.map { item in
            let arrow=inputs.arrow(item.rank)
            return ProfileFact.Fact(text:item.rank.role.label,mark:arrow,markColor:marks[arrow],after:item.rank.name)
        }
        func tally(_ t:Tally?)->String? { t.flatMap { $0.played > 0 ? L("{0}–{1}",String($0.won),String($0.lost)) : nil } }
        var records:[ProfileFact.Fact]=[]
        if let comp=tally(card?.totals["competitive"]?.games) { records.append(.init(text:L("Comp {0}",comp),sub:L("all time"))) }
        if let quick=tally(card?.totals["quickplay"]?.games) { records.append(.init(text:L("Quick Play {0}",quick),sub:L("all time"))) }
        if let week=history.session(.week,now:Date()).flatMap({ tally($0.competitive) }) { records.append(.init(text:L("Comp {0}",week),sub:L("this week"))) }
        if let last=tally(card?.last?.competitive) { records.append(.init(text:L("Comp {0}",last),sub:L("last session"))) }
        let top=inputs.topHeroes
        var heroes=top.prefix(8).map { key in ProfileFact.Fact(text:inputs.heroName(key),after:inputs.heroTime[key].map(inputs.hours),image:card?.heroes[key]?.portrait) }
        if top.count > 8 { heroes.append(.init(text:L("+ {0} more",String(top.count-8)))) }
        let bests=BestLine.allCases.compactMap { line -> ProfileFact.Fact? in
            guard let value=line.value(inputs) else { return nil }
            let number=value.formatted(.number)
            switch line {
            case .eliminations: return .init(text:L("{0} elims",number))
            case .damage: return .init(text:L("{0} damage",number))
            case .healing: return .init(text:L("{0} healing",number))
            case .killStreak: return .init(text:L("{0} kill streak",number))
            case .multikill: return .init(text:L("{0}-kill multikill",number))
            case .new: return nil
            }
        }
        var identity:[ProfileFact.Fact]=[.init(text:L("Player icon"),image:card?.identity?.avatar)]
        if let title=card?.identity?.title { identity.append(.init(text:title,sub:L("title"))) }
        let sample={ (piece:CardPiece) in piece.text(inputs,rank:self.design.rank) }
        return [ProfileFact(icon:"ph:medal-fill",name:L("Ranks"),places:[L("Line 2"),L("Badge")],facts:ranks.isEmpty ? [.init(text:L("No rank this season"))] : ranks,
                            legend:L("Since your last session: ↑ up a division, ↟ two or more, – no change, ↓ down."),sample:sample(.rank(.current))),
                ProfileFact(icon:"ph:sword-fill",name:L("Records"),places:[L("Line 2")],facts:records.isEmpty ? [.init(text:L("No games yet"))] : records,sample:sample(.record(.week,.competitive,winRate:false))),
                ProfileFact(icon:"rc:user-fill",name:L("Heroes and hours"),places:[L("Image"),L("Line 2")],facts:heroes.isEmpty ? [.init(text:L("No heroes yet"))] : heroes,sample:sample(.hero(nil,.hours))),
                ProfileFact(icon:"ph:trophy-fill",name:L("Best games"),places:[L("Line 2")],facts:bests.isEmpty ? [.init(text:L("No bests yet"))] : bests,sample:sample(.best(.eliminations))),
                ProfileFact(icon:"lucide:image",image:card?.identity?.avatar,name:L("Player icon and title"),places:[L("Image")],facts:identity,
                            sample:[card?.identity?.name,card?.identity?.title].compactMap { $0 }.joined(separator:" · ").nilIfEmpty,sampleLabel:L("When friends point at the image"))]
    }
    func notOnCard()->ProfileFact {
        var facts:[ProfileFact.Fact]=[]
        if let level=profile?.identity?.endorsement { facts.append(.init(text:L("Endorsement level {0}",String(level)))) }
        if profile?.identity?.namecard != nil { facts.append(.init(text:L("Name card"))) }
        return ProfileFact(icon:"ph:users-three-fill",name:L("Endorsement and name card"),facts:facts.isEmpty ? [.init(text:L("Endorsement level"))] : facts)
    }

    /// The sessions kept, newest first: each profile change with the runs it covers, and the runs not yet looked at.
    func sessionRows()->[SessionRow] {
        var rows:[SessionRow]=[],previous=Date.distantPast,id=0
        let profileHeroes=profile?.heroes ?? [:]
        for change in history.changes.sorted(by:{ $0.at < $1.at }) {
            let runs=history.runs.filter { $0.end > previous && $0.end <= change.at }
            let hero=change.session.hero.flatMap { profileHeroes[$0] }
            var what=change.session.summary
            if let name=hero?.name { what=L("{0} · {1}",what,name) }
            if runs.isEmpty { what=L("Not on this Mac · {0}",what) }
            let steps=change.rankSteps ?? (change.session.rank == nil ? 0 : change.session.promoted ? 1 : -1)
            let result:String
            if change.session.competitive.played == 0 { result=L("No Comp") }
            else if steps > 0 { result=steps == 1 ? L("↑ 1 division") : L("↑ {0} divisions",String(steps)) }
            else if steps < 0 { result=steps == -1 ? L("↓ 1 division") : L("↓ {0} divisions",String(-steps)) }
            else { result=L("Same rank") }
            rows.append(SessionRow(id:id,when:Self.when(runs.last?.end ?? change.at),what:what,result:result,resultMove:change.session.competitive.played == 0 ? 0 : steps,
                                   image:hero?.portrait,fromLog:!runs.isEmpty,fromProfile:true))
            id+=1;previous=change.at
        }
        for run in history.runs where run.end > previous {
            let matches=run.matches.map { $0 == 1 ? L("1 match") : L("{0} matches",String($0)) } ?? L("Played")
            rows.append(SessionRow(id:id,when:Self.when(run.end),what:battleTag.isEmpty ? matches : L("{0} · records after the next look",matches),
                                   result:battleTag.isEmpty ? "" : L("Waiting"),image:nil,fromLog:true,fromProfile:false))
            id+=1
        }
        return rows.reversed()
    }
    /// "Just now", "Today, 21:14", "Yesterday", "Thu 23 Oct".
    static func when(_ date:Date,now:Date=Date(),calendar:Calendar = .current)->String {
        if now.timeIntervalSince(date) < 15*60 { return L("Just now") }
        if calendar.isDateInToday(date) { return L("Today, {0}",date.formatted(date:.omitted,time:.shortened)) }
        if calendar.isDateInYesterday(date) { return L("Yesterday") }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
    /// Erases the sessions on screen at once; for real after ten seconds (or on leaving the page), unless undone.
    func eraseHistory() {
        guard erased == nil else { return }
        erased=history;history=CareerHistory();undoLeft=10
        eraseTimer?.cancel()
        eraseTimer=Task { [weak self] in
            for _ in 0..<10 {
                try? await Task.sleep(for:.seconds(1))
                guard let self,!Task.isCancelled else { return }
                self.undoLeft-=1
            }
            self?.commitErase()
        }
    }
    func undoErase() {
        eraseTimer?.cancel();eraseTimer=nil
        if let erased { history=erased }
        erased=nil;undoLeft=0
    }
    func commitErase() {
        eraseTimer?.cancel();eraseTimer=nil
        guard erased != nil else { return }
        erased=nil;undoLeft=0
        actions.erase()
    }
    /// The sessions as a spreadsheet in Downloads.
    func exportSessions() {
        guard actions.export() != nil else { return }
        withAnimation { exported=true }
        Task { [weak self] in try? await Task.sleep(for:.seconds(2.6));withAnimation { self?.exported=false } }
    }
}
