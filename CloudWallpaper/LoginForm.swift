import SwiftUI

struct LoginForm: View {
    var onLoginStatusChanged: (Bool) -> Void
    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    @State private var countdown: Int = 60
    @State private var timerActive = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Text("手机号")
                    .frame(width: 50, alignment: .leading)
                TextField("输入手机号", text: $phoneNumber)
                    //.keyboardType(.numberPad)  // 应用数字键盘
                    .onReceive(phoneNumber.publisher.collect()) {
                        self.phoneNumber = String($0.prefix(11))
                    }
            }
            .padding(.horizontal)
            
            HStack {
                Text("验证码")
                    .frame(width: 50, alignment: .leading)
                TextField("输入验证码", text: $verificationCode)
                    //.keyboardType(.numberPad)  // 应用数字键盘
                    .onReceive(verificationCode.publisher.collect()) {
                        self.verificationCode = String($0.prefix(4))
                    }
                
                Button(action: {
                    getVerificationCode()
                }) {
                    Text(timerActive ? "\(countdown)秒" : "获取验证码")
                }
                .disabled(timerActive || !isValidPhoneNumber(phoneNumber))
            }
            .padding(.horizontal)
            
            Button("登录") {
                login()
            }
            .padding()
            .disabled(!canAttemptLogin())
            HStack {
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .padding() // 增加整体视图的边距
        .onAppear(perform: setupTimer)
    }
    
    private func setupTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if self.timerActive && self.countdown > 0 {
                self.countdown -= 1
                if self.countdown == 0 {
                    self.timerActive = false
                    self.countdown = 60
                    timer.invalidate()
                }
            }
        }
    }
    
    private func getVerificationCode() {
        let apiHandler = ApiRequestHandler()
        let body = [
            "flag": 4,
            "phone": "+86\(phoneNumber)"
        ] as [String : Any]
        
        Task {
            _ = try await apiHandler.sendApiRequestAsync(url: URL(string: "https://cnapi.levect.com/social/sms")!, body: body)
            //print("验证码返回 \n\(response)")
            self.errorMessage = "请输入短信验证码"
            self.timerActive = true
            self.countdown = 60
        }
    }
    
    private func login() {
        guard isValidPhoneNumber(phoneNumber) && isValidVerificationCode(verificationCode) else {
            self.errorMessage = "请检查手机号或验证码"
            return
        }
        let apiHandler = ApiRequestHandler()
        let body = [
            "flag": 1,
            "loginType": 4,
            "name": phoneNumber,
            "phoneCode": "+86",
            "userType": 0,
            "valiCode": verificationCode,
            "wechatId": phoneNumber
        ] as [String : Any]
        
        Task {
            let response = try await apiHandler.sendApiRequestAsync(url: URL(string: "https://cnapi.levect.com/social/loginV2")!, body: body)

            if let data = response.data(using: .utf8) {
                
                // 创建一个适用的结构体来匹配 JSON 结构
                struct LoginResponse: Codable {
                    struct Header: Codable {
                        let messageID: String
                        let resCode: Int
                        let resMsg: String
                        let timeStamp: String
                        let transactionType: String
                    }
                    
                    struct Body: Codable {
                        let userId: Int
                        let status: Int
                    }
                    
                    let header: Header
                    let body: Body
                }
                
                do{
                    let json = try JSONDecoder().decode(LoginResponse.self, from: data)
                    
                    if json.body.status == 0 {
                        UserDefaults.standard.set(json.body.userId, forKey: "UserId")
                        errorMessage = ""
                        onLoginStatusChanged(true)
                        //self.isShowing = false  // 关闭登录界面
                    } else {
                        self.errorMessage = "Login failed. Check your credentials."
                    }
                }catch{
                    self.errorMessage = "登录失败，请检查手机号与验证码。"
                }
               
            }
            
        }
    }
    private func checkLoginStatus() {
        if let _ = UserDefaults.standard.object(forKey: "UserId") as? Int {
            //self.isUserLoggedIn = true
            //self.isShowing = false
        }
    }
    private func isValidPhoneNumber(_ number: String) -> Bool {
        let phoneRegex = "^1[3456789]\\d{9}$"
        return NSPredicate(format: "SELF MATCHES %@", phoneRegex).evaluate(with: number)
    }
    
    private func isValidVerificationCode(_ code: String) -> Bool {
        return code.count == 4 && code.allSatisfy({ $0.isNumber })
    }
    
    private func canAttemptLogin() -> Bool {
        isValidPhoneNumber(phoneNumber) && isValidVerificationCode(verificationCode)
    }
}


