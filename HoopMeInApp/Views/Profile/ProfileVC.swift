//
//  ProfileVC.swift
//  HoopMeInApp
//
//  Created by Sakshi on 20/11/25.
//  Copyright © 2025 HoopMeInAppOrganizationName. All rights reserved.
//

import UIKit
import MaterialComponents.MaterialTextControls_OutlinedTextFields

class ProfileVC: UIViewController {
    @IBOutlet var nameLbl: UILabel?
    @IBOutlet var emailLbl: UILabel?
    @IBOutlet var imgView: UIImageView?
    @IBOutlet var userIdTxtFld: MDCOutlinedTextField?
    @IBOutlet var ordIdTxtFld: MDCOutlinedTextField?
    @IBOutlet var usernameTxtFld: MDCOutlinedTextField?
    @IBOutlet var userTypeTxtFld: MDCOutlinedTextField?
    @IBOutlet var contactNumberTxtFld: MDCOutlinedTextField?
    @IBOutlet var addressTxtFld: MDCOutlinedTextField?

    var userWebService = UserWebService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        nameLbl?.text = Defaults.name
        emailLbl?.text = Defaults.userEmail
        imgView?.layer.cornerRadius = 30
        setUpInitial()
    }
    
    func setUpInitial() {
        usernameTxtFld?.text = Defaults.userName
        userTypeTxtFld?.text = "STANDARD"
        contactNumberTxtFld?.text = ""
        addressTxtFld?.text = "India"
        userIdTxtFld?.isHidden = true
        ordIdTxtFld?.isHidden = true
//        usernameTxtFld?.isHidden = true
//        userTypeTxtFld?.isHidden = true
//        contactNumberTxtFld?.isHidden = true
//        addressTxtFld?.isHidden = true
        
        userIdTxtFld?.label.text = "User Id"
        userIdTxtFld?.setOutlineColor(.darkGray, for: .normal)
        userIdTxtFld?.setOutlineColor(UIColor(hex: "223B30") ?? UIColor(), for: .editing)
        userIdTxtFld?.translatesAutoresizingMaskIntoConstraints = false
        
        ordIdTxtFld?.label.text = "Organization Id"
        ordIdTxtFld?.setOutlineColor(.darkGray, for: .normal)
        ordIdTxtFld?.setOutlineColor(UIColor(hex: "223B30") ?? UIColor(), for: .editing)
        ordIdTxtFld?.translatesAutoresizingMaskIntoConstraints = false
        
        usernameTxtFld?.label.text = "Username"
        usernameTxtFld?.setOutlineColor(.darkGray, for: .normal)
        usernameTxtFld?.setOutlineColor(UIColor(hex: "223B30") ?? UIColor(), for: .editing)
        usernameTxtFld?.translatesAutoresizingMaskIntoConstraints = false
        
        userTypeTxtFld?.label.text = "User Type"
        userTypeTxtFld?.setOutlineColor(.darkGray, for: .normal)
        userTypeTxtFld?.setOutlineColor(UIColor(hex: "223B30") ?? UIColor(), for: .editing)
        userTypeTxtFld?.translatesAutoresizingMaskIntoConstraints = false
        
        contactNumberTxtFld?.label.text = "Contact Number"
        contactNumberTxtFld?.setOutlineColor(.darkGray, for: .normal)
        contactNumberTxtFld?.setOutlineColor(UIColor(hex: "223B30") ?? UIColor(), for: .editing)
        contactNumberTxtFld?.translatesAutoresizingMaskIntoConstraints = false
        
        addressTxtFld?.label.text = "ddress Country"
        addressTxtFld?.setOutlineColor(.darkGray, for: .normal)
        addressTxtFld?.setOutlineColor(UIColor(hex: "223B30") ?? UIColor(), for: .editing)
        addressTxtFld?.translatesAutoresizingMaskIntoConstraints = false
    }
}
