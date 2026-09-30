//
//  AutoCheckoutManager.swift
//  HoopMeInApp
//

import UIKit

class AutoCheckoutManager {
    static let checkoutHour = 23
    private static var autoCheckoutTimer: Timer?

//    / Returns true when the user should be punched out (11 PM cutoff or next-day without re-punch).
    static func shouldAutoCheckout() -> Bool {
        if Defaults.wasAutoStopped ?? false {
            return (Defaults.isCheckIn ?? false) || (Defaults.isTrackingStart ?? false)
        }

        guard (Defaults.isCheckIn ?? false) || (Defaults.isTrackingStart ?? false) else {
            return false
        }

        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)

        if hour >= checkoutHour {
            return true
        }

        if let punchInDate = Defaults.punchInDate,
           !calendar.isDate(punchInDate, inSameDayAs: now) {
            return true
        }

        return false
    }
    
//    static func shouldAutoCheckout() -> Bool {
//        guard let punchInDate = Defaults.punchInDate else {
//            return false
//        }
//
//        return Date().timeIntervalSince(punchInDate) >= 4 * 60
//    }

    static func isInCheckedOutState() -> Bool {
        if Defaults.wasAutoStopped ?? false { return true }
        if Defaults.isCheckout ?? false { return true }
        return !(Defaults.isCheckIn ?? false)
    }

    static func canResumeTracking() -> Bool {
        (Defaults.isTrackingStart ?? false) && !(Defaults.wasAutoStopped ?? false) && !shouldAutoCheckout()
    }

    static func recordPunchIn() {
        Defaults.punchInDate = Date()
        Defaults.wasAutoStopped = false
        Defaults.isCheckout = false
        Defaults.isCheckIn = true
        Defaults.isTrackingStart = true
    }

    @discardableResult
    static func performAutoCheckoutIfNeeded(showToast: Bool = true, redirect: Bool = true) -> Bool {
        guard shouldAutoCheckout() else { return false }

        if redirect, let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.stopLocationTracking(showToast: showToast)
            return true
        }

        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.locationManager.stopUpdatingLocation()
        }
        Defaults.isTrackingStart = false
        Defaults.isCheckIn = false
        Defaults.isCheckout = true
        Defaults.wasAutoStopped = true
        Defaults.isfromSalesforce = false
        invalidateAutoCheckoutTimer()
        return true
    }

    static func scheduleAutoCheckoutTimerIfNeeded() {
        autoCheckoutTimer?.invalidate()
        autoCheckoutTimer = nil

        guard (Defaults.isCheckIn ?? false) || (Defaults.isTrackingStart ?? false) else { return }
        guard !(Defaults.wasAutoStopped ?? false) else { return }

        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = checkoutHour
        components.minute = 0
        components.second = 0

        guard let checkoutTime = calendar.date(from: components) else { return }

        if checkoutTime <= now {
            performAutoCheckoutIfNeeded()
            return
        }

        autoCheckoutTimer = Timer.scheduledTimer(
            withTimeInterval: checkoutTime.timeIntervalSince(now),
            repeats: false
        ) { _ in
            performAutoCheckoutIfNeeded()
        }
    }
    
//    static func scheduleAutoCheckoutTimerIfNeeded() {
//        autoCheckoutTimer?.invalidate()
//        autoCheckoutTimer = nil
//
//        guard (Defaults.isCheckIn ?? false) || (Defaults.isTrackingStart ?? false) else {
//            print("❌ Auto checkout timer not scheduled")
//            return
//        }
//
//        guard !(Defaults.wasAutoStopped ?? false) else {
//            print("❌ Already auto stopped")
//            return
//        }
//
//        let interval: TimeInterval = 4 * 60 // 4 minutes
//
//        print("⏰ Auto checkout scheduled after 4 minutes")
//
//        autoCheckoutTimer = Timer.scheduledTimer(
//            withTimeInterval: interval,
//            repeats: false
//        ) { _ in
//
//            print("⏰ 4 minutes completed")
//
//            if performAutoCheckoutIfNeeded(showToast: true, redirect: true) {
//                print("✅ Auto checkout performed")
//            } else {
//                print("⚠️ Auto checkout conditions not satisfied")
//            }
//        }
//    }

    static func invalidateAutoCheckoutTimer() {
        autoCheckoutTimer?.invalidate()
        autoCheckoutTimer = nil
    }
}
