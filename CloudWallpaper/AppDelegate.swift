import Cocoa
import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var wallpaperTimer: Timer?
    var userId: Int
    var screenWidth: Int = 1440
    var screenHeight: Int = 900
    var webViewWindow: WebViewWindow!
    var imageCacheManager: ImageCacheManager!
    var currentWallpaperIndex = 0
//    var wallpaperComponent: WallpaperComponent?
    var functions: Functions!
//    var isComponentVisible: Bool = true {
//        didSet {
//            updateComponentVisibility()
//            updateMenu()
//        }
//    }
    var stats: Stats
    
    override init() {
        self.userId = UserDefaults.standard.integer(forKey: "UserId")
        //self.isUserLoggedIn = (userId != 0)
        self.stats = Stats()
        super.init()
        //ImageCacheManager.shared.initialize(userId: userId)
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
//
//        let shouldStartAtLogin = UserDefaults.standard.bool(forKey: "shouldStartAtLogin")
//        setLaunchAtLogin(enabled: shouldStartAtLogin) 
        
        setWallpaper()
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
//        let screens = NSScreen.screens
//        for screen in screens {
//            do {
//                wallpaperComponent = WallpaperComponent(screen: screen)
//            }
//        }
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
            //self.isUserLoggedIn = (userId != 0)
            self.userId = userId
            performCacheOperation(fetchAllPages: true)
            setWallpaper()
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
    @objc func loadUrlTest() {
        //webViewWindow.load(url: URL(string: WebViewURL.test)!)
    }
    
    func setupStatusBar() {
        // 获取系统的状态栏实例，并创建一个可变长度的状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // 确保状态栏按钮存在
        guard let button = statusItem.button else { return }

        // 设置按钮的图像
        if let image = NSImage(named: "StatusMenuIcon") {
            button.image = image
            button.image?.isTemplate = true // 使用模板图像以适应浅色和深色模式
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
            
        for (title, seconds) in intervals {
            let item = NSMenuItem(title: title, action: #selector(setTimer(_:)), keyEquivalent: "")
            item.tag = seconds
            item.state = (currentInterval == seconds ? .on : .off)
            wallpaperMenu.addItem(item)
        }
        
        menu.setSubmenu(wallpaperMenu, for: menu.addItem(withTitle: "切换壁纸", action: nil, keyEquivalent: "w"))
        
//        let autoStartItem = NSMenuItem(title: "自动启动", action: #selector(toggleAutoStart(_:)), keyEquivalent: "A")
//        autoStartItem.state = UserDefaults.standard.bool(forKey: "shouldStartAtLogin") ? .on : .off
//        menu.addItem(autoStartItem)
        
//#if DEBUG
//        let componentItem = NSMenuItem(title: "显示/隐藏小组件", action: #selector(toggleComponentVisibility), keyEquivalent: "C")
//        componentItem.state = isComponentVisible ? .on : .off
//        menu.addItem(componentItem)
//#endif
        let currentVersion = Constant.softwareVersion as? String ?? "未知"
        menu.addItem(NSMenuItem(title: "检查更新 (版本: \(currentVersion))", action: #selector(checkForUpdates), keyEquivalent: "U"))
        menu.addItem(withTitle: "退出程序", action: #selector(terminate), keyEquivalent: "q")
        statusItem.menu = menu
    }
    
    @objc func checkForUpdates() {
        UpdateManager.shared.checkForUpdates()
    }
    
    @objc func changeWallpaperManually() {
        setWallpaper()
    }
    
    func setupTimer() {
        let interval = UserDefaults.standard.integer(forKey: "wallpaperChangeInterval")

        if interval > 0 {
            wallpaperTimer?.invalidate()
            wallpaperTimer = Timer.scheduledTimer(timeInterval: TimeInterval(interval), target: self, selector: #selector(updateWallpaper), userInfo: nil, repeats: true)
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
    /*
    func setWallpaper() {
        let availableCachedData = ImageCacheManager.shared.getAvailableCachedData()
        let allCachedData = ImageCacheManager.shared.getCachedData()
        
        if availableCachedData.isEmpty || userId == 0 {
            print("Wallpaper URLs are empty or user is not logged in.")
            performCacheOperation(fetchAllPages: true)
        } else {
            print("allCachedData.count \(allCachedData.count)")
            print("availableCachedData.count \(availableCachedData.count)")
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
            
            print("currentWallpaperIndex \(currentWallpaperIndex)")
            currentWallpaperIndex += 1
            
            if currentWallpaperIndex >= availableCachedData.count {
                currentWallpaperIndex = 0
                performCacheOperation(fetchAllPages: true)
            }
        }
    }
    */
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
    
//    @objc func toggleAutoStart(_ sender: NSMenuItem) {
//        let shouldStartAtLogin = !UserDefaults.standard.bool(forKey: "shouldStartAtLogin")
//        UserDefaults.standard.set(shouldStartAtLogin, forKey: "shouldStartAtLogin")
//        setLaunchAtLogin(enabled: shouldStartAtLogin)
//        updateMenu()
//    }
//    
//    func setLaunchAtLogin(enabled: Bool) {
//        let launcherAppIdentifier = Constant.bundleID // 替换为实际的 Bundle Identifier
//        SMLoginItemSetEnabled(launcherAppIdentifier as CFString, enabled)
//    }
//    

    
//    @objc func toggleComponentVisibility() {
//        isComponentVisible.toggle()
//    }
//    
//    func updateComponentVisibility() {
//        if isComponentVisible {
//            if wallpaperComponent == nil {
//                let screens = NSScreen.screens
//                for screen in screens {
//                    do {
//                        wallpaperComponent = WallpaperComponent(screen: screen)
//                    }
//                }
//            }
//            wallpaperComponent?.makeKeyAndOrderFront(nil)
//        } else {
//            wallpaperComponent?.orderOut(nil)
//        }
//    }
    
    @objc func terminate() {
        NSApp.terminate(self)
    }
}
