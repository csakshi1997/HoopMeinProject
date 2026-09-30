//
//  InitialVC.swift
//  HoopMeInApp
//
//  Created by Sakshi on 20/11/25.
//  Copyright © 2025 HoopMeInAppOrganizationName. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import SalesforceSDKCore

class InitialVC: UIViewController, CLLocationManagerDelegate {
    @IBOutlet var nameLbl: UILabel?
    @IBOutlet var addressLbl: UILabel?
    @IBOutlet var mapView: MKMapView?
    @IBOutlet var punchInBtn: UIButton?
    let locationManager = CLLocationManager()
    var userWebService = UserWebService()
    var isAttendanceFound: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpInitialUI()
        setupLocation()
        fetchUserDetails()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        print("UserIddd:- \(Defaults.userId ?? EMPTY)")
        print("Deeplink UserIddd:- \(Defaults.deepLinkUserId ?? EMPTY)")
        print(Defaults.deepLinkUserId ?? EMPTY)
        if !(Defaults.deepLinkUserId?.isEmpty ?? true) {
            if Defaults.userId == Defaults.deepLinkUserId {
                Defaults.isDifferentUserDetected = false
            } else {
                Defaults.isDifferentUserDetected = true
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let statusBarHeight = view.window?.windowScene?.statusBarManager?.statusBarFrame.height {
            let statusBarView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: statusBarHeight))
            statusBarView.backgroundColor = ColorConstant.screensBackgroundColor
            view.addSubview(statusBarView)
        }
    }
            
