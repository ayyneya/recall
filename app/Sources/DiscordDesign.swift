import SwiftUI
import AppKit
import CoreText

// The design's own look for Settings › Discord (the Claude Design artifact "Discord card"; app/ARCHITECTURE.md): its
// colours, the icons it draws (each from its SVG, as the design draws it), and Noto Sans, the font it shows Discord's
// text in.
//
// Icons: Lucide (ISC), Phosphor (MIT), Material Design Icons and Google's Material Icons (Apache 2.0), Simple Icons
// (CC0; the Battle.net mark is Blizzard's), and the design's own "rc" set. Notices: licenses/DESIGN-ICONS-NOTICE.txt.

extension DiscordColors {
    /// What's chosen in Customize's lists, rings and counts.
    static let accent=Color(red:1,green:150/255,blue:96/255)
    /// Links and the breadcrumb.
    static let link=Color(red:1,green:152/255,blue:104/255)
    /// Customize's buttons, and the same a little lighter while pointed at.
    static let fill=Color(red:236/255,green:106/255,blue:46/255)
    static let fillHover=Color(red:246/255,green:120/255,blue:58/255)
    /// The design's text on dark: white with a touch of blue at the given strength (black in light mode).
    static func ink(_ alpha:Double)->Color {
        Color(nsColor:NSColor(name:nil) { appearance in
            appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? NSColor(srgbRed:235/255,green:235/255,blue:245/255,alpha:alpha)
                                                                       : NSColor(white:0,alpha:min(1,alpha*1.15))
        })
    }
    /// The design's "#fff": white on dark, the label colour on light.
    static let bright=Color(nsColor:NSColor(name:nil) { $0.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? .white : .labelColor })
    /// A white veil of the given strength (black in light mode): the design's rgba(255,255,255,a) surfaces.
    static func veil(_ alpha:Double)->Color {
        Color(nsColor:NSColor(name:nil) { $0.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? NSColor(white:1,alpha:alpha) : NSColor(white:0,alpha:alpha) })
    }
    /// The design's ribbon of colour (Customize, the gliding underlines): amber, orange, pink, violet, orange.
    static let ribbon=[Color(red:1,green:184/255,blue:92/255),Color(red:1,green:128/255,blue:64/255),Color(red:1,green:92/255,blue:138/255),
                       Color(red:214/255,green:98/255,blue:230/255),Color(red:236/255,green:106/255,blue:46/255),Color(red:1,green:184/255,blue:92/255)]
}

/// One of the design's icons, at a size (its height, as the design sizes them), in the foreground style.
struct DesignIcon: View {
    let name:String
    var size:CGFloat=14
    init(_ name:String,size:CGFloat=14) { self.name=name;self.size=size }
    var body:some View {
        let image=DesignIcons.image(name,height:size)
        Group {
            if let image { Image(nsImage:image).renderingMode(.template) } else { Color.clear }
        }.frame(width:image?.size.width ?? size,height:size).accessibilityHidden(true)
    }
}

