//
//  DeepLinkHandler.swift
//  HoopMeInApp
//
//  Created by Chaman on 10/01/26.
//  Copyright © 2026 HoopMeInAppOrganizationName. All rights reserved.
//

import UIKit

class DeepLinkHandler: NSObject {
    static func handleDeepLink(_ url: URL) {
        Defaults.isfromSalesforce = true
        print("handleDeepLink\(Defaults.isfromSalesforce)")
        
        guard url.host == "punch" else { return }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        
        let action = queryItems.first(where: { $0.name == "action" })?.value
        Defaults.deepLinkUserId = queryItems.first(where: { $0.name == "userId" })?.value
        
        print(" deepLinkUserId deepLinkUserId\(Defaults.deepLinkUserId ?? EMPTY)")
        
        guard let linkUserId = Defaults.deepLinkUserId else {
            redirectToLogin()
            return
        }
        
        guard let savedUserId = Defaults.userId, !savedUserId.isEmpty else {
            print("⚠️ No user logged in → redirect to Login")
            redirectToLogin()
            return
        }
        
        if linkUserId != savedUserId {
            print("❌ Different user detected")
            showDifferentUserAlert()
            return
        }
        
        if action == "in" {
            goToHomeInitialScreenForCheckIn()
            return
        }
        
        if action == "out" {
            goToHomeInitialScreenForCheckOut()
            return
        }
    }
    
    static func goToHomeInitialScreenForCheckOut() {
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
                  let window = scene.windows.first,
                  let rootVC = window.rootViewController else { return }

            let topVC = rootVC.topMostViewController()

            let alert = UIAlertController(
                title: "Auto Punch-Out",
                message: "You have been automatically punched out. Please Punch in again",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                Defaults.isCheckIn = false
                Defaults.isTrackingStart = false
                Defaults.isCheckout = true
                Defaults.wasAutoStopped = true
                Defaults.isfromSalesforce = false
                AutoCheckoutManager.invalidateAutoCheckoutTimer()
                let storyboard = UIStoryboard(name: "Home", bundle: nil)
                let initialVC = storyboard.instantiateViewController(withIdentifier: "InitialVC")
                let nav = UINavigationController(rootViewController: initialVC)
                nav.setNavigationBarHidden(true, animated: false)

                window.rootViewController = nav
                window.makeKeyAndVisible()
            }))

            topVC.present(alert, animated: true)
        }
    }
    
    static func goToHomeInitialScreenForCheckIn() {
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
                  let window = scene.windows.first else { return }

            Defaults.isCheckIn = false
            Defaults.isTrackingStart = false

            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            let initialVC = storyboard.instantiateViewController(withIdentifier: "InitialVC")
            let nav = UINavigationController(rootViewController: initialVC)
            nav.setNavigationBarHidden(true, animated: false)

            window.rootViewController = nav
            window.makeKeyAndVisible()
        }
    }
    
    static func redirectToLogin() {
        DispatchQueue.main.async {
            Utility.logoutAction()
        }
    }
    
    static func showDifferentUserAlert() {
        DispatchQueue.main.async {
            Defaults.isDifferentUserDetected = true
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let sceneDelegate = scene.delegate as? SceneDelegate,
                  let rootVC = sceneDelegate.window?.rootViewController else { return }

            let alert = UIAlertController(
                title: "Different User",
                message: "We found you have logged in with a different user. To continue, please ensure you are logged in with the correct user account.",
                preferredStyle: .alert
            )

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

            let loginAction = UIAlertAction(title: "Login", style: .default) { _ in
                Defaults.isDifferentUserDetected = true
                Utility.logoutAction()
            }

            alert.addAction(cancelAction)
            alert.addAction(loginAction)

            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }

            if topVC is UIAlertController { return }

            topVC.present(alert, animated: true)
        }
    }
    
    static func callStatusAPI(completion: @escaping (Bool) -> Void) {
        
        guard let url = URL(string: "https://ability-site-6979.my.salesforce-sites.com/services/apexrest/status") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        request.setValue("BrowserId=8cYLkyzvEfGSKrGhNv_cTw; CookieConsentPolicy=0:1; LSKey-c$CookieConsentPolicy=0:1", forHTTPHeaderField: "Cookie")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            if let error = error {
                print("❌ Error:", error.localizedDescription)
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            guard let data = data else {
                print("❌ No data")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) {
                
                let value = (responseString.lowercased() == "true")
                
                Defaults.isSalesforceTrue = value
                
                print("✅ Saved value:", value)
                
                DispatchQueue.main.async {
                    completion(value)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
            
        }.resume()
    }
    
}

extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        if let nav = self as? UINavigationController {
            return nav.visibleViewController?.topMostViewController() ?? nav
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? tab
        }
        return self
    }
}
