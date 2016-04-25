//
//  HTTPRequests.swift
//  HTTPRequests
//
//  Created by Nicolas Seriot on 30/03/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Foundation

public class HTTPResponse : NSObject {
    
    public enum Error: ErrorType {
        case NoData
        case UnexpectedJSONType
    }
    
    public var status : Int = 0
    public var headers : [NSObject:AnyObject] = [:]
    public var data : NSData? = nil
    
    override public init() {
        super.init()
    }
    
    public init(status:Int, headers:[NSObject:AnyObject], data:NSData) {
        super.init()
        self.status = status
        self.headers = headers
        self.data = data
    }
    
    public func json<T>(type:T.Type) throws -> T {
        guard let existingData = self.data else {
            throw NSError(domain: "HTTPResponse", code: Error.NoData._code, userInfo: [NSLocalizedDescriptionKey:"No Data"])
        }
        
        let json = try NSJSONSerialization.JSONObjectWithData(existingData, options: [])
        
        guard let typedJSON = json as? T else {
            throw NSError(
                domain: "HTTPResponse",
                code: Error.UnexpectedJSONType._code,
                userInfo: [NSLocalizedDescriptionKey:"Expected JSON type: \(type.dynamicType), found: \(json.dynamicType)"]
            )
        }
        
        return typedJSON
    }
}

public enum HTTPResultType<T> {
    case Success(httpResponse:HTTPResponse, value:T)
    case Failure(httpResponse:HTTPResponse, nsError:NSError)
}

public enum DRError : ErrorType {
    case Error(httpResponse:HTTPResponse, nsError:NSError)
}

// 1. sum type
extension NSURLRequest {
    
    public func st_fetchData(completionHandler:(HTTPResultType<NSData>)->()) {
        
        #if DEBUG
            print(self.curlDescription())
        #endif
        
        NSURLSession.sharedSession().dataTaskWithRequest(self) { (optionalData, optionalResponse, optionalError) -> Void in
            
            dispatch_async(dispatch_get_main_queue(),{
                
                guard let data = optionalData else {
                    guard let e = optionalError else { assertionFailure(); return }
                    completionHandler(.Failure(httpResponse: HTTPResponse(), nsError: e))
                    return
                }
                
                guard let httpResponse = optionalResponse as? NSHTTPURLResponse else {
                    guard let e = optionalError else { assertionFailure(); return }
                    completionHandler(.Failure(httpResponse: HTTPResponse(), nsError: e))
                    return
                }
                
                let response = HTTPResponse(
                    status:httpResponse.statusCode,
                    headers:httpResponse.allHeaderFields,
                    data:data)
                
                completionHandler(.Success(httpResponse:response, value:data))
            })
            }.resume()
    }
    
    public func st_fetchJSON(completionHandler:(HTTPResultType<AnyObject>)->()) {
        st_fetchTypedJSON(AnyObject.self) {
            completionHandler($0)
        }
    }
    
    public func st_fetchTypedJSON<T>(type:T.Type, completionHandler:HTTPResultType<T> -> ()) {
        st_fetchData { (result) -> () in
            
            switch(result) {
            case let .Failure(httpResponse, nsError):
                completionHandler(.Failure(httpResponse: httpResponse, nsError: nsError))
            case let .Success(httpResponse, _):
                do {
                    completionHandler(.Success(httpResponse: httpResponse, value: try httpResponse.json(T)))
                } catch let e as NSError {
                    completionHandler(.Failure(httpResponse: httpResponse, nsError: e))
                }
            }
        }
    }
}

// 2. deferred result
extension NSURLRequest {
    
    public func dr_fetchData(completion:(result: () throws -> HTTPResponse) -> () ) {
        
        #if DEBUG
            print(self.curlDescription())
        #endif
        
        NSURLSession.sharedSession().dataTaskWithRequest(self) { (optionalData, optionalResponse, optionalError) -> Void in
            
            dispatch_async(dispatch_get_main_queue(), {
                
                guard let data = optionalData else {
                    guard let e = optionalError else { assertionFailure(); return }
                    completion(result: { throw e } )
                    return
                }
                
                guard let httpResponse = optionalResponse as? NSHTTPURLResponse else {
                    guard let e = optionalError else { assertionFailure(); return }
                    completion(result: { throw e } )
                    return
                }
                
                let response = HTTPResponse(
                    status:httpResponse.statusCode,
                    headers:httpResponse.allHeaderFields,
                    data:data)
                
                completion(result: { return response })
            })
            }.resume()
    }
    
    public func dr_fetchJSON(completion:(result: () throws -> (httpResponse:HTTPResponse, json:AnyObject)) -> () ) {
        dr_fetchTypedJSON(AnyObject.self, completion: completion)
    }
    
    public func dr_fetchTypedJSON<T>(type:T.Type, completion:(result: () throws -> (httpResponse:HTTPResponse, json:T)) -> () ) {
        dr_fetchData {
            do {
                let httpResponse = try $0()
                completion(result: { return (httpResponse:httpResponse, json:try httpResponse.json(T)) } )
            } catch let e as NSError {
                completion(result: { throw e } )
            }
        }
    }
}

// 3. deferred result and DRError
extension NSURLRequest {
    