@MainActor enum DesignIcons {
    private static var cache:[String:NSImage]=[:]
    /// The icon drawn from its SVG at the size it's shown (so it stays sharp), as a template the view tints.
    static func image(_ name:String,height:CGFloat)->NSImage? {
        let key="\(name)@\(height)"
        if let image=cache[key] { return image }
        guard let (width,tall,body)=bodies[name] else { return nil }
        let paths=body.replacingOccurrences(of:"currentColor",with:"#000")
        let svg="<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(width)\" height=\"\(tall)\" viewBox=\"0 0 \(width) \(tall)\">\(paths)</svg>"
        guard let image=NSImage(data:Data(svg.utf8)) else { return nil }
        image.size=NSSize(width:height*CGFloat(width)/CGFloat(tall),height:height)
        image.isTemplate=true
        cache[key]=image
        return image
    }
    /// Each icon's width and height (its viewBox) and its SVG, as the design has them.
    private static let bodies:[String:(Int,Int,String)]=[
        "ic:baseline-discord":(24,24,#"<path fill="currentColor" d="M19.27 5.33C17.94 4.71 16.5 4.26 15 4a.1.1 0 0 0-.07.03c-.18.33-.39.76-.53 1.09a16.1 16.1 0 0 0-4.8 0c-.14-.34-.35-.76-.54-1.09c-.01-.02-.04-.03-.07-.03c-1.5.26-2.93.71-4.27 1.33c-.01 0-.02.01-.03.02c-2.72 4.07-3.47 8.03-3.1 11.95c0 .02.01.04.03.05c1.8 1.32 3.53 2.12 5.24 2.65c.03.01.06 0 .07-.02c.4-.55.76-1.13 1.07-1.74c.02-.04 0-.08-.04-.09c-.57-.22-1.11-.48-1.64-.78c-.04-.02-.04-.08-.01-.11c.11-.08.22-.17.33-.25c.02-.02.05-.02.07-.01c3.44 1.57 7.15 1.57 10.55 0c.02-.01.05-.01.07.01c.11.09.22.17.33.26c.04.03.04.09-.01.11c-.52.31-1.07.56-1.64.78c-.04.01-.05.06-.04.09c.32.61.68 1.19 1.07 1.74c.03.01.06.02.09.01c1.72-.53 3.45-1.33 5.25-2.65c.02-.01.03-.03.03-.05c.44-4.53-.73-8.46-3.1-11.95c-.01-.01-.02-.02-.04-.02M8.52 14.91c-1.03 0-1.89-.95-1.89-2.12s.84-2.12 1.89-2.12c1.06 0 1.9.96 1.89 2.12c0 1.17-.84 2.12-1.89 2.12m6.97 0c-1.03 0-1.89-.95-1.89-2.12s.84-2.12 1.89-2.12c1.06 0 1.9.96 1.89 2.12c0 1.17-.83 2.12-1.89 2.12"/>"#),
        "lucide:power":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 2v10m6.4-5.4a9 9 0 1 1-12.77.04"/>"#),
        "lucide:power-off":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.36 6.64A9 9 0 0 1 20.77 15M6.16 6.16a9 9 0 1 0 12.68 12.68M12 2v4M2 2l20 20"/>"#),
        "lucide:monitor":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect width="20" height="14" x="2" y="3" rx="2"/><path d="M8 21h8m-4-4v4"/></g>"#),
        "lucide:smartphone":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect width="14" height="20" x="5" y="2" rx="2" ry="2"/><path d="M12 18h.01"/></g>"#),
        "lucide:mouse":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="7"/><path d="M12 6v4"/></g>"#),
        "lucide:mouse-pointer-click":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 4.1L12 6M5.1 8l-2.9-.8M6 12l-1.9 2M7.2 2.2L8 5.1m1.037 4.59a.498.498 0 0 1 .653-.653l11 4.5a.5.5 0 0 1-.074.949l-4.349 1.041a1 1 0 0 0-.74.739l-1.04 4.35a.5.5 0 0 1-.95.074z"/>"#),
        "ph:users-three-fill":(256,256,#"<path fill="currentColor" d="M64.12 147.8a4 4 0 0 1-4 4.2H16a8 8 0 0 1-7.8-6.17a8.35 8.35 0 0 1 1.62-6.93A67.8 67.8 0 0 1 37 117.51a40 40 0 1 1 66.46-35.8a3.94 3.94 0 0 1-2.27 4.18A64.08 64.08 0 0 0 64 144c0 1.28 0 2.54.12 3.8m182-8.91A67.76 67.76 0 0 0 219 117.51a40 40 0 1 0-66.46-35.8a3.94 3.94 0 0 0 2.27 4.18A64.08 64.08 0 0 1 192 144c0 1.28 0 2.54-.12 3.8a4 4 0 0 0 4 4.2H240a8 8 0 0 0 7.8-6.17a8.33 8.33 0 0 0-1.63-6.94Zm-89 43.18a48 48 0 1 0-58.37 0A72.13 72.13 0 0 0 65.07 212A8 8 0 0 0 72 224h112a8 8 0 0 0 6.93-12a72.15 72.15 0 0 0-33.74-29.93Z"/>"#),
        "ph:squares-four-fill":(256,256,#"<path fill="currentColor" d="M120 56v48a16 16 0 0 1-16 16H56a16 16 0 0 1-16-16V56a16 16 0 0 1 16-16h48a16 16 0 0 1 16 16m80-16h-48a16 16 0 0 0-16 16v48a16 16 0 0 0 16 16h48a16 16 0 0 0 16-16V56a16 16 0 0 0-16-16m-96 96H56a16 16 0 0 0-16 16v48a16 16 0 0 0 16 16h48a16 16 0 0 0 16-16v-48a16 16 0 0 0-16-16m96 0h-48a16 16 0 0 0-16 16v48a16 16 0 0 0 16 16h48a16 16 0 0 0 16-16v-48a16 16 0 0 0-16-16"/>"#),
        "ph:sword-fill":(256,256,#"<path fill="currentColor" d="M216 32h-64a8 8 0 0 0-6.34 3.12l-64 83.21l-9.66-9.64a16 16 0 0 0-22.64 0l-8.69 8.7a16 16 0 0 0 0 22.63l22 22l-32 32a16 16 0 0 0 0 22.63l8.69 8.68a16 16 0 0 0 22.62 0l32-32l22 22a16 16 0 0 0 22.64 0l8.69-8.7a16 16 0 0 0 0-22.63l-9.64-9.64l83.21-64A8 8 0 0 0 224 104V40a8 8 0 0 0-8-8m-8 68.06l-81.74 62.88L115.32 152l50.34-50.34a8 8 0 0 0-11.32-11.31L104 140.68l-10.93-10.94L155.94 48H208Z"/>"#),
        "mdi:dots-horizontal":(24,24,#"<path fill="currentColor" d="M16 12a2 2 0 0 1 2-2a2 2 0 0 1 2 2a2 2 0 0 1-2 2a2 2 0 0 1-2-2m-6 0a2 2 0 0 1 2-2a2 2 0 0 1 2 2a2 2 0 0 1-2 2a2 2 0 0 1-2-2m-6 0a2 2 0 0 1 2-2a2 2 0 0 1 2 2a2 2 0 0 1-2 2a2 2 0 0 1-2-2"/>"#),
        "mdi:controller":(24,24,#"<path fill="currentColor" d="M7.97 16L5 19c-.33.3-.77.5-1.25.5A1.75 1.75 0 0 1 2 17.75v-.25l1-7.38A4.524 4.524 0 0 1 7.5 6h9c2.36 0 4.29 1.81 4.5 4.12l1 7.38v.25a1.75 1.75 0 0 1-1.75 1.75c-.48 0-.92-.2-1.25-.5l-2.97-3zM7 8v2H5v1h2v2h1v-2h2v-1H8V8zm9.5 0a.75.75 0 0 0-.75.75a.75.75 0 0 0 .75.75a.75.75 0 0 0 .75-.75a.75.75 0 0 0-.75-.75m-1.75 1.75a.75.75 0 0 0-.75.75a.75.75 0 0 0 .75.75a.75.75 0 0 0 .75-.75a.75.75 0 0 0-.75-.75m3.5 0a.75.75 0 0 0-.75.75a.75.75 0 0 0 .75.75a.75.75 0 0 0 .75-.75a.75.75 0 0 0-.75-.75M16.5 11.5a.75.75 0 0 0-.75.75a.75.75 0 0 0 .75.75a.75.75 0 0 0 .75-.75a.75.75 0 0 0-.75-.75"/>"#),
        "lucide:repeat":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="m17 2l4 4l-4 4"/><path d="M3 11v-1a4 4 0 0 1 4-4h14M7 22l-4-4l4-4"/><path d="M21 13v1a4 4 0 0 1-4 4H3"/></g>"#),
        "lucide:pencil":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497zM15 5l4 4"/>"#),
        "ph:pencil-simple-fill":(256,256,#"<path fill="currentColor" d="m227.31 73.37l-44.68-44.69a16 16 0 0 0-22.63 0L36.69 152A15.86 15.86 0 0 0 32 163.31V208a16 16 0 0 0 16 16h44.69a15.86 15.86 0 0 0 11.31-4.69L227.31 96a16 16 0 0 0 0-22.63M192 108.68L147.31 64l24-24L216 84.68Z"/>"#),
        "lucide:chevron-left":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m15 18l-6-6l6-6"/>"#),
        "lucide:chevron-right":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m9 18l6-6l-6-6"/>"#),
        "lucide:chevron-down":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m6 9l6 6l6-6"/>"#),
        "rc:ff":(24,24,#"<path fill="currentColor" d="M2.5 6.2v11.6a.8.8 0 0 0 1.25.66l8.3-5.8a.8.8 0 0 0 0-1.32l-8.3-5.8a.8.8 0 0 0-1.25.66zm9.8 0v11.6a.8.8 0 0 0 1.25.66l8.3-5.8a.8.8 0 0 0 0-1.32l-8.3-5.8a.8.8 0 0 0-1.25.66z"/>"#),
        "rc:cards":(24,24,#"<rect fill="currentColor" x="9" y="3" width="13" height="18" rx="2.6"/><rect fill="currentColor" x="5" y="5" width="2.3" height="14" rx="1.15" opacity=".55"/><rect fill="currentColor" x="1.4" y="7" width="2.3" height="10" rx="1.15" opacity=".3"/>"#),
        "rc:line1":(24,24,#"<rect fill="currentColor" x="3" y="4.6" width="18" height="3.6" rx="1.8"/><rect fill="currentColor" x="3" y="10.2" width="14" height="3.6" rx="1.8" opacity=".3"/><rect fill="currentColor" x="3" y="15.8" width="10" height="3.6" rx="1.8" opacity=".3"/>"#),
        "rc:line2":(24,24,#"<rect fill="currentColor" x="3" y="4.6" width="18" height="3.6" rx="1.8" opacity=".3"/><rect fill="currentColor" x="3" y="10.2" width="14" height="3.6" rx="1.8"/><rect fill="currentColor" x="3" y="15.8" width="10" height="3.6" rx="1.8" opacity=".3"/>"#),
        "ph:timer-fill":(256,256,#"<path fill="currentColor" d="M128 40a96 96 0 1 0 96 96a96.11 96.11 0 0 0-96-96m45.66 61.66l-40 40a8 8 0 0 1-11.32-11.32l40-40a8 8 0 0 1 11.32 11.32M96 16a8 8 0 0 1 8-8h48a8 8 0 0 1 0 16h-48a8 8 0 0 1-8-8"/>"#),
        "rc:buttons":(24,24,#"<rect fill="currentColor" x="1.5" y="7" width="9.8" height="10" rx="3"/><rect fill="currentColor" x="12.7" y="7" width="9.8" height="10" rx="3" opacity=".42"/>"#),
        "ph:game-controller-fill":(256,256,#"<path fill="currentColor" d="M247.44 173.75a.7.7 0 0 0 0-.14l-16.39-84.17v-.18A60.08 60.08 0 0 0 172 40H83.89a59.88 59.88 0 0 0-59 49.52L8.58 173.61a.7.7 0 0 0 0 .14a36 36 0 0 0 60.9 31.71l.35-.37L109.52 160h37l39.71 45.09c.11.13.23.25.35.37A36.08 36.08 0 0 0 212 216a36 36 0 0 0 35.43-42.25ZM104 112h-8v8a8 8 0 0 1-16 0v-8h-8a8 8 0 0 1 0-16h8v-8a8 8 0 0 1 16 0v8h8a8 8 0 0 1 0 16m40-8a8 8 0 0 1 8-8h24a8 8 0 0 1 0 16h-24a8 8 0 0 1-8-8m84.37 87.47a19.84 19.84 0 0 1-12.9 8.23a20.09 20.09 0 0 1-17.47-5.39L167.8 160h4.2a60 60 0 0 0 51-28.38l8.74 45a19.82 19.82 0 0 1-3.37 14.85"/>"#),
        "lucide:lock":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></g>"#),
        "lucide:circle":(24,24,#"<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"/>"#),
        "lucide:circle-dot":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/></g>"#),
        "lucide:x":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 6L6 18M6 6l12 12"/>"#),
        "rc:hold":(24,24,#"<circle fill="currentColor" cx="12" cy="12" r="3.6"/><path d="M12 4.4a7.6 7.6 0 1 1-7.6 7.6" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>"#),
        "rc:pick":(24,24,#"<path fill="currentColor" d="M2.6 8.4a.6.6 0 0 1 .95-.49l4.6 3.6a.6.6 0 0 1 0 .95l-4.6 3.6a.6.6 0 0 1-.95-.49z"/><rect fill="currentColor" x="9.5" y="4" width="12" height="3.4" rx="1.7" opacity=".3"/><rect fill="currentColor" x="9.5" y="10.3" width="12" height="3.4" rx="1.7"/><rect fill="currentColor" x="9.5" y="16.6" width="12" height="3.4" rx="1.7" opacity=".3"/>"#),
        "ph:medal-fill":(256,256,#"<path fill="currentColor" d="M216 96a88 88 0 1 0-144 67.83V240a8 8 0 0 0 11.58 7.16L128 225l44.43 22.21a8.1 8.1 0 0 0 3.57.79a8 8 0 0 0 8-8v-76.17A87.85 87.85 0 0 0 216 96M56 96a72 72 0 1 1 72 72a72.08 72.08 0 0 1-72-72m16 0a56 56 0 1 1 56 56a56.06 56.06 0 0 1-56-56"/>"#),
        "rc:live":(24,24,#"<circle fill="currentColor" cx="12" cy="12" r="4.2"/><circle cx="12" cy="12" r="8.6" fill="none" stroke="currentColor" stroke-width="2.2" opacity=".42"/>"#),
        "rc:user-fill":(24,24,#"<circle fill="currentColor" cx="12" cy="7.4" r="4.6"/><path fill="currentColor" d="M3.4 20.1C4.3 15.9 7.8 13.6 12 13.6s7.7 2.3 8.6 6.5c.15.75-.4 1.4-1.15 1.4H4.55c-.75 0-1.3-.65-1.15-1.4z"/>"#),
        "ph:trophy-fill":(256,256,#"<path fill="currentColor" d="M232 64h-24V48a8 8 0 0 0-8-8H56a8 8 0 0 0-8 8v16H24A16 16 0 0 0 8 80v16a40 40 0 0 0 40 40h3.65A80.13 80.13 0 0 0 120 191.61V216H96a8 8 0 0 0 0 16h64a8 8 0 0 0 0-16h-24v-24.42c31.94-3.23 58.44-25.64 68.08-55.58H208a40 40 0 0 0 40-40V80a16 16 0 0 0-16-16M48 120a24 24 0 0 1-24-24V80h24v32q0 4 .39 8Zm184-24a24 24 0 0 1-24 24h-.5a82 82 0 0 0 .5-8.9V80h24Z"/>"#),
        "rc:moon-fill":(24,24,#"<path fill="currentColor" d="M20.5 14.6A8.6 8.6 0 0 1 9.4 3.5a.6.6 0 0 0-.8-.7A9.6 9.6 0 1 0 21.2 15.4a.6.6 0 0 0-.7-.8z"/>"#),
        "rc:id-fill":(24,24,#"<path fill="currentColor" fill-rule="evenodd" d="M5 4h14a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H5a3 3 0 0 1-3-3V7a3 3 0 0 1 3-3zm3.6 4a2.3 2.3 0 1 0 0 4.6a2.3 2.3 0 0 0 0-4.6zM5.2 16.6c.4-1.8 1.7-2.8 3.4-2.8s3 1 3.4 2.8zM14 9h5.2v1.8H14zm0 3.6h4v1.8h-4z"/>"#),
        "lucide:swords":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m13 19l6-6m-4.5 4.5L3.586 6.586A2 2 0 0 1 3 5.172V3h2.172a2 2 0 0 1 1.414.586L17.5 14.5m-2.672-8.328l2.586-2.586A2 2 0 0 1 18.828 3H21v2.172a2 2 0 0 1-.586 1.414l-2.586 2.586M16 16l4 4m-1 1l2-2M5 14l4 4m-4 3l-2-2m4.5-2.5L4 20"/>"#),
        "lucide:hourglass":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 22h14M5 2h14m-2 20v-4.172a2 2 0 0 0-.586-1.414L12 12l-4.414 4.414A2 2 0 0 0 7 17.828V22M7 2v4.172a2 2 0 0 0 .586 1.414L12 12l4.414-4.414A2 2 0 0 0 17 6.172V2"/>"#),
        "rc:key":(24,24,#"<path fill="currentColor" fill-rule="evenodd" d="M7.5 7a5 5 0 1 1 0 10a5 5 0 0 1 0-10zm0 3.2a1.8 1.8 0 1 0 0 3.6a1.8 1.8 0 0 0 0-3.6z"/><path fill="currentColor" d="M11.8 10.6h9.7a.8.8 0 0 1 .8.8v1.4a.8.8 0 0 1-.8.8h-.9v2.1a.6.6 0 0 1-.6.6h-1.6a.6.6 0 0 1-.6-.6v-2.1h-1.2v1.5a.6.6 0 0 1-.6.6h-1.6a.6.6 0 0 1-.6-.6v-1.5h-2z"/>"#),
        "lucide:plus":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14m-7-7v14"/>"#),
        "lucide:check":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 6L9 17l-5-5"/>"#),
        "lucide:arrow-right":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14m-7-7l7 7l-7 7"/>"#),
        "rc:shield-fill":(24,24,#"<path fill="currentColor" d="M12 2.2c-2.3 1.7-4.9 2.7-7.6 2.9a1 1 0 0 0-.9 1V12c0 5.2 3.6 8.5 8.1 9.8a1.4 1.4 0 0 0 .8 0c4.5-1.3 8.1-4.6 8.1-9.8V6.1a1 1 0 0 0-.9-1c-2.7-.2-5.3-1.2-7.6-2.9z"/>"#),
        "rc:crown-fill":(24,24,#"<path fill="currentColor" d="M2.6 7.2a.6.6 0 0 1 1-.6l4.1 3.4a1 1 0 0 0 1.5-.3l2.3-4.6a.6.6 0 0 1 1 0l2.3 4.6a1 1 0 0 0 1.5.3l4.1-3.4a.6.6 0 0 1 1 .6l-2.2 9.6a1 1 0 0 1-1 .8H5.8a1 1 0 0 1-1-.8z"/><rect fill="currentColor" x="5" y="19.2" width="14" height="2" rx="1"/>"#),
        "ph:clock-fill":(256,256,#"<path fill="currentColor" d="M128 24a104 104 0 1 0 104 104A104.11 104.11 0 0 0 128 24m56 112h-56a8 8 0 0 1-8-8V72a8 8 0 0 1 16 0v48h48a8 8 0 0 1 0 16"/>"#),
        "rc:plus-fill":(24,24,#"<path fill="currentColor" d="M10 3.2h4a.8.8 0 0 1 .8.8v5.2H20a.8.8 0 0 1 .8.8v4a.8.8 0 0 1-.8.8h-5.2V20a.8.8 0 0 1-.8.8h-4a.8.8 0 0 1-.8-.8v-5.2H4a.8.8 0 0 1-.8-.8v-4a.8.8 0 0 1 .8-.8h5.2V4a.8.8 0 0 1 .8-.8z"/>"#),
        "lucide:copy":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect width="13" height="13" x="9" y="9" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></g>"#),
        "lucide:share-2":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="m8.59 13.51l6.83 3.98m-.01-10.98l-6.82 3.98"/></g>"#),
        "lucide:trash-2":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 6h18m-2 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2m-6 5v6m4-6v6"/>"#),
        "lucide:clipboard-paste":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M15 2H9a1 1 0 0 0-1 1v2c0 .6.4 1 1 1h6c.6 0 1-.4 1-1V3c0-.6-.4-1-1-1"/><path d="M8 4H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2M16 4h2a2 2 0 0 1 2 2v2m-9 6h10m-4-4l4 4l-4 4"/></g>"#),
        "lucide:rotate-ccw":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M3 12a9 9 0 1 0 9-9a9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/></g>"#),
        "rc:check-fill":(24,24,#"<path fill="currentColor" fill-rule="evenodd" d="M12 2a10 10 0 1 1 0 20a10 10 0 0 1 0-20zm4.7 7.3a1 1 0 0 0-1.4-1.4L10.5 12.7L8.7 10.9a1 1 0 0 0-1.4 1.4l2.5 2.5a1 1 0 0 0 1.4 0z"/>"#),
        "lucide:undo-2":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M9 14L4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 5.5 5.5a5.5 5.5 0 0 1-5.5 5.5H11"/></g>"#),
        "lucide:file-text":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z"/><path d="M14 2v5a1 1 0 0 0 1 1h5M10 9H8m8 4H8m8 4H8"/></g>"#),
        "simple-icons:battledotnet":(24,24,#"<path fill="currentColor" d="M18.94 8.296C15.9 6.892 11.534 6 7.426 6.332c.206-1.36.714-2.308 1.548-2.508c1.148-.275 2.4.48 3.594 1.854c.782.102 1.71.28 2.355.429C12.747 2.013 9.828-.282 7.607.565c-1.688.644-2.553 2.97-2.448 6.094c-2.2.468-3.915 1.3-5.013 2.495c-.056.065-.181.227-.137.305c.034.058.146-.008.194-.04c1.274-.89 2.904-1.373 5.027-1.676c.303 3.333 1.713 7.56 4.055 10.952c-1.28.502-2.356.536-2.946-.087c-.812-.856-.784-2.318-.19-4.04a27 27 0 0 1-.807-2.254c-2.459 3.934-2.986 7.61-1.143 9.11c1.402 1.14 3.847.725 6.502-.926c1.505 1.672 3.083 2.74 4.667 3.094c.084.015.287.043.332-.034c.034-.06-.08-.124-.131-.149c-1.408-.657-2.64-1.828-3.964-3.515c2.735-1.929 5.691-5.263 7.457-8.988c1.076.86 1.64 1.773 1.398 2.595c-.336 1.131-1.615 1.84-3.403 2.185a28 28 0 0 1-1.548 1.826c4.634.16 8.08-1.22 8.458-3.565c.286-1.786-1.295-3.696-4.053-5.17c.696-2.139.832-4.04.346-5.588c-.029-.08-.106-.27-.196-.27c-.068 0-.067.13-.063.187c.135 1.547-.263 3.2-1.062 5.19zm-8.533 9.869c-1.96-3.145-3.09-6.849-3.082-10.594c3.702-.124 7.474.748 10.714 2.627c-1.743 3.269-4.385 6.1-7.633 7.966z"/>"#),
        "lucide:shield-check":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M12 22s8-3.5 8-10V5l-8-3l-8 3v7c0 6.5 8 10 8 10z"/><path d="m9 12l2 2l4-4"/></g>"#),
        "lucide:download":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4m4-5l5 5l5-5m-5 5V3"/>"#),
        "lucide:eye-off":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575a1 1 0 0 1 0 .696a10.8 10.8 0 0 1-1.444 2.49m-6.41-.679a3 3 0 0 1-4.242-4.242"/><path d="M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151a1 1 0 0 1 0-.696a10.75 10.75 0 0 1 4.446-5.143M2 2l20 20"/></g>"#),
        "lucide:image":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect width="18" height="18" x="3" y="3" rx="2" ry="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15l-3.086-3.086a2 2 0 0 0-2.828 0L6 21"/></g>"#),
        "lucide:database":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14a9 3 0 0 0 18 0V5"/><path d="M3 12a9 3 0 0 0 18 0"/></g>"#),
        "ph:check-bold":(256,256,#"<path fill="currentColor" d="m232.49 80.49l-128 128a12 12 0 0 1-17 0l-56-56a12 12 0 1 1 17-17L96 183L215.51 63.51a12 12 0 0 1 17 17Z"/>"#),
        "lucide:gamepad-2":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 11h4M8 9v4m7-1h.01M18 10h.01m-.69-5H6.68a4 4 0 0 0-3.978 3.59l-.017.152C2.604 9.416 2 14.456 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.414-1.414A2 2 0 0 1 9.828 16h4.344a2 2 0 0 1 1.414.586L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.545-.604-6.584-.685-7.258q-.01-.075-.017-.151A4 4 0 0 0 17.32 5"/>"#),
        "lucide:radio":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M16.247 7.761a6 6 0 0 1 0 8.478m2.828-11.306a10 10 0 0 1 0 14.134m-14.15 0a10 10 0 0 1 0-14.134m2.828 11.306a6 6 0 0 1 0-8.478"/><circle cx="12" cy="12" r="2"/></g>"#),
        "lucide:medal":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M7.21 15L2.66 7.14a2 2 0 0 1 .13-2.2L4.4 2.8A2 2 0 0 1 6 2h12a2 2 0 0 1 1.6.8l1.6 2.14a2 2 0 0 1 .14 2.2L16.79 15M11 12L5.12 2.2M13 12l5.88-9.8M8 7h8"/><circle cx="12" cy="17" r="5"/><path d="M12 18v-2h-.5"/></g>"#),
        "lucide:wand-sparkles":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m21.64 3.64l-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1.28 1.28a1.2 1.2 0 0 0 1.72 0L21.64 5.36a1.2 1.2 0 0 0 0-1.72M14 7l3 3M5 6v4m14 4v4M10 2v2M7 8H3m18 8h-4M11 3H9"/>"#),
        "ph:broadcast-fill":(256,256,#"<path fill="currentColor" d="M168 128a40 40 0 1 1-40-40a40 40 0 0 1 40 40m40 0a79.74 79.74 0 0 0-20.37-53.33a8 8 0 1 0-11.92 10.67a64 64 0 0 1 0 85.33a8 8 0 0 0 11.92 10.67A79.8 79.8 0 0 0 208 128M80.29 85.34a8 8 0 1 0-11.92-10.67a79.94 79.94 0 0 0 0 106.67a8 8 0 0 0 11.92-10.67a63.95 63.95 0 0 1 0-85.33m158.28-4A119.5 119.5 0 0 0 213.71 44a8 8 0 1 0-11.42 11.2a103.9 103.9 0 0 1 0 145.56A8 8 0 1 0 213.71 212a120.12 120.12 0 0 0 24.86-130.71Zm-206.4 87.14A103.9 103.9 0 0 1 53.71 55.22A8 8 0 1 0 42.29 44a119.87 119.87 0 0 0 0 168a8 8 0 1 0 11.42-11.2a103.6 103.6 0 0 1-21.54-32.32"/>"#),
        "ph:magic-wand-fill":(256,256,#"<path fill="currentColor" d="M248 152a8 8 0 0 1-8 8h-16v16a8 8 0 0 1-16 0v-16h-16a8 8 0 0 1 0-16h16v-16a8 8 0 0 1 16 0v16h16a8 8 0 0 1 8 8M56 72h16v16a8 8 0 0 0 16 0V72h16a8 8 0 0 0 0-16H88V40a8 8 0 0 0-16 0v16H56a8 8 0 0 0 0 16m128 120h-8v-8a8 8 0 0 0-16 0v8h-8a8 8 0 0 0 0 16h8v8a8 8 0 0 0 16 0v-8h8a8 8 0 0 0 0-16m35.31-112L80 219.31a16 16 0 0 1-22.62 0l-20.7-20.68a16 16 0 0 1 0-22.63L176 36.69a16 16 0 0 1 22.63 0l20.68 20.68a16 16 0 0 1 0 22.63M208 68.69L187.31 48l-32 32L176 100.69Z"/>"#),
        "ph:lock-simple-fill":(256,256,#"<path fill="currentColor" d="M208 80h-32V56a48 48 0 0 0-96 0v24H48a16 16 0 0 0-16 16v112a16 16 0 0 0 16 16h160a16 16 0 0 0 16-16V96a16 16 0 0 0-16-16M96 56a32 32 0 0 1 64 0v24H96Z"/>"#),
        "lucide:map-pin":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0"/><circle cx="12" cy="10" r="3"/></g>"#),
        "lucide:trending-up":(24,24,#"<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m22 7l-8.5 8.5l-5-5L2 17M16 7h6v6"/>"#),
        "lucide:user-round":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><circle cx="12" cy="8" r="5"/><path d="M20 21a8 8 0 0 0-16 0"/></g>"#),
        "lucide:trophy":(24,24,#"<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M10 14.66V17a1 1 0 0 1-1 1a2 2 0 0 0-2 2v2m7-7.34V17a1 1 0 0 0 1 1a2 2 0 0 1 2 2v2m.916-12H19.5A2.5 2.5 0 0 0 22 7.5V5a1 1 0 0 0-1-1h-3M4 22h16"/><path d="M6 9a6 6 0 0 0 12 0V3a1 1 0 0 0-1-1H7a1 1 0 0 0-1 1z"/><path d="M6.084 10H4.5A2.5 2.5 0 0 1 2 7.5V5a1 1 0 0 1 1-1h3"/></g>"#),
    ]
}

/// Noto Sans, the design's stand-in for Discord's own font (gg sans, which isn't free to bundle): the Latin and
/// Latin Extended files Google Fonts serves, each one variable font for every weight. Other scripts fall back
/// to the system's fonts, as they do in Discord.
enum DiscordFont {
    private static let registered:[CTFontDescriptor]={
        guard let folder=Bundle.main.resourceURL else { return [] }
        return ["NotoSans-Latin","NotoSans-LatinExt"].compactMap { name in
            guard let data=try? Data(contentsOf:folder.appendingPathComponent(name+".woff2")) else { return nil }
            return (CTFontManagerCreateFontDescriptorsFromData(data as CFData) as? [CTFontDescriptor])?.first
        }
    }()
    private static let lock=NSLock()
    nonisolated(unsafe) private static var fonts:[String:NSFont]=[:]
    /// Noto Sans at a size and weight (400 regular, 600 semibold, 700 bold), or the system font without the files.
    static func nsFont(_ size:CGFloat,_ weight:Int=400)->NSFont {
        lock.lock();defer { lock.unlock() }
        let key="\(size)/\(weight)"
        if let font=fonts[key] { return font }
        let systemWeight:NSFont.Weight=weight >= 700 ? .bold : weight >= 600 ? .semibold : weight >= 500 ? .medium : .regular
        guard let latin=registered.first else { return NSFont.systemFont(ofSize:size,weight:systemWeight) }
        // The weight axis ('wght'), then Latin Extended for the letters the Latin file doesn't have.
        let axis=0x77676874 as CFNumber
        var descriptor=CTFontDescriptorCreateCopyWithVariation(latin,axis,CGFloat(weight))
        if registered.count > 1 {
            let extended=CTFontDescriptorCreateCopyWithVariation(registered[1],axis,CGFloat(weight))
            descriptor=CTFontDescriptorCreateCopyWithAttributes(descriptor,[kCTFontCascadeListAttribute:[extended] as CFArray] as CFDictionary)
        }
        let font=CTFontCreateWithFontDescriptor(descriptor,size,nil) as NSFont
        fonts[key]=font
        return font
    }
}
extension Font {
    /// Discord's text, as the design shows it (Noto Sans).
    static func discord(_ size:CGFloat,_ weight:Int=400)->Font { Font(DiscordFont.nsFont(size,weight)) }
}
extension Text {
    /// One text after another on the same line, each in its own style (`+` is deprecated on macOS 26).
    func followed(by next:Text)->Text { Text("\(self)\(next)") }
}

extension AnyTransition {
    /// A part that comes with another screen fades in once the screen has moved into place: a new view shows at
    /// its new place at once, while all around it is still moving. It goes at once.
    static var afterMove:AnyTransition {
        .asymmetric(insertion:.opacity.animation(.easeOut(duration:0.2).delay(0.42)),removal:.opacity.animation(.linear(duration:0.06)))
    }
}

/// Text set as the design's CSS sets it: each line its `line-height` tall, the extra split above and below every line.
enum DesignText {
    private static let lock=NSLock()
    nonisolated(unsafe) private static var heights:[String:CGFloat]=[:]
    /// How tall SwiftUI makes one line of a font (measured on macOS 26: the system font's lines are as tall as
    /// CoreText's frame setter makes them, Noto Sans's as AppKit's text measuring makes them).
    static func natural(_ font:NSFont)->CGFloat {
        lock.lock();defer { lock.unlock() }
        let key="\(font.fontName)/\(font.pointSize)"
        if let height=heights[key] { return height }
        let text=NSAttributedString(string:"Hg",attributes:[.font:font]),room=CGSize(width:1000,height:1000)
        let height:CGFloat
        if font.familyName == NSFont.systemFont(ofSize:font.pointSize).familyName {
            height=CTFramesetterSuggestFrameSizeWithConstraints(CTFramesetterCreateWithAttributedString(text as CFAttributedString),CFRange(location:0,length:0),nil,room,nil).height
        } else {
            height=text.boundingRect(with:room,options:[.usesLineFragmentOrigin,.usesFontLeading]).height
        }
        heights[key]=height
        return height
    }
    /// A line of the font as the browser the design was made in makes it ("normal"): its ascender and its
    /// descender, each rounded. SwiftUI rounds the system font's descender up, so its lines can be a point taller.
    static func normal(_ font:NSFont)->CGFloat { font.ascender.rounded()+(-font.descender).rounded() }
}
extension View {
    /// Lines `multiple` times the font's size tall, as the design's `line-height`: the extra goes between lines
    /// (line spacing) and around the text (padding), placed so the first line sits where the browser puts it, in
    /// the middle of the extra.
    func lineHeight(_ multiple:CGFloat,_ font:NSFont)->some View {
        let line=font.pointSize*multiple,natural=DesignText.natural(font),top=max(0,(line-DesignText.normal(font))/2)
        return lineSpacing(max(0,line-natural)).padding(.top,top).padding(.bottom,line-natural-top)
    }
    /// The same in the app's own font (LauncherStyle.font) at a size.
    func lineHeight(_ multiple:CGFloat,size:CGFloat)->some View { lineHeight(multiple,NSFont.systemFont(ofSize:size)) }
    /// Lines of the app's font at a size as tall as the browser makes them when the design gives no line height.
    /// Only for text whose every line is this font.
    func normalLines(size:CGFloat,weight:NSFont.Weight = .regular)->some View {
        let font=NSFont.systemFont(ofSize:size,weight:weight),normal=DesignText.normal(font)
        return lineHeight(normal < DesignText.natural(font) ? .exact(points:normal) : nil)
    }
}
