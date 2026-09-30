//
//  LocationModel.swift
//  HoopMeInApp
//
//  Created by Sakshi on 21/11/25.
//  Copyright © 2025 HoopMeInAppOrganizationName. All rights reserved.
//

import Foundation

struct LocationModel {
    var id: Int?
//    / Server tracking record id (Timeline cache uniqueness). Not used by LocationTable sync.
    var serverRecordId: String? = nil
    var isOfflineRecord: String?
    var latitude: String?
    var longitude: String?
    var diffrenceBetweenCurrentAndLastLatLong: String?
    var address: String?
    var isMockLocation: String?
    var dateTime: String?
    var batteryPercentage: String?
    var deviceModel: String?
    var deviceManufacturer: String?
    var isSyncToServer: String?
    var timeDifference: String?
 }
