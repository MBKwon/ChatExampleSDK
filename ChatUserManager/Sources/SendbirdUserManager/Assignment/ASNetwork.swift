//
//  ASNetwork.swift
//  SendbirdUserManager
//
//  Created by Moonbeom KWON on 12/3/24.
//

import Foundation

fileprivate enum RequestTask {
    case single(singleRequest: URLRequest, dataHandler: (Result<Data, any Error>) -> Void)
    case multiple(requests: [URLRequest], dataList: [Data], dataHandler: (Result<[Data], any Error>) -> Void)
}

fileprivate extension Array where Element == RequestTask {
    func isExceedingLimit(with limit: Int) -> Bool {
        let currentTaskNum = self.reduce(0) { partialResult, task in
            switch task {
            case .single:
                return partialResult + 1
            case .multiple(let requests, _, _):
                return partialResult + requests.count
            }
        }
        
        return currentTaskNum >= limit
    }
}

class ASNetwork: SBNetworkClient {
    private let baseURL: String
    private let token: String
        
    private var requestQueue: [RequestTask] = []
    private var isWorking: Bool = false
    
    static let dispatchQueue = DispatchQueue.global(qos: .userInteractive)
    static let requestLimit = 10
    static let rateLimit = 1.0
    
    init(with applicationID: String, token: String) {
        self.baseURL = "https://api-\(applicationID).sendbird.com/v3"
        self.token = token
    }
    
    func request<R>(request: R, completionHandler: @escaping (Result<R.Response, any Error>) -> Void) where R : Request {
        guard requestQueue.isExceedingLimit(with: ASNetwork.requestLimit) == false else {
            completionHandler(.failure(APIError.exceedRequest))
            return
        }
        
        do {
            let requestData = try request.getRequest(baseURL: self.baseURL, token: self.token)
            
            switch requestData {
            case .single(let singleRequest):
                let processData: (Result<Data, any Error>) -> Void = { dataResult in
                    dataResult.fold { data in
                        do {
                            try request.parseData(with: data).fold { response in
                                if let successResult = response as? R.Response {
                                    completionHandler(.success(successResult))
                                } else {
                                    completionHandler(.failure(APIError.typeCastError))
                                }
                            } failure: { error in
                                completionHandler(.failure(error))
                            }
                        } catch let error {
                            completionHandler(.failure(error))
                        }
                    } failure: { error in
                        completionHandler(.failure(error))
                    }
                }
                
                requestQueue.append(.single(singleRequest: singleRequest,
                                            dataHandler: processData))
                
            case .multiple(let requests):
                let processData: (Result<[Data], any Error>) -> Void = { dataResult in
                    do {
                        try dataResult.fold { dataList in
                            let resultList = try dataList.map(request.parseData(with:))
                            var resultDataList: [R.SingleDataType] = []
                            var resultError: Error?
                            for result in resultList {
                                switch result {
                                case .success(let response):
                                    resultDataList.append(response)
                                case .failure(let error):
                                    resultError = error
                                }
                            }
                            
                            if resultDataList.count > 0, let successResult = resultDataList as? R.Response {
                                if let realError = resultError, case APIError.partialSuccess = realError {
                                    completionHandler(.failure(APIError.partialSuccess(success: successResult,
                                                                                       error: realError)))
                                } else {
                                    completionHandler(.success(successResult))
                                }
                            } else if let realError = resultError {
                                completionHandler(.failure(realError))
                            } else {
                                completionHandler(.failure(APIError.typeCastError))
                            }
                        } failure: { error in
                            if case APIError.partialSuccess(let success, let error) = error,
                               let dataList = success as? [Data] {
                                let resultList = try dataList.map(request.parseData(with:))
                                completionHandler(.failure(APIError.partialSuccess(success: resultList, error: error)))
                            } else {
                                completionHandler(.failure(error))
                            }
                        }
                    } catch let error {
                        completionHandler(.failure(error))
                    }
                }
                
                requestQueue.append(.multiple(requests: requests,
                                              dataList: [],
                                              dataHandler: processData))
            }
            
            if isWorking == false {
                isWorking = true
                ASNetwork.tickTimer(with: self)
            }
            
        } catch let error {
            completionHandler(.failure(error))
        }
    }
}

extension ASNetwork {
    private static func tickTimer(with network: ASNetwork) {
        guard let request = network.requestQueue.first else {
            network.isWorking = false
            return
        }
        
        switch request {
        case .single(let singleRequest, let dataHandler):
            URLSession.shared.dataTask(with: singleRequest,
                                       completionHandler: network.handleSingleRequest(dataHandler: dataHandler))
            .resume()
            
        case .multiple(var requests, let dataList, let dataHandler):
            let request = requests.removeFirst()
            URLSession.shared.dataTask(with: request,
                                       completionHandler: network.handleMultipleRequest(with: requests,
                                                                                        dataList: dataList,
                                                                                        dataHandler: dataHandler))
            .resume()
        }
    }
    
    private func handleSingleRequest(dataHandler: @escaping (Result<Data, any Error>) -> Void)
    -> (Data?, URLResponse?, Error?) -> Void {
        
        return { data, response, error in
            self.requestQueue.removeFirst()
            if let error = error {
                dataHandler(.failure(error))
            } else if let data = data {
                dataHandler(.success(data))
            } else {
                dataHandler(.failure(APIError.invalidResponse))
            }
            
            if self.requestQueue.count > 0 {
                ASNetwork.dispatchQueue
                    .asyncAfter(deadline: .now() + ASNetwork.rateLimit) {
                        ASNetwork.tickTimer(with: self)
                    }
            } else {
                self.isWorking = false
            }
        }
    }
    
    private func handleMultipleRequest(with requests: [URLRequest], dataList: [Data],
                                       dataHandler: @escaping (Result<[Data], any Error>) -> Void)
    -> (Data?, URLResponse?, Error?) -> Void {
        
        return { data, response, error in
            
            let handleFailure: (Error?) -> Void = { error in
                self.isWorking = false
                let concreteError: Error = error ?? APIError.invalidResponse
                if dataList.count > 0 {
                    dataHandler(.failure(APIError.partialSuccess(success: dataList,
                                                                 error: concreteError)))
                } else {
                    dataHandler(.failure(concreteError))
                }
            }
            
            if let data = data {
                var dataList: [Data] = dataList
                dataList.append(data)
                
                if dataList.count >= ASNetwork.requestLimit {
                    handleFailure(error)
                } else if requests.count == 0 {
                    self.isWorking = false
                    dataHandler(.success(dataList))
                } else {
                    self.requestQueue.insert(.multiple(requests: requests,
                                                       dataList: dataList,
                                                       dataHandler: dataHandler), at: 0)
                    ASNetwork.dispatchQueue
                        .asyncAfter(deadline: .now() + ASNetwork.rateLimit) {
                            ASNetwork.tickTimer(with: self)
                        }
                }
            } else {
                handleFailure(error)
            }
        }
    }
}
