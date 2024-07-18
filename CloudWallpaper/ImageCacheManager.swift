import Foundation

struct WallpaperItem: Codable, Equatable, Hashable {
    let createtime: TimeInterval
    let authorName: String
    let groupId: Int
    let shootAddr: String?
    let authorUrl: String
    let albumId: Int
    let shootTime: String?
    let addr: String
    let authorId: Int
    let url: String
    let content: String
    var localPath: URL?

    static func == (lhs: WallpaperItem, rhs: WallpaperItem) -> Bool {
        return lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

struct ApiResponse: Codable {
    struct Header: Codable {
        let messageID: String
        let resCode: Int
        let resMsg: String
        let timeStamp: String
        let transactionType: String?
    }
    
    struct Body: Codable {
        let list: [WallpaperItem]
        let status: Int
    }
    
    let header: Header
    let body: Body
}

enum FetchError: Error {
    case downloadFailed
    case decodingFailed
    case apiRequestFailed(Error)
}

class ImageCacheManager {
    
    static let shared = ImageCacheManager()
    private var userId: Int?
    private var cacheDir: URL?
    private var cacheFile: URL?
    private var allItems: Set<WallpaperItem> = []
    private var fetchedItems: [WallpaperItem] = []
    private var isFetching = false
    private let queue = DispatchQueue(label: "com.imageCacheManager.queue", attributes: .concurrent)
    private let group = DispatchGroup()
    
    private init() {}
    
    func initialize(userId: Int) {
        self.userId = userId
        self.cacheDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Wallpapers_\(userId)")
        print("UserId:\(userId) , cacheDir:\(String(describing: self.cacheDir))")
        self.cacheFile = cacheDir?.appendingPathComponent("cachedData.json")
        createCacheDirectory()
        loadCachedData()
    }
    private func createCacheDirectory() {
        guard let cacheDir = self.cacheDir else { return }
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            do {
                try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
                print("Cache directory created at \(cacheDir.path)")
            } catch {
                print("Failed to create cache directory: \(error.localizedDescription)")
            }
        }
    }
    func fetchAllPages(apiHandler: ApiRequestHandler, screenHeight: Int, screenWidth: Int, completion: @escaping (Result<Void, FetchError>) -> Void) {
        queue.async(flags: .barrier) {
            guard !self.isFetching else { return }
            self.isFetching = true
            self.fetchedItems = []
            self.fetchPages(apiHandler: apiHandler, screenHeight: screenHeight, screenWidth: screenWidth, pageIndex: 1, completion: completion)
        }
    }

    private func fetchPages(apiHandler: ApiRequestHandler, screenHeight: Int, screenWidth: Int, pageIndex: Int, completion: @escaping (Result<Void, FetchError>) -> Void) {
        guard let userId = self.userId else { return }
        let body: [String: Any] = [
            "userId": userId,
            "height": screenHeight,
            "width": screenWidth,
            "pageSize": GlobalData.pageSize,
            "pageIndex": pageIndex
        ]

        Task {
            do {
                let jsonString = try await apiHandler.sendApiRequestAsync(url: URL(string: "https://cnapi.levect.com/v1/photoFrame/imageList")!, body: body)
                if let data = jsonString.data(using: .utf8),
                   let apiResponse = try? JSONDecoder().decode(ApiResponse.self, from: data) {
                    self.fetchedItems.append(contentsOf: apiResponse.body.list)
                    if apiResponse.body.list.count == GlobalData.pageSize {
                        self.fetchPages(apiHandler: apiHandler, screenHeight: screenHeight, screenWidth: screenWidth, pageIndex: pageIndex + 1, completion: completion)
                    } else {
                        self.isFetching = false
                        self.updateItems(with: self.fetchedItems)
                        completion(.success(()))
                    }
                } else {
                    print("Failed to decode response.")
                    self.isFetching = false
                    completion(.failure(.decodingFailed))
                }
            } catch {
                print("API request failed: \(error)")
                self.isFetching = false
                completion(.failure(.apiRequestFailed(error)))
            }
        }
    }

    func fetchOnce(apiHandler: ApiRequestHandler, screenHeight: Int, screenWidth: Int, completion: @escaping (Result<Void, FetchError>) -> Void) {
        queue.async(flags: .barrier) {
            guard !self.isFetching else { return }
            self.isFetching = true
            self.fetchedItems = []
            self.fetchPage(apiHandler: apiHandler, screenHeight: screenHeight, screenWidth: screenWidth, pageIndex: 1) { result in
                self.isFetching = false
                completion(result)
            }
        }
    }
    
    private func fetchPage(apiHandler: ApiRequestHandler, screenHeight: Int, screenWidth: Int, pageIndex: Int, completion: @escaping (Result<Void, FetchError>) -> Void) {
        guard let userId = self.userId else { return }
        let body: [String: Any] = [
            "userId": userId,
            "height": screenHeight,
            "width": screenWidth,
            "pageSize": GlobalData.pageSize,
            "pageIndex": pageIndex
        ]
        
        Task {
            do {
                let jsonString = try await apiHandler.sendApiRequestAsync(url: URL(string: "https://cnapi.levect.com/v1/photoFrame/imageList")!, body: body)
                if let data = jsonString.data(using: .utf8),
                   let apiResponse = try? JSONDecoder().decode(ApiResponse.self, from: data) {
                    self.fetchedItems = apiResponse.body.list
                    self.updateItems(with: self.fetchedItems)
                    completion(.success(()))
                } else {
                    print("Failed to decode response.")
                    completion(.failure(.decodingFailed))
                }
            } catch {
                print("API request failed: \(error)")
                completion(.failure(.apiRequestFailed(error)))
            }
        }
    }
    
    func cacheImages(completion: @escaping (Result<Void, FetchError>) -> Void) {
        let dispatchGroup = DispatchGroup()
        var downloadFailed = false
        var updatedItems: [WallpaperItem] = []

        for item in fetchedItems {
            dispatchGroup.enter()
            cacheImage(for: item, retryCount: 3) { success, updatedItem in
                if !success {
                    downloadFailed = true
                }
                if let updatedItem = updatedItem {
                    updatedItems.append(updatedItem)
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.replaceItemsAfterCaching(updatedItems)
            if downloadFailed {
                completion(.failure(.downloadFailed))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func getCachedData() -> [WallpaperItem] {
        return queue.sync {
            return Array(allItems)
        }
    }
    
    func getAvailableCachedData() -> [WallpaperItem] {
        return queue.sync {
            return allItems.filter { $0.localPath != nil }
        }
    }
    
    private func loadCachedData() {
        guard let cacheFile = self.cacheFile else { return }
        queue.sync(flags: .barrier) {
            if let cachedData = try? Data(contentsOf: cacheFile),
               let cachedItems = try? JSONDecoder().decode([WallpaperItem].self, from: cachedData) {
                allItems = Set(cachedItems)
                for item in allItems {
                    if let url = URL(string: item.url) {
                        let cacheFile = self.cacheDir!.appendingPathComponent(url.lastPathComponent)
                        if FileManager.default.fileExists(atPath: cacheFile.path) {
                            var updatedItem = item
                            updatedItem.localPath = cacheFile
                            allItems.update(with: updatedItem)
                        }
                    }
                }
            }
        }
    }
    
    private func updateItems(with newItems: [WallpaperItem]) {
        queue.async(flags: .barrier) {
            print("Updating items with \(newItems.count) new items")
            self.allItems = Set(newItems)
            self.updateCachedData()
        }
    }
    
    private func replaceItemsAfterCaching(_ updatedItems: [WallpaperItem]) {
        queue.async(flags: .barrier) {
            print("Replacing items with \(updatedItems.count) updated items after caching")
            for updatedItem in updatedItems {
                self.allItems.update(with: updatedItem)
            }
            self.updateCachedData()
        }
    }
    
    private func updateCachedData() {
        guard let cacheFile = self.cacheFile else { return }
        queue.async(flags: .barrier) {
            if let data = try? JSONEncoder().encode(Array(self.allItems)) {
                print("Updating cached data with \(self.allItems.count) items")
                try? data.write(to: cacheFile)
            }
        }
    }
    
    private func cacheImage(for item: WallpaperItem, retryCount: Int, completion: @escaping (Bool, WallpaperItem?) -> Void) {
        guard let url = URL(string: item.url), let cacheDir = self.cacheDir else {
            completion(false, nil)
            return
        }
        let cacheFile = cacheDir.appendingPathComponent(url.lastPathComponent)
        var itemWithLocalPath = item
        itemWithLocalPath.localPath = cacheFile
        
        if FileManager.default.fileExists(atPath: cacheFile.path) {
            completion(true, itemWithLocalPath)
        } else {
            downloadImage(url: url, retryCount: retryCount) { data in
                if let data = data {
                    try? data.write(to: cacheFile)
                    self.queue.async(flags: .barrier) {
                        self.allItems.update(with: itemWithLocalPath)
                        self.updateCachedData()
                    }
                    completion(true, itemWithLocalPath)
                } else {
                    completion(false, nil)
                }
            }
        }
    }
    
    private func downloadImage(url: URL, retryCount: Int, completion: @escaping (Data?) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, error == nil {
                completion(data)
            } else if retryCount > 0 {
                print("Retrying download... \(retryCount) attempts left")
                self.downloadImage(url: url, retryCount: retryCount - 1, completion: completion)
            } else {
                print("Failed to download image: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
            }
        }
        task.resume()
    }
}
