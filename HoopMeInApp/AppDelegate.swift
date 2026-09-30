import Foundation
import UIKit
import MobileSync
import SwiftUI
import IQKeyboardManagerSwift
import BackgroundTasks
import CoreLocation
import Network
import Toast_Swift

@UIApplicationMain
class AppDelegate : UIResponder, UIApplicationDelegate, CLLocationManagerDelegate {
    var window: UIWindow?
    var locationManager = CLLocationManager()
    let monitor = NWPathMonitor()
    let monitorQueue = DispatchQueue(label: "Monitor")
    var isInternetReachable: Bool = false
    var customDateFormatter = CustomDateFormatter()
    let queue = DispatchQueue.global(qos: .background)
    private var autoStopTrackingTimer: Timer?
    func getFormattedDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
    
    override init() {
        super.init()
        MobileSyncSDKManager.initializeSDK()
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.hoopMeIn.syncLocations", using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleBackgroundTask(task: task)
        }
        if let path = Bundle.main.path(forResource: "BootConfig", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
            print("Redirect URI:", dict["oauthRedirectURI"] ?? "nil")
            print("Consumer Key:", dict["remoteAccessConsumerKey"] ?? "nil")
        }
        UIDevice.current.isBatteryMonitoringEnabled = true
        IQKeyboardManager.shared.isEnabled = true
        Database.createDatabase()
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                self.isInternetReachable = true
                LocationSyncManager.shared.handleConnectivityChange(isOnline: true)
            } else {
                self.isInternetReachable = false
                LocationSyncManager.shared.handleConnectivityChange(isOnline: false)
            }
        }
        monitor.start(queue: monitorQueue)
        //        if Defaults.isTrackingStart ?? false {
        //            startLocationTracking()
        //        }
        if AutoCheckoutManager.performAutoCheckoutIfNeeded(showToast: false, redirect: false) {
            // Checked-out state applied; SceneDelegate will show punch-in screen.
        } else if AutoCheckoutManager.canResumeTracking() {
            startLocationTracking()
        }
        AutoCheckoutManager.scheduleAutoCheckoutTimerIfNeeded()
        // Single entry: drain pending LocationTable rows continuously (no 10s timer).
        LocationSyncManager.shared.startPendingLocationSync()
        return true
    }
    
    func handleBackgroundTask(task: BGAppRefreshTask) {
        scheduleBackgroundLocationSync()
        let lock = NSLock()
        var completed = false
        func finish(_ success: Bool) {
            lock.lock()
            defer { lock.unlock() }
            guard !completed else { return }
            completed = true
            task.setTaskCompleted(success: success)
        }
        task.expirationHandler = {
            finish(false)
        }
        LocationSyncManager.shared.startPendingLocationSync {
            finish(true)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            print("✅ Authorized Always")
        case .authorizedWhenInUse:
            print("⚠️ Only When In Use (background won't work)")
        case .denied, .restricted:
            print("❌ Location denied")
        case .notDetermined:
            print("⏳ Waiting for permission")
        @unknown default:
            break
        }
    }
    
    func startLocationTracking() {
        print("startLocationTracking called")
        DispatchQueue.main.async {
            self.locationManager.delegate = self
            print("Delegate assigned")
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager.distanceFilter = 5
            self.locationManager.activityType = .otherNavigation
            self.locationManager.allowsBackgroundLocationUpdates = true
            self.locationManager.pausesLocationUpdatesAutomatically = false
            self.locationManager.showsBackgroundLocationIndicator = true
            print("Authorization:", self.locationManager.authorizationStatus.rawValue)
            
            if self.locationManager.authorizationStatus != .authorizedAlways {
                print("Requesting Always Authorization")
                self.locationManager.requestAlwaysAuthorization()
            }
            self.locationManager.startUpdatingLocation()
            self.scheduleBackgroundLocationSync()
            AutoCheckoutManager.scheduleAutoCheckoutTimerIfNeeded()
            print("Started updating location")
        }
    }

    /// Keeps GPS + sync alive when the app moves to background (Scene-based apps).
    func ensureBackgroundLocationTrackingIfNeeded() {
        guard Defaults.isTrackingStart ?? false else { return }
        guard !(Defaults.wasAutoStopped ?? false) else { return }
        DispatchQueue.main.async {
            self.locationManager.delegate = self
            self.locationManager.allowsBackgroundLocationUpdates = true
            self.locationManager.pausesLocationUpdatesAutomatically = false
            self.locationManager.activityType = .otherNavigation
            if self.locationManager.authorizationStatus == .authorizedAlways ||
                self.locationManager.authorizationStatus == .authorizedWhenInUse {
                self.locationManager.startUpdatingLocation()
            }
            self.scheduleBackgroundLocationSync()
            // Resume drain if idle; do not force-unlock (avoids killing an active upload).
            LocationSyncManager.shared.startPendingLocationSync()
        }
    }
    
    /// Stops GPS without punch-out / checkout side effects. Used on account logout only.
    func stopLocationUpdatesForLogout() {
        DispatchQueue.main.async {
            self.locationManager.stopUpdatingLocation()
            self.locationManager.stopMonitoringSignificantLocationChanges()
        }
    }
    
    func stopLocationTracking(showToast: Bool = true) {
        UserDefaults.standard.removeObject(forKey: "lastSavedLocation")
        DispatchQueue.main.async {
            self.locationManager.stopUpdatingLocation()
            self.locationManager.stopMonitoringSignificantLocationChanges()
        }
        Defaults.isTrackingStart = false
        Defaults.isCheckIn = false
        Defaults.isCheckout = true
        print("🔥 stopLocationTracking called")
        Defaults.isfromSalesforce = false
        print("🔥 isfromSalesforce set to false")
        Defaults.wasAutoStopped = true
        AutoCheckoutManager.invalidateAutoCheckoutTimer()
        if showToast {
            SceneDelegate.getSceneDelegate().window?.rootViewController?.topMostViewController().view.makeToast("You have been automatically punched out. Please punch in again to continue.")
        }
        redirectToInitialScreen()
    }
    
    func redirectToInitialScreen() {
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let sceneDelegate = scene.delegate as? SceneDelegate,
                  let window = sceneDelegate.window else { return }
            
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            let initialVC = storyboard.instantiateViewController(withIdentifier: "InitialVC")
            let nav = UINavigationController(rootViewController: initialVC)
            nav.setNavigationBarHidden(true, animated: false)
            
            window.rootViewController = nav
            window.makeKeyAndVisible()
        }
    }
    
    func scheduleAutoStopTracking() {
        autoStopTrackingTimer?.invalidate()
        autoStopTrackingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { timer in
            if self.isOutsideTrackingHours() {
                self.stopLocationTracking()
                timer.invalidate()
                self.autoStopTrackingTimer = nil
            }
        }
    }
    
    func scheduleBackgroundLocationSync() {
        let request = BGAppRefreshTaskRequest(identifier: "com.hoopMeIn.syncLocations")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background task scheduled")
        } catch {
            print("Failed to schedule background task: \(error.localizedDescription)")
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        ensureBackgroundLocationTrackingIfNeeded()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("📍 didUpdateLocations: \(locations.last?.coordinate.latitude ?? 0), \(locations.last?.coordinate.longitude ?? 0)")
        print(LocationSyncManager.shared.hasValidUserContextForRecording())
        if isOutsideTrackingHours() {
            stopLocationTracking()
            return
        }
        var mockLocationValue = Int()
        guard let newLocation = locations.last else { return }
        
        let isMockLocation = newLocation.horizontalAccuracy > 20
        if isMockLocation {
            mockLocationValue = 1
        } else {
            mockLocationValue = 0
        }
        
        // Location wake (including background): save (+ sync kicks from save path).
        // Do NOT forceUnlock here — that cancels in-flight uploads and can start parallel
        // RestClient.send calls (Salesforce SDK continuation crash after punch-in).
        DispatchQueue.global(qos: .utility).async {
            guard (Defaults.isTrackingStart ?? false),
                  LocationSyncManager.shared.hasValidUserContextForRecording() else { return }
            LocationSyncManager.shared.saveLocationToDatabase(
                newLocation,
                isMockLocation: mockLocationValue,
                lastLocation: nil
            )
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .locationUpdated,
                    object: nil
                )
            }
        }
    }
    
    func registerForRemotePushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            if granted {
                DispatchQueue.main.async {
                    PushNotificationManager.sharedInstance().registerForRemoteNotifications()
                }
            } else {
                SalesforceLogger.d(AppDelegate.self, message: "Push notification authorization denied")
            }
            
            if let error = error {
                SalesforceLogger.e(AppDelegate.self, message: "Push notification authorization error: \(error)")
            }
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
    }
    
    func didRegisterForRemoteNotifications(_ deviceToken: Data) {
        PushNotificationManager.sharedInstance().didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
        if let _ = UserAccountManager.shared.currentUserAccount?.credentials.accessToken {
            PushNotificationManager.sharedInstance().registerForSalesforceNotifications { (result) in
                switch (result) {
                case  .success(let successFlag):
                    SalesforceLogger.d(AppDelegate.self, message: "Registration for Salesforce notifications status:  \(successFlag)")
                case .failure(let error):
                    SalesforceLogger.e(AppDelegate.self, message: "Registration for Salesforce notifications failed \(error)")
                }
            }
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error ) {
    }
    
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        DeepLinkHandler.handleDeepLink(url)
        return false;
    }
    
    func enableIDPLoginFlowForURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return  UserAccountManager.shared.handleIdentityProviderResponse(from: url, with: options)
    }
    
    let isQrCodeLoginUsingReferenceUrlFormat = true
    
    
    let qrCodeLoginUrlScheme = "your-qr-code-login-url-scheme"
    
    let qrCodeLoginUrlHost = "your-qr-code-login-url-host"
    
    
    
    private func setupQrCodeLogin() {
        
        UserAccountManager.shared.loginViewControllerConfig.loginViewControllerCreationBlock = {
            return LoginTypeSelectionViewController()
        }
        assert(qrCodeLoginUrlScheme != "your-qr-code-login-url-scheme", "Please add your login QR code URL's scheme.")
        assert(qrCodeLoginUrlHost != "your-qr-code-login-url-host", "Please add your login QR code URL's host.")
        SalesforceLoginViewController.qrCodeLoginUrlPath = "your-qr-code-login-url-path"
        SalesforceLoginViewController.qrCodeLoginUrlJsonParameterName = "your-qr-code-login-url-json-parameter-name"
        SalesforceLoginViewController.qrCodeLoginUrlJsonFrontdoorBridgeUrlKey = "your-qr-code-login-url-json-frontdoor-bridge-url-key"
        SalesforceLoginViewController.qrCodeLoginUrlJsonPkceCodeVerifierKey = "your-qr-code-login-url-json-pkce-code-verifier-key"
        assert(SalesforceLoginViewController.qrCodeLoginUrlPath != "your-qr-code-login-url-path", "Please add your login QR code URL's path.")
        assert(SalesforceLoginViewController.qrCodeLoginUrlJsonParameterName != "your-qr-code-login-url-json-parameter-name", "Please add your login QR code URL's UI Bridge API JSON query string parameter name.")
        assert(SalesforceLoginViewController.qrCodeLoginUrlJsonFrontdoorBridgeUrlKey != "your-qr-code-login-url-json-frontdoor-bridge-url-key", "Please add your login QR code URL's UI Bridge API JSON frontdoor bridge URL key.")
        assert(SalesforceLoginViewController.qrCodeLoginUrlJsonPkceCodeVerifierKey != "your-qr-code-login-url-json-pkce-code-verifier-key", "Please add your login QR code URL's UI Bridge API JSON PKCE code verifier key.")
    }
    
    private func isOutsideTrackingHours() -> Bool {
        let currentHour = Calendar.current.component(.hour, from: Date())
        return currentHour >= 23 || currentHour < 7
    }
    
    private func isInternetAvailable() -> Bool {
        return isInternetReachable
    }
    
}
