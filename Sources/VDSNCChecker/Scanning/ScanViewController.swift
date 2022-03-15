//
//  ScanViewController.swift
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
import AVFoundation
import UIKit
import Vision


/// A set of methods that your delegate object must implement to interact with the scanner interface.
public protocol ScanViewControllerDelegate: AnyObject {
    
    /// Tells the delegate that the camera detected a QR code but it isnt a valid VDS
    ///
    func didDetectNonVdsQrCode()
    
    /// Tells the delegate that the user scanned a verified VDS.
    ///
    /// - Parameters:
    ///   - vds: The verified VDS that is scanned from the camera
    /// - Discussion: Your delegate's implementation of this method should dismiss the scanner controller.
    func didSuccessfullyVerifyVds(vds: VDS)
    
    /// Tells the delegate that the user scanned a VDS but it failed verification
    ///
    /// - Parameters:
    ///   - vdsVerificationError: The verification error
    /// - Discussion: Your delegate's implementation of this method should dismiss the scanner controller.
    func didFailVDSVerification(vdsVerificationError: VDSVerifyError?)
    
    /// Tells the delegate that the user tapped the right bar button
    ///
    /// - Discussion: Your delegate's implementation of this method should dismiss the scanner controller.
    func didTapRightBarButton()
    
}


/// A view controller that manages the the scanning and verifying of VDS-NC QR codes
///
/// The `ScanViewController` class is meant to be presented.
///
public final class ScanViewController: UIViewController {
    
    // MARK: - Properties
    
    /// The object that acts as the delegate of the `ScanViewController`.
    public weak var delegate: ScanViewControllerDelegate?
    
    private var configuration: ScanViewController.Configuration
    private var hasSetupPreviewOverlayUI = false
    private var isTorchOn = false
    private var isTorchAvailable = false
    private var isZoomOn = false
    private let impactFeedbackGenerator = UINotificationFeedbackGenerator()
    private let captureSession = AVCaptureSession()
    private var shapeMaskLayer: CAShapeLayer?
    private var barcodeOutlineBoxRect: CGRect?
    private var isScanningComplete = false
    private let torchOnButtonImage = UIImage(named: "iconTorchOn", in: .module, compatibleWith: nil)
    private let torchOffButtonImage = UIImage(named: "iconTorchOff", in: .module, compatibleWith: nil)
    private let zoomInButtonImage = UIImage(named: "iconZoomIn", in: .module, compatibleWith: nil)
    private let zoomOutButtonImage = UIImage(named: "iconZoomOut", in: .module, compatibleWith: nil)
    private let scanPlaceholderImage = UIImage(named: "bgScanPlaceholder", in: .module, compatibleWith: nil)
    private let warningImage = UIImage(named: "iconAlert", in: .module, compatibleWith: nil)
    private var isReadyToScan = false
    
