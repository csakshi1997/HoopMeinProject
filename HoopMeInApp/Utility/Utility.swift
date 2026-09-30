//
//  Utility.swift
//  FRATELLI
//
//  Created by Sakshi on 21/10/24.
//

import UIKit
import AVFoundation
import SalesforceSDKCore

class Utility {
    static var homeView: HomeVC?
    static var timelineView: TimelineVC?
    static var profileView: ProfileVC?
    static var tabbarView: TabbarView?
    static var isMenuOpen : Bool = false
    static var isFromHome : Bool = false
    static var fromOtherScreen : Bool = false
    static var button = UIButton()
    static var containerController : UIViewController?
    static var presentController : UIViewController?
    
    func getActualValue(key : String, dict : [String : Any]) -> String {
        if dict[key] is String {
            return dict[key] as! String
        } else if dict[key] is Int {
            return String(dict[key] as! Int)
        } else if dict[key] is Float {
            return String(format: "%.2f", dict[key] as! Float)
        } else if dict[key] is Double {
            return String(format: "%.2f", dict[key] as! Double)
        } else if dict[key] is Bool {
            return String(dict[key] as! Bool)
        } else {
            return EMPTY
        }
    }
    
    static func getConvertedPoint(_ targetView: UIView, baseView: UIView?) -> CGPoint {
        var pnt = targetView.frame.origin
        if nil == targetView.superview {
            return pnt
        }
        var superView = targetView.superview
        while superView != baseView {
            pnt = superView!.convert(pnt, to: superView!.superview)
            if nil == superView!.superview {
                break
            } else {
                superView = superView!.superview
            }
        }
        return superView!.convert(pnt, to: baseView)
    }
    
//    static func gotoTabbar() {
//        let storyBoard : UIStoryboard = UIStoryboard(name: "Tabbar", bundle:nil)
//        tabbarView = storyBoard.instantiateViewController(withIdentifier: "TabbarView") as? TabbarView
//        SceneDelegate.getSceneDelegate().navigationController = UINavigationController(rootViewController: tabbarView ?? TabbarView())
//        SceneDelegate.getSceneDelegate().navigationController?.isNavigationBarHidden = true
//        SceneDelegate.getSceneDelegate().window!.rootViewController = SceneDelegate.getSceneDelegate().navigationController
//    }
    
    static func gotoTabbar() {
        
        let sceneDelegate = SceneDelegate.getSceneDelegate()
        
        let storyBoard = UIStoryboard(name: "Tabbar", bundle: nil)
        let tabbarView = storyBoard.instantiateViewController(withIdentifier: "TabbarView") as! TabbarView
        
        let nav = UINavigationController(rootViewController: tabbarView)
        nav.isNavigationBarHidden = true
        
        sceneDelegate.window?.rootViewController = nav
        sceneDelegate.window?.makeKeyAndVisible() // ✅ IMPORTANT
    }
    
    static func gotoHome() {
        if let nav = SceneDelegate.getSceneDelegate().navigationController {
            let storyBoard = UIStoryboard(name: "Home", bundle: nil)
            if let homeVC = storyBoard.instantiateViewController(withIdentifier: "HomeVC") as? HomeVC {
                nav.pushViewController(homeVC, animated: true)
            }
        }
    }
    
    static func gotoTimeline() {
        if let nav = SceneDelegate.getSceneDelegate().navigationController {
            let storyBoard = UIStoryboard(name: "Timeline", bundle: nil)
            if let inventoryVC = storyBoard.instantiateViewController(withIdentifier: "TimelineVC") as? TimelineVC {
                nav.pushViewController(inventoryVC, animated: true)
            }
        }
    }
    
    static func gotoProfile() {
        if let nav = SceneDelegate.getSceneDelegate().navigationController {
            let storyBoard = UIStoryboard(name: "Profile", bundle: nil)
            if let profileVC = storyBoard.instantiateViewController(withIdentifier: "ProfileVC") as? ProfileVC {
                nav.pushViewController(profileVC, animated: true)
            }
        }
    }
    
//    static func logoutAction() {
//        if let currentUser = UserAccountManager.shared.currentUserAccount {
//            Defaults.isCheckIn = false
//            Defaults.isTrackingStart = false
//            Defaults.userId = EMPTY
//            Defaults.deeplinkUserId = EMPTY
//            UserAccountManager.shared.logout(currentUser)
//        }
//    }
    
//    static func logoutAction() {
//        Defaults.isCheckIn = false
//        Defaults.isTrackingStart = false
//        Defaults.userId = EMPTY
////        Defaults.deeplinkUserId = EMPTY
////        Defaults.isDifferentUserDetected = false
//        
//
//        if let currentUser = UserAccountManager.shared.currentUserAccount {
//            UserAccountManager.shared.logout(currentUser)
//        }
//
//        _ = UserAccountManager.shared.login { result in
//            switch result {
//            case .success(let (userAccount, authInfo)):
//                print("User logged in: \(userAccount)")
//            case .failure(let error):
//                print("Login failed: \(error.localizedDescription)")
//            }
//        }
//    }
    
