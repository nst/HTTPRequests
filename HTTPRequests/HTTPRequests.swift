//
//  HTTPRequests.swift
//  HTTPRequests
//
//  Created by Nicolas Seriot on 30/03/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Foundation

extension Error {
    func nsError(_ localizedDescription:String?, underlyingError:NSError? = nil) -> NSError {
        var userInfo : [AnyHashable: Any] = [:]
        if let s = localizedDescription {
            userInfo[NSLocalizedDescriptionKey] = s
        }
        if let u = underlyingError {
            userInfo[NSUnderlyingErrorKey] = u
        }
        return NSError(domain: self._domain, code: self._code, userInfo: userInfo)
    }
}

open class HTTPResponse : NSObject {
    
    public enum HTTPResponse: Error {
        case noData
        case unexpectedJSONType
    }
    
    open var status : Int = 0
    open var headers : [AnyHashable: Any] = [:]
    open var data : Data? = nil
    
    override public init() {
        super.init()
    }
    
    public init(status:Int, headers:[AnyHashable: Any], data:Data) {
        super.init()
        self.status = status
        self.headers = headers
        self.data = data
    }
    
    open func json<T>(_ type:T.Type) throws -> T {
        guard let existingData = self.data else {
            throw HTTPResponse.noData.nsError("No Data")
        }
        
        let json = try JSONSerialization.jsonObject(with: existingData, options: [])
        
        guard let typedJSON = json as? T else {
            throw HTTPResponse.unexpectedJSONType.nsError("Expected JSON type: \(type(of: type)), found: \(type(of: json))")
        }
        
        return typedJSON
    }
}

public enum HTTPResultType<T> {
    case success(httpResponse:HTTPResponse, value:T)
    case failure(httpResponse:HTTPResponse, nsError:NSError)
}

public enum DRError : Error {
    case error(httpResponse:HTTPResponse, nsError:NSError)
}

// 1. sum type
extension URLRequest {
    
    public func st_fetchData(_ completionHandler:@escaping (HTTPResultType<Data>)->()) {
        
        #if DEBUG
            print(self.curlDescription())
        #endif
        
        URLSession.shared.dataTask(with: self, completionHandler: { (optionalData, optionalResponse, optionalError) -> Void in
            
            DispatchQueue.main.async(execute: {
                
                guard let data = optionalData else {
                    guard let e = optionalError else { assertionFailure(); return }
                    completionHandler(.failure(httpResponse: HTTPResponse(), nsError: e as NSError))
                    return
                }
                
                guard let httpResponse = optionalResponse as? HTTPURLResponse else {
                    guard let e = optionalError else { assertionFailure(); return }
                    completionHandler(.failure(httpResponse: HTTPResponse(), nsError: e as NSError))
                    return
                }
                
                let response = HTTPResponse(
                    status:httpResponse.statusCode,
                    headers:httpResponse.allHeaderFields,
                    data:data)
                
                completionHandler(.success(httpResponse:response, value:data))
            })
            }) .resume()
    }
    
    public func st_fetchJSON(_ completionHandler:@escaping (HTTPResultType<AnyObject>)->()) {
        st_fetchTypedJSON(AnyObject.self) {
            completionHandler($0)
        }
    }
    
    public func st_fetchTypedJSON<T>(_ type:T.Type, completionHandler:@escaping (HTTPResultType<T>) -> ()) {
        st_fetchData { (result) -> () in
            
            switch(result) {
            case let .failure(httpResponse, nsError):
                completionHandler(.failure(httpResponse: httpResponse, nsError: nsError))
            case let .success(httpResponse, _):
                do {
                    completionHandler(.success(httpResponse: httpResponse, value: try httpResponse.json(T.self)))
                } catch let e as NSError {
                    completionHandler(.failure(httpResponse: httpResponse, nsError: e))
                }
            }
        }
    }
}

// 2. deferred result
extension URLRequest {
    
