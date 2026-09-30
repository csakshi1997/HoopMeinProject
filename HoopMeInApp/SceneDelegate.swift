
import UIKit
import SwiftUI
import MobileSync
import SalesforceSDKCore

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var navigationController : UINavigationController?
        
    func scene(_ scene: UIScene,
               openURLContexts urlContexts: Set<UIOpenURLContext>) {
        guard let url = urlContexts.first?.url else { return }
        DeepLinkHandler.handleDeepLink(url)
        print("DEEPLINK RECEIVED:", url)
        
    }
    
    static func getSceneDelegate() -> SceneDelegate {
        return UIApplication.shared.connectedScenes.first?.delegate as! SceneDelegate
    }
    
    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions)
    {
        if let url = connectionOptions.urlContexts.first?.url {
            DeepLinkHandler.handleDeepLink(url)
        }
        guard let windowScene = (scene as? UIWindowScene) else { return }
        self.window = UIWindow(frame: windowScene.coordinateSpace.bounds)
        self.window?.windowScene = windowScene
        
        DeepLinkHandler.callStatusAPI { isSalesforce in
            DispatchQueue.main.async {
                
                if AutoCheckoutManager.performAutoCheckoutIfNeeded(showToast: false) {
                    let storyboard = UIStoryboard(name: "Home", bundle: nil)
                    let initialVC = storyboard.instantiateViewController(withIdentifier: "InitialVC")
                    let nav = UINavigationController(rootViewController: initialVC)
                    nav.setNavigationBarHidden(true, animated: false)
                    self.window?.rootViewController = nav
                    self.window?.makeKeyAndVisible()
                    return
                }

                if Defaults.isCheckIn ?? false {
                    Utility.gotoTabbar()
                    AutoCheckoutManager.scheduleAutoCheckoutTimerIfNeeded()
                    return
                }
                
                if isSalesforce {
                    let storyboard = UIStoryboard(name: "Login", bundle: nil)
                    let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginVC")
                    let nav = UINavigationController(rootViewController: loginVC)
                    nav.setNavigationBarHidden(true, animated: false)
                    self.window?.rootViewController = nav
                    self.window?.makeKeyAndVisible()
                    
                } else {
                    AuthHelper.loginIfRequired(scene) {
                        self.setupRootViewController()
                    }
                }
            }
        }
    }
 

    func sceneDidDisconnect(_ scene: UIScene) {
        
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Drain pending locations in DB insert order (oldest id first).
        // Do not forceUnlock every activate — that can cancel an in-flight upload mid-flight.
        LocationSyncManager.shared.startPendingLocationSync()
        if AutoCheckoutManager.performAutoCheckoutIfNeeded() {
            return
        }
        AutoCheckoutManager.scheduleAutoCheckoutTimerIfNeeded()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        if AutoCheckoutManager.performAutoCheckoutIfNeeded() {
            return
        }
        AutoCheckoutManager.scheduleAutoCheckoutTimerIfNeeded()
        self.initializeAppViewState()
        self.configureSalesforceLoginUI()
        if !(Defaults.isSalesforceTrue ?? false) {
            AuthHelper.loginIfRequired {
                self.setupRootViewController()
            }
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.ensureBackgroundLocationTrackingIfNeeded()
        }
    }
        
//    func initializeAppViewState()
    
    func initializeAppViewState() {
        if AutoCheckoutManager.isInCheckedOutState() {
            return
        }
        if Defaults.isCheckIn ?? false {
            Utility.gotoTabbar()
        }
    }
       
    func setupRootViewController() {
        
        if Defaults.isSalesforceTrue ?? false {
            return
        }
        
        MobileSyncSDKManager.shared.setupUserStoreFromDefaultConfig()
        MobileSyncSDKManager.shared.setupUserSyncsFromDefaultConfig()
        
        if AutoCheckoutManager.isInCheckedOutState() {
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            let initialVC = storyboard.instantiateViewController(withIdentifier: "InitialVC")
            let navController = UINavigationController(rootViewController: initialVC)
            navController.setNavigationBarHidden(true, animated: false)
            self.window?.rootViewController = navController
            self.window?.makeKeyAndVisible()
            return
        }

        if Defaults.isCheckIn ?? false {
            Utility.gotoTabbar()
            AutoCheckoutManager.scheduleAutoCheckoutTimerIfNeeded()
        } else {
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            let initialVC = storyboard.instantiateViewController(withIdentifier: "InitialVC")
            let navController = UINavigationController(rootViewController: initialVC)
            navController.setNavigationBarHidden(true, animated: false)
            self.window?.rootViewController = navController
            self.window?.makeKeyAndVisible()
        }
    }
   
    func resetViewState(_ postResetBlock: @escaping () -> ()) {
        if let rootViewController = self.window?.rootViewController {
            if let _ = rootViewController.presentedViewController {
                rootViewController.dismiss(animated: false, completion: postResetBlock)
                return
            }
        }
        postResetBlock()
    }

    private func configureSalesforceLoginUI() {
        UserAccountManager.shared.loginViewControllerConfig.loginViewControllerCreationBlock = nil
    }
    
    private func useQrCodeLogInUrl(_ url: URL) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        
        if (appDelegate.isQrCodeLoginUsingReferenceUrlFormat) {
            
            guard let components = NSURLComponents(
                url: url,
                resolvingAgainstBaseURL: true),
                  let scheme = components.scheme,
                  scheme == appDelegate.qrCodeLoginUrlScheme,
                  let host = components.host,
                  host == appDelegate.qrCodeLoginUrlHost,
                  let path = components.path,
                  path == SalesforceLoginViewController.qrCodeLoginUrlPath,
                  let queryItems = components.queryItems,
                  let _ = queryItems.first(where: { $0.name == SalesforceLoginViewController.qrCodeLoginUrlJsonParameterName })?.value else {
                SFSDKCoreLogger().e(classForCoder, message: "Invalid QR code log in URL.")
                return
            }
            let _ = LoginTypeSelectionViewController.loginWithFrontdoorBridgeUrlFromQrCode(url.absoluteString)
        } else {
            
            let frontdoorBridgeUrl = "your-qr-code-login-frontdoor-bridge-url"
            let pkceCodeVerifier = "your-qr-code-login-pkce-code-verifier"
            assert(frontdoorBridgeUrl != "your-qr-code-login-frontdoor-bridge-url", "Please implement your app's frontdoor bridge URL retrieval.")
            assert(pkceCodeVerifier != "your-qr-code-login-pkce-code-verifier", "Please add your app's PKCE code verifier retrieval if web server flow is used.")
            let _ = LoginTypeSelectionViewController.loginWithFrontdoorBridgeUrl(
                frontdoorBridgeUrl,
                pkceCodeVerifier: pkceCodeVerifier
            )
        }
    }
}