    /// View at the bottom for displaying guide text
    lazy private var footerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    /// Guide Label  that appears to prompt the user to scan the QR code
    lazy private var guideLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.textColor = UIColor.white
        label.text = configuration.guideLabelText
        label.font = configuration.guideLabelFont
        return label
    }()
    
    /// View to contain the invalid QR code label
    lazy private var invalidQRCodeView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 175 / 255, green: 29 / 255, blue: 29 / 255, alpha: 0.8)
        view.layer.cornerRadius = 10
        return view
    }()
    
    /// Label to show invalid QR code message
    lazy private var invalidQRCodeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = NSTextAlignment.center
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = UIColor.white
        label.text = configuration.invalidVdsNcLabelText
        label.font = configuration.invalidVdsNcLabelFont
        return label
    }()
    
    /// Placeholder image view to guide position of the QR Code
    lazy private var barcodePlaceholderImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.image = scanPlaceholderImage
        return view
    }()
    
    /// Camera preview view
    lazy private var cameraView: CameraView = {
        let view = CameraView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    /// Torch button to toggle on/off device flashlight
    lazy private var torchButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(torchOffButtonImage, for: .normal)
        return button
    }()
    
    /// Zoom button to toggle between 1x and 2x zoom
    lazy private var zoomButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(zoomInButtonImage, for: .normal)
        return button
    }()
    
    /// View to hold the control buttons for zoom / flash
    lazy private var buttonsContainerStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 30
        return stack
    }()
    
    /// Warning view that holds the warning label
    lazy private var crlWarningView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.systemOrange
        return view
    }()
    
    lazy private var crlWarningIconImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.image = warningImage
        return view
    }()
    
    /// Warning Label that appears at the top of the screen for a warning message
    lazy private var crlWarningLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .left
        label.adjustsFontForContentSizeCategory = true
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.textColor = UIColor.black
        label.text = configuration.crlWarningLabelText
        label.font = configuration.crlWarningLabelFont
        return label
    }()
    
    
    /// Check to see if the app is authorized to use the camera
    /// - Returns: True or False
    private func isVideoAuthorized() -> Bool {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch authorizationStatus {
        case .notDetermined:
            return false
        case .authorized:
            return true
        case .denied, .restricted: return false
        @unknown default:
            return false
        }
    }
    
    
    // MARK: - Life cycle
    
    /// Initialize the ScanViewController
    /// - Parameters:
    ///   - configuration: configuration for scanning features and layouts
    ///   - delegate: delegate to recieve events
    public required init(configuration: ScanViewController.Configuration, delegate: ScanViewControllerDelegate? = nil) {
        
        self.delegate = delegate
        self.configuration = configuration
        
        super.init(nibName: nil, bundle: nil)
        
    }
    
    /// Initialize the ScanViewController
    /// - Parameters:
    ///   - configuration: configuration for scanning features and layouts
    ///   - delegate: delegate to recieve events
    ///   - nibNameOrNil: nib name or nil
    ///   - nibBundleOrNil: nib name or nil
    public required init(configuration: ScanViewController.Configuration, delegate: ScanViewControllerDelegate? = nil, nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.delegate = delegate
        self.configuration = configuration
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    public override func viewDidLoad() {
        
        super.viewDidLoad()
        
        setupUI()
        
        impactFeedbackGenerator.prepare()
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        CertificateRepository.shared().delegate = self
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        isScanningComplete = false
        
        startCamera()
        
        //torch
        isTorchOn = false
        toggleTorch(toOn: false)
        
        
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        // make sure the view has fully appeared before we start detecting QR codes, otherwise we could have navigation issues
        isReadyToScan = true
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        
        super.viewDidDisappear(animated)
        
        //reset zoom
        isZoomOn = false
        resetButtonImages()
        toggleZoom(toZoomed: false, withAnimation: false)
        
        //reset images
        resetButtonImages()
        
        //reset camera
        isReadyToScan = false
        tearDownCamera()
        
    }
    
    public override func viewDidLayoutSubviews() {
        
        super.viewDidLayoutSubviews()
        
        // Draw shape mask layer for QR code placeholder
        shapeMaskLayer?.drawShapeMaskLayer(
            boundingViewBox: view.bounds,
            shape: Shape.rectangle,
            boundingBox: barcodeOutlineBoxRect ?? CGRect(),
            fillColor: configuration.dimBackground ? (shapeMaskLayer?.fillColor)! : UIColor.clear.cgColor,
            strokeColor: (shapeMaskLayer?.strokeColor)!)
        
        if let shapeMask = shapeMaskLayer {
            cameraView.layer.addSublayer(shapeMask)
        }
    }
    
    /// Fires when notified the app has moved into the background
    @objc func appMovedToBackground() {
        isTorchOn = false
        resetButtonImages()
    }
    
    // MARK: - UI
    
    private func setupUI() {
        title = configuration.navigationTitle
        navigationController?.title = configuration.navigationTitle
        navigationItem.hidesBackButton = configuration.hidesBackButton
        navigationItem.backBarButtonItem = UIBarButtonItem(
            title: configuration.backButtonTitle, style: .plain, target: nil, action: nil)
        view.backgroundColor = UIColor.darkGray
        
        //add camera view
        view.addSubview(cameraView)
        setupCameraViewConstraints()
        
        // guide view
        if (guideLabel.text?.count ?? 0) > 0 {
            view.addSubview(footerView)
            footerView.addSubview(guideLabel)
            footerView.backgroundColor = UIColor.darkGray
            guideLabel.textColor = UIColor.white
            
            setupFooterViewConstraints()
        }
        
        //warning view
        if (crlWarningLabel.text?.count ?? 0) > 0 {
            view.addSubview(crlWarningView)
            crlWarningView.addSubview(crlWarningLabel)
            crlWarningView.addSubview(crlWarningIconImageView)
            setupWarningViewConstraints()
        }
        checkCRLWarning()
        
        //right bar button item
        if let buttonImage = configuration.rightBarButtonImage {
            let rightBarButton = UIBarButtonItem(image: buttonImage, style: .plain, target: self, action: #selector(rightBarButtonTapped))
            self.navigationItem.rightBarButtonItem  = rightBarButton
        } else if (configuration.rightBarButtonTitle?.count ?? 0) > 0 {
            let rightBarButton = UIBarButtonItem(title: configuration.rightBarButtonTitle, style: .plain, target: self, action: #selector(rightBarButtonTapped))
            self.navigationItem.rightBarButtonItem  = rightBarButton
        }
        
    }
    
    /// Check the status of the buttons and set image accordingly
    private func resetButtonImages() {
        
        torchButton.isHidden = configuration.torchEnabled ? !isTorchAvailable : true
        torchButton.setImage(isTorchOn ? torchOnButtonImage : torchOffButtonImage, for: .normal)
        
        zoomButton.isHidden = !configuration.zoomEnabled
        zoomButton.setImage(isZoomOn ? zoomOutButtonImage: zoomInButtonImage, for: .normal)
    }
    
    /// Sets up the overlay which includes the box to position the barcode and the darker surrounding
    private func setupPreviewOverlayUI() {
        
        // rect silhouette
        shapeMaskLayer = CAShapeLayer()
        shapeMaskLayer?.frame = view.layer.bounds
        shapeMaskLayer?.fillColor = UIColor.black.cgColor
        shapeMaskLayer?.strokeColor = UIColor.clear.cgColor
        
        // scan guide box width / height
        var boxWidthHeight = (view.bounds.width / 7) * 5 //padding on either side, taking up 5/7 of the screen on iphone
        var barcodeBoxY =  (view.bounds.height / 2) - (boxWidthHeight / 2) - 40
        
        if let navBar = navigationController?.navigationBar {
            if !navBar.isTranslucent {
                barcodeBoxY = barcodeBoxY - navBar.bounds.height
            }
        }
        
        
        if (configuration.zoomEnabled || configuration.torchEnabled) {
            barcodeBoxY = barcodeBoxY - 20
        }
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            boxWidthHeight = (view.bounds.width / 5) * 2 //padding on either side, taking up 2/5 of the screen on ipad
            barcodeBoxY = (view.bounds.height / 2) - (boxWidthHeight / 2) - 80
        }
        
        barcodeOutlineBoxRect = CGRect(x: (cameraView.bounds.width - boxWidthHeight) / 2,
                                       y: barcodeBoxY,
                                       width: boxWidthHeight,
                                       height: boxWidthHeight)
        
        //add barcode placeholder
        cameraView.addSubview(barcodePlaceholderImageView)
        
        //set up invalid QR code label
        invalidQRCodeView.addSubview(invalidQRCodeLabel)
        cameraView.addSubview(invalidQRCodeView)
        invalidQRCodeView.alpha = 0
        
        //add buttons (to view so in front of dimmed bg)
        view.addSubview(buttonsContainerStackView)
        buttonsContainerStackView.addArrangedSubview(torchButton)
        torchButton.addTarget(self, action: #selector(toggleTorchButton), for: .touchUpInside)
        buttonsContainerStackView.addArrangedSubview(zoomButton)
        zoomButton.addTarget(self, action: #selector(toggleZoomButton), for: .touchUpInside)
        
        //setup constraints
        setupPreviewOverlayConstraints()
        
        //done
        hasSetupPreviewOverlayUI = true
    }
    
    /// sets up constraints for the camera view
    private func setupCameraViewConstraints() {
        
        let cameraViewConstraints = [
            cameraView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cameraView.leftAnchor.constraint(equalTo: view.leftAnchor),
            cameraView.rightAnchor.constraint(equalTo: view.rightAnchor),
        ]
        
        //activate the constraints
        NSLayoutConstraint.activate(cameraViewConstraints)
    }
    
    /// sets up constraints for the footer view
    private func setupFooterViewConstraints() {
        
        let footerViewConstraints = [
            footerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            footerView.leftAnchor.constraint(equalTo: view.leftAnchor),
            footerView.rightAnchor.constraint(equalTo: view.rightAnchor),
        ]
        
        let guideLabelConstraints = [
            guideLabel.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 20),
            guideLabel.bottomAnchor.constraint(equalTo: footerView.bottomAnchor, constant: -20),
            guideLabel.leftAnchor.constraint(equalTo: footerView.leftAnchor, constant: 20),
            guideLabel.rightAnchor.constraint(equalTo: footerView.rightAnchor, constant: -20),
        ]
        
        //activate the constraints
        NSLayoutConstraint.activate(footerViewConstraints + guideLabelConstraints)
    }
    
    /// sets up constraints for the preview overlay UI
    private func setupPreviewOverlayConstraints() {
        
        let outlineConstraints = [
            barcodePlaceholderImageView.topAnchor.constraint(equalTo: cameraView.topAnchor, constant: barcodeOutlineBoxRect?.origin.y ?? 0),
            barcodePlaceholderImageView.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
            barcodePlaceholderImageView.heightAnchor.constraint(equalToConstant: barcodeOutlineBoxRect?.size.height ?? 0),
            barcodePlaceholderImageView.widthAnchor.constraint(equalToConstant: (barcodeOutlineBoxRect?.size.width ?? 0))
        ]
        NSLayoutConstraint.activate(outlineConstraints)
        
        let buttonsConstraints = [
            buttonsContainerStackView.topAnchor.constraint(equalTo: barcodePlaceholderImageView.bottomAnchor, constant: 40),
            buttonsContainerStackView.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
            buttonsContainerStackView.heightAnchor.constraint(equalToConstant: 60),
        ]
        NSLayoutConstraint.activate(buttonsConstraints)
        
        let invalidQRconstraints = [
            invalidQRCodeView.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
            invalidQRCodeView.centerYAnchor.constraint(equalTo: barcodePlaceholderImageView.centerYAnchor),
            invalidQRCodeView.leftAnchor.constraint(equalTo: barcodePlaceholderImageView.leftAnchor, constant: 10),
            invalidQRCodeView.rightAnchor.constraint(equalTo: barcodePlaceholderImageView.rightAnchor, constant: -10),
            
            invalidQRCodeLabel.topAnchor.constraint(equalTo: invalidQRCodeView.topAnchor, constant: 20),
            invalidQRCodeLabel.leftAnchor.constraint(equalTo: invalidQRCodeView.leftAnchor, constant: 20),
            invalidQRCodeLabel.rightAnchor.constraint(equalTo: invalidQRCodeView.rightAnchor, constant: -20),
            invalidQRCodeLabel.bottomAnchor.constraint(equalTo: invalidQRCodeView.bottomAnchor, constant: -20)
        ]
        NSLayoutConstraint.activate(invalidQRconstraints)
    }
    
    /// sets up constraints for the warning view
    private func setupWarningViewConstraints() {
        
        let warningViewConstraints = [
            crlWarningView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            crlWarningView.leftAnchor.constraint(equalTo: view.leftAnchor),
            crlWarningView.rightAnchor.constraint(equalTo: view.rightAnchor),
        ]
        
        let warningImageIconConstraints = [
            crlWarningIconImageView.centerYAnchor.constraint(equalTo: crlWarningLabel.centerYAnchor),
            crlWarningIconImageView.leftAnchor.constraint(equalTo: crlWarningView.leftAnchor, constant: 20),
            crlWarningIconImageView.rightAnchor.constraint(equalTo: crlWarningLabel.leftAnchor, constant: -10),
            crlWarningIconImageView.widthAnchor.constraint(equalToConstant: 19),
            crlWarningIconImageView.heightAnchor.constraint(equalToConstant: 16)
        ]
        
        let warningLabelConstraints = [
            crlWarningLabel.topAnchor.constraint(equalTo: crlWarningView.topAnchor, constant: 10),
            crlWarningLabel.bottomAnchor.constraint(equalTo: crlWarningView.bottomAnchor, constant: -10),
            crlWarningLabel.rightAnchor.constraint(equalTo: crlWarningView.rightAnchor, constant: -20),
        ]
        
        //activate the constraints
        NSLayoutConstraint.activate(warningViewConstraints + warningImageIconConstraints + warningLabelConstraints)
    }
    
    // MARK: - CRL Warning
    
    private func checkCRLWarning() {
        if CertificateRepository.shared().isUpdateOverdue && configuration.crlWarningLabelText.count > 0 {
            crlWarningView.isHidden = false
        } else {
            crlWarningView.isHidden = true
        }
    }
    
    // MARK: - Camera
    
    private func startCamera() {
        if isVideoAuthorized() {
            setupCamera()
        }
        
        // setup barcode UI after the camera because the frames may be off
        if !hasSetupPreviewOverlayUI {
            setupPreviewOverlayUI()
        }
        captureSession.startRunning()
    }
    
      
    /// set up camera preview layer and input
    private func setupCamera() {
        
        cameraView.videoPreviewLayer.frame.size = view.frame.size
        cameraView.videoPreviewLayer.videoGravity = .resizeAspectFill
        
        cameraView.session = captureSession
        
        let cameraDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back)
        var cameraDevice: AVCaptureDevice?
        
        for device in cameraDevices.devices where device.position == .back {
            cameraDevice = device
            break
        }
        
        do {
            if let cameraDevice = cameraDevice {
                let captureDeviceInput = try AVCaptureDeviceInput(device: cameraDevice)
                
                if captureSession.canAddInput(captureDeviceInput) {
                    captureSession.addInput(captureDeviceInput)
                }
            }
            
        } catch {
            // no input from camera
            return
        }
        
        if let device = cameraDevice {
            do {
                try device.lockForConfiguration()
                
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                
                if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .continuousAutoExposure
                }
                
                device.unlockForConfiguration()
            } catch {
                // Camera Focus/Exposure Error
            }
        }
        
        captureSession.sessionPreset = .high
        
        let metaOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metaOutput) {
            captureSession.addOutput(metaOutput)
        }
        
        metaOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue(label: "meta_ouput_queue"))
        
        captureSession.startRunning()
        
        if metaOutput.availableMetadataObjectTypes.contains(.qr) {
            metaOutput.metadataObjectTypes = [.qr]
        }
    }
    
    
    /// Toggle the device torch on and off
    /// - Parameter toOn: is the torch toggling on
    /// - Returns: result if it was successful or not
    @discardableResult private func toggleTorch(toOn: Bool) -> Bool {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video), device.hasTorch else {
            isTorchOn = false
            resetButtonImages()
            return false
            
        }
        guard (try? device.lockForConfiguration()) != nil else { return false }
        
        isTorchAvailable = true
        device.torchMode = toOn ? .on : .off
        device.unlockForConfiguration()
        return true
    }
    
    /// Toggle the camera zoom factor between 1x and 2x
    /// - Parameter toOn: is the torch toggling on
    /// - Returns: result if it was successful or not
    @discardableResult private func toggleZoom(toZoomed: Bool, withAnimation: Bool) -> Bool {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else {
            isZoomOn = false
            return false
            
        }
        guard (try? device.lockForConfiguration()) != nil else { return false }
        device.cancelVideoZoomRamp()
        if withAnimation {
            device.ramp(toVideoZoomFactor: toZoomed ? 2.0 : 1.0, withRate: 4)
        } else {
            device.videoZoomFactor = toZoomed ? 2.0 : 1.0
        }
        
        device.unlockForConfiguration()
        return true
    }
    
    private func tearDownCamera() {
        captureSession.stopRunning()
    }
    
    // MARK: - Actions
    
    @objc func toggleTorchButton(_ sender: Any) {
        isTorchOn.toggle()
        resetButtonImages()
        toggleTorch(toOn: isTorchOn)
    }
    
    @objc func toggleZoomButton(_ sender: Any) {
        isZoomOn.toggle()
        resetButtonImages()
        toggleZoom(toZoomed: isZoomOn, withAnimation: true)
    }
    
    @objc func rightBarButtonTapped(_ sender: Any) {
        delegate?.didTapRightBarButton()
    }
    
    // MARK: - Functions
    
    func completedScan(scanResult: ScanResult) {
        // Ignore if we're already complete
        if isScanningComplete {
            return
        }
        isScanningComplete = true
        
        // Stop our scanning session
        captureSession.stopRunning()
        
        switch scanResult.vdsVerificationResult {
        case .verified:
            delegate?.didSuccessfullyVerifyVds(vds: scanResult.vds)
            break
        case .failed:
            delegate?.didFailVDSVerification(vdsVerificationError: scanResult.vdsVerificationError)
        }
    }
    
    
    public override var shouldAutorotate: Bool {
        return false
    }
    
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension ScanViewController: AVCaptureMetadataOutputObjectsDelegate {
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        if !isReadyToScan { return }
        
        // meta objects found
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            
            // grab the text
            guard let foundText = readableObject.stringValue else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Parse valid VDS
                if let vds = try? VDSReader().decodeVDSFrom(jsonString: foundText) {
                    
                    self.invalidQRCodeView.alpha = 0
                    self.impactFeedbackGenerator.notificationOccurred(.success)
                    
                    self.completedScan(scanResult: ScanResult.init(vds: vds))
                    
                } else {
                    if (self.invalidQRCodeLabel.text?.count ?? 0) > 0 {
                        self.invalidQRCodeView.alpha = 1
                        UIView.animate(withDuration: 0.5, delay: 2, options: UIView.AnimationOptions.curveEaseOut, animations: {
                            self.invalidQRCodeView.alpha = 0
                        }, completion: nil)
                    }
                }
            }
        }
    }
}