    public func dr2_fetchData(completion:(result: () throws -> HTTPResponse) -> () ) {
        
        #if DEBUG
            print(self.curlDescription())
        #endif
        
        NSURLSession.sharedSession().dataTaskWithRequest(self) { (optionalData, optionalResponse, optionalError) -> Void in
            
            dispatch_async(dispatch_get_main_queue(), {
                
                guard let data = optionalData else {
                    guard let e = optionalError else { assertionFailure(); return }
                    completion(result: { throw DRError.Error(httpResponse:HTTPResponse(), nsError:e) } )
                    return
                }
                
                guard let httpResponse = optionalResponse as? NSHTTPURLResponse else {
                    guard let e = optionalError else { assertionFailure(); return }
                    completion(result: { throw DRError.Error(httpResponse:HTTPResponse(), nsError:e) } )
                    return
                }
                
                let response = HTTPResponse(
                    status:httpResponse.statusCode,
                    headers:httpResponse.allHeaderFields,
                    data:data)
                
                completion(result: { return response })
            })
            }.resume()
    }
    
    public func dr2_fetchJSON(completion:(result: () throws -> (httpResponse:HTTPResponse, json:AnyObject)) -> () ) {
        dr2_fetchTypedJSON(AnyObject.self, completion: completion)
    }
    
    public func dr2_fetchTypedJSON<T>(type:T.Type, completion:(result: () throws -> (httpResponse:HTTPResponse, json:T)) -> () ) {
        dr2_fetchData {
            do {
                let httpResponse = try $0()
                do {
                    let json = try httpResponse.json(T)
                    completion(result: { return (httpResponse:httpResponse, json:json) } )
                } catch let nsError as NSError { // JSON error
                    let dre = DRError.Error(httpResponse:httpResponse, nsError:nsError)
                    completion(result: { throw dre } )
                } catch {
                    completion(result: { throw error } )
                }
            } catch let dre as DRError {
                completion(result: { throw dre } )
            } catch let nsError as NSError {
                completion(result: { throw DRError.Error(httpResponse:HTTPResponse(), nsError:nsError) } )
            }
        }
    }
}

// 4. success and error closures
extension NSURLRequest {
    
    @objc
    public func se_fetchData(successHandler successHandler:(HTTPResponse)->(), errorHandler:(NSError)->()) {
        
        #if DEBUG
            print(self.curlDescription())
        #endif
        
        NSURLSession.sharedSession().dataTaskWithRequest(self) { (optionalData, optionalResponse, optionalError) -> Void in
            
            dispatch_async(dispatch_get_main_queue(),{
                
                guard let data = optionalData else {
                    guard let e = optionalError else { assertionFailure(); return }
                    errorHandler(e)
                    return
                }
                
                guard let httpResponse = optionalResponse as? NSHTTPURLResponse else {
                    guard let e = optionalError else { assertionFailure(); return }
                    errorHandler(e)
                    return
                }
                
                let response = HTTPResponse(
                    status:httpResponse.statusCode,
                    headers:httpResponse.allHeaderFields,
                    data:data)
                
                successHandler(response)
            })
            }.resume()
    }
    
    @objc
    public func se_fetchJSON(
        successHandler successHandler:(HTTPResponse, AnyObject)->(),
                       errorHandler:(HTTPResponse, NSError)->()) {
        
        se_fetchTypedJSON(successHandler: { (httpResponse, json:AnyObject) in
            successHandler(httpResponse, json)
            }, errorHandler: { (httpResponse, error) in
                errorHandler(httpResponse, error)
        })
    }
    
    public func se_fetchTypedJSON<T>(
        successHandler successHandler:(HTTPResponse, T)->(),
                       errorHandler:(HTTPResponse, NSError)->()) {
        
        se_fetchData(
            successHandler:{ (httpResponse) in
                do {
                    let json = try httpResponse.json(T)
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
extension NSURLRequest {
    
    public func curlDescription() -> String {
        
        var s = "\u{0001F340} curl -i \\\n"
        
        if let
            credential = self.requestCredential(),
            user = credential.user,
            password = credential.password
        {
            s += "-u \(user):\(password) \\\n"
        }
        
        if let method = self.HTTPMethod where method != "GET" {
            s += "-X \(method) \\\n"
        }
        
        self.allHTTPHeaderFields?.forEach({ (k,v) -> () in
            let kEscaped = k.stringByReplacingOccurrencesOfString("\"", withString: "\\\"")
            let vEscaped = v.stringByReplacingOccurrencesOfString("\"", withString: "\\\"")
            s += "-H \"\(kEscaped): \(vEscaped)\" \\\n"
        })
        
        if let url = self.URL {
            if let cookies = NSHTTPCookieStorage.sharedHTTPCookieStorage().cookiesForURL(url) {
                for (_,v) in NSHTTPCookie.requestHeaderFieldsWithCookies(cookies) {
                    s += "-H \"Cookie: \(v)\" \\\n"
                }
            }
        }
        
        if let bodyData = self.HTTPBody,
            bodyString = NSString(data: bodyData, encoding: NSUTF8StringEncoding) as? String {
            let bodyEscaped = bodyString.stringByReplacingOccurrencesOfString("\"", withString: "\\\"")
            s += "-d \"\(bodyEscaped)\" \\\n"
        }
        
        if let url = self.URL {
            s += "\"\(url.absoluteString)\"\n"
        }
        
        return s
    }
    
    private func requestCredential() -> NSURLCredential? {
        
        guard let url = self.URL else { return nil }
        guard let host = url.host else { return nil }
        
        let credentialsDictionary = NSURLCredentialStorage.sharedCredentialStorage().allCredentials
        
        for protectionSpace in credentialsDictionary.keys {
            
            if let c = credentialsDictionary.values.first?.values.first where
                // we consider neither realm nor host, NSURL instance doesn't know them in advance
                (host as NSString).hasSuffix(protectionSpace.host) &&
                    protectionSpace.`protocol` == url.scheme {
                return c
            }
        }
        
        return nil
    }
}
