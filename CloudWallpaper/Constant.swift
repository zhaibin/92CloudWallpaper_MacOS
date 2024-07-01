//
//  Constants.swift
//  CloudWallpaper
//
//  Created by 翟斌 on 2024/6/19.
//

import Foundation
struct Constant {
    static let urlStore = "https://look.levect.com/web/"
    static let urlLogin = "https://look.levect.com/web/login"
    static let urlLoginSMS = "https://look.levect.com/web/verifylogin"
    static let urlPost = "https://look.levect.com/web/publishWorks"
    static let urlMySub = "https://look.levect.com/web/subscription"
    static let urlMyAlbum = "https://look.levect.com/web/album"
    static let urlTest = "https://hk-h5.oss-cn-hangzhou.aliyuncs.com/test.html"
    static let urlAliyunLog = "https://hk-tracking-hz.log-global.aliyuncs.com/logstores/eframe/track?APIVersion=0.6.0"
    static let maxRetries = 3
    static let appName = "92云壁纸"
    static let appNameEN = "92CloudWallpaper"
    static let softwareVersion = "0.4.0.0"
    static let distributeChannel = "Self"
}

struct GlobalData {
    static var userId = UserDefaults.standard.integer(forKey: "UserId")
    static let pageIndex = 1
    static let pageSize = 20
    static let imageIndex = 0
    static let loginFlag = 0
}



