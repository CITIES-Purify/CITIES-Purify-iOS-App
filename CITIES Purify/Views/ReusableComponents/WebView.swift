import SwiftUI
import WebKit
import os

struct WebView: UIViewRepresentable {
    @Binding var url: String
    @Binding var isLoading: Bool?
    
    var onSurveyComplete: (() -> Void)?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: WebView.self)
    )
    
    init(url: Binding<String>, isLoading: Binding<Bool?> = .constant(nil), onSurveyComplete: (() -> Void)? = nil) {
        self._url = url
        self._isLoading = isLoading
        self.onSurveyComplete = onSurveyComplete
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self, onSurveyComplete: onSurveyComplete)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "didCompleteSurvey")
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Safely unwrap the URL from the string and log it
        if let validURL = URL(string: url) {
            let request = URLRequest(url: validURL)
            Self.logger.notice("Loading URL: \(validURL.absoluteString, privacy: .public)")
            webView.load(request)
        } else {
            Self.logger.error("Invalid URL: \(url, privacy: .public)")
        }
        
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        return
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var onSurveyComplete: (() -> Void)?
        var parent: WebView

        init(_ parent: WebView, onSurveyComplete: (() -> Void)?) {
            self.parent = parent
            self.onSurveyComplete = onSurveyComplete
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "didCompleteSurvey" {
                onSurveyComplete?()
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        
    }
}
