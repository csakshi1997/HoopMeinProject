//
//  CustomDateFormatter.swift
//  FRATELLI
//
//  Created by Sakshi on 22/10/24.
//

import Foundation
import UIKit

class CustomDateFormatter {
    func getTodayDateString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormatOneType
        let todayDate = Date()
        return dateFormatter.string(from: todayDate)
    }
    
    func getDateForVisits(dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "dd-MMM"
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        } else {
            return ""
        }
    }
    
    func getDateForSettlement(dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy-MM-dd" 
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        } else {
            return ""
        }
    }
    
    func getDateForVisitsOrderDate(dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "dd-MMM"
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        } else {
            return ""
        }
    }
    
    func formatDateForTasks(_ dateString: String) -> String? {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")

        if let date = inputFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "dd-MM-yyyy"  
            return outputFormatter.string(from: date)
        }

        return nil
    }
    
    static func getCurrentDateTime() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.string(from: Date())
    }
    
    let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"  
        return formatter
    }()
    
    func getFormattedDateForAccount() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.timeZone = TimeZone.current
        
        let currentDate = Date()
        return formatter.string(from: currentDate)
    }
    
    func getFormattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone.current
        
        let currentDate = Date()
        return formatter.string(from: currentDate)
    }
}
