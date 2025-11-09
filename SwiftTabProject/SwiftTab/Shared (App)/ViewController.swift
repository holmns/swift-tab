//
//  ViewController.swift
//  Shared (App)
//
//  Created by Nawat Suangburanakul on 1/11/2568 BE.
//

import WebKit

#if os(iOS)
import UIKit
typealias PlatformViewController = UIViewController
#elseif os(macOS)
import Cocoa
import SwiftUI
typealias PlatformViewController = NSViewController
#endif

class ViewController: PlatformViewController {

#if os(iOS)
    @IBOutlet var webView: WKWebView!
#elseif os(macOS)
    private let onboardingViewModel = MacOnboardingViewModel()
#endif

    override func viewDidLoad() {
        super.viewDidLoad()

#if os(iOS)
        configureWebView()
#elseif os(macOS)
        configureMacContent()
#endif
    }
}

#if os(macOS)
private extension ViewController {
    func configureMacContent() {
        let hostingView = NSHostingView(rootView: OnboardingFlowView(viewModel: onboardingViewModel))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
#endif
