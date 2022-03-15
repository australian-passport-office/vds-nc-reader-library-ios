//
//  AppDelegate.swift
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

import UIKit
import VDSNCChecker

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        setupCSCAs()
                 
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: CSCA Certificates
    
    func setupCSCAs() {
        
        CertificateRepository.shared().cscaCertificates = []
                
        //create AUS Certificate
        
        if let ausCrlUrl = URL.init(string: "https://download.pkd.icao.int/CRLs/AUS.crl") {

            // if we have some hardcoded CRL data that we want to start off with, add here
            let ausCrlData = Constants.crlData

            // create CRL object, with some intial data, and the URL that will be used to make sure the data is updated
            let ausCrl = CRL.init(updatingURL:ausCrlUrl, initialCrlData: ausCrlData)

            // create a CSCA certificate
            let cscaCertificate = CSCACertificate(data: Constants.cscaCertData, integrityHash: Constants.cscaCertSHA256Hash, crl: ausCrl)
            
            // add the CSCA certificate to the repositiory
            CertificateRepository.shared().cscaCertificates.append(cscaCertificate)
        }
        
  
        //start auto monitoring crls
        #if DEBUG
        CertificateRepository.shared().startAutoUpdatingCRLData(secondsBetweenUpdates: 20)
        CertificateRepository.shared().maxSecondsBeforeOverdue = 60
        #else
        CertificateRepository.shared().startAutoUpdatingCRLData()
        #endif
        
    }

}

