//
//  LoginVC.swift
//  HoopMeInApp
//
//  Created by Sakshi on 31/03/26.
//  Copyright © 2026 HoopMeInAppOrganizationName. All rights reserved.
//

import UIKit
import MaterialComponents.MaterialTextControls_OutlinedTextFields

class LoginVC: UIViewController, UITextFieldDelegate {
    @IBOutlet var emailTxtFld: MDCOutlinedTextField?
    @IBOutlet var passwordTxtFld: MDCOutlinedTextField?
    @IBOutlet var loginBtn: UIButton?
    var window: UIWindow?

    override func viewDidLoad() {
        super.viewDidLoad()
        initialUI()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
           tapGesture.cancelsTouchesInView = false
           view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func initialUI() {
        emailTxtFld?.delegate = self
        passwordTxtFld?.delegate = self
        loginBtn?.layer.cornerRadius = 8
        emailTxtFld?.label.text = "Enter Email"
        emailTxtFld?.setOutlineColor(.darkGray, for: .normal)
        emailTxtFld?.setOutlineColor(UIColor(hex: "223B30") ?? UIColor(), for: .editing)
        emailTxtFld?.translatesAutoresizingMaskIntoConstraints = false
        
        passwordTxtFld?.label.text = "Enter Password"
        passwordTxtFld?.setOutlineColor(.darkGray, for: .normal)
        passwordTxtFld?.setOutlineColor(UIColor(hex: "223B30") ?? UIColor(), for: .editing)
        passwordTxtFld?.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func callLoginAPI() {
        
        guard let username = emailTxtFld?.text,
              let password = passwordTxtFld?.text else {
            print("Missing credentials")
            return
        }
        
        let urlString = "https://login.salesforce.com/services/oauth2/token"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // ✅ Header
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // ✅ Body (IMPORTANT)
        let params = [
            "grant_type": "password",
            "client_id": "3MVG9RGN2EqkAxhJcefY0zQDmusOaghTywz_lpRRWuvNiRzyFpaDeWIVdNIVwJlR5mWWVjAvNkX9dKp3Cc.Bp",
            "client_secret": "8D197496F1B16033BCA5EC5CDBA5305DD85D17EFE601478503D7EEAD34C168B2",
            "username": "shubhanshu@cccinfotech.com",
            "password": "SCloud@2026SC8FnMq1EzxHNXv9x06tv0YiE"
        ]
        
        let bodyString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        // ✅ API Call
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            if let error = error {
                print("❌ Error:", error.localizedDescription)
                return
            }
            
            guard let data = data else {
                print("❌ No Data")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    print("✅ Response:", json)
                    
                    // ✅ Success Case
                    if let accessToken = json["access_token"] as? String {
                        
                        print("✅ Login Success")
                        
                        // Save token
                        UserDefaults.standard.set(accessToken, forKey: "access_token")
                        
                        DispatchQueue.main.async {
                            self.showInitialVC()
                        }
                        
                    } else {
                        // ❌ Error from Salesforce
                        let errorDesc = json["error_description"] as? String ?? "Login failed"
                        print("❌ Salesforce Error:", errorDesc)
                        
                        DispatchQueue.main.async {
                        
                        }
                    }
                }
            } catch {
                print("❌ JSON Error:", error.localizedDescription)
            }
            
        }.resume()
    }
    
    @IBAction func loginTapped(_ sender: UIButton) {
        callLoginAPI()
    }

    private func showInitialVC() {
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        let initialVC = storyboard.instantiateViewController(withIdentifier: "InitialVC")

        if let nav = navigationController {
            nav.setViewControllers([initialVC], animated: true)
            return
        }

        let nav = UINavigationController(rootViewController: initialVC)
        nav.setNavigationBarHidden(true, animated: false)

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = scene.delegate as? SceneDelegate,
           let window = sceneDelegate.window {
            window.rootViewController = nav
            window.makeKeyAndVisible()
        } else {
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }
    

    

}
