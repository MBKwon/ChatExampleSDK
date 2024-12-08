//
//  ASUserInfoCache.swift
//  SendbirdUserManager
//
//  Created by Moonbeom KWON on 12/3/24.
//

import Foundation

class ASUserInfoCache: SBUserStorage {
    
    private var userDic: [String: SBUser] = [:]
    private let serialQueue: DispatchQueue = DispatchQueue(label: "ASUserInfoCache.serialQueue")
    
    func upsertUser(_ user: SBUser) {
        self.serialQueue.sync {
            userDic[user.userId] = user
        }
    }
    
    func getUsers() -> [SBUser] {
        self.serialQueue.sync {
            return Array(userDic.values)
        }
    }
    
    func getUsers(for nickname: String) -> [SBUser] {
        self.serialQueue.sync {
            return userDic.values.filter { userInfo in
                guard let userNickname = userInfo.nickname else { return false }
                return userNickname.lowercased().contains(nickname.lowercased())
            }
        }
    }
    
    func getUser(for userId: String) -> (SBUser)? {
        self.serialQueue.sync {
            return userDic[userId]
        }
    }
}
