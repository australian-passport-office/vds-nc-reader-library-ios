//
//  HomeViewController.swift
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
import AVFoundation
import VDSNCChecker
import CoreServices

class HomeViewController: UIViewController {
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    // MARK: - Camera Access
    
    /// Check to see if the app is authorized to use the camera
    private func checkVideoAuth() {
        
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch authorizationStatus {
        case .notDetermined:
            // The user has not yet been asked for camera access.
            requestCameraAccess()
        case .authorized:
            // The user has previously granted access to the camera.
            navigateToScanner(animated: true)
        case .denied:
            // The user has previously denied access.
            showNoCameraAccessAlert()
        case .restricted:
            // The user can't grant access due to restrictions.
            showNoCameraAccessAlert()
        @unknown default:
            return
        }
    }
    
    func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: AVMediaType.video,
                                      completionHandler: { (granted: Bool) -> Void in
                                        if granted {
                                            DispatchQueue.main.async { [weak self] in
                                                guard let self = self else { return }
                                                self.navigateToScanner(animated: true)
                                            }
                                        }
        })
    }
    
    /// if not authorised to show the camera, present an alert for guidance
    private func showNoCameraAccessAlert() {
        let alert = UIAlertController(title: "Camera Access",
                                      message: "To continue, you will need to allow camera access in Settings",
                                      preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .default) { _ in
            self.dismiss(animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                return
            }
            
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl, completionHandler: { (_) in
                })
            }
            self.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Actions
    
    @IBAction func scanWithCameraButtonAction(_ sender: Any) {
        
        checkVideoAuth()
    }
    
    @IBAction func tapOpenVDSPDFButton(_ sender: Any) {
        //Create a picker specifying file type and mode
        let documentPicker = UIDocumentPickerViewController.init(documentTypes: [kUTTypePDF as String], in: .import)
        
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true, completion: nil)
    }
    
    @IBAction func useExampleValidVDSButtonAction(_ sender: Any) {
        readVDSJson(vdsJson: Constants.validVDSJson)
    }
    
    @IBAction func useExampleInvalidVDSButtonAction(_ sender: Any) {
        readVDSJson(vdsJson: Constants.invalidVDSJson)
    }
    @IBAction func useExampleNonVDSButtonAction(_ sender: Any) {
        readVDSJson(vdsJson: Constants.nonVDSJson)
    }
    
    // MARK: - Navigation
    private func showResultForValidVDS(vds: VDS) {
        let storyBoard : UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let vdsViewController = storyBoard.instantiateViewController(withIdentifier: "vdsViewController") as! VDSViewController
        vdsViewController.vds = vds
        
        navigationController?.pushViewController(vdsViewController, animated: true)
    }
    
    private func showNotAuthenticVDS() {
        let storyBoard : UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let invalidViewController = storyBoard.instantiateViewController(withIdentifier: "invalidViewController")
        navigationController?.pushViewController(invalidViewController, animated: true)
    }
    
    private func showInfoViewController() {
        let storyBoard : UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let infoViewController = storyBoard.instantiateViewController(withIdentifier: "infoViewController")
        navigationController?.pushViewController(infoViewController, animated: true)
    }
    
    // MARK: - Using Camera
   
    func navigateToScanner(animated: Bool) {
        
        // Load scan view controller
        var configuration = ScanViewController.Configuration()
        configuration.navigationTitle = "VDS-NC Checker"
        configuration.hidesBackButton = false
        configuration.torchEnabled = true
        configuration.zoomEnabled = true
        configuration.dimBackground = true
        configuration.invalidVdsNcLabelText = "This code is not a VDS-NC"
        configuration.guideLabelText = "Align QR code within frame" 
     
        let scanViewController = ScanViewController(configuration: configuration, delegate: self)
        navigationController?.pushViewController(scanViewController, animated: animated)
      
    }
    
    // MARK: - Not Using Camera
        
    private func readVDSJson(vdsJson: String) {
        // Decode VDS
        let vds = try? VDSReader().decodeVDSFrom(jsonString: vdsJson)
        
        // Verify VDS
        let vdsAuthenticator = VDSAuthenticator()
        if let vds = vds {
            // Verify VDS
            if let _ = try? vdsAuthenticator.verify(
                vds: vds,
                withCscaCertificates: CertificateRepository.shared().cscaCertificates
            ) {
                // A valid VDS
                showResultForValidVDS(vds: vds)
            } else {
                // Not an authentic VDS
                showNotAuthenticVDS()
            }
        } else {
            // Not a VDS
            showNotAVDSAlert()
        }
    }
    
    ///   Finds and reads a VDS from an image
    /// - Parameter image: image as input to the QR code detector
    func findVDSInImage(_ image: UIImage) {
        var vdsFound = false
        
        let ciImage = CIImage(cgImage: image.cgImage!)
        
        let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let qrCodeDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: options)!
        
        let qrCodeFeatures = qrCodeDetector.features(in: ciImage)
        
        if let vdsStr = (qrCodeFeatures.first as? CIQRCodeFeature)?.messageString {
            vdsFound = true
            readVDSJson(vdsJson: vdsStr)
        }
        
        if !vdsFound {
            showNoVDSFoundAlert()
        }
    }
    
    private func showNotAVDSAlert() {
        let alert = UIAlertController(
            title: "Not a VDS",
            message: "This JSON is not a VDS",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.dismiss(animated: true)
        })

        present(alert, animated: true)
    }
    
    private func showNoVDSFoundAlert() {
        let alert = UIAlertController(
            title: "No VDS",
            message: "Unable to find a VDS",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
    
}



extension HomeViewController: ScanViewControllerDelegate {
    func didTapRightBarButton() {
        //show info screen
        showInfoViewController()
    }
    
    func didDetectNonVdsQrCode() {
        
    }
    
    func didFailVDSVerification(vdsVerificationError: VDSVerifyError?) {
        showNotAuthenticVDS()
    }
    
    func didSuccessfullyVerifyVds(vds: VDS) {
        showResultForValidVDS(vds: vds)
    }
}

extension HomeViewController: UIDocumentPickerDelegate {
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard controller.documentPickerMode == .import, let url = urls.first else { return }
        
        //load document as cgpdf
        guard let document = CGPDFDocument(url as CFURL) else { return }
        
        //get page we want to check for the VDS
        guard let page = document.page(at: 1) else { return }
        
        //convert page to image
        guard let image = page.toImage() else { return }
        
        //find VDS
        findVDSInImage(image)
        
        controller.dismiss(animated: true)
    }
    
    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
    }
    
}

extension CGPDFPage {
    
    /// Converts a CGPDF page to a UIImage
    /// - Returns: An image if successful, nil if not
    func toImage() -> UIImage? {
        let pageRect = self.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let img = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            
            ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            ctx.cgContext.drawPDFPage(self)
        }
        
        return img
    }
}
