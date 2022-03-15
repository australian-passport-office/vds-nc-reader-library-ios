# VDS-NC Checker iOS Library

This library handles parsing and verifying the authenticity of VDS-NC JSON data as defined in the [VDS-NC Visible Digital Seal for non-constrained environments specification](https://www.icao.int/Security/FAL/TRIP/PublishingImages/Pages/Publications/Visible%20Digital%20Seal%20for%20non-constrained%20environments%20%28VDS-NC%29.pdf)

## Requirements

- Swift 5.0
- iOS 13.0+ | macOS 10.15+
- Xcode 13

## Usage

### Swift

1. In order to make the framework available, add `import VDSNCChecker` at the top of the Swift source file 

```swift
import VDSNCChecker

```

#### Certificate Repository

Before any VDS verification occurs, there must be CSCA certificates set up in the certificate repository.
 ```swift 

let cscaCertData = Data() // CSCA certificate data
let cscaCertSHA256Hash = "..." // SHA256 hash of the CSCA certificate data (as a lowercase hex string)
let crlData = Data() // CRL data 

CertificateRepository.shared().cscaCertificates = []
                
// create CRL object, with some intial data, and the URL that will be used to make sure the data is updated
let ausCrl = CRL.init(updatingURL:ausCrlUrl, initialCrlData: crlData)

// create a CSCA certificate, with the CRL we just set up
let cscaCertificate = CSCACertificate(data: cscaCertData, integrityHash: cscaCertSHA256Hash, crl: ausCrl)

// add the CSCA certificate to the repositiory
CertificateRepository.shared().cscaCertificates.append(cscaCertificate)

// start auto updating CRLs using the default time between updates
CertificateRepository.shared().startAutoUpdatingCRLData()

```

If you want to manually configure the time between CRL updates, or specify the time period of where the CRL update is deemed overdue:

```swift

// specify the time period in which the update becomes overdue as every 3 days
CertificateRepository.shared().maxSecondsBeforeOverdue = 86400 * 3

// specify the time between updates as every 1 day
CertificateRepository.shared().startAutoUpdatingCRLData(secondsBetweenUpdates: 86400) 

```
Conform to the `CertificateRepositoryDelegate` protocol to be notified when a CRL data update has been performed:

```swift
extension YourViewController: CertificateRepositoryDelegate {
    public func didUpdateCRLData() {
        // do something
    }
}
```

#### Scanning and auto-validating a VDS

First, ensure you have requested permission to use the camera before using the ScanViewController, please see the example app for more.

Configure the ScanViewController, and display:

```swift
// configure
var configuration = ScanViewController.Configuration()
configuration.navigationTitle = "VDS-NC Checker"
configuration.hidesBackButton = false
configuration.torchEnabled = true
configuration.zoomEnabled = true
configuration.dimBackground = false
configuration.invalidVdsNcLabelText = "This code is not a VDS-NC"
configuration.guideLabelText = "Align QR code within frame"

// show scan screen
let scanViewController = ScanViewController(configuration: configuration, delegate: self)
navigationController?.pushViewController(scanViewController, animated: animated)
```


Make sure that your view controller conforms to the `ScanViewControllerDelegate` protocol:

```swift
extension YourViewController: ScanViewControllerDelegate {
    func didTapRightBarButton() {
   
    }
    
    func didDetectNonVdsQrCode() {
        // Not a VDS
        print("This is not a VDS.")
    }
    
    func didFailVDSVerification(vdsVerificationError: VDSVerifyError?) {
        // VDS is not authentic
        print("This is not an authentic VDS. It may have been tampered with.")
    }
    
    func didSuccessfullyVerifyVds(vds: VDS) {
        // VDS is authentic

        // Access data from the VDS
        print("This is an authentic VDS. The name of the person stored in the VDS is \(vds.data.msg.pid.n)")

    }
}
```

#### Validating a VDS manually

If you have the VDS JSON string via from another QR scanning implementation, you can simply use only the verification, and pass in the CSCA certificates.

```swift
let vdsJson = "..." // VDS JSON string obtained from reading the QR code

// Decode VDS from the JSON string
let vds = try? VDSReader().decodeVDSFrom(jsonString: vdsJson)

// Authenticate VDS
let vdsAuthenticator = VDSAuthenticator()
if let vds = vds {
    // Verify VDS using the CSCA certificates
    if let _ = try? vdsAuthenticator.verify(
        vds: vds,
        cscaCertificates: CertificateRepository.shared().cscaCertificates
    ) {
        // VDS is authentic

        // Access data from the VDS
        print("This is an authentic VDS. The name of the person stored in the VDS is \(vds.data.msg.pid.n)")
    } else {
        // VDS is not authentic
        print("This is not an authentic VDS. It may have been tampered with.")
    }
} else {
    // JSON is not a VDS
    print("This is not a VDS.")
}

```

Please see `VDSNCCheckerTests.swift` for a full list of test scenarios and example VDS, CSCA certificate and CRL data.

### Displaying a VDS

The `VDS` class is a model class that stores the data parsed from VDS-NC JSON data. It has the following properties:

| Property             | Purpose                                                                                                           |
| -------------------- | ----------------------------------------------------------------------------------------------------------------- |
| VDS                  |                                                                                                                   |
| `data`               | Data. The actual data for the VDS, including version, person info, vaccination info, etc.                         |
| `sig`                | Signature. The cryptographic signature used to verify the authenticity of the data.                               |
| Data                 |                                                                                                                   |
| `data.hdr`           | Header. Includes type of data, version and issuing country.                                                       |
| `data.msg`           | Message. Includes person and vaccination info.                                                                    |
| Header               |                                                                                                                   |
| `data.hdr.t`         | Type of data. Can be either `icao.test` or `icao.vacc`. Other types possible in the future. Required.             |
| `data.hdr.v`         | Version. Required.                                                                                                |
| `data.hdr.hdrIs`     | Issuing country. In 3 letter country code format (e.g. `AUS`). Required.                                          |
| Message              |                                                                                                                   |
| `data.msg.uvci`      | Unique vaccination certificate identifier. Required.                                                              |
| `data.msg.pid`       | Person identification info. Required.                                                                             |
| `data.msg.ve`        | Array of vaccination events. Required.                                                                            |
| `data.msg.pid.dob`   | Date of birth. In `yyyy-MM-dd` format. Required if `i` (travel document number) is not provided.                  |
| `data.msg.pid.n`     | Name. A double space separates first and last name (e.g. `JANE CITIZEN`). May be truncated. Required.             |
| `data.msg.pid.sex`   | Sex. `M` for male, `F` for female or `X` for unspecified.                                                         |
| `data.msg.pid.i`     | Unique travel document number.                                                                                    |
| `data.msg.pid.ai`    | Additional identifier at discretion of issuer.                                                                    |
| Vaccination Events   |                                                                                                                   |
| `data.msg.ve.des`    | Vaccine type/subtype. Required.                                                                                   |
| `data.msg.ve.nam`    | Brand name. Required.                                                                                             |
| `data.msg.ve.dis`    | Disease targeted by vaccine. Required.                                                                            |
| `data.msg.ve.vd`     | Array of vaccination details. Required.                                                                           |
| Vaccination Details  |                                                                                                                   |
| `data.msg.ve.vd.dvc` | Date of vaccination. In `yyyy-MM-dd` format. Required.                                                            |
| `data.msg.ve.vd.seq` | Dose sequence number. Required.                                                                                   |
| `data.msg.ve.vd.ctr` | Country of vaccination. In 3 letter country code format (e.g. `AUS`). Required.                                   |
| `data.msg.ve.vd.adm` | Administering center. Required.                                                                                   |
| `data.msg.ve.vd.lot` | Vaccine lot number. Required.                                                                                     |
| `data.msg.ve.vd.dvn` | Vaccine lot number. Required.                                                                                     |
| Signature            |                                                                                                                   |
| `sig.alg`            | Crypto algorithm used for the signature. Can be either `ES256`, `ES384` or `ES512` (typically `ES256`). Required. |
| `sig.cer`            | Certificate used for the signature. In Base64 URL encoding (not the same as normal Base64!). Required.            |
| `sig.sigvl`          | Signature value. In Base64 URL encoding (not the same as normal Base64!). Required.                           

# Glossary

**BSC** - Barcode signing certificate. This is the certificate used by issuing authorities to sign the barcode data in a VDS to ensure it's authentic.

**CRL** - Certificate Revocation List. A certificate may be revoked by its issuing authority in the instance of the certificates private key becoming compromised, as which point any data signed with said certificate can no longer be trusted. Further information [here](https://en.wikipedia.org/wiki/Certificate_revocation_list).

**CSCA** - Country Signing Certificate Authority. ​Each State issuing an ePassport establishes a single Country Signing Certification Authority (CSCA) as its national trust point in the context of ePassports. Further information [here](https://www.icao.int/Security/FAL/PKD/BVRT/Pages/CSCA.aspx).

**VDS** - Visible Digital Seal. This is the visible, scannable code on a document which can be machine read to verify the integrity of the document. Full specification [here](https://www.icao.int/Security/FAL/TRIP/Documents/TR%20-%20Visible%20Digital%20Seals%20for%20Non-Electronic%20Documents%20V1.31.pdf).


# API Definition
See Documentation in Xcode for full API definition of this library.

## Acknowledgements

This library uses:
- a modified version of [ASN1Decoder](https://github.com/filom/ASN1Decoder) for parsing certificate and CRL data.
- a modified version of [JSONSerialization] for the JsonCanonicalizer ( https://github.com/apple/swift-corelibs-foundation/blob/ee856f110177289af602c4040a996507f7d1b3ce/Sources/Foundation/JSONSerialization.swift) for canonicalizing JSON data, in particular sorting lexicographically
