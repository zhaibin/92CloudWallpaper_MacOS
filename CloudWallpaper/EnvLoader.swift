import Foundation

class EnvLoader {
    static func loadEnv() {
        guard let filePath = Bundle.main.path(forResource: ".env", ofType: nil) else {
            print(".env file not found")
            return
        }

        do {
            let contents = try String(contentsOfFile: filePath)
            let lines = contents.split { $0.isNewline }
            
            for line in lines {
                let parts = line.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                    setenv(key, value, 1)
                }
            }
        } catch {
            print("Error reading .env file: \(error)")
        }
    }
}
