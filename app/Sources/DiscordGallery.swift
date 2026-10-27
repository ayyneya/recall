import SwiftUI
import AppKit

// My cards, as the design shows them: the player's own cards and the ready-made ones on the stage, the one in
// the middle playing (sped up, its turns as dots), its neighbours peeking in at the sides; under it its name
// (click to rename yours), what it shows, Use or Edit, Duplicate, Share as a code, Delete; and a code to add
// someone else's card. The code is the card itself (DiscordCardCode.swift): nothing is stored anywhere.

struct DiscordGallery: View {
    @Bindable var studio:DiscordStudio
    var body:some View {
        // Inside the stage's one-point border, as the design's are.
        VStack(spacing:0) {
            GalleryCards(studio:studio).frame(height:548-2-34-268)
            GalleryCaption(studio:studio).frame(height:268)
        }
        .padding(.vertical,1)
        .focusable().focusEffectDisabled()
        .onKeyPress(.leftArrow) { studio.galleryStep(-1);return .handled }
        .onKeyPress(.rightArrow) { studio.galleryStep(1);return .handled }
        .onExitCommand { studio.openGallery(false) }
    }
}

/// The card in the middle, its neighbours at the sides, and the arrows.
private struct GalleryCards: View {
    @Bindable var studio:DiscordStudio
    var body:some View {
        let items=studio.galleryItems,place=studio.galleryPlace
        TimelineView(.periodic(from:.now,by:1)) { context in
            ZStack {
                if place > 0 { neighbour(items[place-1],now:context.date,leading:true) }
                if place < items.count-1 { neighbour(items[place+1],now:context.date,leading:false) }
                let activity=studio.activity(at:context.date)
                DiscordShell(profile:false) {
                    DiscordCardView(activity:activity,now:context.date,pins:studio.galleryPins,turn:studio.turn(at:context.date))
                        .overlay(alignment:.top) {
                            HStack(spacing:5) {
                                TurnDots(studio:studio,now:context.date)
                                if studio.loopLength(at:context.date) > 1 {
                                    HStack(spacing:3) { DesignIcon("rc:ff",size:9);Text(L("Sped up")).designFont(10,.bold) }
                                        .foregroundStyle(Color(red:1,green:190/255,blue:140/255).opacity(0.9)).fixedSize()
                                }
                            }.offset(y:10)
                        }
                }
                .scaleEffect(0.86)
                .id(studio.galleryItem?.design.id)
                .transition(.asymmetric(insertion:.opacity.combined(with:.scale(scale:0.94)),removal:.opacity))
                HStack {
                    arrow("lucide:chevron-left",name:L("Previous card"),enabled:place > 0) { studio.galleryStep(-1) }
                    Spacer()
                    arrow("lucide:chevron-right",name:L("Next card"),enabled:place < items.count-1) { studio.galleryStep(1) }
                }
                // Eight points inside the stage's border, and a point under the middle (the design's sum for their
                // place counts the border in the stage's height).
                .padding(.horizontal,9).offset(y:1)
            }
            .frame(maxWidth:.infinity,maxHeight:.infinity)
            .animation(.timingCurve(0.22,1,0.36,1,duration:0.45),value:place)
        }
    }
    /// A neighbour, smaller and to the side: a click shows it.
    private func neighbour(_ item:DiscordStudio.GalleryItem,now:Date,leading:Bool)->some View {
        let activity=studio.galleryActivity(item,at:now)
        return Button { studio.galleryStep(leading ? -1 : 1) } label: {
            VStack(spacing:0) { DiscordCardView(activity:activity,now:now) }
                .padding(10).frame(width:300)
                .background(DiscordColors.popout,in:RoundedRectangle(cornerRadius:10))
                .compositingGroup().shadow(color:.black.opacity(0.45),radius:16,y:12)
        }
        .buttonStyle(NeighbourStyle())
        .scaleEffect(0.74,anchor:leading ? .trailing : .leading)
        .frame(width:300)
        .offset(x:leading ? -(166+150) : 166+150)
        .accessibilityLabel(leading ? L("Previous card") : L("Next card"))
        .transition(.opacity)
    }
    private func arrow(_ icon:String,name:String,enabled:Bool,_ action:@escaping ()->Void)->some View {
        Button(action:action) {
            DesignIcon(icon,size:16).foregroundStyle(.white)
                .frame(width:30,height:30).background(Color(red:17/255,green:18/255,blue:20/255).opacity(0.78),in:Circle())
                .compositingGroup().shadow(color:.black.opacity(0.35),radius:6,y:4).contentShape(Circle())
        }
        .buttonStyle(.plain).opacity(enabled ? 1 : 0).allowsHitTesting(enabled).accessibilityLabel(name)
        .animation(.easeOut(duration:0.25),value:enabled)
    }
}
private struct NeighbourStyle: ButtonStyle {
    @State private var inside=false
    func makeBody(configuration:Configuration)->some View {
        configuration.label.brightness(inside ? 0.06 : 0).onHover { inside=$0 }
    }
}

