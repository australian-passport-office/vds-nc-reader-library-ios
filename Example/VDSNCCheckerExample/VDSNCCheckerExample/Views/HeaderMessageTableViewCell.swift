//
//  HeaderMessageTableViewCell.swift
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

class HeaderMessageTableViewCell: UITableViewCell {

    // MARK: - Properties

    @IBOutlet weak var typeTitleLabel: UILabel!
    @IBOutlet weak var typeValueLabel: UILabel!
    @IBOutlet weak var versionTitleLabel: UILabel!
    @IBOutlet weak var versionValueLabel: UILabel!
    @IBOutlet weak var issuingCountryTitleLabel: UILabel!
    @IBOutlet weak var issuingCountryValueLabel: UILabel!
    @IBOutlet weak var uvciTitleLabel: UILabel!
    @IBOutlet weak var uvciValueLabel: UILabel!
    @IBOutlet weak var nameTitleLabel: UILabel!
    @IBOutlet weak var nameValueLabel: UILabel!
    @IBOutlet weak var dateOfBirthTitleLabel: UILabel!
    @IBOutlet weak var dateOfBirthValueLabel: UILabel!
    @IBOutlet weak var travelDocumentNumberTitleLabel: UILabel!
    @IBOutlet weak var travelDocumentNumberValueLabel: UILabel!
    @IBOutlet weak var otherDocumentNumberTitleLabel: UILabel!
    @IBOutlet weak var otherDocumentNumberValueLabel: UILabel!
    @IBOutlet weak var sexTitleLabel: UILabel!
    @IBOutlet weak var sexValueLabel: UILabel!

    // MARK: - Setup

    func setupWith(vds: VDS) {
        typeTitleLabel.text = "Type"
        typeValueLabel.text = vds.data.hdr.t

        versionTitleLabel.text = "Version"
        versionValueLabel.text = "\(vds.data.hdr.v)"

        issuingCountryTitleLabel.text = "Issuing Country"
        issuingCountryValueLabel.text = vds.data.hdr.hdrIs

        uvciTitleLabel.text = "UVCI"
        uvciValueLabel.text = vds.data.msg.uvci

        nameTitleLabel.text = "Name"
        nameValueLabel.text = vds.data.msg.pid.n

        dateOfBirthTitleLabel.text = "Date of birth"
        dateOfBirthValueLabel.text = vds.data.msg.pid.dob

        travelDocumentNumberTitleLabel.text = "Travel Document Number"
        travelDocumentNumberValueLabel.text = vds.data.msg.pid.i

        otherDocumentNumberTitleLabel.text = "Other Document Number"
        otherDocumentNumberValueLabel.text = vds.data.msg.pid.ai

        sexTitleLabel.text = "Sex"
        sexValueLabel.text = vds.data.msg.pid.sex
    }
}
