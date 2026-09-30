//
//  Enum.swift
//  FRATELLI
//
//  Created by Sakshi on 21/10/24.
//

import Foundation
import UIKit

enum ResponseStatus: Int {
    case success
    case alreadyRegister
    case tokenExpired
    case error
    case badRequest
}

enum CustomerDetails: String, CaseIterable {
    case details = "DETAILS"
    case contacts = "CONTACTS"
    case orders = "ORDERS"
    case beatPlan = "BEAT PLAN"
    case visits = "VISITS"
    case stocks = "STOCKS"
    case returns = "RETURNS"
}

enum SchemeDiscountType: String {
    case flat = "Flat"
    case percentage = "%"
    case quantity = "Quantity"
}

enum UploadField: String {
    case aadhaar = "Aadhaar Upload"
    case pan = "PAN Upload"
    case passport = "Passport Upload"
}

let customDateFormatter1 = CustomDateFormatter()
let todayDateString1 = customDateFormatter1.getTodayDateString()









