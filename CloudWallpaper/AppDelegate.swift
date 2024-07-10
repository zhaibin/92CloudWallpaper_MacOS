import Cocoa
import ServiceManagement
#if canImport(AppKit)
import AppKit
#endif

//@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var wallpaperTimer: Timer?
    var userId: Int
    var screenWidth: Int = 1440
    var screenHeight: Int = 900
    var webViewWindow: WebViewWindow!
    var imageCacheManager: ImageCacheManager!
    var currentWallpaperIndex = 0
    var functions: Functions!
    var stats: Stats

    override init() {
        self.userId = UserDefaults.standard.integer(forKey: "UserId")
        self.stats = Stats()
        super.init()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        preventMultipleInstances()
        EnvLoader.loadEnv()
        initializeComponents()
        setupStatusBar()
        setupTimer()

        stats = Stats()
        Task {
            try await stats.report(groupId: 0, albumId: 0, authorId: 0, behavior: String(StatsPara.Behavior.startApplication))
        }
        setupObservers()
        setWallpaper()
        
        let shouldStartAtLogin = UserDefaults.standard.bool(forKey: "shouldStartAtLogin")
        setLaunchAtLogin(enabled: shouldStartAtLogin)
    }

    func preventMultipleInstances() {
        let allApps = NSWorkspace.shared.runningApplications
        let running = allApps.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        if running.count > 1 {
            NSApp.terminate(nil)
        }
    }

    func initializeComponents() {
        ImageCacheManager.shared.initialize(userId: userId)
        webViewWindow = WebViewWindow(window: nil)
        performCacheOperation(fetchAllPages: false)

#if DEBUG
        loadUrlStore()
#endif
    }

    func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserData(_:)), name: .didReceiveUserData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleImagesAsync), name: .imagesAsync, object: nil)
    }

    @objc func handleImagesAsync(notification: Notification) {
        performCacheOperation(fetchAllPages: true)
    }

    @objc func handleUserData(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let userId = userInfo["userId"] as? Int,
           let token = userInfo["token"] as? String {
            print("Received UserId appdelegte: \(userId), Token: \(token)")
            self.userId = userId
            UserDefaults.standard.set(Int(userId), forKey: "UserId")
            print(UserDefaults.standard.integer(forKey: "UserId"))
            ImageCacheManager.shared.initialize(userId: userId)
            performCacheOperation(fetchAllPages: true)
            //setWallpaper()
        }
    }
    
    @objc func terminate(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "确认退出"
        alert.informativeText = "您确定要退出程序吗？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "退出")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSApp.terminate(self)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .didReceiveUserData, object: nil)
        NotificationCenter.default.removeObserver(self, name: .imagesAsync, object: nil)
        wallpaperTimer?.invalidate()
    }

    @objc func loadUrlStore() {
        if let url = URL(string: WebViewURL.store) {
            webViewWindow.load(url: url)
        }
    }

    @objc func loadUrlLogin() {
        webViewWindow.load(url: URL(string: WebViewURL.login)!)
    }

    @objc func loadUrlPost() {
        webViewWindow.load(url: URL(string: WebViewURL.post)!)
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        if let image = NSImage(named: "StatusMenuIcon") {
            button.image = image
            button.image?.isTemplate = true
        } else {
            print("Error: StatusMenuIcon image not found.")
        }
        updateMenu()
    }

    func updateMenu() {
        guard statusItem.button != nil else { return }

        let menu = NSMenu()
        menu.addItem(withTitle: "壁纸商店", action: #selector(loadUrlStore), keyEquivalent: "S")
        menu.addItem(withTitle: "上传壁纸", action: #selector(loadUrlPost), keyEquivalent: "P")

        let wallpaperMenu = NSMenu(title: "切换壁纸")
        wallpaperMenu.addItem(withTitle: "立即更换", action: #selector(changeWallpaperManually), keyEquivalent: "n")

#if DEBUG
        let intervals = [
            ("暂停", -1),
            ("五秒钟", 5),
            ("一分钟", 60),
            ("十分钟", 600),
            ("半小时", 1800),
            ("一小时", 3600)
        ]
#else
        let intervals = [
            ("暂停", -1),
            ("一分钟", 60),
            ("十分钟", 600),
            ("半小时", 1800),
            ("一小时", 3600)
        ]
#endif
        let currentInterval = UserDefaults.standard.integer(forKey: "wallpaperChangeInterval")
        let effectiveInterval = currentInterval > 0 ? currentInterval : 600 // 确保默认值为600
        for (title, seconds) in intervals {
            let item = NSMenuItem(title: title, action: #selector(setTimer(_:)), keyEquivalent: "")
            item.tag = seconds
            item.state = (effectiveInterval == seconds ? .on : .off)
            wallpaperMenu.addItem(item)
        }

        menu.setSubmenu(wallpaperMenu, for: menu.addItem(withTitle: "切换壁纸", action: nil, keyEquivalent: "w"))

        let autoStartItem = NSMenuItem(title: "开机启动", action: #selector(toggleAutoStart(_:)), keyEquivalent: "")
        autoStartItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(autoStartItem)

        let currentVersion = Constant.softwareVersion as? String ?? "未知"
        menu.addItem(NSMenuItem(title: "检查更新 (版本: \(currentVersion))", action: #selector(checkForUpdates), keyEquivalent: "U"))
        menu.addItem(withTitle: "退出程序", action: #selector(terminate), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc func checkForUpdates() {
        UpdateManager.shared.checkForUpdates()
    }

    @objc func changeWallpaperManually() {
        if UserDefaults.standard.integer(forKey: "UserId") > 0 {
            //print("G\(GlobalData.userId)")
            setWallpaper()
        }
        else {
            loadUrlStore()
        }
    }

    func setupTimer() {
        let interval = UserDefaults.standard.integer(forKey: "wallpaperChangeInterval")
        let effectiveInterval = interval > 0 ? interval : 600 // 如果没有取到值或取到的值<=0，就设置为600
        if effectiveInterval > 0 {
            wallpaperTimer?.invalidate()
            wallpaperTimer = Timer.scheduledTimer(timeInterval: TimeInterval(effectiveInterval), target: self, selector: #selector(updateWallpaper), userInfo: nil, repeats: true)
        }
    }

    @objc func setTimer(_ sender: NSMenuItem) {
        let seconds = sender.tag
        UserDefaults.standard.set(Int(seconds), forKey: "wallpaperChangeInterval")
        if seconds == -1 {
            wallpaperTimer?.invalidate()
            wallpaperTimer = nil
        } else {
            wallpaperTimer?.invalidate()
            wallpaperTimer = Timer.scheduledTimer(timeInterval: TimeInterval(Int(seconds)), target: self, selector: #selector(changeWallpaperManually), userInfo: nil, repeats: true)
        }
        updateMenu()
    }

    @objc func updateWallpaper() {
        setWallpaper()
    }

    func setWallpaper() {
        let availableCachedData = ImageCacheManager.shared.getAvailableCachedData()
        let allCachedData = ImageCacheManager.shared.getCachedData()
        
        guard !availableCachedData.isEmpty, userId != 0 else {
            print("Wallpaper URLs are empty or user is not logged in.")
            performCacheOperation(fetchAllPages: true)
            return
        }
        print("currentIndex \(currentWallpaperIndex) | allCached.count \(allCachedData.count) | availableData.count \(availableCachedData.count)")
        
        let wallpaperURL = availableCachedData[currentWallpaperIndex % availableCachedData.count].localPath!
        
        let workspace = NSWorkspace.shared
        let screens = NSScreen.screens
        
        for screen in screens {
            do {
                try workspace.setDesktopImageURL(wallpaperURL, for: screen, options: [:])
            } catch {
                print("Failed to set wallpaper for screen \(screen): \(error)")
            }
        }
        
        Task {
            try await stats.report(groupId: availableCachedData[currentWallpaperIndex].groupId, albumId: availableCachedData[currentWallpaperIndex].albumId, authorId: availableCachedData[currentWallpaperIndex].authorId, behavior: String(StatsPara.Behavior.setWallpaper))
        }
        currentWallpaperIndex += 1
        
        if currentWallpaperIndex >= availableCachedData.count {
            currentWallpaperIndex = 0
            performCacheOperation(fetchAllPages: true)
        }
    }

    func performCacheOperation(fetchAllPages: Bool) {
        let screenSize = Functions().getScreenSize()
        let screenWidth = screenSize?.width ?? 0
        let screenHeight = screenSize?.height ?? 0
        let apiHandler = ApiRequestHandler()

        if fetchAllPages {
            ImageCacheManager.shared.fetchAllPages(apiHandler: apiHandler, screenHeight: screenHeight, screenWidth: screenWidth) { result in
                self.handleFetchResult(result)
            }
        } else {
            ImageCacheManager.shared.fetchOnce(apiHandler: apiHandler, screenHeight: screenHeight, screenWidth: screenWidth) { result in
                self.handleFetchResult(result)
            }
        }
    }

    private func handleFetchResult(_ result: Result<Void, FetchError>) {
        switch result {
        case .success:
            ImageCacheManager.shared.cacheImages { cacheResult in
                switch cacheResult {
                case .success:
                    print("All images cached")
                case .failure(let error):
                    print("Failed to cache images: \(error)")
                }
            }
        case .failure(let error):
            print("Failed to fetch data: \(error)")
        }
    }
    @objc func toggleAutoStart(_ sender: NSMenuItem) {
            let shouldStartAtLogin = !isLaunchAtLoginEnabled()
            setLaunchAtLogin(enabled: shouldStartAtLogin)
            UserDefaults.standard.set(shouldStartAtLogin, forKey: "shouldStartAtLogin")
            updateMenu()
        }
        
        func setLaunchAtLogin(enabled: Bool) {
            if #available(macOS 13.0, *) {
                setLaunchAtLoginMacOS13(enabled: enabled)
            } else {
                setLaunchAtLoginLegacy(enabled: enabled)
            }
        }
        
        func isLaunchAtLoginEnabled() -> Bool {
            if #available(macOS 13.0, *) {
                return isLaunchAtLoginEnabledMacOS13()
            } else {
                return isLaunchAtLoginEnabledLegacy()
            }
        }
        
        @available(macOS 13.0, *)
        private func setLaunchAtLoginMacOS13(enabled: Bool) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        }
        
        @available(macOS 13.0, *)
        private func isLaunchAtLoginEnabledMacOS13() -> Bool {
            return SMAppService.mainApp.status == .enabled
        }
        
        private func setLaunchAtLoginLegacy(enabled: Bool) {
            let helperBundleIdentifier = Constant.bundleHelperID as CFString
            if SMLoginItemSetEnabled(helperBundleIdentifier, enabled) {
                print("Successfully \(enabled ? "added" : "removed") login item.")
            } else {
                print("Failed to \(enabled ? "add" : "remove") login item.")
            }
        }
        
        private func isLaunchAtLoginEnabledLegacy() -> Bool {
            // For older versions, we'll rely on UserDefaults
            return UserDefaults.standard.bool(forKey: "shouldStartAtLogin")
        }
}
