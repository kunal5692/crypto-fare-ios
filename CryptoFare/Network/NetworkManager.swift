//
//  NetworkManager.swift
//  CryptoFare
//
//  Created by kunal.ch on 11/09/18.
//  Copyright © 2018 CryptoFare. All rights reserved.
//

import Foundation

//MARK: Enum for handling network error
public enum NetworkError : Swift.Error {
    case invalidURL
    case noData
}

//MARK: Enum for http method
public enum HTTPMethod : String {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
    case patch = "PATCH"
}

//MARK: Request Data
public struct RequestData {
    public let path : String
    public let method : HTTPMethod
    public let params : [String : Any?]?
    public let headers : [String : String]?

    public init(
        path : String,
        method : HTTPMethod = .get,
        params : [String : Any?]? = nil,
        headers : [String : String]? = nil
        ) {
        self.path = path
        self.method = method
        self.params = params
        self.headers = headers
    }
}

//MARK: Network dispatcher
public protocol NetworkDispatcher {
    func dispatch(request : RequestData, onSuccess : @escaping (Data) -> Void, onError : @escaping (Error) -> Void)
}

//MARK: URLSessionNetworkDispatcher
public struct URLSessionNetworkDispatcher : NetworkDispatcher {
    public static let sharedInstance = URLSessionNetworkDispatcher.init()
    private init() {}
    
    public func dispatch(request: RequestData, onSuccess: @escaping (Data) -> Void, onError: @escaping (Error) -> Void) {
        guard let url = URL(string: request.path) else {
            onError(NetworkError.invalidURL)
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        
        do {
            if let params = request.params {
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: params, options: [])
            }
        } catch let error {
            onError(error)
            return
        }
        
        if let headers = request.headers {
            urlRequest.allHTTPHeaderFields = headers
        }
        
        URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
            if let err = error {
                onError(err)
                return
            }
            
            guard let _data = data else {
                onError(NetworkError.noData)
                return
            }
            
            onSuccess(_data)
        }.resume()
    }
    
}
//MARK: Request type
public protocol RequestType {
    associatedtype ResponseType : Codable
    var data : RequestData { get }
}

//MARK: Request type extension
public extension RequestType {
    public func execute(
        dispatcher : NetworkDispatcher = URLSessionNetworkDispatcher.sharedInstance,
        onSuccess : @escaping (ResponseType) -> Void,
        onError : @escaping (Error) -> Void
        ){
        dispatcher.dispatch(request: self.data, onSuccess: { (responseData : Data) in
            do {
                let jsonDecoder = JSONDecoder()
                let result = try jsonDecoder.decode(ResponseType.self, from: responseData)
                DispatchQueue.main.async {
                    onSuccess(result)
                }
            }catch let error {
                DispatchQueue.main.async {
                    onError(error)
                }
            }
        }, onError: {(error : Error) in
            DispatchQueue.main.async {
                onError(error)
            }
        })
        }
}
