//
//  Constants.swift
//  CloudWallpaper
//
//  Created by 翟斌 on 2024/6/19.
//

import Foundation
struct Constant {
    static let appName = "92云壁纸"
    static let appNameEN = "92CloudWallpaper"
    static let softwareVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
    static let bundleID = "com.haokan.CloudWallpaper"
    static let bundleHelperID = "com.haokan.CloudWallpaper.helper"
    
}

struct WebViewURL{
    static let store = "https://look.levect.com/web/"
    static let login = "https://look.levect.com/web/login"
    static let loginSMS = "https://look.levect.com/web/verifylogin"
    static let post = "https://look.levect.com/web/publishWorks"
    static let mySub = "https://look.levect.com/web/subscription"
    static let myAlbum = "https://look.levect.com/web/album"
    static let test = "https://hk-h5.oss-cn-hangzhou.aliyuncs.com/test.html"
}

struct GlobalData {
    static var userId = UserDefaults.standard.integer(forKey: "UserId")
    static let loginFlag = 0
    static let maxRetries = 3
    static let pageIndex = 1
    static let pageSize = 20
    static let imageIndex = 0
}

struct StatsPara{
    static let url = "https://hk-tracking-hz.log-global.aliyuncs.com/logstores/eframe/track"
    static let distributeChannel = "Self"
    struct Behavior {
        static let startApplication = 0
        static let setWallpaper = 1
    }
}