public extension ScanViewController {
    
    /// Configure the scan screen features and layout
    struct Configuration {
        
        public init() {
            
        }
        
        /// Whether or not to hide the navigation back button
        public var hidesBackButton = false
        
        /// Back button title that appears on the next screen
        public var backButtonTitle = "Back"
        
        /// Title that appears in the navigation bar
        public var navigationTitle = "VDS-NC Checker"
        
        /// Invalid VDS NC label
        public var invalidVdsNcLabelText = "This code is not a VDS-NC"
        public var invalidVdsNcLabelFont = UIFont.preferredFont(forTextStyle: .body)
        
        /// Guide label
        public var guideLabelText = "Align QR code within frame"
        public var guideLabelFont = UIFont.preferredFont(forTextStyle: .headline)
        
        /// Warning label
        public var crlWarningLabelText = "For correct results, connect to internet for product update"
        public var crlWarningLabelFont = UIFont.preferredFont(forTextStyle: .footnote)
        
        /// Specifies whether torch functionality is enabled
        public var torchEnabled = true
        
        /// Specifies whether zoom functionality is enabled
        public var zoomEnabled = true
        
        /// Specifies whether to dim the background outside of the placeholder
        public var dimBackground = true
                
        /// Add a right bar button item to the navigation bar, with an image or text
        public var rightBarButtonImage: UIImage?
        public var rightBarButtonTitle: String?
        
    }
    
}

extension ScanViewController: CertificateRepositoryDelegate {
    public func didUpdateCRLData() {
        checkCRLWarning()
    }
}
