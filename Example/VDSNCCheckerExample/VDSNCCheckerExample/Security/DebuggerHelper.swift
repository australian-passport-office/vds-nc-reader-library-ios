//
//  Debugger.swift
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

public enum DebuggerHelper {
    
    /// Ensures no other debugger can attach to the calling process; if a debugger attempts to attach, the process will terminate
    public static func denyAttach() {
        disable_gdb()
    }
    
    /// Returns true if process is being debugged
    public static func isDebuggerAttached() -> Bool {
        if isBeingDebugged_sysctl() { return true }
        if isBeingDebugged_ppid() { return true }
        return false
    }
    
    private static func isBeingDebugged_ppid() -> Bool {
        // if a debugger starts an application, getppid returns a PID different than 1
        return getppid() != 1
    }
}
