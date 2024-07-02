import Foundation

class Stats {
    private var functions : Functions!
    func report(groupId: Int, albumId: Int, authorId: Int, behavior: String) async throws {
        var urlComponents = URLComponents(string: StatsPara.url)!
        let functions = Functions()
        urlComponents.queryItems = [
            URLQueryItem(name: "APIVersion", value: "0.6.0"),
            URLQueryItem(name: "uid", value: String(GlobalData.userId)),
            URLQueryItem(name: "did", value: functions.getDeviceIdentifier()),
            URLQueryItem(name: "groupid", value: String(groupId)),
            URLQueryItem(name: "albumid", value: String(albumId)),
            URLQueryItem(name: "authorid", value: String(authorId)),
            URLQueryItem(name: "bhv", value: behavior),
            URLQueryItem(name: "appver", value: Constant.softwareVersion as? String),
            URLQueryItem(name: "dc", value: StatsPara.distributeChannel),
            URLQueryItem(name: "ts", value: String(getUnixTimeStamp())),
        ]
        
        let systemParameters = getStatsSystemParameters()
        urlComponents.queryItems?.append(contentsOf: systemParameters.map { URLQueryItem(name: $0.key, value: $0.value) })
        
        guard let url = urlComponents.url else { return }
        
        do {
            print("stats url: \(url)")
            let (_, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
        } catch {
            print("Request error: \(error)")
        }
    }
    
    func getStatsSystemParameters() -> [String: String] {
        var parameters = [String: String]()
        
        // 获取操作系统版本
        if let osName = getSystemVersion() {
            parameters["platform"] = "macOS"
            parameters["os"] = osName
        }
        
        // 获取系统内存
        if let memory = getSystemMemory() {
            parameters["memory"] = memory
        }
        
        return parameters
    }
    
    func getSystemVersion() -> String? {
        var size = 0
        sysctlbyname("kern.osproductversion", nil, &size, nil, 0)
        var version = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osproductversion", &version, &size, nil, 0)
        return String(cString: version)
    }
    
    func getSystemMemory() -> String? {
        var size = 0
        sysctlbyname("hw.memsize", nil, &size, nil, 0)
        var memorySize: Int64 = 0
        sysctlbyname("hw.memsize", &memorySize, &size, nil, 0)
        
        let gigabytes = Double(memorySize) / (1024 * 1024 * 1024)
        let roundedGigabytes = Int((gigabytes / 8).rounded(.toNearestOrAwayFromZero)) * 8
        return "\(roundedGigabytes)GB"
    }
    
    func getUnixTimeStamp() -> Int {
        return Int(Date().timeIntervalSince1970)
    }
}
// 示例调用
//let stats = Stats()
//let imageInfo = ImageInfo(GroupId: "group123", AlbumId: "album123", AuthorId: "author123")
//Task {
//    try await stats.report(imageInfo: imageInfo, behavior: "view")
//}
