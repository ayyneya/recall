// Draws app/Resources/MacBadge.png, the Discord card's Mac badge: an original drawing of a classic compact Mac
// (never Apple's logo), dark on a light circle, as the design's card shows its Mac badge. Discord loads it from the
// repository's main branch and crops it round; Settings › Discord shows the app's own copy.
//   swift scripts/mac_badge.swift app/Resources/MacBadge.png
import AppKit
let size:CGFloat=512
let image=NSImage(size:NSSize(width:size,height:size),flipped:true) { rect in
    guard let g=NSGraphicsContext.current?.cgContext else { return false }
    let dark=CGColor(srgbRed:23/255,green:24/255,blue:27/255,alpha:1),light=CGColor(srgbRed:240/255,green:240/255,blue:242/255,alpha:1)
    g.setFillColor(light);g.fillEllipse(in:rect)
    // The Mac on a 24-point grid, two thirds of the circle, in its middle.
    let k=size*0.66/24,origin=(size-24*k)/2
    func box(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ radius:CGFloat)->CGPath {
        CGPath(roundedRect:CGRect(x:origin+x*k,y:origin+y*k,width:w*k,height:h*k),cornerWidth:radius*k,cornerHeight:radius*k,transform:nil)
    }
    g.setFillColor(dark);g.addPath(box(4.5,1,15,19.5,2.4));g.addPath(box(5.75,19.5,12.5,3.5,0.9));g.fillPath()
    // Its screen and its disk slot.
    g.setFillColor(light);g.addPath(box(7.25,3.75,9.5,8,1.2));g.addPath(box(12.25,15.25,4.5,1.25,0.6));g.fillPath()
    return true
}
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(size),pixelsHigh:Int(size),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
image.draw(in:NSRect(x:0,y:0,width:size,height:size))
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
