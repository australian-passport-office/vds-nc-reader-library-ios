//
//  VaccinationEventTableViewCell.swift
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

class VaccinationEventTableViewCell: UITableViewCell {

    // MARK: - Properties

    @IBOutlet weak var vaccineOrProphylaxisTitleLabel: UILabel!
    @IBOutlet weak var vaccineOrProphylaxisValueLabel: UILabel!
    @IBOutlet weak var vaccineBrandTitleLabel: UILabel!
    @IBOutlet weak var vaccineBrandValueLabel: UILabel!
    @IBOutlet weak var diseaseOrAgentTargetedTitleLabel: UILabel!
    @IBOutlet weak var diseaseOrAgentTargetedValueLabel: UILabel!

    // MARK: - Setup

    func setupWith(event: VDSVe) {
        vaccineOrProphylaxisTitleLabel.text = "Vaccine or Prophylaxis"
        vaccineOrProphylaxisValueLabel.text = event.des

        vaccineBrandTitleLabel.text = "Vaccine brand"
        vaccineBrandValueLabel.text = event.nam

        diseaseOrAgentTargetedTitleLabel.text = "Disease or agent targeted"
        diseaseOrAgentTargetedValueLabel.text = event.dis
    }
}
