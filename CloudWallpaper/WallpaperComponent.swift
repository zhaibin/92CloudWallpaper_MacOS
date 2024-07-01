import Cocoa
import SwiftUI
import WebKit

class WallpaperComponent: NSWindow {
    init(screen: NSScreen) {
        let screenFrame = screen.frame
        super.init(contentRect: screenFrame, styleMask: [.borderless], backing: .buffered, defer: false)
        
        self.level = .init(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        
        let webView = WKWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.load(URLRequest(url: URL(string: "https://look.levect.com/web/")!))
        
        self.contentView = webView
        self.orderFrontRegardless()
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: self.contentView!.topAnchor),
            webView.bottomAnchor.constraint(equalTo: self.contentView!.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: self.contentView!.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: self.contentView!.trailingAnchor)
        ])
    }
}
