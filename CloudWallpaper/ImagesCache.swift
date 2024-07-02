import Foundation

class ImagesCache {
    var wallpaperURLs: [URL] = []
    var syncWallpaperURLs: [URL] = []
    var imageInfos: [URL: WallpaperImageInfo] = [:]
    var pageIndex = 1
    var downloader: Downloader
    var userId: Int
    var screenWidth: Int = 1440
    var screenHeight: Int = 900
    
    init(userId: Int) {
        self.userId = userId
        self.downloader = Downloader(userId: userId)
    }
    
    func refreshWallpaperList(completion: @escaping ([URL]) -> Void) {
        let functions = Functions()
        let screenSize = functions.getScreenSize()
        screenWidth = screenSize?.width ?? screenWidth
        screenHeight = screenSize?.height ?? screenHeight
        let apiHandler = ApiRequestHandler()
        let body: [String: Any] = [
            "userId": userId,
            "height": screenHeight,
            "width": screenWidth,
            "pageSize": 4,
            "pageIndex": pageIndex
        ]
        Task {
            do {
                let wallpaperList = try await apiHandler.sendApiRequestAsync(url: URL(string: "https://cnapi.levect.com/v1/photoFrame/imageList")!, body: body)
                print(wallpaperList)
                let newImageInfos = parseWallpaperList(jsonString: wallpaperList)
                if newImageInfos.isEmpty {
                    pageIndex = 1
                    downloader.cleanupCacheAgainstAllURLs(keepingURLs: syncWallpaperURLs) { updatedCacheFilePaths in
                        self.wallpaperURLs = updatedCacheFilePaths
                        completion(self.wallpaperURLs)
                    }
                    syncWallpaperURLs = []
                } else {
                    let newURLs = Array(newImageInfos.keys)
                    syncWallpaperURLs.append(contentsOf: newURLs)
                    downloader.updateCache(with: newURLs) { [weak self] cachedURLs in
                        guard let self = self else { return }
                        self.wallpaperURLs.append(contentsOf: cachedURLs)
                        self.imageInfos.merge(newImageInfos) { (_, new) in new }
                        self.imageInfos = self.imageInfos.sorted(by: { $0.value.createTime ?? Date.distantPast > $1.value.createTime ?? Date.distantPast }).reduce(into: [URL: WallpaperImageInfo]()) { result, item in
                            result[item.key] = item.value
                        }
                        self.pageIndex += 1
                        completion(self.wallpaperURLs)
                    }
                }
            } catch {
                print("Error refreshing wallpaper list: \(error)")
                completion([])
            }
        }
    }
    
    private func parseWallpaperList(jsonString: String) -> [URL: WallpaperImageInfo] {
        guard let data = jsonString.data(using: .utf8) else {
            print("Error: Cannot create Data from jsonString")
            return [:]
        }
        var imageInfos: [URL: WallpaperImageInfo] = [:]
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let body = json["body"] as? [String: Any],
               let list = body["list"] as? [[String: Any]] {
                for item in list {
                    if let urlString = item["url"] as? String, let url = URL(string: urlString) {
                        let createTime: Date? = {
                            if let timestamp = item["createTime"] as? TimeInterval {
                                return Date(timeIntervalSince1970: timestamp)
                            }
                            return nil
                        }()
                        let imageInfo = WallpaperImageInfo(
                            url: url,
                            createTime: createTime,
                            authorName: item["authorName"] as? String ?? "",
                            groupId: item["groupId"] as? Int,
                            shootAddr: item["shootAddr"] as? String ?? "",
                            authorUrl: item["authorUrl"] as? String ?? "",
                            albumId: item["albumId"] as? Int,
                            shootTime: item["shootTime"] as? String ?? "",
                            addr: item["addr"] as? String ?? "",
                            authorId: item["authorId"] as? Int,
                            content: item["content"] as? String ?? ""
                        )
                        imageInfos[url] = imageInfo
                    } else {
                        print("Invalid URL or missing 'url' key: \(item)")
                    }
                }
            } else {
                print("JSON does not contain a dictionary at the root level")
            }
        } catch {
            print("Error parsing JSON: \(error)")
        }
        return imageInfos
    }
}

class WallpaperImageInfo {
    let url: URL
    let createTime: Date?
    let authorName: String
    let groupId: Int?
    let shootAddr: String
    let authorUrl: String
    let albumId: Int?
    let shootTime: String
    let addr: String
    let authorId: Int?
    let content: String
    
    init(url: URL, createTime: Date?, authorName: String, groupId: Int?, shootAddr: String, authorUrl: String, albumId: Int?, shootTime: String, addr: String, authorId: Int?, content: String) {
        self.url = url
        self.createTime = createTime
        self.authorName = authorName
        self.groupId = groupId
        self.shootAddr = shootAddr
        self.authorUrl = authorUrl
        self.albumId = albumId
        self.shootTime = shootTime
        self.addr = addr
        self.authorId = authorId
        self.content = content
    }
}
