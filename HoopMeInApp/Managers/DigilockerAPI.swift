//
//  DigilockerAPI.swift
//  GaurSonsApp
//
//  Created by Sakshi on 03/10/25.
//  Copyright © 2025 GaurSonsAppOrganizationName. All rights reserved.
//

import Foundation

final class DigilockerService {
    
    private func makeRequest(url: String, body: [String: Any]) -> URLRequest? {
        guard let requestURL = URL(string: url) else { return nil }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(applictionId, forHTTPHeaderField: "x-parse-application-id")
        request.addValue(ApiKey, forHTTPHeaderField: "x-parse-rest-api-key")
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        return request
    }
    
    func generateReferenceId() -> String {
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return String(uuid.prefix(16)) // take first 16 chars
    }
    
    func generateDigilockerLink(referenceId: String, completion: @escaping (Result<(String, String), Error>) -> Void) {
        let urlString = generateLinkUrl
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(applictionId, forHTTPHeaderField: "x-parse-application-id")
        request.setValue(ApiKey, forHTTPHeaderField: "x-parse-rest-api-key")
        
        let body: [String: Any] = [
            "reference_id": referenceId,
            "source": "AADHAAR"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: -1)))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("API Response: \(json)")
                    
                    if let status = json["status"] as? String, status == "success",
                       let result = json["result"] as? [String: Any],
                       let link = result["link"] as? String,
                       let txnId = json["transaction_id"] as? String {
                        completion(.success((link, txnId)))
                    } else {
                        completion(.failure(NSError(domain: "InvalidResponse", code: -2)))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    func getAadhaarDetails(referenceId: String, transactionId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let body: [String: Any] = [
            "reference_id": referenceId,
            "transaction_id": transactionId
        ]
        
        guard let request = makeRequest(url: getAadhaarDetailsUrl, body: body) else { return }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    completion(.success(json))
                } else {
                    completion(.failure(NSError(domain: "ParseError", code: -1)))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
