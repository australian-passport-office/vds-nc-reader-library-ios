//
//  VDSViewController.swift
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

class VDSViewController: UIViewController {

    // MARK: - VaccinationInfo

    struct VaccinationInfo {
        let event: VDSVe?
        let details: VDSVd?
    }

    // MARK: - Properties
    
    @IBOutlet weak var resultTableView: UITableView!

    var vds: VDS!
    private var vaccinationInfos: [VaccinationInfo] = []

    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // detect screen recording
        SecurityManager.shared().delegate = self
        SecurityManager.shared().startDetectingScreenRecording()
        
        //detect if device is compromised
        checkIfDeviceIsCompromised()
        
        showResults(for: vds)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
       
    }
    
    // MARK: - Table
    
    private func showResults(for vds:VDS) {
        // Build vaccination infos
        for event in vds.data.msg.ve {
            vaccinationInfos.append(VaccinationInfo(event: event, details: nil))

            for details in event.vd {
                vaccinationInfos.append(VaccinationInfo(event: nil, details: details))
            }
        }

        // Display them
        resultTableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension VDSViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if vaccinationInfos.count > 0 {
            return 1 + vaccinationInfos.count
        }

        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cellToReturn = UITableViewCell()

        // First row - show header/message
        if indexPath.row == 0 {
            // Header/Message
            let cell = tableView.dequeueReusableCell(withIdentifier: "headerMessageTableViewCell", for: indexPath) as! HeaderMessageTableViewCell
         
            cell.setupWith(vds: vds)

            cellToReturn = cell
        } else {
            // Other rows - show vaccination info
            let info = vaccinationInfos[indexPath.row - 1]

            if let event = info.event {
                // Vaccination Event
                let cell = tableView.dequeueReusableCell(withIdentifier: "vaccinationEventTableViewCell", for: indexPath) as! VaccinationEventTableViewCell

                cell.setupWith(event: event)

                cellToReturn = cell
            } else if let details = info.details {
                // Vaccination Details
                let cell = tableView.dequeueReusableCell(withIdentifier: "vaccinationDetailsTableViewCell", for: indexPath) as! VaccinationDetailsTableViewCell

                cell.setupWith(details: details)

                cellToReturn = cell
            }
        }

        // Hide selections
        cellToReturn.selectionStyle = UITableViewCell.SelectionStyle.none
       
        return cellToReturn
    }
    
    // MARK: - Security
    
    private func checkIfScreenRecordingInProgress() {
        if SecurityManager.shared().isScreenBeingRecorded {
            resultTableView.isHidden = true
            showScreenIsBeingRecordedAlert()
        }
    }
    
    private func checkIfDeviceIsCompromised() {
        if SecurityManager.shared().isDeviceJailBroken {
            resultTableView.isHidden = true
            showDeviceCompromisedAlert()
        }
    }
    
    private func showScreenIsBeingRecordedAlert() {
        let alert = UIAlertController(
            title: "VDS cannot be displayed",
            message: "The screen is being recorded, mirrored, sent over airplay, or otherwise cloned to another destination",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.dismiss(animated: true)
        })

        present(alert, animated: true)
    }
    
    private func showDeviceCompromisedAlert() {
        let alert = UIAlertController(
            title: "VDS cannot be displayed",
            message: "The device has been compromised",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.dismiss(animated: true)
        })

        present(alert, animated: true)
    }
}

extension VDSViewController: SecurityManagerDelegate {
    func screenRecordingStarted() {
        checkIfScreenRecordingInProgress()
    }
    
    func screenRecordingStopped() {
        SecurityManager.shared().hidePrivacyProtectionWindow()
    }
}
