//
//  TabManager.swift
//  web_browser
//
//  Manages multiple browser tabs
//

import Foundation
import Combine

class TabManager: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var activeTabId: UUID?

    var activeTab: BrowserTab? {
        guard let activeTabId = activeTabId else { return nil }
        return tabs.first(where: { $0.id == activeTabId })
    }

    init() {
        // Create initial tab
        let initialTab = BrowserTab()
        tabs.append(initialTab)
        activeTabId = initialTab.id
    }

    func createNewTab(url: String = "https://www.apple.com") {
        let newTab = BrowserTab(url: url)
        tabs.append(newTab)
        activeTabId = newTab.id
    }

    func closeTab(_ tabId: UUID) {
        guard tabs.count > 1 else { return } // Keep at least one tab

        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs.remove(at: index)

            // If we closed the active tab, switch to another
            if activeTabId == tabId {
                if index < tabs.count {
                    activeTabId = tabs[index].id
                } else if !tabs.isEmpty {
                    activeTabId = tabs[tabs.count - 1].id
                }
            }
        }
    }

    func switchToTab(_ tabId: UUID) {
        if tabs.contains(where: { $0.id == tabId }) {
            activeTabId = tabId
        }
    }

    func updateTab(_ tabId: UUID, url: String? = nil, title: String? = nil, canGoBack: Bool? = nil, canGoForward: Bool? = nil, isLoading: Bool? = nil, progress: Double? = nil) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }

        if let url = url { tabs[index].url = url }
        if let title = title { tabs[index].title = title }
        if let canGoBack = canGoBack { tabs[index].canGoBack = canGoBack }
        if let canGoForward = canGoForward { tabs[index].canGoForward = canGoForward }
        if let isLoading = isLoading { tabs[index].isLoading = isLoading }
        if let progress = progress { tabs[index].progress = progress }
    }
}
