//
//  HomeVC.swift
//  HoopMeInApp
//
//  Created by Sakshi on 20/11/25.
//  Copyright © 2025 HoopMeInAppOrganizationName. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import SalesforceSDKCore

class HomeVC: UIViewController, CLLocationManagerDelegate {
    @IBOutlet var nameLbl: UILabel?
    @IBOutlet var versionLbl: UILabel?
    @IBOutlet var addressLbl: UILabel?
    @IBOutlet var mapView: MKMapView?
    @IBOutlet var btn1: UIButton?
    @IBOutlet var btn2: UIButton?
    @IBOutlet var btn3: UIButton?
    @IBOutlet var btn4: UIButton?
    @IBOutlet var btn5: UIButton?
    @IBOutlet var btn6: UIButton?
    let locationManager = CLLocationManager()
    var userWebService = UserWebService()
//    let totalDistance = 4090.8000
    let webRequest = BaseWebService()
    var currentLocationAnnotation: MKPointAnnotation?
    private var lastGeocodedLocation: CLLocation?
    private let geocoder = CLGeocoder()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpInitialUI()
        fetchUserDetails()
        setupLocation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupLocation()
        Task {
            await fetchDistance()
        }

        if let info = Bundle.main.infoDictionary,
           let version = info["CFBundleShortVersionString"] as? String,
           let build = info["CFBundleVersion"] as? String {

            versionLbl?.text = "V_\(version)(\(build))"
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
    
    func showAddressOnMap(_ address: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            guard let place = placemarks?.first,
                  let location = place.location,
                  error == nil else {
                print("Error geocoding saved address:", error?.localizedDescription ?? "")
                return
            }
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            )
            DispatchQueue.main.async {
                self.mapView?.setRegion(region, animated: true)
                let annotation = MKPointAnnotation()
                annotation.coordinate = location.coordinate
                annotation.title = "Current Location"
                annotation.subtitle = address
                Defaults.punchInAddress = address
                self.mapView?.addAnnotation(annotation)
            }
        }
    }

    
    func fetchUserDetails() {
        userWebService.fetchCurrentSalesforceUserDetails { [weak self] error, response, statusCode in

            guard let self = self else { return }

            print("response:", response as Any)
            print("error:", error as Any)
            print("status:", statusCode)

            guard statusCode == .success else {
                print("❌ Failed to fetch Salesforce user:", error ?? "")
                return
            }

            let responseDict = response ?? [:]

            Defaults.name = responseDict["Name"] as? String
            Defaults.userEmail = responseDict["Email"] as? String
            Defaults.userName = responseDict["Username"] as? String

            DispatchQueue.main.async {
                self.nameLbl?.text =
                    Defaults.name ?? Defaults.userName ?? ""
            }
        }
    }
    
    func setUpInitialUI() {
        mapView?.layer.cornerRadius = 8
        btn1?.layer.cornerRadius = 6
        btn2?.layer.cornerRadius = 6
        btn3?.layer.cornerRadius = 6
        btn4?.layer.cornerRadius = 6
        btn5?.layer.cornerRadius = 6
        btn6?.layer.cornerRadius = 6
    }
    
    
    func setupLocation() {

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.activityType = .otherNavigation
        locationManager.pausesLocationUpdatesAutomatically = false

        switch locationManager.authorizationStatus {

        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse,
             .authorizedAlways:

            mapView?.showsUserLocation = true
            locationManager.startUpdatingLocation()

        case .denied,
             .restricted:

            print("❌ Location permission denied/restricted")

        @unknown default:
            break
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {

        switch manager.authorizationStatus {

        case .authorizedWhenInUse,
             .authorizedAlways:

            print("✅ Location permission granted")

            mapView?.showsUserLocation = true
            manager.startUpdatingLocation()

        case .denied,
             .restricted:

            print("❌ Location permission denied")

        case .notDetermined:
            break

        @unknown default:
            break
        }
    }
    
    
    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        
        guard let location = locations.last else {
            return
        }

        // Ignore inaccurate GPS readings
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 100 else {
            return
        }

        print("📍 GPS Location Updated")
        print("Latitude:", location.coordinate.latitude)
        print("Longitude:", location.coordinate.longitude)
        print("Accuracy:", location.horizontalAccuracy)

        DispatchQueue.main.async { [weak self] in

            guard let self = self else {
                return
            }

            // Move map to actual GPS coordinate
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 300,
                longitudinalMeters: 300
            )

            self.mapView?.setRegion(region, animated: true)

            // Update custom marker
            self.updateCurrentLocationMarker(location)

            // Reverse geocode current GPS location
            self.updateAddress(location)
        }
    }
    
    private func updateAddress(_ location: CLLocation) {

        // Don't repeatedly reverse geocode the exact same location
        if let lastLocation = lastGeocodedLocation,
           location.distance(from: lastLocation) < 20 {
            return
        }

        lastGeocodedLocation = location

        geocoder.cancelGeocode()

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in

            guard let self = self else {
                return
            }

            if let error = error {
                print("❌ Reverse geocoding error:", error.localizedDescription)
                return
            }

            guard let place = placemarks?.first else {
                print("⚠️ No placemark found")
                return
            }

            let addressParts = [
                place.subLocality,
                place.thoroughfare,
                place.locality,
                place.administrativeArea,
                place.postalCode
            ]

            let address = addressParts
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")

            guard !address.isEmpty else {
                return
            }

            DispatchQueue.main.async {

                print("📍 Address Updated:")
                print(address)

                // Update label
                self.addressLbl?.text = address

                // Save latest address
                Defaults.punchInAddress = address

                // Update annotation subtitle
                self.currentLocationAnnotation?.subtitle = address
            }
        }
    }
    
    private func updateCurrentLocationMarker(_ location: CLLocation) {

        guard let mapView = mapView else {
            return
        }

        if let annotation = currentLocationAnnotation {

            // Existing pin → move it
            UIView.animate(withDuration: 0.3) {
                annotation.coordinate = location.coordinate
            }

        } else {

            // First time → create pin
            let annotation = MKPointAnnotation()
            annotation.coordinate = location.coordinate
            annotation.title = "Current Location"

            mapView.addAnnotation(annotation)

            currentLocationAnnotation = annotation
        }
    }
    
    
    func fetchAddress(from location: CLLocation) {

        geocoder.cancelGeocode()

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in

            guard let self = self else { return }

            guard let place = placemarks?.first, error == nil else {
                return
            }

            let fullAddress = [
                place.subLocality,
                place.thoroughfare,
                place.locality,
                place.administrativeArea,
                place.postalCode,
                place.country
            ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

            DispatchQueue.main.async {
                Defaults.punchInAddress = fullAddress
                self.addressLbl?.text = fullAddress
            }
        }
    }
    
    
    func getTotalDistance() -> Double {
        var locations = [LocationModel]()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        let date = formatter.string(from: today)
        
        let locationTable = LocationTable()
        locations = locationTable.getAllLocation(date: date)
        
        let totalDifference = locations.reduce(into: 0.0) { result, model in
            result += Double(model.diffrenceBetweenCurrentAndLastLatLong ?? "0.0") ?? 0.0
        }
        
        return totalDifference
    }
    
    func sfGet(fullUrl: String, headers: [String: String]? = nil) async throws -> Data {
        
        guard let url = URL(string: fullUrl) else {
            throw NSError(domain: "Invalid URL", code: 0)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
    
    func fetchDistance() async {
        
        let userId = Defaults.userId ?? ""
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")
        
        let date = formatter.string(from: Date())
        
        let urlString = "https://vikrant-location.fieldblaze.com/user/tracking/location-total-distance-location/\(userId)/\(date)"
        
        guard let url = URL(string: urlString) else {
            showCachedOrLocalDistance(for: date)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("a9F3kL8M2Qw7Xc5R0E6N1ZP4JYHUTbsvDArCneomxGiKfdWqLSp", forHTTPHeaderField: "API-SECRET-TOKEN")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataObj = json["data"] as? [String: Any],
               let distanceString = dataObj["total_distance"] as? String {
                
                let cleanValue = distanceString
                    .replacingOccurrences(of: " km", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                let value = Double(cleanValue) ?? 0.0
                
                print("✅ API Distance:", value)
                Defaults.saveTotalDistance(distanceString, for: date)
                
                DispatchQueue.main.async {
                    self.updateButtons(for: value)
                }
                
            } else {
                print("⚠️ API parsing failed → fallback")
                showCachedOrLocalDistance(for: date)
            }
            
        } catch {
            print("❌ API Error:", error.localizedDescription)
            showCachedOrLocalDistance(for: date)
        }
    }
    
    func showCachedOrLocalDistance(for date: String) {
        if let cached = Defaults.cachedTotalDistance(for: date) {
            let cleanValue = cached
                .replacingOccurrences(of: " km", with: "")
                .trimmingCharacters(in: .whitespaces)
            let value = Double(cleanValue) ?? 0.0
            print("💾 Cached Distance:", value)
            DispatchQueue.main.async {
                self.updateButtons(for: value)
            }
            return
        }
        showLocalDistance()
    }
    
    func showLocalDistance() {
        let localValue = getTotalDistance()
        
        print("📍 Local Distance:", localValue)
        
        DispatchQueue.main.async {
            self.updateButtons(for: localValue)
        }
    }
    
    func updateButtons(for value: Double) {
        
        let roundedValue = (value * 100).rounded() / 100
        
        let kmPart = Int(roundedValue)
        
        let meterPart = Int((roundedValue - Double(kmPart)) * 100)
        
        let kmString = String(format: "%04d", kmPart)
        let meterString = String(format: "%02d", meterPart)
        
        let full = kmString + meterString
        
        let chars = Array(full)
        
        guard chars.count == 6 else { return }
        
        btn1?.setTitle(String(chars[0]), for: .normal)
        btn2?.setTitle(String(chars[1]), for: .normal)
        btn3?.setTitle(String(chars[2]), for: .normal)
        btn4?.setTitle(String(chars[3]), for: .normal)
        btn5?.setTitle(String(chars[4]), for: .normal)
        btn6?.setTitle(String(chars[5]), for: .normal)
    }
    
//    func updateButtons(for value: Double) {
//        let roundedValue = (value * 100).rounded() / 100
//
//        let kmPart = Int(roundedValue)
//        let meterPart = Int(((roundedValue - Double(kmPart)) * 100).rounded())
//
//        let kmString = String(format: "%04d", kmPart)
//        let meterString = String(format: "%02d", meterPart)
//
//        let full = kmString + meterString
//
//        let chars = Array(full)
//
//        guard chars.count == 6 else { return }
//
//        btn1?.setTitle(String(chars[0]), for: .normal)
//        btn2?.setTitle(String(chars[1]), for: .normal)
//        btn3?.setTitle(String(chars[2]), for: .normal)
//        btn4?.setTitle(String(chars[3]), for: .normal)
//        btn5?.setTitle(String(chars[4]), for: .normal)
//        btn6?.setTitle(String(chars[5]), for: .normal)
//    }
}
