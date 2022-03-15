//
//  SecurityManager.swift
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
import UIKit

public protocol SecurityManagerDelegate: AnyObject {
    func screenRecordingStarted()
    func screenRecordingStopped()
}

public final class SecurityManager {
    
    // MARK: - Properties
    
    public weak var delegate: SecurityManagerDelegate?

    //debugger timers
    private var debuggerDisablingTimer: DispatchSourceTimer?
    private var debuggerDetectingTimer: DispatchSourceTimer?
    
    //privacy protection for moving app into the background
    private var privacyProtectionWindow: UIWindow?
    
    // MARK: - Lifecyle
    
    private static let sharedInstance: SecurityManager = {
        let instance = SecurityManager()
        
        return instance
    }()
    
    private init() {}
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Accessors
    
    public class func shared() -> SecurityManager {
        return sharedInstance
    }
    
    // MARK: - Jailbreak Detection
    
    public var isDeviceJailBroken: Bool {
        get {
            if UIDevice.current.isSimulator { return false }
            if JailBrokenHelper.hasCydiaInstalled() { return true }
            if JailBrokenHelper.hasSuspiciousApps() { return true }
            if JailBrokenHelper.hasSuspiciousSystemPaths() { return true }
            return JailBrokenHelper.canEditSystemFiles()
        }
    }
    
    public var isScreenBeingRecorded: Bool {
        get {
            return UIScreen.main.isCaptured
        }
    }
    
    // MARK: - Debugger
    
    public func startDisablingDebugger() {
        
        debuggerDisablingTimer = DispatchSource.makeTimerSource()
        debuggerDisablingTimer?.schedule(deadline: .now() + .seconds(20))
        debuggerDisablingTimer?.setEventHandler {
            DebuggerHelper.denyAttach()
        }
        debuggerDisablingTimer?.activate()
    }
    
    public func startDetectingDebugger() {
        
        debuggerDetectingTimer = DispatchSource.makeTimerSource()
        debuggerDetectingTimer?.schedule(deadline: .now() + .seconds(20))
        debuggerDetectingTimer?.setEventHandler {
            if DebuggerHelper.isDebuggerAttached() {
                exit(0)
            }
        }
        debuggerDetectingTimer?.activate()
    }
    
    // MARK: - Screen Protection
    
    /// prevents the contents of the screen being recorded, mirrored, sent over airplay, or otherwise cloned to another destination
    public func startDetectingScreenRecording() {
        // UIKit sends this notification when the capture status of the screen changes
        NotificationCenter.default.addObserver(self, selector: #selector(checkScreenRecording), name: UIScreen.capturedDidChangeNotification, object: nil)
        
        //check now in case its already recording before we subscribe to the change
        if isScreenBeingRecorded {
            delegate?.screenRecordingStarted()
        }
    }
    
    
    /// Checks to see if the screen is being recorded
    @objc private func checkScreenRecording() {
        
        if isScreenBeingRecorded {
            delegate?.screenRecordingStarted()
        } else {
            delegate?.screenRecordingStopped()
        }
    }
    
    public func showPrivacyProtectionWindow(for scene: UIWindowScene, color: UIColor? = UIColor.black) {
        
        let privacyVC = UIViewController()
        privacyVC.view.backgroundColor = color
        
        privacyProtectionWindow = UIWindow(windowScene: scene)
        privacyProtectionWindow?.rootViewController = privacyVC
        privacyProtectionWindow?.windowLevel = .alert + 1
        privacyProtectionWindow?.makeKeyAndVisible()
    }
    
    public func hidePrivacyProtectionWindow() {
        privacyProtectionWindow?.isHidden = true
        privacyProtectionWindow = nil
    }
}

extension UIDevice {
    
    var isSimulator: Bool {
        return TARGET_OS_SIMULATOR != 0
    }
    
}
