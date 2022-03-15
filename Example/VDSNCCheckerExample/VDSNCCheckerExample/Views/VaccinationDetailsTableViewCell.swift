//
//  VaccinationDetailsTableViewCell.swift
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

class VaccinationDetailsTableViewCell: UITableViewCell {

    // MARK: - Properties

    @IBOutlet weak var dateOfVaccinationTitleLabel: UILabel!
    @IBOutlet weak var dateOfVaccinationValueLabel: UILabel!
    @IBOutlet weak var doseNumberTitleLabel: UILabel!
    @IBOutlet weak var doseNumberValueLabel: UILabel!
    @IBOutlet weak var countryOfVaccinationTitleLabel: UILabel!
    @IBOutlet weak var countryOfVaccinationValueLabel: UILabel!
    @IBOutlet weak var administeringCentreTitleLabel: UILabel!
    @IBOutlet weak var administeringCentreValueLabel: UILabel!
    @IBOutlet weak var vaccineBatchNumberTitleLabel: UILabel!
    @IBOutlet weak var vaccineBatchNumberValueLabel: UILabel!
    @IBOutlet weak var dueDateOfNextDoseTitleLabel: UILabel!
    @IBOutlet weak var dueDateOfNextDoseValueLabel: UILabel!

    // MARK: - Setup

    func setupWith(details: VDSVd) {
        dateOfVaccinationTitleLabel.text = "Date of vaccination"
        dateOfVaccinationValueLabel.text = details.dvc

        doseNumberTitleLabel.text = "Dose number"
        doseNumberValueLabel.text = "\(details.seq)"

        countryOfVaccinationTitleLabel.text = "Country of vaccination"
        countryOfVaccinationValueLabel.text = details.ctr

        administeringCentreTitleLabel.text = "Administering centre"
        administeringCentreValueLabel.text = details.adm

        vaccineBatchNumberTitleLabel.text = "Vaccine batch number"
        vaccineBatchNumberValueLabel.text = details.lot

        dueDateOfNextDoseTitleLabel.text = "Due date of next dose"
        dueDateOfNextDoseValueLabel.text = details.dvn
    }
}
