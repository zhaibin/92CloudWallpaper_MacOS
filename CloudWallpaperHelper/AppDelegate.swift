import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Helper app needs to stay running
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(terminate), name: NSNotification.Name("terminateHelper"), object: nil)
    }

    @objc func terminate() {
        NSApp.terminate(nil)
    }
}
