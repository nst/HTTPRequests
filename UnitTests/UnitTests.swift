//
//  UnitTests.swift
//  UnitTests
//
//  Created by nst on 25/04/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import XCTest

class UnitTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        
        let url = URL(string:"http://seriot.ch/objects.json")!
        let request = URLRequest(url: url)
        
        let expectationGoodType = expectation(description:"expectationGoodType")
        let expectationBadType = expectation(description:"expectationBadType")
        
        
        request.dr_fetchTypedJSON([[String:AnyObject]].self) {
            do {
                let (r, _) = try $0()
                XCTAssertEqual(r.status, 200)
                expectationGoodType.fulfill()
            } catch let e as NSError {
                print(e)
            }
        }

        request.dr_fetchTypedJSON([String:AnyObject].self) {
            do {
                let (_, _) = try $0()
                XCTFail()
            } catch let e as NSError {
                print(e)
                expectationBadType.fulfill()
            }
        }

        // Loop until the expectation is fulfilled
        waitForExpectations(timeout: 5, handler: { error in
            XCTAssertNil(error, "Error")
        })
    }
    
    
}
