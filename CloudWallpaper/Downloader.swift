import Foundation

class Downloader {
    private var userId: Int
    private var filePaths: [URL] = []
    private var allDownloadedURLs: [Int: Set<URL>] = [:] // 按用户ID存储下载过的URLs
    private var downloadProgress: [URL: Double] = [:]
    private let fileAccessQueue = DispatchQueue(label: "com.downloader.fileAccess")
    private let cacheLifespan: TimeInterval = 604800 // 7 days in seconds

    init(userId: Int) {
        self.userId = userId
        allDownloadedURLs[userId] = Set<URL>() // 初始化当前用户的URL集合
    }
    
    // 更新当前用户的下载过的URLs
    func updateDownloadedURLs(with newURLs: [URL]) {
        fileAccessQueue.sync {
            let userURLs = allDownloadedURLs[userId, default: Set<URL>()]
            allDownloadedURLs[userId] = userURLs.union(newURLs)
        }
    }

    // 只处理新URL的添加和下载，不处理清理逻辑
    func updateCache(with newURLs: [URL], completion: @escaping ([URL]) -> Void) {
        fileAccessQueue.async {
            // 更新当前用户的下载过的URLs
            let userURLs = self.allDownloadedURLs[self.userId, default: Set<URL>()]
            self.allDownloadedURLs[self.userId] = userURLs.union(newURLs.filter { !userURLs.contains($0) })
            
            // 提取 filePaths 中的文件名
            let filePathsFileNames = Set(self.filePaths.map { $0.lastPathComponent })
            
            // 筛选出尚未下载的新URLs
            let urlsToDownload = newURLs.filter { !filePathsFileNames.contains($0.lastPathComponent) }
            
            if !urlsToDownload.isEmpty {
                self.downloadFiles(from: urlsToDownload) { downloadedURLs in
                    DispatchQueue.main.async {
                        completion(downloadedURLs)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }

    func cleanupCacheAgainstAllURLs(keepingURLs: [URL], completion: @escaping ([URL]) -> Void) {
        fileAccessQueue.async {
            let keepingFileNames = Set(keepingURLs.map { $0.lastPathComponent })
            print("keepingFileNames \(keepingFileNames)")
            // 提取 filePaths 中的文件名
            let cachedFileNames = Set(self.filePaths.map { $0.lastPathComponent })
            print("cachedFileNames \(cachedFileNames)")
            // 找出需要删除的文件名
            let fileNamesToDelete = cachedFileNames.subtracting(keepingFileNames)
            print("fileNamesToDelete \(fileNamesToDelete)")
            // 删除不再需要的文件
            self.filePaths = self.filePaths.filter { url in
                if fileNamesToDelete.contains(url.lastPathComponent) {
                    try? FileManager.default.removeItem(at: url)
                    return false
                }
                return true
            }
            
            // 清理过期的文件
            self.filePaths = self.filePaths.filter { url in
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let modificationDate = attributes[.modificationDate] as? Date,
                   Date().timeIntervalSince(modificationDate) <= self.cacheLifespan {
                    return true
                } else {
                    try? FileManager.default.removeItem(at: url)
                    return false
                }
            }
            
            // 返回最新的 cache 文件路径数组
            DispatchQueue.main.async {
                completion(self.filePaths)
            }
        }
    }


    func downloadFiles(from urls: [URL], completion: @escaping ([URL]) -> Void) {
        let dispatchGroup = DispatchGroup()
        let backgroundQueue = DispatchQueue(label: "com.downloader.backgroundQueue")

        var downloadedURLs: [URL] = []

        urls.forEach { url in
            dispatchGroup.enter()
            backgroundQueue.async {
                self.downloadFile(from: url, retryCount: 3) { [weak self] localUrl, progress in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        if let localUrl = localUrl, progress == 1.0 {
                            self.fileAccessQueue.async {
                                self.filePaths.append(localUrl)
                                downloadedURLs.append(localUrl)
                                self.downloadProgress[url] = progress
                                dispatchGroup.leave()
                            }
                        } else {
                            self.fileAccessQueue.async {
                                self.downloadProgress[url] = progress
                                if progress == 1.0 {
                                    dispatchGroup.leave()
                                }
                            }
                        }
                    }
                }
            }
        }

        dispatchGroup.notify(queue: DispatchQueue.main) {
            self.fileAccessQueue.async {
                completion(downloadedURLs)
            }
        }
    }

    private func downloadFile(from url: URL, retryCount: Int, completion: @escaping (URL?, Double) -> Void) {
        let fileName = url.lastPathComponent
        let folderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Wallpapers_\(userId)")
        let fileURL = folderURL.appendingPathComponent(fileName)
        
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        // Check if file already exists
        if FileManager.default.fileExists(atPath: fileURL.path) {
            completion(fileURL, 1.0)
            return
        }

        // Download file
        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let tempURL = tempURL, error == nil {
                do {
                    try FileManager.default.moveItem(at: tempURL, to: fileURL)
                    completion(fileURL, 1.0)
                } catch {
                    completion(nil, 0)
                }
            } else if retryCount > 0 {
                self.downloadFile(from: url, retryCount: retryCount - 1, completion: completion)
            } else {
                completion(nil, 0)
            }
        }
        task.resume()
    }
}
