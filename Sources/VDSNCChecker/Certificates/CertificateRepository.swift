//
//  CertificateRepository.swift
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
import UIKit


/// The methods that you use to receive events from an associated certificate repository object.
public protocol CertificateRepositoryDelegate: AnyObject {
    /// the CRL data has been updated
    func didUpdateCRLData()
}

/// A convenient interface for the managing, updating and storing of CSCA Certificates
///
/// A Certifiate Repository lets you store ``CSCACertificate`` objects and can manage the routine updating of the ``CRL`` objects
///
public final class CertificateRepository {
    
    // MARK: - Properties
    
    /// the CSCA certificates being managed
    public var cscaCertificates: [CSCACertificate] = []
            
    /// defaults to 10 days
    public var maxSecondsBeforeOverdue = 86400 * 10 // 10 days
    
    /// returns true if any of the CRLs are overdue for an update
    public var isUpdateOverdue : Bool {
        get {
            return !crls.allSatisfy { crl in
                !crl.isUpdateOverdue()
            }
        }
    }
    
    private var crls : [CRL] {
        get {
            return cscaCertificates.compactMap( { $0.crl })
        }
    }
    
    /// The delegate object to receive events.
    public weak var delegate: CertificateRepositoryDelegate?
    
    /// Timer to take care of automatically running the updates
    private var updateTimer: Timer?
    
    /// Flag to check whether a scheduled update failed because of a connectivity issue
    private var didFailAutoUpdateWithConnectivity: Bool = false
    
    // MARK: - Lifecyle
    
    private static let sharedInstance: CertificateRepository = {
        let instance = CertificateRepository()
        // setup
        instance.setupReachabilityNotifier()
        return instance
    }()
    
    private init() {}
    
    deinit {
        updateTimer?.invalidate()
    }
    
    // MARK: - Accessors
    
    public class func shared() -> CertificateRepository {
        return sharedInstance
    }
    
       
    // MARK: - Auto Update CRLs
    
    /// Starts off the timer to auto update the CRL data, defaults to running every 86400 seconds (1 day)
    /// - Parameter secondsBetweenUpdates: the seconds between timer updates, defaults to 86400
    public func startAutoUpdatingCRLData(secondsBetweenUpdates : Int = 86400) {
        updateTimer = Timer.scheduledTimer(timeInterval: TimeInterval(secondsBetweenUpdates), target: self, selector: #selector(updateTimerFired), userInfo: nil, repeats: true)
        updateTimer?.fire()
    }
    
    /// Stop the automatic downloads of the CRL data
    public func stopAutoUpdatingCRLData() {
        updateTimer?.invalidate()
    }
    
    /// Called when the auto update timer fires
    @objc private func updateTimerFired() {
    
        updateCRLData { 
            self.delegate?.didUpdateCRLData()
        }
   
        didFailAutoUpdateWithConnectivity = !Reachability.shared.isReachable
    }
    
    // MARK: - Manually update CRLs
        
    /// Manually update the CRL Data
    /// - Parameter completion: completion for when all CRLs are updated
    public func updateCRLData(completion: @escaping () -> Void) {
        
        let dispatchGroup = DispatchGroup()
        let updatableCRLs = crls.filter { crl in
            return crl.url != nil
        }
        for crl in updatableCRLs {
            dispatchGroup.enter()
            crl.update(completion: { success in
                dispatchGroup.leave()
            })
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main, execute: {
            completion()
        })
    }
    
    // MARK: - Reachability / Connectivity
    
    
    /// Set up monitoring for network changes / reachability
    private func setupReachabilityNotifier() {
        Reachability.shared.startMonitoring()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reachabilityChanged(note:)),
            name: .reachabilityChanged,
            object: nil
        )
    }
    
    /// Fires when notification comes in for a network reachability change
    /// - Parameter note: notification
    @objc func reachabilityChanged(note: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if Reachability.shared.isReachable && self.didFailAutoUpdateWithConnectivity {

                self.updateTimer?.fire()
            }
        }
    }
}

private extension CRL {
        
    /// Checks if an update is overdue by determining if X many days have passed since the last update.
    /// For example, an update may be overdue if there has been no update in the last 90 days.
    ///
    /// - Returns: `true` if an update is overdue, `false` otherwise
    func isUpdateOverdue() -> Bool {
        if url == nil {
            return false
        }
        guard let downloadedDate = dateLastDownloaded else {
            //not yet downloaded
            return true
        }
        
        // downloaded previously, check if its overdue for next download
        let secondsSinceLastUpdate = Int(Date().timeIntervalSince(downloadedDate))
        return secondsSinceLastUpdate >= CertificateRepository.shared().maxSecondsBeforeOverdue
    }
}