/// Under the cards: the name, what it shows, what can be done with it, the dots, and adding a card from a code.
private struct GalleryCaption: View {
    @Bindable var studio:DiscordStudio
    @FocusState private var renameFocused:Bool
    @FocusState private var importFocused:Bool
    var body:some View {
        let items=studio.galleryItems,place=studio.galleryPlace
        VStack(spacing:8) {
            if let item=studio.galleryItem {
                HStack(spacing:8) {
                    if studio.renaming == item.design.id {
                        TextField("",text:$studio.renameDraft)
                            .textFieldStyle(.plain).font(LauncherStyle.font(18,.bold)).multilineTextAlignment(.center)
                            .frame(width:190,height:28).overlay(alignment:.bottom) { Rectangle().fill(DiscordColors.fill).frame(height:2) }
                            .focused($renameFocused).onAppear { renameFocused=true }
                            .onSubmit { studio.finishRename() }.onExitCommand { studio.renaming=nil }
                            .onChange(of:renameFocused) { _,focused in if !focused { studio.finishRename() } }
                            .onChange(of:studio.renameDraft) { _,draft in if draft.count > 24 { studio.renameDraft=String(draft.prefix(24)) } }
                    } else {
                        NameButton(name:item.name,renamable:!item.readyMade) { studio.startRename(item) }
                    }
                    if item.design.id == studio.shelf.inUse.id {
                        tag(L("In use on Discord"),icon:"rc:check-fill",back:DiscordColors.accent.opacity(0.16),fore:Color(red:1,green:176/255,blue:128/255))
                    }
                    if item.readyMade { tag(L("System"),icon:nil,back:.white.opacity(0.08),fore:DiscordColors.ink(0.62)) }
                }.frame(height:30)
                // The design balances its lines (text-wrap: balance).
                let description=studio.galleryDescription(item)
                Text(description).designFont(12,line:12*1.45).foregroundStyle(DiscordColors.ink(0.62))
                    .multilineTextAlignment(.center).frame(width:DesignText.balanced(description,SystemFont.nsFont(12),within:390)).frame(minHeight:34,alignment:.top)
                    .fixedSize(horizontal:false,vertical:true)
                HStack(spacing:6) {
                    let inUse=item.design.id == studio.shelf.inUse.id
                    MainButton(title:inUse ? L("Edit this card") : L("Use this card"),icon:inUse ? "lucide:pencil" : "lucide:check") {
                        if inUse { studio.openGallery(false) } else { studio.use(item) }
                    }
                    ActButton(icon:"lucide:copy",tip:L("Duplicate")) { studio.duplicate(item) }
                    ActButton(icon:"lucide:share-2",tip:L("Share as a code"),on:studio.sharing) {
                        studio.sharing.toggle();studio.importing=false;studio.copied=false;studio.renaming=nil
                    }
                    ActButton(icon:"lucide:trash-2",tip:studio.canDelete(item) ? L("Delete") : L("Your only card can’t be deleted"),enabled:studio.canDelete(item)) { studio.delete(item) }
                }
                if studio.sharing { SharePanel(studio:studio,code:studio.code(item)).popIn(0.3).transition(.identity) }
            }
            if studio.importing { importPanel.popIn(0.3).transition(.identity) }
            Spacer(minLength:0)
            HStack(spacing:0) {
                let mine=studio.shelf.mine.count
                ForEach(Array(items.enumerated()),id:\.offset) { index,item in
                    Button { studio.galleryStep(index-place) } label: {
                        Capsule().fill(index == place ? DiscordColors.accent : .white.opacity(0.22)).frame(width:index == place ? 18 : 6,height:6)
                            .padding(.vertical,4).padding(.horizontal,2.5).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).padding(.leading,index == mine && index > 0 ? 10 : 0)
                    .designTip(item.name).accessibilityLabel(item.name)
                }
            }.frame(height:14).animation(.timingCurve(0.22,1,0.36,1,duration:0.35),value:place)
            HStack(spacing:12) {
                Text(L("{0} of {1}",String(place+1),String(items.count))).designFont(11).monospacedDigit()
                if studio.hiddenCount > 0 {
                    smallButton(studio.hiddenCount == 1 ? L("Bring back 1 system card") : L("Bring back {0} system cards",String(studio.hiddenCount)),icon:"lucide:rotate-ccw",color:DiscordColors.ink(0.6)) { studio.bringBack() }
                }
                smallButton(studio.importing ? L("Cancel") : L("Add from a code"),icon:"lucide:clipboard-paste",color:DiscordColors.link) {
                    studio.importing.toggle();studio.sharing=false;studio.importDraft="";studio.importFailed=false;studio.renaming=nil
                }
            }.foregroundStyle(DiscordColors.ink(0.42)).frame(height:16)
        }
        .padding(.top,2).padding(.horizontal,20).padding(.bottom,14)
        .animation(.timingCurve(0.22,1,0.36,1,duration:0.3),value:studio.sharing)
        .animation(.timingCurve(0.22,1,0.36,1,duration:0.3),value:studio.importing)
    }
    private func tag(_ text:String,icon:String?,back:Color,fore:Color)->some View {
        HStack(spacing:4) { if let icon { DesignIcon(icon,size:13) };Text(text).designFont(11,.bold) }
            .foregroundStyle(fore)
            .padding(.leading,icon == nil ? 8 : 6).padding(.trailing,8).frame(height:22)
            .background(back,in:RoundedRectangle(cornerRadius:7)).fixedSize()
    }
    private func smallButton(_ title:String,icon:String,color:Color,_ action:@escaping ()->Void)->some View {
        Button(action:action) { HStack(spacing:4) { DesignIcon(icon,size:11);Text(title).designFont(11,.semibold) }.foregroundStyle(color) }
            .buttonStyle(.plain)
    }
    private var importPanel:some View {
        VStack(spacing:5) {
            HStack(spacing:8) {
                DesignIcon("lucide:clipboard-paste",size:13).foregroundStyle(DiscordColors.link)
                TextField(L("Paste a code"),text:$studio.importDraft)
                    .textFieldStyle(.plain).font(.system(size:15,weight:.bold,design:.monospaced)).multilineTextAlignment(.center)
                    .focused($importFocused).onAppear { importFocused=true }
                    .onSubmit { studio.importCode() }.onExitCommand { studio.importing=false }
                    .onChange(of:studio.importDraft) { _,draft in
                        studio.importFailed=false
                        let upper=draft.uppercased();if upper != draft { studio.importDraft=upper }
                    }
                FillButton(title:L("Add"),height:26,size:12,radius:7,padding:11,weight:.bold) { studio.importCode() }
            }
            .padding(.leading,11).padding(.trailing,4).frame(width:340,height:38)
            .background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:10))
            .overlay { if studio.importFailed { RoundedRectangle(cornerRadius:10).strokeBorder(Color(red:1,green:110/255,blue:100/255).opacity(0.7),lineWidth:1.5) } }
            Text(studio.importFailed ? L("No card has that code.") : L("Paste someone’s code to add their card."))
                .designFont(11).foregroundStyle(studio.importFailed ? Color(red:1,green:130/255,blue:120/255) : DiscordColors.ink(0.45))
        }
    }
}
/// The card's name: a click renames one of yours (a dashed line under it says so).
private struct NameButton: View {
    let name:String
    let renamable:Bool
    let action:()->Void
    @State private var inside=false
    var body:some View {
        Button(action:action) {
            Text(name).designFont(18,.bold).tracking(-0.3).foregroundStyle(.white).lineLimit(1)
                .overlay(alignment:.bottom) {
                    Rectangle().stroke(style:StrokeStyle(lineWidth:1.5,dash:[4,3])).frame(height:0.1).offset(y:6)
                        .foregroundStyle(DiscordColors.ink(inside && renamable ? 0.5 : 0))
                }
                .padding(.horizontal,2).frame(height:30).contentShape(Rectangle())
        }
        .buttonStyle(.plain).allowsHitTesting(renamable).onHover { inside=$0 }
        .designTip(renamable ? L("Click to rename") : nil)
        .animation(.easeOut(duration:0.2),value:inside)
    }
}
private struct MainButton: View {
    let title:String
    let icon:String
    let action:()->Void
    @State private var inside=false
    var body:some View {
        Button(action:action) {
            HStack(spacing:6) { DesignIcon(icon,size:13);Text(title).designFont(12.5,.bold) }
                .foregroundStyle(.white)
                .padding(.leading,13).padding(.trailing,16).frame(height:32)
                .background(inside ? DiscordColors.fillHover : DiscordColors.fill,in:RoundedRectangle(cornerRadius:9))
                .compositingGroup().shadow(color:DiscordColors.pick.opacity(0.28),radius:9,y:6).contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { inside=$0 }
    }
}
private struct ActButton: View {
    let icon:String
    let tip:String
    var on=false
    var enabled=true
    let action:()->Void
    @State private var inside=false
    var body:some View {
        Button(action:action) {
            DesignIcon(icon,size:14)
                .foregroundStyle(on ? Color(red:1,green:176/255,blue:128/255) : inside && enabled ? .white : DiscordColors.ink(0.75))
                .frame(width:32,height:32)
                .background(on ? DiscordColors.accent.opacity(0.2) : .white.opacity(inside && enabled ? 0.12 : 0.06),in:RoundedRectangle(cornerRadius:9))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.35).onHover { inside=$0 }
        .designTip(tip).accessibilityLabel(tip)
    }
}
/// The card's code, to copy and send: everything chosen travels in it, nothing else.
private struct SharePanel: View {
    @Bindable var studio:DiscordStudio
    let code:String
    var body:some View {
        VStack(spacing:5) {
            HStack(spacing:8) {
                DesignIcon("lucide:share-2",size:13).foregroundStyle(DiscordColors.link)
                Text(verbatim:code).font(.system(size:code.count > 30 ? 13 : 16,weight:.bold,design:.monospaced)).tracking(code.count > 30 ? 0.3 : 1.5)
                    .foregroundStyle(.white).multilineTextAlignment(.center).lineLimit(3).textSelection(.enabled)
                    .frame(maxWidth:.infinity).padding(.vertical,6)
                FillButton(title:studio.copied ? L("Copied") : L("Copy"),height:26,size:12,radius:7,padding:11,weight:.bold) {
                    NSPasteboard.general.clearContents();NSPasteboard.general.setString(code,forType:.string);studio.copied=true
                }
            }
            .padding(.leading,11).padding(.trailing,4).frame(minHeight:38).frame(maxWidth:code.count > 12 ? 420 : 230)
            .background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:10))
            Text(L("Only your choices travel: no stats, no BattleTag.")).designFont(11).foregroundStyle(DiscordColors.ink(0.45))
        }
    }
}

extension DiscordStudio {
    /// What takes turns on the gallery's card, pinned to its parts.
    var galleryPins:CardPins {
        let card=shown
        return CardPins(picture:card.pictures?.count ?? card.lineTwo.count,badge:card.badges.count,lineOne:card.lineOne.count,lineTwo:card.lineTwo.count)
    }
    /// A gallery card at its first turn (the neighbours).
    func galleryActivity(_ item:GalleryItem,at now:Date)->[String:Any] { item.design.activity(inputs(at:now),turn:0) }
}
