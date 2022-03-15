//
//  JSONCanonicalizationTests.swift
//  VDSNCChecker
//
//  Copyright (c) 2021, Commonwealth of Australia. vds.support@dfat.gov.au
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not
//  use this file except in compliance with the License. You may obtain a copy
//  of the License at:
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
//  License for the specific language governing permissions and limitations
//  under the License.

import Foundation
import XCTest
@testable import VDSNCChecker

class JSONCanonicalizationTests: XCTestCase {
    func testNumbers() throws {
        
        let inputStr = """
        {
           "numbers": [333333333.33333329, 1E30, 4.50, 2e-3, 1]
        }
        """
        
        let expectedStr = """
        {"numbers":[333333333.3333333,1e+30,4.5,0.002,1]}
        """
        
        let data = try JsonCanonicalizer.canonicalize(json: inputStr)
        XCTAssertNotNil(data)
        let outputStr = String(data: data, encoding: String.Encoding.utf8)
        XCTAssertNotNil(outputStr)
        XCTAssertEqual(outputStr!, expectedStr)
        
        
    }
    
    // invalid Unicode data like "lone surrogates" (e.g. U+DEAD) may lead to interoperability issues including broken signatures, occurrences of such data should not be processed
    func testLoneSurrogates() throws {
        let inputStr = #"""
        {
           "lone surrogate": "\uDEAD"
        }
        """#
        
        XCTAssertThrowsError(try JsonCanonicalizer.canonicalize(json: inputStr))
      
       
    }
    
    // literals "null", "true", and "false" MUST be serialized as null, true, and false respectively
    func testLiterals() throws {
        let inputStr = """
        {
           "literals": [null, true, false]
        }
        """
        
        let expectedStr = """
        {"literals":[null,true,false]}
        """
        
        let data = try JsonCanonicalizer.canonicalize(json: inputStr)
        XCTAssertNotNil(data)
        let outputStr = String(data: data, encoding: String.Encoding.utf8)
        XCTAssertNotNil(outputStr)
        XCTAssertEqual(outputStr!, expectedStr)
    }
    
    // Whitespace between JSON tokens MUST NOT be emitted
    func testWhitespace() throws {
        let inputStr = """
        {
          "whitespace" : "remove",
          "more" : "whitespace",
        }
        """
        
        let expectedStr = """
        {"more":"whitespace","whitespace":"remove"}
        """
        
        let data = try JsonCanonicalizer.canonicalize(json: inputStr)
        XCTAssertNotNil(data)
        let outputStr = String(data: data, encoding: String.Encoding.utf8)
        XCTAssertNotNil(outputStr)
        XCTAssertEqual(outputStr!, expectedStr)
    }
    
    //locale must be ignored when sorting for canonicalization
    func testSortingLocale() throws {
        //set the test to the France region for this
        let inputStr = """
        {
          "peach": "This sorting order",
          "péché": "is wrong according to French",
          "pêche": "but canonicalization MUST",
          "sin":   "ignore locale"
        }
        """
        
        let expectedStr = """
        {"peach":"This sorting order","péché":"is wrong according to French","pêche":"but canonicalization MUST","sin":"ignore locale"}
        """
        
        let data = try JsonCanonicalizer.canonicalize(json: inputStr)
        XCTAssertNotNil(data)
        let outputStr = String(data: data, encoding: String.Encoding.utf8)
        XCTAssertNotNil(outputStr)
        XCTAssertEqual(outputStr!, expectedStr)
    }
    
    func testSortingStrings() throws {
        let inputStr = #"""
        {
            "\u20ac": "Euro Sign",
            "\r": "Carriage Return",
            "\ufb33": "Hebrew Letter Dalet With Dagesh",
            "1": "One",
            "\ud83d\ude00": "Emoji: Grinning Face",
            "\u0080": "Control",
          }
        """#
        
        let expectedStr = #"""
        {"\r":"Carriage Return","1":"One","":"Control","דּ":"Hebrew Letter Dalet With Dagesh","€":"Euro Sign","😀":"Emoji: Grinning Face"}
        """#
        
        let data = try JsonCanonicalizer.canonicalize(json: inputStr)
        XCTAssertNotNil(data)
        let outputStr = String(data: data, encoding: String.Encoding.utf8)
        XCTAssertNotNil(outputStr)
        XCTAssertEqual(outputStr!, expectedStr)
    
    }
    
    func testSortingStructures() throws {
        //Arrays keep their sort order, dictionaries must be sorted lexicographically
        let inputStr = #"""
        {
          "1": {"f": {"f": "hi","F": 5} ,"\n": 56.0},
          "10": { },
          "": "empty",
          "a": { },
          "111": [ {"e": "yes","E": "no" } ],
          "A": { }
        }
        """#
        
        let expectedStr = #"""
        {"":"empty","1":{"\n":56,"f":{"F":5,"f":"hi"}},"10":{},"111":[{"E":"no","e":"yes"}],"A":{},"a":{}}
        """#
        
        let data = try JsonCanonicalizer.canonicalize(json: inputStr)
        XCTAssertNotNil(data)
        let outputStr = String(data: data, encoding: String.Encoding.utf8)
        XCTAssertNotNil(outputStr)
        XCTAssertEqual(outputStr!, expectedStr)
    }
    
    func testStringValues() throws {
        
        let inputStr = #"""
        {
          "string":"\u20ac$\u000F\u000aA'\u0042\u0022\u005c\\\""
        }
        """#
        
        let expectedStr = #"""
        {"string":"€$\u000f\nA'B\"\\\\\""}
        """#
        
        let data = try JsonCanonicalizer.canonicalize(json: inputStr)
        XCTAssertNotNil(data)
        let outputStr = String(data: data, encoding: String.Encoding.utf8)
        XCTAssertNotNil(outputStr)
        XCTAssertEqual(outputStr!, expectedStr)
    }
    
    func testUnicode() throws {
        //Arrays keep their
        let inputStr = #"""
        {
          "Unnormalized Unicode":"A\u030a"
        }
        """#
        
        let expectedStr = #"""
        {"Unnormalized Unicode":"Å"}
        """#
        
        let data = try JsonCanonicalizer.canonicalize(json: inputStr)
        XCTAssertNotNil(data)
        let outputStr = String(data: data, encoding: String.Encoding.utf8)
        XCTAssertNotNil(outputStr)
        XCTAssertEqual(outputStr!, expectedStr)
    }
}
