//
//  WebView.swift
//  web_browser
//
//  Created by Gary Wu on 10/26/25.
//

import SwiftUI
import WebKit
import Foundation

struct WebState {
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var isLoading: Bool = false
    var progress: Double = 0
    var title: String? = nil
    var url: String? = nil
}

struct WebView: UIViewRepresentable {
    let tabId: UUID
    let initialURL: String
    let onState: (WebState) -> Void
    let onNewTab: ((String) -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()                 // persistent cookies/storage
        cfg.allowsInlineMediaPlayback = true
        if #available(visionOS 1.0, *) {
            cfg.mediaTypesRequiringUserActionForPlayback = []
        }

        let web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true

        // Store reference for coordinator
        context.coordinator.webView = web

        // KVO for progress/title/loading
        web.addObserver(context.coordinator, forKeyPath: "estimatedProgress", options: .new, context: nil)
        web.addObserver(context.coordinator, forKeyPath: "title", options: .new, context: nil)
        web.addObserver(context.coordinator, forKeyPath: "loading", options: .new, context: nil)

        // Commands - now tab-aware
        context.coordinator.loadURLObserver = NotificationCenter.default.addObserver(forName: .webLoadURL, object: nil, queue: .main) { [weak web] note in
            guard let userInfo = note.userInfo,
                  let targetTabId = userInfo["tabId"] as? UUID,
                  targetTabId == context.coordinator.tabId,
                  let u = note.object as? URL else { return }
            web?.load(URLRequest(url: u))
        }
        context.coordinator.goBackObserver = NotificationCenter.default.addObserver(forName: .webGoBack, object: nil, queue: .main) { [weak web] note in
            guard let userInfo = note.userInfo,
                  let targetTabId = userInfo["tabId"] as? UUID,
                  targetTabId == context.coordinator.tabId else { return }
            if web?.canGoBack == true { web?.goBack() }
        }
        context.coordinator.goForwardObserver = NotificationCenter.default.addObserver(forName: .webGoForward, object: nil, queue: .main) { [weak web] note in
            guard let userInfo = note.userInfo,
                  let targetTabId = userInfo["tabId"] as? UUID,
                  targetTabId == context.coordinator.tabId else { return }
            if web?.canGoForward == true { web?.goForward() }
        }
        context.coordinator.reloadObserver = NotificationCenter.default.addObserver(forName: .webReload, object: nil, queue: .main) { [weak web] note in
            guard let userInfo = note.userInfo,
                  let targetTabId = userInfo["tabId"] as? UUID,
                  targetTabId == context.coordinator.tabId else { return }
            web?.reload()
        }
        context.coordinator.stopObserver = NotificationCenter.default.addObserver(forName: .webStop, object: nil, queue: .main) { [weak web] note in
            guard let userInfo = note.userInfo,
                  let targetTabId = userInfo["tabId"] as? UUID,
                  targetTabId == context.coordinator.tabId else { return }
            web?.stopLoading()
        }

        // Load initial URL
        if let url = URL(string: initialURL) {
            web.load(URLRequest(url: url))
        }
        context.coordinator.updateState(from: web) // initial state callback
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(tabId: tabId, onState: onState, onNewTab: onNewTab)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let tabId: UUID
        let onState: (WebState) -> Void
        let onNewTab: ((String) -> Void)?
        weak var webView: WKWebView?

        // Store observers for cleanup
        var loadURLObserver: NSObjectProtocol?
        var goBackObserver: NSObjectProtocol?
        var goForwardObserver: NSObjectProtocol?
        var reloadObserver: NSObjectProtocol?
        var stopObserver: NSObjectProtocol?

        init(tabId: UUID, onState: @escaping (WebState) -> Void, onNewTab: ((String) -> Void)?) {
            self.tabId = tabId
            self.onState = onState
            self.onNewTab = onNewTab
        }

        deinit {
            // Clean up observers
            if let observer = loadURLObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = goBackObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = goForwardObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = reloadObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = stopObserver {
                NotificationCenter.default.removeObserver(observer)
            }

            // Remove KVO observers
            if let web = webView {
                web.removeObserver(self, forKeyPath: "estimatedProgress")
                web.removeObserver(self, forKeyPath: "title")
                web.removeObserver(self, forKeyPath: "loading")
            }
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                   change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard let web = object as? WKWebView else { return }
            updateState(from: web)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateState(from: webView)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            updateState(from: webView)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        func updateState(from web: WKWebView) {
            onState(WebState(
                canGoBack: web.canGoBack,
                canGoForward: web.canGoForward,
                isLoading: web.isLoading,
                progress: web.estimatedProgress,
                title: web.title,
                url: web.url?.absoluteString
            ))
        }

        // MARK: - WKUIDelegate - Handle new window requests
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // When a link wants to open in a new window, create a new tab instead
            if let url = navigationAction.request.url?.absoluteString {
                onNewTab?(url)
            }
            return nil
        }
    }
}
