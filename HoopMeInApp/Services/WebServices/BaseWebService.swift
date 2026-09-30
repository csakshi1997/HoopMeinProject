//
//  BaseWebService.swift
//  FRATELLI
//
//  Created by Sakshi on 21/10/24.
//

import Foundation
import UIKit
//import Alamofire
import SalesforceSDKCore

enum ContentType: String {
    case multipart = "multipart/form-data"
    case json = "application/json"
    case urlEncoded = "application/x-www-form-urlencoded"
    case none = ""
}

let tokenExpiredErrorMessage = "Session expired or invalid"

class BaseWebService {
    let validation = Validation()
    func setLoader() {
        var config : SwiftLoader.Config = SwiftLoader.Config()
        config.size = 100
        config.spinnerColor = #colorLiteral(red: 0.2588235438, green: 0.7568627596, blue: 0.9686274529, alpha: 1)
        config.foregroundColor = .black
        config.foregroundAlpha = 0.5
        SwiftLoader.setConfig(config: config)
    }
    
    func getHeader(contentType: ContentType = .json) ->  [String: String] {
        var header: [String: String] = [:]
        if !(Defaults.accessToken ?? "").isEmpty {
            header["Authorization"] = "Bearer \(Defaults.accessToken ?? "")"
        }
        if contentType == .multipart {
            header["Content-Type"] = "multipart/form-data"
        } else if contentType == .json  {
            header["Content-Type"] = "application/json"
            header["accept"] = "application/json"
        } else if contentType == .urlEncoded  {
            header["Content-Type"] = "application/x-www-form-urlencoded"
        } else if contentType == .none {
        }
        return header
    }
    
    func sfPost(path: String, body: [String: Any]) async throws -> RestResponse {
        // Never put nested dicts/arrays in queryParams — Salesforce SDK casts them and crashes with
        // "Could not cast Swift.__SwiftDeferredNSArray to NSMutableArray".
        let request = RestRequest(method: .POST, path: path, queryParams: nil)
        request.setCustomRequestBodyDictionary(body, contentType: "application/json")
        return try await RestClient.shared.send(request: request)
    }
    
    func sfGet(path: String, params: [String: Any]? = nil) async throws -> RestResponse {
        let request = RestRequest(method: .GET, path: path, queryParams: params)
        return try await RestClient.shared.send(request: request)
    }
    
    func sfPutRequest(path: String, body: [String: Any]) async throws -> RestResponse {
        let request = RestRequest(method: .PUT, path: path, queryParams: nil)
        request.setCustomRequestBodyDictionary(body, contentType: "application/json")
        return try await RestClient.shared.send(request: request)
    }
    
    func sfDeleteRequest(path: String) async throws -> RestResponse {
        let request = RestRequest(method: .DELETE, path: path, queryParams: nil)
        return try await RestClient.shared.send(request: request)
    }
    
    func sfPatchRequest(path: String, body: [String: Any]) async throws -> RestResponse {
        let request = RestRequest(method: .PATCH, path: path, queryParams: nil)
        request.setCustomRequestBodyDictionary(body, contentType: "application/json")
        return try await RestClient.shared.send(request: request)
    }
    
    func sfGetWithHeader(path: String,
               params: [String: Any]? = nil,
               headers: [String: String]? = nil) async throws -> RestResponse {
        
        var request = RestRequest(method: .GET, path: path, queryParams: params)
        
        headers?.forEach { key, value in
            request.setHeaderValue(value, forHeaderName: key)
        }
        
        return try await RestClient.shared.send(request: request)
    }
}

