//
//  Alert.swift
//  GaurSonsApp
//
//  Created by Sakshi on 28/08/25.
//  Copyright © 2025 GaurSonsAppOrganizationName. All rights reserved.
//

import UIKit

class Alert {
    
    static func showValidationAlert(message: String, on viewController: UIViewController) {
        let alert = UIAlertController(title: "Validation Error",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true, completion: nil)
    }
    
    static func showArrayValidationAlert(on viewController: UIViewController, messages: [String]) {
        let alert = UIAlertController(
            title: "Validation Error",
            message: messages.joined(separator: "\n"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true, completion: nil)
    }
    
    private static var loaderView: UIActivityIndicatorView?
    private static var overlayView: UIView?
    
    static func showLoader(on view: UIView) {
        DispatchQueue.main.async {
            if loaderView != nil { return }
            
            let overlay = UIView(frame: view.bounds)
            overlay.backgroundColor = UIColor(white: 0, alpha: 0.3)
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            let loader = UIActivityIndicatorView(style: .large)
            loader.color = .white
            loader.center = overlay.center
            loader.startAnimating()
            
            overlay.addSubview(loader)
            view.addSubview(overlay)
            
            loaderView = loader
            overlayView = overlay
            
            view.isUserInteractionEnabled = false
        }
    }
    
    static func hideLoader(from view: UIView) {
        DispatchQueue.main.async {
            loaderView?.stopAnimating()
            overlayView?.removeFromSuperview()
            
            loaderView = nil
            overlayView = nil
            
            view.isUserInteractionEnabled = true
        }
    }
}
