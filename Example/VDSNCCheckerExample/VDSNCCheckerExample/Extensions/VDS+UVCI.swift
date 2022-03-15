//
//  VDS+UVCI.swift
//  VDSNCCheckerExample
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
import VDSNCChecker

/// An enum used to know if the UCVI is valid
public enum UVCIRange {
    case invalid
    case test
    case specimen
    case production
}

extension VDS {
    
    /// Checks the Australian UVCI number  range
    /// - Returns: range that the uvci falls in
    public func UVCIRange() -> UVCIRange {
        let value = data.msg.uvci
        
        if value.count < 4 {
            return .invalid
        }
        
        let testLimit = 998999
        let specimenLimit = 999999
        
        //get the number string, dont include the first two alpha chars, or the last check digit
        let numberStr = value.subString(2, to: value.count - 2)
        
        //get the check digit, the last digit
        let checkDigit = value.subString(value.count - 1, to: value.count - 1)
        
        //validate the check digit
        if !validateCheckDigit(value.subString(0, to: value.count - 2), check: checkDigit) {
            return .invalid
        }
        
        //check its numeric
        if !isNumericAllowedCharacter(numberStr) {
            return .invalid
        }
        
        //convert to number
        guard let number = Int(numberStr) else {
            return .invalid
        }
        
        //now check the range
        if number <= testLimit {
            return .test
        }
            
        if number <= specimenLimit {
            return .specimen
        }
         
        return .production
    }
    
    private func isNumericAllowedCharacter(_ value: String) -> Bool {
        let set = NSCharacterSet(charactersIn: "0123456789").inverted
        return value.rangeOfCharacter(from: set) == nil
    }
    
    /**
     data validation function
     
     :param: data The data that needs to be validated
     :param: check The checksum string for the validation
     
     :returns: Returns true if the data was valid
     */
    private func validateCheckDigit(_ data: String, check: String) -> Bool {
        // The check digit calculation is as follows: each position is assigned a value; for the digits 0 to 9 this is
        // the value of the digits, for the letters A to Z this is 10 to 35, for the filler < this is 0. The value of
        // each position is then multiplied by its weight; the weight of the first position is 7, of the second it is 3,
        // and of the third it is 1, and after that the weights repeat 7, 3, 1, etcetera. All values are added together
        // and the remainder of the final value divided by 10 is the check digit.
        
        var i: Int = 1
        var dc: Int = 0
        let w: [Int] = [7, 3, 1]
        let b0: UInt8 = "0".utf8.first!
        let b9: UInt8 = "9".utf8.first!
        let bA: UInt8 = "A".utf8.first!
        let bZ: UInt8 = "Z".utf8.first!
        let bK: UInt8 = "<".utf8.first!
        for c: UInt8 in Array(data.utf8) {
            var d: Int = 0
            if c >= b0 && c <= b9 {
                d = Int(c - b0)
            } else if c >= bA && c <= bZ {
                d = Int((10 + c) - bA)
            } else if c != bK {
                return false
            }
            dc = dc + d * w[(i-1)%3]
            i += 1
        }
        if dc%10 != Int(check) {
            return false
        }
        //NSLog("Item was valid")
        return true
    }
}
    
extension String {
    /**
     Get a substring
     
     :param: from from which character
     :param: to   to what character
     
     :returns: Return the substring
     */
    func subString(_ from: Int, to: Int) -> String {
        let f: String.Index = self.index(self.startIndex, offsetBy: from)
        let t: String.Index = self.index(self.startIndex, offsetBy: to + 1)
        let substring = String(self[f..<t])
        return substring
    }
}


