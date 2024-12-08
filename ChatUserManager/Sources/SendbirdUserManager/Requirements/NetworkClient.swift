//
//  NetworkClient.swift
//  
//
//  Created by Sendbird
//

import Foundation

public enum RequestType {
    case single(request: URLRequest)
    case multiple(requests: [URLRequest])
}

public protocol Request {
    associatedtype SingleDataType
    associatedtype Response
    
    var method: String { get }
    func getRequest(baseURL: String, token: String) throws -> RequestType
    func parseData(with data: Data) throws -> Result<SingleDataType, Error>
}

public protocol SBNetworkClient {
    /// 리퀘스트를 요청하고 리퀘스트에 대한 응답을 받아서 전달합니다
    func request<R: Request>(
        request: R,
        completionHandler: @escaping (Result<R.Response, Error>) -> Void
    )
}
