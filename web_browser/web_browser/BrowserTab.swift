//
//  BrowserTab.swift
//  web_browser
//
//  Created for multi-tab browser functionality
//

import Foundation

struct BrowserTab: Identifiable, Equatable {
    let id: UUID
    var url: String
    var title: String
    var canGoBack: Bool
    var canGoForward: Bool
    var isLoading: Bool
    var progress: Double

    init(id: UUID = UUID(), url: String = "https://www.apple.com", title: String = "New Tab") {
        self.id = id
        self.url = url
        self.title = title
        self.canGoBack = false
        self.canGoForward = false
        self.isLoading = false
        self.progress = 0
    }

    static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool {
        lhs.id == rhs.id
    }
}
