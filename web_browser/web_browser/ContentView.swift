//
//  ContentView.swift
//  web_browser
//
//  Created by Gary Wu on 10/26/25.
//

import SwiftUI
import WebKit

// Chrome-style tab shape
struct ChromeTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let cornerRadius: CGFloat = 8
        let sideAngle: CGFloat = 10

        // Start from bottom left
        path.move(to: CGPoint(x: sideAngle, y: rect.maxY))

        // Left side angled line to top
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))

        // Top left corner
        path.addQuadCurve(
            to: CGPoint(x: cornerRadius, y: 0),
            control: CGPoint(x: 0, y: 0)
        )

        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: 0))

        // Top right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: cornerRadius),
            control: CGPoint(x: rect.maxX, y: 0)
        )

        // Right side angled line to bottom
        path.addLine(to: CGPoint(x: rect.maxX - sideAngle, y: rect.maxY))

        // Bottom edge (implicit close)
        path.closeSubpath()

        return path
    }
}

struct ContentView: View {
    @StateObject private var tabManager = TabManager()
    @State private var urlText = "https://www.apple.com"
    @FocusState private var isURLFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Address bar + controls
            if let activeTab = tabManager.activeTab {
                HStack(spacing: 8) {
                    Button {
                        NotificationCenter.default.post(name: .webGoBack, object: nil, userInfo: ["tabId": activeTab.id])
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!activeTab.canGoBack)

                    Button {
                        NotificationCenter.default.post(name: .webGoForward, object: nil, userInfo: ["tabId": activeTab.id])
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!activeTab.canGoForward)

                    Button {
                        if activeTab.isLoading {
                            NotificationCenter.default.post(name: .webStop, object: nil, userInfo: ["tabId": activeTab.id])
                        } else {
                            NotificationCenter.default.post(name: .webReload, object: nil, userInfo: ["tabId": activeTab.id])
                        }
                    } label: {
                        Image(systemName: activeTab.isLoading ? "xmark" : "arrow.clockwise")
                    }

                    TextField("Enter URL", text: $urlText, onCommit: {
                        loadTypedURL()
                        isURLFieldFocused = false
                    })
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                        .focused($isURLFieldFocused)
                        .onChange(of: tabManager.activeTabId) { _ in
                            // Only update URL text when not editing
                            if !isURLFieldFocused, let tab = tabManager.activeTab {
                                urlText = tab.url
                            }
                        }
                        .onChange(of: isURLFieldFocused) { focused in
                            // When user starts editing, select all text for easy replacement
                            // When user stops editing without committing, restore the current tab's URL
                            if focused {
                                // User started editing - do nothing, let them edit
                            } else if let activeTab = tabManager.activeTab {
                                // User stopped editing (unfocused) - restore current URL
                                urlText = activeTab.url
                            }
                        }

                    Button("Go", action: {
                        loadTypedURL()
                        isURLFieldFocused = false
                    })
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Progress
                if activeTab.isLoading {
                    ProgressView(value: activeTab.progress)
                        .progressViewStyle(.linear)
                        .padding(.horizontal)
                }

                // Tab bar (Chrome-style)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: -8) {
                        ForEach(tabManager.tabs) { tab in
                            let isActive = tabManager.activeTabId == tab.id

                            HStack(spacing: 8) {
                                Text(tab.title)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                    .frame(maxWidth: 180)

                                Button {
                                    tabManager.closeTab(tab.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(isActive ? .white : .white.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .opacity(tabManager.tabs.count > 1 ? 1 : 0)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            .frame(minWidth: 120, maxWidth: 220)
                            .background(
                                ChromeTabShape()
                                    .fill(isActive ? Color.blue : Color(red: 0.4, green: 0.4, blue: 0.4))
                            )
                            .overlay(
                                ChromeTabShape()
                                    .stroke(isActive ? Color.blue.opacity(0.6) : Color.black.opacity(0.2), lineWidth: 0.5)
                            )
                            .foregroundColor(.white)
                            .zIndex(isActive ? 1 : 0)
                            .shadow(color: isActive ? Color.black.opacity(0.2) : Color.clear, radius: 3, x: 0, y: 2)
                            .onTapGesture {
                                isURLFieldFocused = false
                                tabManager.switchToTab(tab.id)
                                if let activeTab = tabManager.activeTab {
                                    urlText = activeTab.url
                                }
                            }
                        }

                        // New tab button
                        Button {
                            isURLFieldFocused = false
                            tabManager.createNewTab()
                            if let activeTab = tabManager.activeTab {
                                urlText = activeTab.url
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.leading, 8)
                }
                .frame(height: 36)
                .background(Color(red: 0.3, green: 0.3, blue: 0.3))

                // Web views - keep all alive but only show active one
                ZStack {
                    ForEach(tabManager.tabs) { tab in
                        WebView(
                            tabId: tab.id,
                            initialURL: tab.url,
                            onState: { state in
                                tabManager.updateTab(
                                    tab.id,
                                    url: state.url,
                                    title: state.title ?? "New Tab",
                                    canGoBack: state.canGoBack,
                                    canGoForward: state.canGoForward,
                                    isLoading: state.isLoading,
                                    progress: state.progress
                                )
                            },
                            onNewTab: { url in
                                // Create a new tab when a link wants to open in a new window
                                tabManager.createNewTab(url: url)
                            }
                        )
                        .opacity(tab.id == tabManager.activeTabId ? 1 : 0)
                        .allowsHitTesting(tab.id == tabManager.activeTabId)
                    }
                }
            }
        }
    }

    private func loadTypedURL() {
        guard let activeTab = tabManager.activeTab else { return }

        let s = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        var u: URL?
        if let direct = URL(string: s), direct.scheme != nil {
            u = direct
        } else if let https = URL(string: "https://\(s)") {
            u = https
        }
        if let u {
            // Update the tab's URL
            tabManager.updateTab(activeTab.id, url: u.absoluteString)
            // Post notification with tab ID
            NotificationCenter.default.post(name: .webLoadURL, object: u, userInfo: ["tabId": activeTab.id])
        }
    }
}

extension Notification.Name {
    static let webLoadURL   = Notification.Name("web.loadURL")
    static let webGoBack    = Notification.Name("web.goBack")
    static let webGoForward = Notification.Name("web.goForward")
    static let webReload    = Notification.Name("web.reload")
    static let webStop      = Notification.Name("web.stop")
}