    public func dr_fetchData(_ completion:@escaping (_ result: () throws -> HTTPResponse) -> () ) {
        
        #if DEBUG
            print(self.curlDescription())
        #endif
        
        URLSession.shared.dataTask(with: self, completionHandler: { (optionalData, optionalResponse, optionalError) -> Void in
            
            DispatchQueue.main.async(execute: {
                
                guard let data = optionalData else {
                    guard let e = optionalError else { assertionFailure(); return }
                    completion({ throw e } )
                    return
                }
                
                guard let httpResponse = optionalResponse as? HTTPURLResponse else {
                    guard let e = optionalError else { assertionFailure(); return }
                    completion({ throw e } )
                    return
                }
                
                let response = HTTPResponse(
                    status:httpResponse.statusCode,
                    headers:httpResponse.allHeaderFields,
                    data:data)
                
                completion({ return response })
            })
            }) .resume()
    }
    
    public func dr_fetchJSON(_ completion:@escaping (_ result: () throws -> (httpResponse:HTTPResponse, json:AnyObject)) -> () ) {
        dr_fetchTypedJSON(AnyObject.self, completion: completion)
    }
    
    public func dr_fetchTypedJSON<T>(_ type:T.Type, completion:@escaping (_ result: () throws -> (httpResponse:HTTPResponse, json:T)) -> () ) {
        dr_fetchData {
            do {
                let httpResponse = try $0()
                completion({ return (httpResponse:httpResponse, json:try httpResponse.json(T.self)) } )
            } catch let e as NSError {
                completion({ throw e } )
            }
        }
    }
}

// 3. deferred result and DRError
extension URLRequest {
    
    public func dr2_fetchData(_ completion:@escaping (_ result: () throws -> HTTPResponse) -> () ) {
        
        #if DEBUG
            print(self.curlDescription())
        #endif
        
        URLSession.shared.dataTask(with: self, completionHandler: { (optionalData, optionalResponse, optionalError) -> Void in
            
            DispatchQueue.main.async(execute: {
                
                guard let data = optionalData else {
                    guard let e = optionalError else { assertionFailure(); return }
                    completion({ throw DRError.error(httpResponse:HTTPResponse(), nsError:e as NSError) } )
                    return
                }
                
                guard let httpResponse = optionalResponse as? HTTPURLResponse else {
                    guard let e = optionalError else { assertionFailure(); return }
                    completion({ throw DRError.error(httpResponse:HTTPResponse(), nsError:e as NSError) } )
                    return
                }
                
                let response = HTTPResponse(
                    status:httpResponse.statusCode,
                    headers:httpResponse.allHeaderFields,
                    data:data)
                
                completion({ return response })
            })
            }) .resume()
    }
    
    public func dr2_fetchJSON(_ completion:@escaping (_ result: () throws -> (httpResponse:HTTPResponse, json:AnyObject)) -> () ) {
        dr2_fetchTypedJSON(AnyObject.self, completion: completion)
    }
    
    public func dr2_fetchTypedJSON<T>(_ type:T.Type, completion:@escaping (_ result: () throws -> (httpResponse:HTTPResponse, json:T)) -> () ) {
        dr2_fetchData {
            do {
                let httpResponse = try $0()
                do {
                    let json = try httpResponse.json(T.self)
                    completion({ return (httpResponse:httpResponse, json:json) } )
                } catch let nsError as NSError { // JSON error
                    let dre = DRError.error(httpResponse:httpResponse, nsError:nsError)
                    completion({ throw dre } )
                } catch {
                    completion({ throw error } )
                }
            } catch let dre as DRError {
                completion({ throw dre } )
            } catch let nsError as NSError {
                completion({ throw DRError.error(httpResponse:HTTPResponse(), nsError:nsError) } )
            }
        }
    }
}

