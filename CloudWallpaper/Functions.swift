//
//  Functions.swift
//  CloudWallpaper
//
//  Created by 翟斌 on 2024/6/25.
//

import Foundation
import CryptoKit
import Cocoa

class Functions {
    func generateFormattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: Date())
    }

    func generateMd5Signature(messageId: String, timestamp: String, secretKey: String, messageBody: String) -> String {
        let rawString = "\(messageId)\(timestamp)\(secretKey)\(messageBody)"
        let digest = Insecure.MD5.hash(data: rawString.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    func orderedArrayToJson(_ orderedArray: [(key: String, value: Any)]) -> String {
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

    func getDeviceIdentifier() -> String {
        let key = "deviceIdentifier"
        if let deviceIdentifier = UserDefaults.standard.string(forKey: key) {
            return deviceIdentifier
        } else {
            let deviceIdentifier = UUID().uuidString
            UserDefaults.standard.set(deviceIdentifier, forKey: key)
            return deviceIdentifier
        }
    }
    func generateRandomNumberString(length: Int) -> String {
        var result = ""
        for _ in 0..<length {
            let randomDigit = Int.random(in: 0...9)
            result.append(String(randomDigit))
        }
        return result
    }
    
    func getScreenSize() -> (width: Int, height: Int)? {
        guard let mainScreen = NSScreen.main else {
            print("Unable to access the main screen")
            return (1440,900)
        }

        let screenFrame = mainScreen.frame
        let width = Int(screenFrame.width)
        let height = Int(screenFrame.height)
        return (width, height)
    }
}
