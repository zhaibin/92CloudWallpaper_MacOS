import Foundation
import CryptoKit

class ApiRequestHandler {
    private var client = URLSession.shared
    private let apiKey = ProcessInfo.processInfo.environment["API_KEY"] ?? ""
    private var ts: String { return generateFormattedTimestamp() }
    var userId = "0"

    func sendApiRequestAsync(url: URL, body: [String: Any]) async throws -> String {
        let messageID = "\(ts)0000000001"
        let timeStamp = ts
        let header: [String: Any] = [
            "messageID": messageID,
            "timeStamp": timeStamp,
            "terminal": 1,
            "version": "0.1",
            "companyId": "10120",
            "countryCode": "+86"
        ]
        var message = [
            "header": header,
            "body": body
        ]
        
        
        
        //print("body : \(body)")
        // 将字典转换为一个由元组组成的数组，并按键排序
        let sortedKeys = body.keys.sorted()
        
        // 创建一个有序数组来存储排序后的键值对
        var sortedBody: [(key: String, value: Any)] = []
        for key in sortedKeys {
            sortedBody.append((key: key, value: body[key]!))
        }
        
        
        
        //print("sortedBody : \(sortedBody)")
        
        
        // 使用 JSONSerialization 来序列化有序字典
        //do {
        //let jsonData = try JSONSerialization.data(withJSONObject: sortedBody, options: [])
            // jsonData 现在是一个按照 key 排序后的 JSON 数据
        //let jsonString = String(data: jsonData, encoding: .utf8)!
        let jsonString = orderedArrayToJson(sortedBody)
        
        //print(jsonString)
        
        
        let sign = generateMd5Signature(messageId: messageID, timestamp: timeStamp, secretKey: apiKey, messageBody: jsonString)
        var mutableHeader = header
        mutableHeader["sign"] = sign
        message["header"] = mutableHeader

        let finalData = try JSONSerialization.data(withJSONObject: message, options: [])
        _ = String(data: finalData, encoding: .utf8) ?? ""

        //print("req : \(jsonNew)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = finalData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, _) = try await client.data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func generateFormattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: Date())
    }

    private func generateMd5Signature(messageId: String, timestamp: String, secretKey: String, messageBody: String) -> String {
        let rawString = "\(messageId)\(timestamp)\(secretKey)\(messageBody)"
        let digest = Insecure.MD5.hash(data: rawString.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    private func orderedArrayToJson(_ orderedArray: [(key: String, value: Any)]) -> String {
        var jsonString = "{"
        
        for (index, (key, value)) in orderedArray.enumerated() {
            // 处理 key
            jsonString += "\"\(key)\":"
            
            // 处理 value，根据类型决定是否加引号
            if let stringValue = value as? String {
                jsonString += "\"\(stringValue)\""
            } else if let boolValue = value as? Bool {
                jsonString += boolValue ? "true" : "false"
            } else {
                jsonString += "\(value)"
            }
            
            // 如果不是最后一个元素，添加逗号
            if index < orderedArray.count - 1 {
                jsonString += ","
            }
        }
        
        jsonString += "}"
        return jsonString
    }
}

struct GlobalData {
    static var userId = UserDefaults.standard.integer(forKey: "UserId")
    static var pageIndex = 1
    static var imageIndex = 0
    static var loginFlag = 0
}
