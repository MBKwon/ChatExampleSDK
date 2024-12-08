//
//  ASUserManager.swift
//  SendbirdUserManager
//
//  Created by Moonbeom KWON on 12/3/24.
//

import Foundation

class ASUserManager: SBUserManager {
    
    var networkClient: SBNetworkClient = ASNetwork(with: "", token: "")
    var userStorage: SBUserStorage = ASUserInfoCache()
    
    private var applicationId: String?
    private var apiToken: String?
    
    func initApplication(applicationId: String, apiToken: String) {
        if self.applicationId != applicationId {
            self.networkClient = ASNetwork(with: applicationId, token: apiToken)
            self.userStorage = ASUserInfoCache()
        }
        
        self.applicationId = applicationId
        self.apiToken = apiToken
    }
    
    func createUser(params: UserCreationParams, completionHandler: ((UserResult) -> Void)?) {
        self.networkClient.request(request: APIRequest.ASCreateUserRequest(params: params)) { [weak self] in
            guard let self = self else { return }
            switch $0 {
            case .success(let user):
                self.userStorage.upsertUser(user)
            case .failure:
                do { }
            }
            completionHandler?($0)
        }
    }
    
    func createUsers(params: [UserCreationParams], completionHandler: ((UsersResult) -> Void)?) {
        self.networkClient.request(request: APIRequest.ASCreateUsersRequest(params: params)) { [weak self] in
            guard let self = self else { return }
            switch $0 {
            case .success(let users):
                users.forEach(self.userStorage.upsertUser)
            case .failure(let error):
                if case APIError.partialSuccess(let success, _) = error,
                   let userList = success as? [Result<SBUser, Error>] {
                    userList.compactMap({ result in
                        switch result {
                        case .success(let userInfo): return userInfo
                        case .failure: return nil
                        }
                    }).forEach(self.userStorage.upsertUser)
                }
            }
            completionHandler?($0)
        }
    }
    
    func updateUser(params: UserUpdateParams, completionHandler: ((UserResult) -> Void)?) {
        self.networkClient.request(request: APIRequest.ASUpdateUserRequest(params: params)) { [weak self] in
            guard let self = self else { return }
            switch $0 {
            case .success(let user):
                self.userStorage.upsertUser(user)
            case .failure:
                do { }
            }
            completionHandler?($0)
        }
    }
    
    func getUser(userId: String, completionHandler: ((UserResult) -> Void)?) {
        if let user = self.userStorage.getUser(for: userId) {
            completionHandler?(.success(user))
        } else {
            self.networkClient.request(request: APIRequest.ASGetUserRequest(id: userId)) {
                completionHandler?($0)
            }
        }
    }
    
    func getUsers(nicknameMatches: String, completionHandler: ((UsersResult) -> Void)?) {
        if nicknameMatches.isEmpty {
            completionHandler?(.failure(APIError.invalidParameter))
        } else {
            let users = self.userStorage.getUsers(for: nicknameMatches)
            if users.count > 0 {
                completionHandler?(.success(users))
            } else {
                self.networkClient.request(request: APIRequest.ASGetUsersRequest(nickname: nicknameMatches)) {
                    completionHandler?($0)
                }
            }
        }
    }
}
