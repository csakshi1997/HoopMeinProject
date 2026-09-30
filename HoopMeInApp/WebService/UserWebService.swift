//
//  UserWebService.swift
//  HoopMeInApp
//
//  Created by Sakshi on 20/11/25.
//  Copyright © 2025 HoopMeInAppOrganizationName. All rights reserved.
//

import Foundation
import SalesforceSDKCore

class UserWebService {

    let endPoint = EndPoints()
    let webRequest = SalesforceWebService()

    func fetchCurrentSalesforceUserDetails(
        outerClosure: @escaping (
            String?,
            [String: Any]?,
            ResponseStatus
        ) -> Void
    ) {

        guard let userAccount = UserAccountManager.shared.currentUserAccount,
              let userId = userAccount.credentials.userId else {

            print("❌ No logged-in Salesforce user")

            DispatchQueue.main.async {
                outerClosure(
                    "⚠️ No logged-in Salesforce user",
                    nil,
                    .error
                )
            }

            return
        }

        print("✅ Salesforce User ID:", userId)
        let soqlQuery = """
        SELECT Id, Name, Email, FirstName, LastName, Username
        FROM User
        WHERE Id = '\(userId)'
        """

        print("📡 SOQL Query:")
        print(soqlQuery)

        let restAPI = RestClient.shared

        let request = restAPI.request(
            forQuery: soqlQuery,
            apiVersion: "v62.0"
        )

        restAPI.send(
            request,

            failureBlock: { response, error, rawResponse in

                let statusCode =
                    (rawResponse as? HTTPURLResponse)?.statusCode

                print("❌ Salesforce request failed")
                print("❌ HTTP Status:", statusCode ?? -1)
                print(
                    "❌ Error:",
                    error?.localizedDescription ?? "Unknown error"
                )

                if statusCode == 401 {

                    DispatchQueue.main.async {
                        outerClosure(
                            "Unauthorized. Redirecting to login.",
                            nil,
                            .tokenExpired
                        )
                    }

                    return
                }

                DispatchQueue.main.async {
                    outerClosure(
                        error?.localizedDescription
                            ?? "Salesforce request failed",
                        nil,
                        .error
                    )
                }
            },

            successBlock: { response, rawResponse in

                print("======================================")
                print("✅ Salesforce User API success")
                print("======================================")

                print("🔍 Response type:", type(of: response))
                print("🔍 Response:", response as Any)

                print(
                    "🔍 HTTP Status:",
                    (rawResponse as? HTTPURLResponse)?.statusCode ?? -1
                )

                guard let jsonObject = response as? [String: Any] else {

                    print("❌ Unable to convert Salesforce response to dictionary")
                    print("❌ Actual response type:", type(of: response))

                    DispatchQueue.main.async {
                        outerClosure(
                            "Invalid Salesforce response format",
                            nil,
                            .error
                        )
                    }

                    return
                }

                print("✅ Salesforce response converted to dictionary")
                print("📦 JSON Object:", jsonObject)

                guard let records = jsonObject["records"] as? [[String: Any]] else {

                    print("❌ 'records' not found in Salesforce response")

                    DispatchQueue.main.async {
                        outerClosure(
                            "Salesforce user records not found",
                            nil,
                            .error
                        )
                    }

                    return
                }

                print("📦 Number of records:", records.count)

                guard let userDict = records.first else {

                    print("❌ No Salesforce user record found")

                    DispatchQueue.main.async {
                        outerClosure(
                            "User record not found",
                            nil,
                            .error
                        )
                    }

                    return
                }

                print("======================================")
                print("✅ Salesforce User Record")
                print("======================================")
                print("👤 Name:", userDict["Name"] as? String ?? "")
                print("📧 Email:", userDict["Email"] as? String ?? "")
                print("🔑 Username:", userDict["Username"] as? String ?? "")
                print("🆔 ID:", userDict["Id"] as? String ?? "")
                print("======================================")

                GlobalData.user = User(dict: userDict)

                DispatchQueue.main.async {
                    outerClosure(
                        nil,
                        userDict,
                        .success
                    )
                }
            }
        )
    }
    
    func checkPunchInFromSaleforce(
        payload: [String: Any],
        outerClosure: @escaping ((String?, [String: Any]?, ResponseStatus) -> ())
    ) {
        print(payload)
        Task {
            do {
                let response = try await webRequest.post(
                    path: "https://ability-site-6979.my.salesforce.com/services/apexrest/Attendance__c",
                    body: payload
                )
                
                if let jsonObject = try response.asJson() as? [String: Any] {
                    
                    DispatchQueue.main.async {
                        outerClosure(nil, jsonObject, .success)
                    }
                    
                } else {
                    
                    DispatchQueue.main.async {
                        outerClosure("Invalid JSON format", nil, .error)
                    }
                }
                
            } catch {
                print(error)
                
//                Utility.handleSalesforceError(error) { message, status in
//                    
//                    outerClosure(message, nil, status)
//                }
            }
        }
    }
    

    
}
