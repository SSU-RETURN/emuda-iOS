//
//  WebViewController.swift
//  emuda
//
//  Created by 정민지 on 6/10/24.
//

import UIKit
import WebKit

class WebViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    var webView: WKWebView!
    var urlString: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupWebView()
        loadUrl()
    }

    private func setupWebView() {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.preferences.javaScriptEnabled = true

        let contentController = WKUserContentController()
        contentController.add(self, name: "consoleLog")
        contentController.add(self, name: "consoleWarn")
        contentController.add(self, name: "consoleError")
        contentController.add(self, name: "alertHandler")
        contentController.add(self, name: "imageUploadHandler") // Add handler for image upload
        webConfiguration.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        view.addSubview(webView)

        // AutoLayout constraints for the webView
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadUrl() {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        let request = URLRequest(url: url)
        webView.load(request)
    }

    // WKScriptMessageHandler method
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "consoleLog":
            if let messageBody = message.body as? String {
                print("JavaScript log: \(messageBody)")
            }
        case "consoleWarn":
            if let messageBody = message.body as? String {
                print("JavaScript warning: \(messageBody)")
            }
        case "consoleError":
            if let messageBody = message.body as? String {
                print("JavaScript error: \(messageBody)")
            }
        case "alertHandler":
            if let messageBody = message.body as? String {
                showAlert(message: messageBody)
            }
        case "imageUploadHandler":
            if let messageBody = message.body as? String {
                print("호출됨")
                handleImageUpload(imageUrlString: messageBody)
            }
        default:
            break
        }
    }

    private func showAlert(message: String) {
        let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    private func handleImageUpload(imageUrlString: String) {
        guard let data = Data(base64Encoded: imageUrlString.components(separatedBy: ",").last ?? "") else {
            print("Invalid image data URL")
            return
        }

        if let image = UIImage(data: data), let jpegData = image.jpegData(compressionQuality: 0.8) {
            let base64JpegString = jpegData.base64EncodedString()
            let base64JpegDataUrl = "data:image/jpeg;base64,\(base64JpegString)"
            DispatchQueue.main.async {
                let script = "handleProcessedImage('\(base64JpegDataUrl)')"
                self.webView.evaluateJavaScript(script, completionHandler: nil)
            }
        } else {
            print("Failed to decode image")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Finished loading")

        // Inject JavaScript to intercept console methods, alert and disable zoom
        let js = """
        (function() {
            var oldLog = console.log;
            console.log = function(message) {
                if (typeof message === 'object') {
                    message = JSON.stringify(message);
                }
                window.webkit.messageHandlers.consoleLog.postMessage(message);
                oldLog.apply(console, arguments);
            }

            var oldWarn = console.warn;
            console.warn = function(message) {
                if (typeof message === 'object') {
                    message = JSON.stringify(message);
                }
                window.webkit.messageHandlers.consoleWarn.postMessage(message);
                oldWarn.apply(console, arguments);
            }

            var oldError = console.error;
            console.error = function(message) {
                if (typeof message === 'object') {
                    message = JSON.stringify(message, Object.getOwnPropertyNames(message));
                }
                window.webkit.messageHandlers.consoleError.postMessage(message);
                oldError.apply(console, arguments);
            }

            window.alert = function(message) {
                window.webkit.messageHandlers.alertHandler.postMessage(message);
            }

            var meta = document.createElement('meta');
            meta.name = 'viewport';
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            document.getElementsByTagName('head')[0].appendChild(meta);
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Failed to load: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
}

// Custom input accessory view to hide the toolbar
extension WKWebView {
    private struct AssociatedKeys {
        static var accessoryView: UIView?
    }

    override open var inputAccessoryView: UIView? {
        get {
            if let accessoryView = objc_getAssociatedObject(self, &AssociatedKeys.accessoryView) as? UIView {
                return accessoryView
            }
            let accessoryView = UIView()
            objc_setAssociatedObject(self, &AssociatedKeys.accessoryView, accessoryView, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return accessoryView
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.accessoryView, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
