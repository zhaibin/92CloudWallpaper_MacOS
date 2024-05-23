import Cocoa
import SwiftUI



class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var loginWindow: NSWindow?
    var statusItem: NSStatusItem!
    var downloader: Downloader!
    var wallpaperTimer: Timer?
    var userId: Int
    var wallpaperURLs: [URL] = []
    var syncWallpaperURLs: [URL] = [] //当前与 API 一致的图片
    var currentWallpaperIndex = 0
    var screenWidth: Int = 1440
    var screenHeight: Int = 900
    var pageIndex = 1  // 翻页参数初始化为1
    //var isAutoStartEnabled: Bool = false

           
    override init() {
        self.userId = UserDefaults.standard.integer(forKey: "UserId")
        self.isUserLoggedIn = (userId != 0)
        super.init()
    }
    var isUserLoggedIn: Bool {
        didSet {
            updateLoginMenuItem()
        }
    }
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 检查是否已有同名应用在运行
        _ = Bundle.main.infoDictionary?["CFBundleName"] as? String
        let allApps = NSWorkspace.shared.runningApplications
        let running = allApps.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }

        if running.count > 1 {
            // 如果发现有另一个实例已在运行，则终止当前应用
            NSApp.terminate(nil)
        }
        //let shouldShowIcon = true// 你的逻辑条件
        //showDockIcon(shouldShowIcon)
        

        EnvLoader.loadEnv()
        let screenSize = getScreenSize()
        screenWidth = screenSize?.width ?? screenWidth
        screenHeight = screenSize?.height ?? screenHeight
        downloader = Downloader(userId: userId)  // 初始化 Downloader 时传入 userId
        setupTimer()
        refreshWallpaperList()
        setupStatusBar()
        setupLoginWindow()  // 设置用于登录的窗口
        
              
    }
    
    //@objc func checkForUpdates() {
    //    updaterController.checkForUpdates(nil)
    //}

    
    func showDockIcon(_ show: Bool) {
        if show {
            // 设置为常规应用，会在 Dock 显示图标
            NSApp.setActivationPolicy(.regular)
        } else {
            // 设置为辅助应用，不会在 Dock 显示图标
            NSApp.setActivationPolicy(.accessory)
        }
    }
    func setupLoginWindow() {
        let loginFormView = LoginForm(onLoginStatusChanged: { isLoggedIn in
            DispatchQueue.main.async {  // 确保在主线程执行 UI 更新
                self.isUserLoggedIn = isLoggedIn
                if isLoggedIn {
                    self.userId = UserDefaults.standard.integer(forKey: "UserId")
                    print(self.userId)
                    self.downloader = Downloader(userId: self.userId)  // 用新的 userId 重新初始化 Downloader
                    self.setupTimer()  // 重新设置壁纸更换定时器
                    self.refreshWallpaperList()  // 刷新壁纸列表
                    self.updateMenu()
                    self.setWallpaper()
                    self.loginWindow?.close()  // 关闭登录窗口
                    
                }
            }
        })

        loginWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        loginWindow?.center()
        loginWindow?.setFrameAutosaveName("Login Window")
        loginWindow?.contentView = NSHostingView(rootView: loginFormView)
        loginWindow?.title = "Login"
        loginWindow?.isReleasedWhenClosed = false  // 防止窗口关闭时被释放
    }

    func showLoginWindow() {
        loginWindow?.makeKeyAndOrderFront(nil)  // 显示登录窗口
        NSApp.activate(ignoringOtherApps: true)  // 使应用成为活跃应用
    }
    
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(named: "StatusMenuIcon")  // 确保在资源中有名为 'StatusMenuIcon' 的图标
        updateMenu()
    }

    func updateMenu() {
        guard statusItem.button != nil else { return }

        let menu = NSMenu()

        // 登录/登出
        menu.addItem(withTitle: isUserLoggedIn ? "登出" : "登录", action: #selector(toggleLogin), keyEquivalent: "l")
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
        menu.addItem(NSMenuItem(title: "检查更新 (版本: \(currentVersion))", action: #selector(checkForUpdates), keyEquivalent: "U"))
                
        //menu.addItem(NSMenuItem(title: "检查更新", action: #selector(checkForUpdates), keyEquivalent: "U"))
                    
        // 切换壁纸
        let wallpaperMenu = NSMenu(title: "切换壁纸")
        wallpaperMenu.addItem(withTitle: "立即更换", action: #selector(changeWallpaperManually), keyEquivalent: "n")
        let intervals = [
            ("暂停", -1),
            ("一分钟", 60),
            ("十分钟", 600),
            ("半小时", 1800),
            ("一小时", 3600)
        ]
        for (title, seconds) in intervals {
            let item = NSMenuItem(title: title, action: #selector(setTimer(_:)), keyEquivalent: "")
            item.tag = seconds
            item.state = (wallpaperTimer?.timeInterval == Double(seconds) ? .on : .off)
            wallpaperMenu.addItem(item)
        }
        
        menu.setSubmenu(wallpaperMenu, for: menu.addItem(withTitle: "切换壁纸", action: nil, keyEquivalent: "w"))

   
        // 退出程序
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
#if DEBUG
        let interval = 5
#else
        let interval = 60
#endif
        
        //print(interval)
        wallpaperTimer?.invalidate()
        if interval > 0 {
            wallpaperTimer = Timer.scheduledTimer(timeInterval: Double(interval), target: self, selector: #selector(updateWallpaper), userInfo: nil, repeats: true)
        }
    }

    @objc func setTimer(_ sender: NSMenuItem) {
        let seconds = sender.tag
        if seconds == -1 {
            wallpaperTimer?.invalidate()
            wallpaperTimer = nil
        } else {
            wallpaperTimer?.invalidate()
            wallpaperTimer = Timer.scheduledTimer(timeInterval: Double(seconds), target: self, selector: #selector(changeWallpaperManually), userInfo: nil, repeats: true)
        }
        updateMenu()
    }
    
    @objc func updateWallpaper() {
        setWallpaper()
    }

    func setWallpaper() {
        if wallpaperURLs.isEmpty || userId == 0 {
            print("Wallpaper URLs are empty or user is not logged in.")
            refreshWallpaperList()
        } else {
            print("wallpaperURLs.count \(wallpaperURLs.count)")
            let wallpaperURL = wallpaperURLs[currentWallpaperIndex % wallpaperURLs.count]
            
            let workspace = NSWorkspace.shared
            let screens = NSScreen.screens
            
            for screen in screens {
                do {
                    try workspace.setDesktopImageURL(wallpaperURL, for: screen, options: [:])
                } catch {
                    print("Failed to set wallpaper for screen \(screen): \(error)")
                }
            }
            
            print("currentWallpaperIndex \(currentWallpaperIndex)")
            currentWallpaperIndex += 1
            
            if currentWallpaperIndex >= wallpaperURLs.count {
                currentWallpaperIndex = 0
                refreshWallpaperList()  // 刷新壁纸列表
            }
        }
    }

    func refreshWallpaperList() {
        let apiHandler = ApiRequestHandler()
        let body: [String: Any] = [
            "userId": userId,
            "height": screenHeight,
            "width": screenWidth,
            "pageSize": 4,
            "pageIndex": pageIndex
        ]
        Task {
            let wallpaperList = try await apiHandler.sendApiRequestAsync(url: URL(string: "https://cnapi.levect.com/v1/photoFrame/imageList")!, body: body)
            let newURLs = parseWallpaperList(jsonString: wallpaperList)
            print(body)
            if newURLs.isEmpty {
                pageIndex = 1  // 重置页码
                print(syncWallpaperURLs)
                
                self.downloader.cleanupCacheAgainstAllURLs(keepingURLs: syncWallpaperURLs) { updatedCacheFilePaths in
                    print("updatedCacheFilePaths \(updatedCacheFilePaths)")
                    self.wallpaperURLs = updatedCacheFilePaths
                }
                syncWallpaperURLs = []
            } else {
                syncWallpaperURLs.append(contentsOf: newURLs)
                downloader.updateCache(with: newURLs) { [weak self] cachedURLs in
                    guard let strongSelf = self else { return }
                    print("cachedURLsCount \(cachedURLs.count)")
                    
                    strongSelf.wallpaperURLs.append(contentsOf: cachedURLs)
                    strongSelf.pageIndex += 1
                }
            }
        }
    }
    
    func parseWallpaperList(jsonString: String) -> [URL] {
        guard let data = jsonString.data(using: .utf8) else {
            print("Error: Cannot create Data from jsonString")
            return []
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let body = json["body"] as? [String: Any],
                   let list = body["list"] as? [[String: Any]] {
                    print(list.count)
                    return list.compactMap { item in
                        if let urlString = item["url"] as? String, let url = URL(string: urlString) {
                            return url
                        } else {
                            print("Invalid URL or missing 'url' key: \(item)")  // 输出无效的 URL 或缺少 'url' 键的信息
                            return nil
                        }
                    }
                } else {
                    print("Missing 'body' or 'list' key, or wrong data type")
                }
            } else {
                print("JSON does not contain a dictionary at the root level")
            }
        } catch {
            print("Error parsing JSON: \(error)")
        }
        
        return []
    }

    @objc func toggleLogin() {
        if isUserLoggedIn {
            let alert = NSAlert()
            alert.messageText = "确认退出"
            alert.informativeText = "您确定要退出登录吗？"
            alert.icon = NSApp.applicationIconImage  // 设置为应用图标
            alert.addButton(withTitle: "退出")
            alert.addButton(withTitle: "取消")
            alert.alertStyle = .warning
            if alert.runModal() == .alertFirstButtonReturn {
                UserDefaults.standard.removeObject(forKey: "UserId")
                isUserLoggedIn = false
                updateMenu()
                userId = 0
            }
        } else {
            if loginWindow == nil {
                setupLoginWindow()  // 如果登录窗口为空，则重新设置登录窗口
            }
            loginWindow?.makeKeyAndOrderFront(nil)  // 显示登录窗口
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func updateLoginMenuItem() {
        if let menu = statusItem.menu {
            let loginItem = menu.item(withTitle: isUserLoggedIn ? "Login" : "Logout")
            loginItem?.title = isUserLoggedIn ? "Logout" : "Login"
        }
    }

    @objc func terminate() {
        NSApp.terminate(self)
    }
    
    func getScreenSize() -> (width: Int, height: Int)? {
        guard let mainScreen = NSScreen.main else {
            print("Unable to access the main screen")
            return (1440,900)
        }

        let screenFrame = mainScreen.frame // 使用 visibleFrame 考虑屏幕的菜单栏和停靠区
        let width = Int(screenFrame.width)
        let height = Int(screenFrame.height)
        return (width, height)
    }
    
    
}
