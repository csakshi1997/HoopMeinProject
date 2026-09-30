//
//  SalesforceWebService.swift
//  HoopMeInApp
//
//  Created by Sakshi on 10/08/26.
//  Copyright © 2026 HoopMeInAppOrganizationName. All rights reserved.
//


import Foundation
import SalesforceSDKCore

struct EndPoints {
    var CHECK_PUNCHIN = "/services/apexrest/Attendance__c"
}
    
final class SalesforceWebService {
    func get(path: String, parameters: [String: Any]? = nil) async throws -> RestResponse {
        let request = RestRequest(method: .GET, path: path, queryParams: parameters)
        return try await RestClient.shared.send(request: request)
    }
    
    func post(path: String, body: [String: Any]) async throws -> RestResponse {
        let request = RestRequest(method: .POST, path: path, queryParams: nil)
        request.setCustomRequestBodyDictionary(body, contentType: "application/json")
        return try await RestClient.shared.send(request: request)
    }
    
    func put(path: String, body: [String: Any]) async throws -> RestResponse {
        let request = RestRequest(method: .PUT, path: path, queryParams: nil)
        request.setCustomRequestBodyDictionary(body, contentType: "application/json")
        return try await RestClient.shared.send(request: request)
    }
    
    func delete(path: String) async throws -> RestResponse {
        let request = RestRequest(method: .DELETE, path: path, queryParams: nil)
        return try await RestClient.shared.send(request: request)
    }
    
    func patch(path: String, body: [String: Any]) async throws -> RestResponse {
        let request = RestRequest(method: .PATCH, path: path, queryParams: nil)
        request.setCustomRequestBodyDictionary(body, contentType: "application/json")
        return try await RestClient.shared.send(request: request)
    }
    
}
