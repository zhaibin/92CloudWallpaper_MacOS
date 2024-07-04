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
        contentController.add(self, name: "consoleLog")
        contentController.add(self, name: "receiveUserData")

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

        // 注入禁用文本选择、右键菜单、页面调试、和拖拽的JavaScript代码
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
        contentController.addUserScript(script)
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
        NSApp.activate(ignoringOtherApps: true)  // 将应用程序置于前方并激活窗口
        window?.makeKeyAndOrderFront(nil)
    }
}

extension WebViewWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // 隐藏窗口，但不退出应用程序
        window?.orderOut(nil)
    }
}

extension WebViewWindow: WKNavigationDelegate, WKUIDelegate {
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
        dialog.title = "Choose an image"
        dialog.allowedFileTypes = ["png", "jpg", "jpeg", "gif", "bmp", "tiff"]
        dialog.allowsMultipleSelection = false
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false

        if dialog.runModal() == .OK {
            completionHandler(dialog.urls)
        } else {
            completionHandler(nil)
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