// 4. success and error closures
extension URLRequest {
    
    
    public func se_fetchData(successHandler:@escaping (HTTPResponse)->(), errorHandler:@escaping (NSError)->()) {
        
        #if DEBUG
            print(self.curlDescription())
        #endif
        
        URLSession.shared.dataTask(with: self, completionHandler: { (optionalData, optionalResponse, optionalError) -> Void in
            
            DispatchQueue.main.async(execute: {
                
                guard let data = optionalData else {
                    guard let e = optionalError else { assertionFailure(); return }
                    errorHandler(e as NSError)
                    return
                }
                
                guard let httpResponse = optionalResponse as? HTTPURLResponse else {
                    guard let e = optionalError else { assertionFailure(); return }
                    errorHandler(e as NSError)
                    return
                }
                
                let response = HTTPResponse(
                    status:httpResponse.statusCode,
                    headers:httpResponse.allHeaderFields,
                    data:data)
                
                successHandler(response)
            })
            }) .resume()
    }
    
    
    public func se_fetchJSON(
        successHandler:@escaping (HTTPResponse, AnyObject)->(),
                       errorHandler:@escaping (HTTPResponse, NSError)->()) {
        
        se_fetchTypedJSON(successHandler: { (httpResponse, json:AnyObject) in
            successHandler(httpResponse, json)
            }, errorHandler: { (httpResponse, error) in
                errorHandler(httpResponse, error)
        })
    }
    
    public func se_fetchTypedJSON<T>(
        successHandler:@escaping (HTTPResponse, T)->(),
                       errorHandler:@escaping (HTTPResponse, NSError)->()) {
        
        se_fetchData(
            successHandler:{ (httpResponse) in
                do {
                    let json = try httpResponse.json(T.self)
                    successHandler(httpResponse, json)
                } catch let e as NSError {
                    errorHandler(httpResponse, e)
                }
            }, errorHandler:{ (nsError) in
                errorHandler(HTTPResponse(), nsError)
        })
    }
    
}

// cURL description
extension URLRequest {
    
    public func curlDescription() -> String {
        
        var s = "\u{0001F340} curl -i \\\n"
        
        if let
            credential = self.requestCredential(),
            let user = credential.user,
            let password = credential.password
        {
            s += "-u \(user):\(password) \\\n"
        }
        
        if let method = self.httpMethod , method != "GET" {
            s += "-X \(method) \\\n"
        }
        
        self.allHTTPHeaderFields?.forEach({ (k,v) -> () in
            let kEscaped = k.replacingOccurrences(of: "\"", with: "\\\"")
            let vEscaped = v.replacingOccurrences(of: "\"", with: "\\\"")
            s += "-H \"\(kEscaped): \(vEscaped)\" \\\n"
        })
        
        if let url = self.url {
            if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
                for (_,v) in HTTPCookie.requestHeaderFields(with: cookies) {
                    s += "-H \"Cookie: \(v)\" \\\n"
                }
            }
        }
        
        if let bodyData = self.httpBody,
            let bodyString = NSString(data: bodyData, encoding: String.Encoding.utf8.rawValue) as? String {
            let bodyEscaped = bodyString.replacingOccurrences(of: "\"", with: "\\\"")
            s += "-d \"\(bodyEscaped)\" \\\n"
        }
        
        if let url = self.url {
            s += "\"\(url.absoluteString)\"\n"
        }
        
        return s
    }
    
    fileprivate func requestCredential() -> URLCredential? {
        
        guard let url = self.url else { return nil }
        guard let host = url.host else { return nil }
        
        let credentialsDictionary = URLCredentialStorage.shared.allCredentials
        
        for protectionSpace in credentialsDictionary.keys {
            
            if let c = credentialsDictionary.values.first?.values.first ,
                // we consider neither realm nor host, NSURL instance doesn't know them in advance
                (host as NSString).hasSuffix(protectionSpace.host) &&
                    protectionSpace.`protocol` == url.scheme {
                return c
            }
        }
        
        return nil
    }
}
