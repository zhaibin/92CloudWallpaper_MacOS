import Foundation

class ApiRequestHandler {
    private var client = URLSession.shared
    private let apiKey = ProcessInfo.processInfo.environment["API_KEY"] ?? ""
    private var functions : Functions!
    private var ts = ""
    private var randomNumberString = ""

    func sendApiRequestAsync(url: URL, body: [String: Any]) async throws -> String {
        self.functions = Functions()
        let ts = functions.generateFormattedTimestamp()
        let randomNumberString = functions.generateRandomNumberString(length: 10)
        let messageID = "\(ts)\(randomNumberString)"
        let timeStamp = ts
        let header: [String: Any] = [
            "messageID": messageID,
            "timeStamp": timeStamp,
            "terminal": 11,
            "version": Constant.softwareVersion as Any,
            "companyId": "10120",
            "countryCode": "+86",
            "did": functions.getDeviceIdentifier()
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

        let jsonString = functions.orderedArrayToJson(sortedBody)
        let sign = functions.generateMd5Signature(messageId: messageID, timestamp: timeStamp, secretKey: apiKey, messageBody: jsonString)
        var mutableHeader = header
        mutableHeader["sign"] = sign
        message["header"] = mutableHeader
        //print(header)
        //print(jsonString)
        let finalData = try JSONSerialization.data(withJSONObject: message, options: [])
        _ = String(data: finalData, encoding: .utf8) ?? ""

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = finalData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        //print("finalData : \(finalData)")
        let (data, _) = try await client.data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }

    
}
