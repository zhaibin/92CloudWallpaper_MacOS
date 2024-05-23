import Cocoa

class UpdateManager {
    static let shared = UpdateManager()
    
    private var progressWindow: NSWindow!
    private var progressBar: NSProgressIndicator!
    private var progressLabel: NSTextField!
    
    private init() {
        setupProgressWindow()
    }
    
    func checkForUpdates() {
        // 设置更新源 URL
        guard let url = URL(string: "https://zhaibin.github.io/92CloudWallpaper_MacOS/updates/update.json") else {
            print("无效的更新 URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                if let error = error {
                    print("获取更新信息失败: \(error)")
                }
                return
            }
            
            do {
                let updateInfo = try JSONDecoder().decode(UpdateInfo.self, from: data)
                self.handleUpdateInfo(updateInfo)
            } catch {
                print("解码更新信息失败: \(error)")
            }
        }
        
        task.resume()
    }
    
    private func handleUpdateInfo(_ updateInfo: UpdateInfo) {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        if updateInfo.version.compare(currentVersion, options: .numeric) == .orderedDescending {
            promptForUpdate(updateInfo)
        }
    }
    
    private func promptForUpdate(_ updateInfo: UpdateInfo) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "发现新版本"
            alert.informativeText = "发现新版本 \(updateInfo.version)。是否下载并安装？"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "下载并安装")
            alert.addButton(withTitle: "稍后")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.downloadAndInstallUpdate(updateInfo)
            }
        }
    }
    
    private func setupProgressWindow() {
        progressWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                                  styleMask: [.titled, .closable],
                                  backing: .buffered, defer: false)
        progressWindow.center()
        progressWindow.title = "下载更新"
        progressWindow.isReleasedWhenClosed = false
        
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        
        progressBar = NSProgressIndicator(frame: NSRect(x: 20, y: 40, width: 260, height: 20))
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 100
        progressBar.doubleValue = 0
        contentView.addSubview(progressBar)
        
        progressLabel = NSTextField(frame: NSRect(x: 20, y: 70, width: 260, height: 20))
        progressLabel.isEditable = false
        progressLabel.isBordered = false
        progressLabel.backgroundColor = .clear
        progressLabel.stringValue = "正在下载..."
        contentView.addSubview(progressLabel)
        
        progressWindow.contentView = contentView
    }
    
    private func showProgressWindow() {
        DispatchQueue.main.async {
            self.progressWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func updateProgress(_ progress: Double) {
        DispatchQueue.main.async {
            self.progressBar.doubleValue = progress * 100
        }
    }
    
    private func downloadAndInstallUpdate(_ updateInfo: UpdateInfo) {
        guard let url = URL(string: updateInfo.url) else {
            print("无效的更新 URL")
            return
        }
        
        showProgressWindow()
        
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            guard let localURL = localURL else {
                if let error = error {
                    print("下载更新失败: \(error)")
                }
                return
            }
            
            self.installUpdate(from: localURL)
        }
        
        task.resume()
        
        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            self.updateProgress(progress.fractionCompleted)
        }
        
        // Hold the observation to avoid being deallocated
        _ = observation
    }
    
    private func installUpdate(from localURL: URL) {
        do {
            let fileManager = FileManager.default
            let destinationURL = fileManager.temporaryDirectory.appendingPathComponent("yourapp.zip")
            
            try fileManager.moveItem(at: localURL, to: destinationURL)
            
            // 模拟安装过程
            print("更新已下载至: \(destinationURL.path)")
            // 这里你可以解压并替换应用
            
            // 提示用户重启应用
            DispatchQueue.main.async {
                self.progressWindow.close()
                let alert = NSAlert()
                alert.messageText = "更新已安装"
                alert.informativeText = "更新已安装。请重启应用以应用更改。"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "立即重启")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    self.restartApplication()
                }
            }
        } catch {
            print("安装更新失败: \(error)")
        }
    }
    
    private func restartApplication() {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["open", Bundle.main.bundlePath]
        task.launch()
        
        NSApp.terminate(nil)
    }
}

struct UpdateInfo: Codable {
    let version: String
    let url: String
    let notes: String
}
