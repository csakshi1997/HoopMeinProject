//
//  TimelineVC.swift
//  HoopMeInApp
//
//  Created by Sakshi on 20/11/25.
//  Copyright © 2025 HoopMeInAppOrganizationName. All rights reserved.
//

import UIKit
import MaterialComponents.MaterialTextControls_OutlinedTextFields
import WebKit

var lastLocationTime = ""
class TimelineVC: UIViewController {
    @IBOutlet var dateTxtFld: MDCOutlinedTextField?
    @IBOutlet var totalRecordLbl: UILabel?
    @IBOutlet var totalDistanceTravelledLbl: UILabel?
    private let mapButton = UIButton(type: .system)
    var DOIDatePicker = UIDatePicker()
    var locations = [LocationModel]()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let webView = WKWebView()
    private let closeButton = UIButton(type: .system)
    let formatter = CustomDateFormatter()
    //    var haltIsDone = false
    @IBOutlet var noRecordLabel: UILabel?
    private var timelineTask: Task<Void, Never>?
    /// Ignores stale responses when a newer Timeline load has started.
    private var timelineLoadGeneration = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUp()
        setCurrentDate()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshTimeline),
            name: .locationUpdated,
            object: nil
        )
    }
    
    deinit {
        timelineTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func refreshTimeline() {
        // Live refresh disabled — keep list stable after server/local load.
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addMapButtonWithoutBreakingConstraints()
        mapButton.addTarget(self, action: #selector(openMapView), for: .touchUpInside)
    }
    
    func addMapButtonWithoutBreakingConstraints() {
        guard let textField = dateTxtFld else { return }
        
        mapButton.translatesAutoresizingMaskIntoConstraints = false
        mapButton.setImage(
            UIImage(named: "location.png")?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        mapButton.tintColor = .systemBlue
        mapButton.backgroundColor = .clear
        
        view.addSubview(mapButton)
        
        if let constraints = textField.superview?.constraints {
            for constraint in constraints {
                if (constraint.firstItem as? UIView == textField && constraint.firstAttribute == .trailing) ||
                    (constraint.secondItem as? UIView == textField && constraint.secondAttribute == .trailing) {
                    textField.superview?.removeConstraint(constraint)
                    break
                }
            }
        }
        
        NSLayoutConstraint.activate([
            mapButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            mapButton.centerYAnchor.constraint(equalTo: textField.centerYAnchor),
            mapButton.heightAnchor.constraint(equalTo: textField.heightAnchor),
            mapButton.widthAnchor.constraint(equalTo: mapButton.heightAnchor),
            
            textField.trailingAnchor.constraint(equalTo: mapButton.leadingAnchor, constant: -8)
        ])
    }
    
    @objc func openMapView() {
        setupWebViewIfNeeded()
        tableView.isHidden = true
        webView.isHidden = false
        closeButton.isHidden = false
        
//        let userId = Defaults.userId
//        let urlString = "https://vikrant-location.fieldblaze.com/osrm-local/mobile-map-view.php?UserId=\(userId ?? EMPTY)&Date=\(dateTxtFld?.text ?? EMPTY)"
//        if let url = URL(string: urlString) {
//            webView.load(URLRequest(url: url))
//        }
        reloadMapView()
    }
    
    @objc func closeMapView() {
        webView.isHidden = true
        closeButton.isHidden = true
        tableView.isHidden = false
    }
    
    func setupWebViewIfNeeded() {
        if webView.superview != nil { return }
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(webView)
        view.addSubview(closeButton)
        
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = .boldSystemFont(ofSize: 20)
        
        closeButton.addTarget(self, action: #selector(closeMapView), for: .touchUpInside)
        
        webView.isHidden = true
        closeButton.isHidden = true
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: tableView.topAnchor),
            webView.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: tableView.bottomAnchor),
            
            closeButton.trailingAnchor.constraint(equalTo: webView.trailingAnchor, constant: -12),
            closeButton.topAnchor.constraint(equalTo: webView.topAnchor, constant: 12),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    
    func setUp() {
        addTapGestureToDismissKeyboard()
        setupDistanceLabelConstraint()
        dateTxtFld?.label.text = "Date of Incorporation *"
        dateTxtFld?.setOutlineColor(.darkGray, for: .normal)
        dateTxtFld?.setOutlineColor(UIColor(hex: "223B30") ?? UIColor(), for: .editing)
        dateTxtFld?.translatesAutoresizingMaskIntoConstraints = false
        
        DOIDatePicker.datePickerMode = .date
        DOIDatePicker.preferredDatePickerStyle = .wheels
//        DOIDatePicker.addTarget(self, action: #selector(dateChangedForStart(_:)), for: .valueChanged)
//        dateTxtFld?.inputView = DOIDatePicker
        DOIDatePicker.addTarget(self, action: #selector(dateChangedForStart(_:)), for: .valueChanged)
        dateTxtFld?.inputView = DOIDatePicker

        let toolbar = UIToolbar()
        toolbar.sizeToFit()

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                                        target: nil,
                                        action: nil)

        let doneButton = UIBarButtonItem(title: "Done",
                                         style: .done,
                                         target: self,
                                         action: #selector(doneButtonTapped))

        toolbar.items = [flexSpace, doneButton]

        dateTxtFld?.inputAccessoryView = toolbar
        let today = Date()
//        let calendar = Calendar.current
//        let last7Days = calendar.date(byAdding: .day, value: -7, to: today)!
//        DOIDatePicker.minimumDate = last7Days
        DOIDatePicker.minimumDate = nil
        DOIDatePicker.maximumDate = today
        
        tableView.register(TimelineCell.self, forCellReuseIdentifier: "TimelineCell")
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 210),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100)
        ])
    }
    
    private func setupDistanceLabelConstraint() {
        guard let distanceLabel = totalDistanceTravelledLbl else { return }
        
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            distanceLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            distanceLabel.leadingAnchor.constraint(greaterThanOrEqualTo: totalRecordLbl!.trailingAnchor, constant: 10)
        ])
        
        distanceLabel.numberOfLines = 1
        distanceLabel.lineBreakMode = .byTruncatingTail
    }
    
    @objc func dateChangedForStart(_ sender: UIDatePicker) {
        dateTxtFld?.text = formatter.displayDateFormatter.string(from: sender.date)
    }
    
    @objc func doneButtonTapped() {
        dateTxtFld?.resignFirstResponder()
        loadTimelineForSelectedDate()
        if !webView.isHidden {
            reloadMapView()
        }
    }
    
    func setCurrentDate() {
        let today = Date()
        dateTxtFld?.text = formatter.displayDateFormatter.string(from: today)
        DOIDatePicker.date = today
        loadTimelineForSelectedDate()
    }

    /// Cancels any in-flight load so an older response cannot hide a newer list.
    private func loadTimelineForSelectedDate() {
        timelineTask?.cancel()
        timelineLoadGeneration += 1
        let generation = timelineLoadGeneration
        let selectedDate = dateTxtFld?.text ?? ""

        timelineTask = Task { [weak self] in
            await self?.getLocationsFromServer(generation: generation, selectedDate: selectedDate)
        }
    }
    
    @MainActor
    private func showNoInternetState() {
        let date = dateTxtFld?.text ?? ""
        if showCachedTimelineFromDatabase(for: date) {
            return
        }
        locations = []
        totalRecordLbl?.text = "Total Record: 0"
        if let cached = Defaults.cachedTotalDistance(for: date) {
            totalDistanceTravelledLbl?.text = "Travelled distance: \(cached)"
        } else {
            totalDistanceTravelledLbl?.text = "Travelled distance: 0"
        }
        noRecordLabel?.text = "No internet connection."
        noRecordLabel?.isHidden = false
        let mapVisible = !webView.isHidden && webView.superview != nil
        if !mapVisible {
            tableView.isHidden = true
        }
        tableView.reloadData()
    }

    /// Loads Timeline rows previously saved from server for this date.
    @MainActor
    @discardableResult
    private func showCachedTimelineFromDatabase(for date: String) -> Bool {
        let cacheTable = TimelineServerCacheTable()
        guard let cache = cacheTable.cache(for: date) else { return false }

        locations = cache.locations
        totalRecordLbl?.text = "Total Record: \(cache.totalRecord)"
        totalDistanceTravelledLbl?.text = "Travelled distance: \(cache.totalDistance)"
        totalDistanceTravelledLbl?.adjustsFontSizeToFitWidth = true
        totalDistanceTravelledLbl?.minimumScaleFactor = 0.7
        if locations.isEmpty {
            noRecordLabel?.text = "No records found."
        }
        applyTimelineListVisibility()
        return true
    }

    @MainActor
    private func showEmptyState(message: String) {
        locations = []
        totalRecordLbl?.text = "Total Record: 0"
        totalDistanceTravelledLbl?.text = "Travelled distance: 0"
        noRecordLabel?.text = message
        noRecordLabel?.isHidden = false
        let mapVisible = !webView.isHidden && webView.superview != nil
        if !mapVisible {
            tableView.isHidden = true
        }
        tableView.reloadData()
    }

    @MainActor
    private func applyTimelineListVisibility() {
        // Don't un-hide the table while the map WebView is open.
        let mapVisible = !webView.isHidden && webView.superview != nil

        if locations.isEmpty {
            noRecordLabel?.isHidden = false
            if !mapVisible {
                tableView.isHidden = true
            }
        } else {
            noRecordLabel?.isHidden = true
            if !mapVisible {
                tableView.isHidden = false
            }
        }
        tableView.reloadData()
    }

    private func isNetworkAvailable() -> Bool {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate, appDelegate.isInternetReachable {
            return true
        }
        return InternetConnectionManager.isConnectedToNetwork()
    }
    
    func getLocationsFromServer(generation: Int, selectedDate: String) async {
        await MainActor.run {
            Alert.showLoader(on: self.view)
        }

        // Offline: show cached server rows for selected date, else "No internet".
        if !isNetworkAvailable() {
            await finishTimelineLoad(generation: generation) {
                self.showNoInternetState()
            }
            return
        }

        let userId = Defaults.userId ?? ""
        let urlString = "https://vikrant-location.fieldblaze.com/user/tracking/location-total-distance-location/\(userId)/\(selectedDate)"
        print("URL:", urlString)

        guard let url = URL(string: urlString) else {
            await finishTimelineLoad(generation: generation) {
                self.showEmptyState(message: "No records found.")
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("a9F3kL8M2Qw7Xc5R0E6N1ZP4JYHUTbsvDArCneomxGiKfdWqLSp", forHTTPHeaderField: "API-SECRET-TOKEN")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled, generation == timelineLoadGeneration else { return }

            if let httpResponse = response as? HTTPURLResponse {
                print("Status Code:", httpResponse.statusCode)
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw Response:\n\(responseString)")
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                await finishTimelineLoad(generation: generation) {
                    self.showEmptyState(message: "No records found.")
                }
                return
            }

            let status = json["status"] as? String ?? ""
            let message = json["message"] as? String ?? ""

            if status.lowercased() == "error" {
                await finishTimelineLoad(generation: generation) {
                    self.showEmptyState(message: message.isEmpty ? "No records found." : message)
                }
                return
            }

            guard let dataObj = json["data"] as? [String: Any] else {
                await finishTimelineLoad(generation: generation) {
                    self.showEmptyState(message: "No records found.")
                }
                return
            }

            let distanceString = dataObj["total_distance"] as? String ?? "0"
            let totalRecord = dataObj["total_record_count"] as? Int ?? 0
            let trackingRecords = dataObj["tracking_records"] as? [[String: Any]] ?? []

            let sortedRecords = trackingRecords.sorted {
                ($0["CreatedAt"] as? String ?? "") > ($1["CreatedAt"] as? String ?? "")
            }

            var fetched: [LocationModel] = []
            for record in sortedRecords {
                let serverId = Self.timelineServerRecordId(from: record)
                // Skip duplicate server ids within the same response.
                if let serverId,
                   fetched.contains(where: { $0.serverRecordId == serverId }) {
                    continue
                }

                var location = LocationModel()
                location.serverRecordId = serverId
                location.isOfflineRecord = record["IsOfflineRecord"] as? String
                location.latitude = record["Latitude"] as? String
                location.longitude = record["Longitude"] as? String
                location.diffrenceBetweenCurrentAndLastLatLong = record["MobileDistanceKm"] as? String
                location.address = record["Address"] as? String
                location.isMockLocation = record["IsFakeLocation"] as? String
                location.dateTime = record["DateTime"] as? String
                location.batteryPercentage = record["BatteryPercentage"] as? String
                location.deviceModel = record["DeviceModel"] as? String
                location.deviceManufacturer = record["DeviceManufacturer"] as? String
                location.isSyncToServer = "1"
                location.timeDifference = ""
                fetched.append(location)
            }

            guard !Task.isCancelled, generation == timelineLoadGeneration else { return }

            await finishTimelineLoad(generation: generation) {
                // Persist server payload for this date (Timeline-only cache).
                TimelineServerCacheTable().replaceCache(
                    for: selectedDate,
                    locations: fetched,
                    totalDistance: distanceString,
                    totalRecord: fetched.isEmpty ? 0 : totalRecord
                )
                Defaults.saveTotalDistance(distanceString, for: selectedDate)

                if fetched.isEmpty {
                    self.showEmptyState(message: "No records found.")
                    self.totalDistanceTravelledLbl?.text = "Travelled distance: \(distanceString)"
                } else {
                    self.locations = fetched
                    self.totalRecordLbl?.text = "Total Record: \(totalRecord)"
                    self.totalDistanceTravelledLbl?.text = "Travelled distance: \(distanceString)"
                    self.totalDistanceTravelledLbl?.adjustsFontSizeToFitWidth = true
                    self.totalDistanceTravelledLbl?.minimumScaleFactor = 0.7
                    self.applyTimelineListVisibility()
                }
            }
        } catch {
            guard !Task.isCancelled, generation == timelineLoadGeneration else { return }
            await finishTimelineLoad(generation: generation) {
                if !self.isNetworkAvailable() {
                    self.showNoInternetState()
                } else if self.showCachedTimelineFromDatabase(for: selectedDate) {
                    return
                } else {
                    self.showEmptyState(message: error.localizedDescription)
                }
            }
        }
    }

    private func finishTimelineLoad(generation: Int, apply: @escaping () -> Void) async {
        await MainActor.run {
            guard generation == self.timelineLoadGeneration else { return }
            apply()
            Alert.hideLoader(from: self.view)
        }
    }
    
    private func reloadMapView() {
        let userId = Defaults.userId ?? ""
        let selectedDate = dateTxtFld?.text ?? ""

        let urlString = "https://vikrant-location.fieldblaze.com/osrm-local/mobile-map-view.php?UserId=\(userId)&Date=\(selectedDate)"

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }

    /// Reads server tracking record id from API payload (`Id` / `id`).
    private static func timelineServerRecordId(from record: [String: Any]) -> String? {
        if let value = record["Id"] as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = record["id"] as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = record["Id"] as? Int {
            return "\(value)"
        }
        if let value = record["id"] as? Int {
            return "\(value)"
        }
        if let value = record["Id"] as? Int64 {
            return "\(value)"
        }
        if let value = record["id"] as? Int64 {
            return "\(value)"
        }
        if let value = record["Id"] as? NSNumber {
            return value.stringValue
        }
        if let value = record["id"] as? NSNumber {
            return value.stringValue
        }
        return nil
    }

    func addTapGestureToDismissKeyboard() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func showTotaldistance() {
        let totalDifference = locations.reduce(into: 0.0) { result, model in
            let diff = Double(model.diffrenceBetweenCurrentAndLastLatLong ?? "0.0") ?? 0.0
            result += diff
        }
        
        // Round to 2 decimals
        let rounded = (totalDifference * 100).rounded() / 100
        
//        if let apiDistance = Defaults.todaysTotalDistance, !apiDistance.isEmpty {
//            totalDistanceTravelledLbl?.text = "Travelled distance: \(apiDistance) km"
//        } else {
//            totalDistanceTravelledLbl?.text = "Travelled distance: \(rounded) km"
//        }
        
        DispatchQueue.main.async {
            print(Defaults.todaysTotalDistance)
            if let apiDistance = Defaults.todaysTotalDistance, !apiDistance.isEmpty {
                self.totalDistanceTravelledLbl?.text = "Travelled distance: \(apiDistance)"
            } else {
                self.totalDistanceTravelledLbl?.text = "Travelled distance: \(rounded)"
            }
            
            self.totalDistanceTravelledLbl?.adjustsFontSizeToFitWidth = true
            self.totalDistanceTravelledLbl?.minimumScaleFactor = 0.7
        }
        
        totalRecordLbl?.text = "Total Record: \(locations.count)"
        
    }
}