    static func logoutAction() {
        // Stop GPS first so no more points are recorded after logout starts.
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.stopLocationUpdatesForLogout()
        }

        // Session / tracking reset. Keep login config (tokens, instanceUrl, isSalesforceTrue, etc.).
        Defaults.isCheckIn = false
        Defaults.isTrackingStart = false
        Defaults.isCheckout = false
        Defaults.wasAutoStopped = false
        Defaults.punchInDate = nil
        AutoCheckoutManager.invalidateAutoCheckoutTimer()

        LocationSyncManager.shared.clearPendingUnsyncedLocations()
        Defaults.userId = EMPTY

        if let currentUser = UserAccountManager.shared.currentUserAccount {
            UserAccountManager.shared.logout(currentUser)
        }

        DispatchQueue.main.async {
            let sceneDelegate = SceneDelegate.getSceneDelegate()

            if Defaults.isSalesforceTrue ?? false {
                // ✅ Custom Login Screen
                let storyboard = UIStoryboard(name: "Login", bundle: nil)
                let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginVC")
                let nav = UINavigationController(rootViewController: loginVC)
                nav.setNavigationBarHidden(true, animated: false)

                sceneDelegate.window?.rootViewController = nav
                sceneDelegate.window?.makeKeyAndVisible()

            } else {
                // ✅ Salesforce Default Login
                _ = UserAccountManager.shared.login { result in
                    switch result {
                    case .success(let (userAccount, _)):
                        print("User logged in:", userAccount)
                        
                        DispatchQueue.main.async {
                            sceneDelegate.setupRootViewController()
                        }

                    case .failure(let error):
                        print("Login failed:", error.localizedDescription)
                    }
                }
            }
        }
    }
    
    static func getUniqueName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmssSSSS"
        let dateString = dateFormatter.string(from: Date())
        return dateString
    }
    
    static func getStatus(responseCode: Int) -> ResponseStatus {
        switch responseCode {
        case 200, 201, 203, 204:
            return ResponseStatus.success
        case 409:
            return ResponseStatus.alreadyRegister
        case 500:
            return ResponseStatus.error
        case 401:
            return ResponseStatus.tokenExpired
        case 400:
            return ResponseStatus.badRequest
        default:
            return ResponseStatus.error
        }
    }
    
    static func setRightViewController(containerController: UIViewController, childViewController : UIViewController, isAnimated : Bool, fromOtherSCreen : Bool = false ) {
        self.fromOtherScreen = fromOtherSCreen
        presentController = childViewController
        removeAllChildController(containerController: containerController)
        let navigationController = UINavigationController(rootViewController: childViewController)
        navigationController.isNavigationBarHidden = true
        containerController.addChild(navigationController)
        containerController.view.addSubview(navigationController.view)
        navigationController.view.dropShadow(color: UIColor.black, opacity: 1.0, offSet: CGSize(width: -1, height: 1), radius:0.0, scale: true)
        navigationController.didMove(toParent: containerController)
        isMenuOpen = false
        if isAnimated {
            navigationController.view.frame.origin.x = getSideMenuWidth()
            UIView.animate(withDuration: 0.2, animations: {
                navigationController.view.frame.origin.x = 0
            })
        }
    }
    
    static func tokenExpiredAction() {
        
    }
    
    static func removeAllChildController(containerController: UIViewController) {
        for(_, controller) in containerController.children.enumerated() {
            controller.removeFromParent()
            controller.view.removeFromSuperview()
        }
    }
    
    static var overlayView: UIView?


    static func getSideMenuWidth() -> CGFloat {
        return 250.0
    }
    
    static func handleSalesforceError(
        _ error: Error,
        completion: @escaping (String?, ResponseStatus) -> Void
    ) {

        print("======================================")
        print("❌ SALESFORCE API ERROR")
        print("======================================")
        print("Error:", error)

        // MARK: - Salesforce RestClient Error

        if let restError = error as? RestClientError {

            print("🔴 RestClientError:", restError)

            if case let .apiFailed(
                response,
                underlyingError,
                urlResponse
            ) = restError {

                // ======================================
                // HTTP STATUS CODE
                // ======================================

                var statusCode = 0

                if let httpResponse = urlResponse as? HTTPURLResponse {
                    statusCode = httpResponse.statusCode
                }

                print("🌐 HTTP Status Code:", statusCode)

                // ======================================
                // SESSION EXPIRED
                // ======================================

                if statusCode == 401 {

                    DispatchQueue.main.async {

                        Utility.logoutAction()

                        completion(
                            "Session expired. Please login again.",
                            .tokenExpired
                        )
                    }

                    return
                }

                // ======================================
                // PARSE RESPONSE BODY
                // ======================================

                var errorMessage = "Something went wrong."

                if let data = response as? Data {

                    print("📦 Error Response Data:", data)

                    if let jsonObject = try? JSONSerialization.jsonObject(
                        with: data,
                        options: []
                    ) {

                        print("📦 Error JSON:", jsonObject)

                        // ----------------------------------
                        // Your Attendance API format
                        // ----------------------------------
                        //
                        // {
                        //     "status": "Error",
                        //     "records": null,
                        //     "message": "Attendance not found."
                        // }
                        //

                        if let jsonDict = jsonObject as? [String: Any] {

                            if let message = jsonDict["message"] as? String,
                               !message.isEmpty {

                                errorMessage = message
                            }

                            print("💬 API Message:", errorMessage)
                        }

                        // ----------------------------------
                        // Standard Salesforce error format
                        // ----------------------------------
                        //
                        // [
                        //     {
                        //         "message": "...",
                        //         "errorCode": "..."
                        //     }
                        // ]
                        //

                        else if let jsonArray = jsonObject as? [[String: Any]],
                                let firstError = jsonArray.first {

                            if let message = firstError["message"] as? String,
                               !message.isEmpty {

                                errorMessage = message
                            }

                            print("💬 Salesforce Message:", errorMessage)
                        }
                    }
                }

                // ======================================
                // UNDERLYING ERROR
                // ======================================

                if let nsUnderlyingError = underlyingError as NSError? {

                    print("======================================")
                    print("🔍 UNDERLYING ERROR")
                    print("======================================")
                    print("Domain:", nsUnderlyingError.domain)
                    print("Code:", nsUnderlyingError.code)
                    print("UserInfo:", nsUnderlyingError.userInfo)

                    // Try message from underlying error
                    if let message =
                        nsUnderlyingError.userInfo["message"] as? String,
                       !message.isEmpty {

                        errorMessage = message
                    }

                    // Try status code from underlying error
                    if let underlyingResponse =
                        nsUnderlyingError.userInfo["urlResponse"]
                        as? HTTPURLResponse {

                        statusCode = underlyingResponse.statusCode
                    }

                    // Sometimes statusCode is directly available
                    if let underlyingStatus =
                        nsUnderlyingError.userInfo["statusCode"] as? Int {

                        statusCode = underlyingStatus
                    }

                    // Your error can contain:
                    //
                    // Error Domain=com.salesforce.RestAPI.ErrorDomain
                    // Code=404
                    //
                    // So use the error code if it is an HTTP status code.

                    if nsUnderlyingError.code >= 100 &&
                        nsUnderlyingError.code <= 599 {

                        statusCode = nsUnderlyingError.code
                    }
                }

                // ======================================
                // FINAL RESULT
                // ======================================

                if errorMessage == "Something went wrong." {

                    errorMessage = restError.localizedDescription
                }

                print("======================================")
                print("📌 FINAL SALESFORCE ERROR")
                print("======================================")
                print("🌐 Status Code:", statusCode)
                print("💬 Message:", errorMessage)
                print("======================================")

                DispatchQueue.main.async {

                    completion(
                        errorMessage,
                        .error
                    )
                }

                return
            }

            // ======================================
            // OTHER REST CLIENT ERROR
            // ======================================

            DispatchQueue.main.async {

                completion(
                    restError.localizedDescription,
                    .error
                )
            }

            return
        }

        // ======================================
        // GENERIC ERROR
        // ======================================

        let nsError = error as NSError

        print("======================================")
        print("🔴 GENERIC ERROR")
        print("======================================")
        print("Domain:", nsError.domain)
        print("Code:", nsError.code)
        print("UserInfo:", nsError.userInfo)
        print("======================================")

        DispatchQueue.main.async {

            completion(
                error.localizedDescription,
                .error
            )
        }
    }
    

    
}

