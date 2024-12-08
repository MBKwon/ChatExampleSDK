//
//  ASNetworkRequests.swift
//  SendbirdUserManager
//
//  Created by Moonbeom KWON on 12/7/24.
//

import Foundation

enum APIError: Error {
    case unkwonError
    case invalidParameter
    case invalidURL
    case invalidData
    case invalidResponse
    case exceedRequest
    case typeCastError
    case partialSuccess(success: Any, error: Error)
}

enum APIRequest {
    static let timeout = 1.0
    
    struct ASCreateUserRequest: Request {
        typealias SingleDataType = SBUser
        typealias Response = SBUser
        let params: UserCreationParams
        var method: String { "POST" }
        
        func getRequest(baseURL: String, token: String) throws -> RequestType {
            let requestURL = baseURL.appending("/users")
            guard let url = URL(string: requestURL) else { throw APIError.invalidURL }
            
            var request = URLRequest(url: url)
            request.allHTTPHeaderFields = [
                "Content-Type": "application/json; charset=utf8",
                "Api-Token": token
            ]
            request.httpMethod = method
            var parameters: [String: String] = [
                "user_id": params.userId,
                "nickname": params.nickname,
            ]
            
            if let profileURL = params.profileURL {
                parameters["profile_url"] = profileURL
            }
            
            request.timeoutInterval = APIRequest.timeout
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            return .single(request: request)
        }
        
        func parseData(with data: Data) throws -> Result<SBUser, Error> {
            let userInfoDic = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let userInfoDic = userInfoDic, let userId = userInfoDic["user_id"] as? String {
                return .success(SBUser(userId: userId,
                                       nickname: userInfoDic["nickname"] as? String,
                                       profileURL: userInfoDic["profile_url"] as? String))
            } else {
                return .failure(APIError.invalidData)
            }
        }
    }
    struct ASGetUserRequest: Request {
        typealias SingleDataType = SBUser
        typealias Response = SBUser
        let id: String
        var method: String { "GET" }
        
        func getRequest(baseURL: String, token: String) throws -> RequestType {
            let requestURL = baseURL.appending("/users/\(id)")
            guard let url = URL(string: requestURL) else { throw APIError.invalidURL }
            
            var request = URLRequest(url: url)
            request.allHTTPHeaderFields = [
                "Content-Type": "application/json; charset=utf8",
                "Api-Token": token
            ]
            
            request.timeoutInterval = APIRequest.timeout
            request.httpMethod = method
            return .single(request: request)
        }
        
        func parseData(with data: Data) throws -> Result<SBUser, Error> {
            let userInfoDic = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let userInfoDic = userInfoDic, let userId = userInfoDic["user_id"] as? String {
                return .success(SBUser(userId: userId,
                                       nickname: userInfoDic["nickname"] as? String,
                                       profileURL: userInfoDic["profile_url"] as? String))
            } else {
                return .failure(APIError.invalidData)
            }
        }
    }
    struct ASUpdateUserRequest: Request {
        typealias SingleDataType = SBUser
        typealias Response = SBUser
        let params: UserUpdateParams
        var method: String { "PUT" }
        
        func getRequest(baseURL: String, token: String) throws -> RequestType {
            let requestURL = baseURL.appending("/users/\(params.userId)")
            guard let url = URL(string: requestURL) else { throw APIError.invalidURL }
            
            var request = URLRequest(url: url)
            request.allHTTPHeaderFields = [
                "Content-Type": "application/json; charset=utf8",
                "Api-Token": token
            ]
            request.httpMethod = method
            var parameters: [String: String] = [:]
            if let nickname = params.nickname {
                parameters["nickname"] = nickname
            }
            
            if let profileURL = params.profileURL {
                parameters["profile_url"] = profileURL
            }
            
            request.timeoutInterval = APIRequest.timeout
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            return .single(request: request)
        }
        
        func parseData(with data: Data) throws -> Result<SBUser, Error> {
            let userInfoDic = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let userInfoDic = userInfoDic, let userId = userInfoDic["user_id"] as? String {
                return .success(SBUser(userId: userId,
                                       nickname: userInfoDic["nickname"] as? String,
                                       profileURL: userInfoDic["profile_url"] as? String))
            } else {
                return .failure(APIError.invalidData)
            }
        }
    }
    struct ASCreateUsersRequest: Request {
        typealias SingleDataType = SBUser
        typealias Response = [SBUser]
        let params: [UserCreationParams]
        var method: String { "POST" }
        
        func getRequest(baseURL: String, token: String) throws -> RequestType {
            let requestURL = baseURL.appending("/users")
            guard let url = URL(string: requestURL) else { throw APIError.invalidURL }
            
            let requestList = try params.map { internalParams in
                var request = URLRequest(url: url)
                request.allHTTPHeaderFields = [
                    "Content-Type": "application/json; charset=utf8",
                    "Api-Token": token
                ]
                request.httpMethod = method
                var parameters: [String: String] = [
                    "user_id": internalParams.userId,
                    "nickname": internalParams.nickname
                ]
                
                if let profileURL = internalParams.profileURL {
                    parameters["profile_url"] = profileURL
                }
                
                request.timeoutInterval = APIRequest.timeout
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                return request
            }
            
            return .multiple(requests: requestList)
        }
        
        func parseData(with data: Data) throws -> Result<SBUser, Error> {
            let userInfoDic = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let userInfoDic = userInfoDic, let userId = userInfoDic["user_id"] as? String {
                return .success(SBUser(userId: userId,
                                        nickname: userInfoDic["nickname"] as? String,
                                        profileURL: userInfoDic["profile_url"] as? String))
            } else {
                return .failure(APIError.invalidData)
            }
        }
    }
    struct ASGetUsersRequest: Request {
        typealias SingleDataType = [SBUser]
        typealias Response = [SBUser]
        let nickname: String
        let limit: Int = 10
        var method: String { "GET" }
        
        func getRequest(baseURL: String, token: String) throws -> RequestType {
            let encodedNickname = nickname.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            let requestURL = baseURL.appending("/users?nickname_startswith=\(encodedNickname)&limit=\(limit)")
            
            guard let url = URL(string: requestURL) else { throw APIError.invalidURL }
            
            var request = URLRequest(url: url)
            request.allHTTPHeaderFields = [
                "Content-Type": "application/json; charset=utf8",
                "Api-Token": token
            ]
            
            request.timeoutInterval = APIRequest.timeout
            request.httpMethod = method
            return .single(request: request)
        }
        
        func parseData(with data: Data) throws -> Result<[SBUser], Error> {
            let userResponseDic = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let userList = userResponseDic?["users"] as? [[String: Any]] else { return .failure(APIError.invalidData) }
            
            var resultUserList: [SBUser] = []
            for userInfoDic in userList {
                if let userId = userInfoDic["user_id"] as? String {
                    resultUserList.append(SBUser(userId: userId,
                                                 nickname: userInfoDic["nickname"] as? String,
                                                 profileURL: userInfoDic["profile_url"] as? String))
                } else {
                    return .failure(APIError.invalidData)
                }
            }
            return .success(resultUserList)
        }
    }
}
