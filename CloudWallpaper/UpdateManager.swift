import Cocoa

class UpdateManager: NSObject, URLSessionDownloadDelegate {
    static let shared = UpdateManager()
    
    private var progressWindow: NSWindow!
    private var progressBar: NSProgressIndicator!
    private var progressLabel: NSTextField!
    private var downloadTask: URLSessionDownloadTask?
    private var observation: NSKeyValueObservation?
    private var functions : Functions!
    
    private override init() {
        super.init()
        setupProgressWindow()
    }
    
    func checkForUpdates() {
        // 设置更新源 URL
        self.functions = Functions()
        guard let url = URL(string: "https://hk-content.oss-cn-hangzhou.aliyuncs.com/92CloudWallpaperVersion/update.txt?\(functions.generateRandomNumberString(length: 10))") else {
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
                print(updateInfo)
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
        } else {
            print(updateInfo,currentVersion)
            noUpdateAvailable()
        }
    }
    
    private func promptForUpdate(_ updateInfo: UpdateInfo) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "发现新版本"
            alert.informativeText = "\(Constant.appName)发现新版本 \(updateInfo.version)。是否下载并安装？"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "下载并安装")
            alert.addButton(withTitle: "稍后")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.downloadAndInstallUpdate(updateInfo)
            }
        }
    }
    
    private func noUpdateAvailable() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "没有发现新版本"
            alert.informativeText = "您已经安装了最新版本。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "确定")
            alert.runModal()
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
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }
    
    private func installUpdate(from localURL: URL) {
        do {
            let fileManager = FileManager.default
            let downloadsDirectory = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let destinationURL = downloadsDirectory.appendingPathComponent("CloudWallpaper.pkg")
            print("destinationURL: \(destinationURL)")
            // 如果目标文件存在，删除它
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.moveItem(at: localURL, to: destinationURL)
            
            if destinationURL.pathExtension == "pkg" {
                // 安装 pkg 文件
                DispatchQueue.main.async {
                    self.progressWindow.close()
                    //NSWorkspace.shared.open(destinationURL)
                    let alert = NSAlert()
                    alert.messageText = "更新包已下载"
                    alert.informativeText = "新的软件已放在 下载 目录下。请安装新的版本。"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "确定")
                    
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(downloadsDirectory)
                    }
                }
            } else {
                // 解压缩 zip 文件
                let unzipDirectory = downloadsDirectory.appendingPathComponent("CloudWallpaper")
                if fileManager.fileExists(atPath: unzipDirectory.path) {
                    try fileManager.removeItem(at: unzipDirectory)
                }
                try fileManager.createDirectory(at: unzipDirectory, withIntermediateDirectories: true, attributes: nil)
                
                let task = Process()
                task.launchPath = "/usr/bin/unzip"
                task.arguments = [destinationURL.path, "-d", unzipDirectory.path]
                task.launch()
                task.waitUntilExit()
                
                // 提示用户重启应用并移动应用到 Downloads 目录
                DispatchQueue.main.async {
                    self.progressWindow.close()
                    let alert = NSAlert()
                    alert.messageText = "更新已下载并解压缩"
                    alert.informativeText = "新的软件已放在 \(unzipDirectory.path) 目录下。请重新打开应用。"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "确定")
                    
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        self.restartApplication(at: unzipDirectory.appendingPathComponent("CloudWallpaper.app"))
                    }
                }
            }
        } catch {
            print("安装更新失败: \(error)")
        }
    }
    
    private func restartApplication(at appURL: URL) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["open", appURL.path]
        task.launch()
        
        NSApp.terminate(nil)
    }
    
    // URLSessionDownloadDelegate 方法
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        installUpdate(from: location)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        updateProgress(progress)
    }
}

struct UpdateInfo: Codable {
    let version: String
    let url: String
    let notes: String
}
