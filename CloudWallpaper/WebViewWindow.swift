import Cocoa
import WebKit

class WebViewWindow: NSWindowController {
    var webView: WKWebView!

    override init(window: NSWindow?) {
        super.init(window: window)
        createWebView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        createWebView()
    }

    private func createWebView() {
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let contentController = webViewConfiguration.userContentController

        // 添加 "consoleLog" 消息处理
        addScriptMessageHandler(contentController: contentController, name: "consoleLog")

        // 添加 "receiveUserData" 消息处理
        addScriptMessageHandler(contentController: contentController, name: "receiveUserData")

        webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self

        // 直接创建NSViewController实例，而不是从nib文件加载
        let viewController = NSViewController()
        viewController.view = webView

        let window = NSWindow(contentViewController: viewController)
        window.setContentSize(NSSize(width: 1280, height: 720))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.title = Constant.appName
        window.isReleasedWhenClosed = false  // 确保窗口关闭时不会释放

        // 窗口居中显示
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let xPos = (screenRect.width - window.frame.width) / 2
            let yPos = ((screenRect.height - window.frame.height) / 2) + screenRect.origin.y
            window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
        }

        self.window = window
        self.window?.delegate = self  // 设置窗口委托

        let userAgentSuffix = " (92CloudWallpaper_macOS)"
        webView.customUserAgent = (WKWebView().value(forKey: "userAgent") as? String ?? "") + userAgentSuffix
    }

    private func addScriptMessageHandler(contentController: WKUserContentController, name: String) {
        // 移除之前的处理器（如果存在）
        contentController.removeScriptMessageHandler(forName: name)
        // 添加新的处理器
        contentController.add(self, name: name)
    }



    func load(url: URL) {
        guard url.absoluteString != "" else {
            print("Error: URL is empty or invalid")
            return
        }
        webView.load(URLRequest(url: url))
        showWindowAndActivate()
    }

    func showWindowAndActivate() {
        showWindow(self)
        //NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func injectJavaScript() {
        let scriptSource = """
        document.addEventListener('contextmenu', event => event.preventDefault());
        document.addEventListener('selectstart', event => event.preventDefault());
        document.addEventListener('dragstart', event => event.preventDefault());
        document.addEventListener('keydown', event => {
            if (event.keyCode === 123) {  // F12
                event.preventDefault();
            }
            if (event.ctrlKey && event.shiftKey && event.keyCode === 73) {  // Ctrl+Shift+I
                event.preventDefault();
            }
        });

        (function() {
            var oldLog = console.log;
            console.log = function(message) {
                window.webkit.messageHandlers.consoleLog.postMessage({type: 'log', message: message});
                oldLog.apply(console, arguments);
            };

            var oldWarn = console.warn;
            console.warn = function(message) {
                window.webkit.messageHandlers.consoleLog.postMessage({type: 'warn', message: message});
                oldWarn.apply(console, arguments);
            };

            var oldError = console.error;
            console.error = function(message) {
                window.webkit.messageHandlers.consoleLog.postMessage({type: 'error', message: message});
                oldError.apply(console, arguments);
            };
        })();
        """
        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(script)
        
        webView.evaluateJavaScript(scriptSource) { (result, error) in
            if let error = error {
                self.showErrorDialog(message: "JavaScript 注入失败: \(error.localizedDescription)")
            } else {
                print("JavaScript 注入成功")
            }
        }
    }

    private func showErrorDialog(message: String) {
        let alert = NSAlert()
        alert.messageText = "错误"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}

extension WebViewWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
}

extension WebViewWindow: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        injectJavaScript()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Failed to navigate: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("Failed to start navigation: \(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        print("Web content process terminated")
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let dialog = NSOpenPanel()
        dialog.title = NSLocalizedString("Choose an image", comment: "Open panel title for image selection")
        dialog.allowedFileTypes = ["png", "jpg", "jpeg", "bmp", "webp"]
        dialog.allowsMultipleSelection = false
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        DispatchQueue.main.async {
            if dialog.runModal() == .OK {
                completionHandler(dialog.urls)
            } else {
                completionHandler(nil)
            }
        }
    }
}

extension WebViewWindow: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "consoleLog" {
            if let body = message.body as? [String: Any],
               let type = body["type"] as? String,
               let logMessage = body["message"] as? String {
                handleConsoleLog(type: type, message: logMessage)
            }
        } else if message.name == "receiveUserData" {
            if let body = message.body as? [String: Any],
               let type = body["type"] as? String {
                if type == "login" || type == "logout" {
                    if let userIdValue = body["UserId"],
                       let token = body["Token"] as? String {
                        if let userId = userIdValue as? Int {
                            handleUserData(userId: userId, token: token)
                        } else if let userIdString = userIdValue as? String,
                                  let userId = Int(userIdString) {
                            handleUserData(userId: userId, token: token)
                        }
                    }
                } else if type == "imagesAsync" {
                    NotificationCenter.default.post(name: .imagesAsync, object: nil)
                }
            }
        }
    }

    func handleConsoleLog(type: String, message: String) {
        switch type {
        case "log":
            print("Console Log: \(message)")
        case "warn":
            print("Console Warn: \(message)")
        case "error":
            print("Console Error: \(message)")
        default:
            break
        }
    }

    func handleUserData(userId: Int, token: String) {
        // 在这里处理接收到的UserId和Token
        print("Received UserId: \(userId), Token: \(token)")
        if userId != 0 {
            UserDefaults.standard.set(userId, forKey: "UserId")
            UserDefaults.standard.set(token, forKey: "UserToken")
        } else {
            print("Logout")
            UserDefaults.standard.removeObject(forKey: "UserId")
            UserDefaults.standard.removeObject(forKey: "UserToken")
        }
        // 发送通知
        NotificationCenter.default.post(name: .didReceiveUserData, object: nil, userInfo: ["userId": userId, "token": token])
    }
}

extension Notification.Name {
    static let didReceiveUserData = Notification.Name("didReceiveUserData")
    static let imagesAsync = Notification.Name("imagesAsync")
}