//    func fetchUserDetails() {
//
//        guard let user = UserAccountManager.shared.currentUserAccount else {
//            print("❌ No Salesforce user account")
//            return
//        }
//
//        let credentials = user.credentials
//
//        Defaults.accessToken = credentials.accessToken
//        Defaults.refreshToken = credentials.refreshToken
//        Defaults.instanceUrl = credentials.instanceUrl?.absoluteString
//        Defaults.userId = credentials.userId
//        Defaults.domain = credentials.domain
//
//        print("======================================")
//        print("🔐 Salesforce Credentials")
//        print("======================================")
//        print("User ID:", Defaults.userId ?? "")
//        print("Instance URL:", Defaults.instanceUrl ?? "")
//        print("Access Token:", Defaults.accessToken ?? "")
//        print("======================================")
//
//        userWebService.fetchCurrentSalesforceUserDetails { error, response, statusCode in
//
//            if statusCode == .success {
//
//                let responseDict = response ?? [:]
//
//                Defaults.name = responseDict["Name"] as? String
//                Defaults.userEmail = responseDict["Email"] as? String
//                Defaults.userName = responseDict["Username"] as? String
//
//                DispatchQueue.main.async {
//                    self.nameLbl?.text = Defaults.name
//                }
//
//                // Now userId is definitely available
//                self.checkIsPunchInFromSaleforce { [weak self] isPunchedIn in
//                    
//                    guard let self = self else { return }
//
//                    if isPunchedIn {
//                        print("✅ YES — Already punched in")
//                        return
//                    }
//                    self.continuePunchInFlow()
//                }
//            } else {
//
//                print("❌ Failed to fetch Salesforce user details")
//                print("❌ Error:", error ?? "Unknown error")
//            }
//        }
//    }
    
    func fetchUserDetails() {

        // 1️⃣ Get logged-in Salesforce account
        guard let user = UserAccountManager.shared.currentUserAccount else {
            print("❌ No Salesforce user account")
            return
        }

        // 2️⃣ Save Salesforce credentials
        let credentials = user.credentials

        Defaults.accessToken = credentials.accessToken
        Defaults.refreshToken = credentials.refreshToken
        Defaults.instanceUrl = credentials.instanceUrl?.absoluteString
        Defaults.userId = credentials.userId
        Defaults.domain = credentials.domain

        print("======================================")
        print("🔐 Salesforce Credentials")
        print("======================================")
        print("User ID:", Defaults.userId ?? "")
        print("Instance URL:", Defaults.instanceUrl ?? "")
        print("======================================")

        // Make sure User ID exists
        guard let userId = Defaults.userId, !userId.isEmpty else {
            print("❌ Salesforce User ID is missing")
            return
        }

        print("👤 Salesforce User ID:", userId)

        // 3️⃣ FIRST: Fetch Salesforce User Details
        print("📤 Fetching Salesforce user details...")

        userWebService.fetchCurrentSalesforceUserDetails { [weak self] error, response, statusCode in

            guard let self = self else { return }

            DispatchQueue.main.async {

                // 4️⃣ User API failed → STOP FLOW
                guard statusCode == .success else {

                    print("❌ Failed to fetch Salesforce user details")
                    print("❌ Error:", error ?? "Unknown error")

                    return
                }

                // 5️⃣ User API succeeded
                let responseDict = response ?? [:]

                print("======================================")
                print("✅ Salesforce User Details Received")
                print("======================================")
                print("Name:", responseDict["Name"] ?? "")
                print("Email:", responseDict["Email"] ?? "")
                print("Username:", responseDict["Username"] ?? "")
                print("User ID:", userId)
                print("======================================")

                // Save user details
                Defaults.name = responseDict["Name"] as? String
                Defaults.userEmail = responseDict["Email"] as? String
                Defaults.userName = responseDict["Username"] as? String

                self.nameLbl?.text = Defaults.name

                // 6️⃣ ONLY AFTER USER DETAILS SUCCESS
                // Call Attendance API
                print("📤 Calling Attendance API...")

                self.checkIsPunchInFromSaleforce { [weak self] isPunchedIn in

                    guard let self = self else { return }

                    if isPunchedIn {

                        print("✅ YES — Already punched in")

                        return

                    } else {

                        print("❌ Attendance not found")
                        print("➡️ Continuing Punch-In Flow")

                    }
                }
            }
        }
    }
    
    func checkIsPunchInFromSaleforce(
        completion: @escaping (Bool) -> Void
    ) {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let currentDate = formatter.string(from: Date())

        guard let userId = Defaults.userId,
              !userId.isEmpty else {

            print("❌ Salesforce User ID not found")

            isAttendanceFound = false
            completion(false)
            return
        }

        let payload: [String: Any] = [
            "userId": userId,
            "attendanceDate": "2026-08-05"
        ]

        userWebService.checkPunchInFromSaleforce(
            payload: payload
        ) { [weak self] error, response, statusCode in

            guard let self = self else { return }

            DispatchQueue.main.async {

                print("📥 Attendance Response:", response ?? [:])
                print("📌 Status:", statusCode)
                print("❌ Error:", error ?? "nil")

                if statusCode == .success {

                    // Attendance record exists
                    self.isAttendanceFound = true

                    print("✅ Attendance found")
                    print("isAttendanceFound:", self.isAttendanceFound)

                    completion(true)

                } else {

                    // Attendance record does not exist / API failed
                    self.isAttendanceFound = false

                    print("❌ Attendance not found")
                    print("isAttendanceFound:", self.isAttendanceFound)

                    completion(false)
                }
            }
        }
    }
    
    func setUpInitialUI() {
        punchInBtn?.layer.cornerRadius = 24
        mapView?.layer.cornerRadius = 8
    }
    
    func setupLocation() {
        mapView?.showsUserLocation = true
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
//        locationManager.startUpdatingLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {

        switch manager.authorizationStatus {

        case .authorizedWhenInUse:
            manager.startUpdatingLocation()

            // Request Always if needed
            manager.requestAlwaysAuthorization()

        case .authorizedAlways:
            manager.startUpdatingLocation()

        default:
            break
        }
    }
    
    func requestLocationPermission() {
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
        mapView?.setRegion(region, animated: true)
        fetchAddress(from: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {

        print("❌ Location Error:", error)

    }

    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {

        print("⏸ Paused")

    }

    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {

        print("▶️ Resumed")

    }
    
    func fetchAddress(from location: CLLocation) {
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard let place = placemarks?.first, error == nil else {
                print("Unable to get address:", error?.localizedDescription ?? "No error")
                return
            }
            
            let street     = place.thoroughfare ?? ""
            let subLocal   = place.subLocality ?? ""
            let city       = place.locality ?? ""
            let state      = place.administrativeArea ?? ""
            let pin        = place.postalCode ?? ""
            let country    = place.country ?? ""
            
            let fullAddress = [
                subLocal,
                street,
                city,
                state,
                pin,
                country
            ]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
            
            DispatchQueue.main.async {
                Defaults.punchInAddress = fullAddress
                self.addressLbl?.text = fullAddress
            }
            
            print("📍 Full Address:", fullAddress)
        }
    }
    
    func gotoPunchInView() {
        if isAttendanceFound {
            AutoCheckoutManager.recordPunchIn()
            
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.startLocationTracking()
            }
            
            Utility.gotoTabbar()
        } else {
            
            print("gotoPunchInView isfromSalesforce =", Defaults.isfromSalesforce)
            let isFromSalesforce = Defaults.isfromSalesforce ?? false
            let isDifferentUser = Defaults.isDifferentUserDetected ?? false
            let isCheckout = Defaults.isCheckout ?? false
            let wasAutoStopped = Defaults.wasAutoStopped ?? false
            
            print("========== PUNCH IN CHECK ==========")
            print("isfromSalesforce Raw:", Defaults.isfromSalesforce)
            print("isfromSalesforce:", isFromSalesforce)
            print("isDifferentUserDetected:", isDifferentUser)
            print("isCheckout:", isCheckout)
            print("wasAutoStopped:", wasAutoStopped)
            print("====================================")
            
            // 1. Different user has priority
            if isDifferentUser {
                
                let alert = UIAlertController(
                    title: "Different User",
                    message: "We found you have logged in with a different user. To continue, please ensure you are logged in with the correct user account.",
                    preferredStyle: .alert
                )
                
                alert.addAction(
                    UIAlertAction(title: "Cancel", style: .cancel)
                )
                
                alert.addAction(
                    UIAlertAction(title: "Login", style: .default) { _ in
                        Utility.logoutAction()
                    }
                )
                
                present(alert, animated: true)
                return
            }
            
            // 2. User MUST come from Salesforce
            if !isFromSalesforce {
                
                let alert = UIAlertController(
                    title: "Salesforce Deep Link Required",
                    message: "Please initiate punch-in from Salesforce first. You need to access this app via Salesforce deep link to enable punch-in functionality.",
                    preferredStyle: .alert
                )
                
                alert.addAction(
                    UIAlertAction(title: "OK", style: .default)
                )
                
                present(alert, animated: true)
                return
            }
            
            // 3. Salesforce deep link received + correct user
            let punchInAlert = UIAlertController(
                title: "Punch In",
                message: "Are you sure you want to Punch In?",
                preferredStyle: .alert
            )
            
            punchInAlert.addAction(
                UIAlertAction(title: "Cancel", style: .cancel)
            )
            
            punchInAlert.addAction(
                UIAlertAction(title: "OK", style: .default) { _ in
                    
                    AutoCheckoutManager.recordPunchIn()
                    
                    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                        appDelegate.startLocationTracking()
                    }
                    
                    Utility.gotoTabbar()
                }
            )
            
            present(punchInAlert, animated: true)
        }
    }
    
    
    @IBAction func punchInAction() {
        gotoPunchInView()
    }
}
