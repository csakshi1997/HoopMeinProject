//
//  LocationPreviewVC.swift
//  HoopMeInApp
//
//  Created by Sakshi on 24/07/26.
//  Copyright © 2026 HoopMeInAppOrganizationName. All rights reserved.
//

import UIKit
import MapKit

class LocationPreviewVC: UIViewController {

    var latitude: Double = 0
    var longitude: Double = 0
    var address: String = ""

    let mapView = MKMapView()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = .boldSystemFont(ofSize: 24)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])

        view.addSubview(mapView)

        mapView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        view.bringSubviewToFront(closeButton)

        let coordinate = CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )

        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = address

        mapView.addAnnotation(annotation)

        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )

        mapView.setRegion(region, animated: false)
    }
    
    @objc func closeTapped() {
        dismiss(animated: true)
    }
}
