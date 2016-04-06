//
//  PBKDF2.swift
//  CryptoKitten
//
//  Created by Joannis Orlandos on 29/03/16.
//
//

import C7
import HMAC
import SHA1
import CryptoEssentials
import XCTest

public final class SHATests: XCTestCase {
    public func testMeasurements() {
        var data = [Byte]()
        data.append(contentsOf: "bobsaakpatat".utf8)
        let a = NSDate()
        
        measure {
            SHA1.calculate(data)
        }
        let b = NSDate()
        
        print(b.timeInterval(since: a))
    }
}