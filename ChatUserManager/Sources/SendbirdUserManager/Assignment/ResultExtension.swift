//
//  ResultExtension.swift
//  SendbirdUserManager
//
//  Created by Moonbeom KWON on 12/8/24.
//

extension Result {
    func fold(success successHandler: (Success) -> Void,
              failure failureHandler: (Failure) -> Void) {
        switch self {
        case .success(let value):
            successHandler(value)
        case .failure(let error):
            failureHandler(error)
        }
    }
    
    func fold(success successHandler: (Success) throws -> Void,
              failure failureHandler: (Failure) throws -> Void) throws {
        switch self {
        case .success(let value):
            try successHandler(value)
        case .failure(let error):
            try failureHandler(error)
        }
    }
}
