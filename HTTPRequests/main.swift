//
//  main.swift
//  HTTPRequests
//
//  Created by nst on 24/04/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Foundation

func requestWithSumType() {
    
    let url = NSURL(string:"http://seriot.ch/objects.json")!
    let request = NSURLRequest(URL: url)
    
    request.st_fetchData {
        switch($0) {
        case let .Success(r, data):
            print(r.status, data)
        case let .Failure(r, nsError):
            print(r.status, nsError.localizedDescription)
        }
    }
    
    request.st_fetchJSON {
        switch($0) {
        case let .Success(r, json) where 200..<300 ~= r.status:
            print(json)
        case let .Success(r, json) where r.status == 450:
            print(json)
        case let .Success(r, json):
            print(r.status, json)
        case let .Failure(r, nsError):
            print(r.status, nsError.localizedDescription)
        }
    }
    
    request.st_fetchTypedJSON([[String:AnyObject]].self) {
        switch($0) {
        case let .Success(r, json):
            print(r.status, json)
        case let .Failure(r, nsError):
            print(r.status, nsError.localizedDescription)
        }
    }
}

func requestWithDeferredResult() {
    
    let url = NSURL(string:"http://seriot.ch/objects.json")!
    let request = NSURLRequest(URL: url)
    
    request.dr_fetchData {
        do {
            let r = try $0()
            print(r.status, r.data)
        } catch let e as NSError {
            print(e)
        }
    }
    
    request.dr_fetchJSON() {
        do {
            let (r, json) = try $0()
            print(r.status, json)
        } catch let e as NSError {
            print(e)
        }
    }
    
    request.dr_fetchTypedJSON([[String:AnyObject]].self) {
        do {
            let (r, json) = try $0()
            print(r.status, json)
        } catch let e as NSError {
            print(e)
        }
    }
    
    request.dr_fetchData {
        if let r = try? $0() {
            print(r.status, r.data)
        }
    }
}

func requestWithDeferredResultAndDRError() {
    
    let url = NSURL(string:"http://seriot.ch/objects.json")!
    let request = NSURLRequest(URL: url)
    
    request.dr2_fetchJSON() {
        do {
            let (r, json) = try $0()
            print(r.status, json)
        } catch let DRError.Error(r, nsError) {
            print(r.status, nsError)
        } catch {
            print(error)
        }
    }
    
    request.dr2_fetchTypedJSON([[String:AnyObject]].self) {
        do {
            let (r, json) = try $0()
            print(r.status, json)
        } catch let DRError.Error(r, nsError) {
            print(r.status, nsError)
        } catch {
            print(error)
        }
    }
    
    request.dr2_fetchTypedJSON([[String:AnyObject]].self) {
        do {
            let (r, json) = try $0()
            print(r.status, json)
        } catch let DRError.Error(r, nsError) where r.status == 400 {
            print(r.status, nsError)
        } catch let DRError.Error(r, nsError) {
            print(r.status, nsError)
        } catch {
            assertionFailure()
        }
    }
}

func requestWithSuccessError() {
    
    let url = NSURL(string:"http://seriot.ch/objects.json")!
    let request = NSURLRequest(URL: url)
    
    request.se_fetchData(
        successHandler: { (r) in
            print(r.status, r.data)
        }, errorHandler: { (nsError) in
            print(nsError)
        }
    )
    
    request.se_fetchJSON(
        successHandler:{ (r, json) in
            print(json)
        }, errorHandler: { (r, nsError) in
            print(nsError)
        }
    )
    
    request.se_fetchTypedJSON(
        successHandler:{ (r, json:[[String:AnyObject]]) in
            print(json)
        }, errorHandler: { (r, nsError) in
            print(nsError)
        }
    )
}

func main() {
    
    requestWithSumType()
    
    requestWithDeferredResult()
    
    requestWithDeferredResultAndDRError()
    
    requestWithSuccessError()
    
    NSRunLoop.mainRunLoop().run()
}

main()
