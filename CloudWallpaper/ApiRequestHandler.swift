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
            "countryCode": "+86",
            "did": getDeviceIdentifier()
        ]
        var message = [
            "header": header,
            "body": body
        ]

        let sortedKeys = body.keys.sorted()
        var sortedBody: [(key: String, value: Any)] = []
        for key in sortedKeys {
            sortedBody.append((key: key, value: body[key]!))
        }

        let jsonString = orderedArrayToJson(sortedBody)
        let sign = generateMd5Signature(messageId: messageID, timestamp: timeStamp, secretKey: apiKey, messageBody: jsonString)
        var mutableHeader = header
        mutableHeader["sign"] = sign
        message["header"] = mutableHeader
        //print(header)
        let finalData = try JSONSerialization.data(withJSONObject: message, options: [])
        _ = String(data: finalData, encoding: .utf8) ?? ""

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
            jsonString += "\"\(key)\":"
            if let stringValue = value as? String {
                jsonString += "\"\(stringValue)\""
            } else if let boolValue = value as? Bool {
                jsonString += boolValue ? "true" : "false"
            } else {
                jsonString += "\(value)"
            }
            if index < orderedArray.count - 1 {
                jsonString += ","
            }
        }
        jsonString += "}"
        return jsonString
    }

    private func getDeviceIdentifier() -> String {
        let key = "deviceIdentifier"
        if let deviceIdentifier = UserDefaults.standard.string(forKey: key) {
            return deviceIdentifier
        } else {
            let deviceIdentifier = UUID().uuidString
            UserDefaults.standard.set(deviceIdentifier, forKey: key)
            return deviceIdentifier
        }
    }
}

struct GlobalData {
    static var userId = UserDefaults.standard.integer(forKey: "UserId")
    static var pageIndex = 1
    static var imageIndex = 0
    static var loginFlag = 0
}