extension TimelineVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        locations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TimelineCell", for: indexPath) as! TimelineCell
        cell
            .configure(
                with: locations[indexPath.row],
                isFirst: indexPath.row == 0,
                isLast: indexPath.row == locations.count - 1,
                index: indexPath.row
            )
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let location = locations[indexPath.row]

        guard
            let lat = Double(location.latitude ?? ""),
            let lng = Double(location.longitude ?? "")
        else {
            return
        }

        let mapVC = LocationPreviewVC()
        mapVC.latitude = lat
        mapVC.longitude = lng
        mapVC.address = location.address ?? ""

        mapVC.modalPresentationStyle = .pageSheet
        present(mapVC, animated: true)
    }
}

class TimelineCell: UITableViewCell {
    private let dotView = UIView()
    private let topLine = UIView()
    private let bottomLine = UIView()
    private var haltIsDone = false
    
    
    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.numberOfLines = 0
        lbl.font = .systemFont(ofSize: 15, weight: .medium)
        return lbl
    }()
    
    private let timeLabel: UILabel = {
        let lbl = UILabel()
        lbl.numberOfLines = 1
        lbl.font = .systemFont(ofSize: 13)
        lbl.textColor = .gray
        return lbl
    }()
    
    private let stack = UIStackView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupTimelineUI()
        setupContent()
    }
    
    private func setupTimelineUI() {
        topLine.backgroundColor = UIColor(hex: "#6294C1")
        bottomLine.backgroundColor =  UIColor(hex: "#6294C1")
        
        dotView.layer.cornerRadius = 15
        dotView.layer.borderWidth = 10
        
        let timelineContainer = UIView()
        timelineContainer.addSubview(topLine)
        timelineContainer.addSubview(bottomLine)
        timelineContainer.addSubview(dotView)
        
        topLine.translatesAutoresizingMaskIntoConstraints = false
        bottomLine.translatesAutoresizingMaskIntoConstraints = false
        dotView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            dotView.centerXAnchor.constraint(equalTo: timelineContainer.centerXAnchor),
            dotView.centerYAnchor.constraint(equalTo: timelineContainer.centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 30),
            dotView.heightAnchor.constraint(equalToConstant: 30),
            
            topLine.topAnchor.constraint(equalTo: timelineContainer.topAnchor),
            topLine.centerXAnchor.constraint(equalTo: dotView.centerXAnchor),
            topLine.widthAnchor.constraint(equalToConstant: 5),
            topLine.bottomAnchor.constraint(equalTo: dotView.topAnchor),
            
            bottomLine.topAnchor.constraint(equalTo: dotView.bottomAnchor),
            bottomLine.centerXAnchor.constraint(equalTo: dotView.centerXAnchor),
            bottomLine.widthAnchor.constraint(equalToConstant: 5),
            bottomLine.bottomAnchor.constraint(equalTo: timelineContainer.bottomAnchor)
        ])
        
        timelineContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timelineContainer)
        
        NSLayoutConstraint.activate([
            timelineContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            timelineContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            timelineContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0),
            timelineContainer.widthAnchor.constraint(equalToConstant: 26)
        ])
        
        stack.axis = .vertical
        stack.spacing = 6
        
        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: timelineContainer.trailingAnchor, constant: 25),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -15)
        ])
    }
    
    private func setupContent() {
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(timeLabel)
    }
    
    func configure(with model: LocationModel, isFirst: Bool, isLast: Bool, index: Int) {
        haltIsDone
        lastLocationTime = model.dateTime ?? ""
        titleLabel.text = model.address
        timeLabel.text = model.dateTime
        let timeDifference = Int(Double(model.timeDifference ?? "0") ?? 0.0)
        if timeDifference > 10 && !haltIsDone {
            titleLabel.textColor = UIColor(hex: "#FF2D55")
            dotView.backgroundColor = .white
            dotView.layer.borderColor = UIColor(hex: "#FF2D55")?.cgColor
            timeLabel.text = "Duration: \(getFormattedDuration(timeDifference: timeDifference)) hours"
            titleLabel.text = "Halt: No updates"
            haltIsDone = true
        } else if isFirst {
            titleLabel.textColor = UIColor.systemGreen
            dotView.backgroundColor = UIColor.white
            dotView.layer.borderColor = UIColor.systemGreen.cgColor
            haltIsDone = false
        } else if isLast {
            titleLabel.textColor = UIColor(hex: "#2F497C")
            dotView.backgroundColor = .white
            dotView.layer.borderColor = UIColor(hex: "#2F497C")?.cgColor
            haltIsDone = false
        } else {
            titleLabel.textColor = .black
            dotView.backgroundColor = .white
            dotView.layer.borderColor = UIColor(hex: "#C9D6E2")?.cgColor
            haltIsDone = false
        }
        topLine.isHidden = isFirst
        bottomLine.isHidden = isLast
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func getFormattedDuration(timeDifference: Int ) -> String  {
        let totalSeconds = Int(timeDifference * 60)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let formatted = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        return formatted
    }
}
