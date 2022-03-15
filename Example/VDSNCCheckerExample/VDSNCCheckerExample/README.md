# VDS-NC Checker Example app

## Overview

This example app demonstrates using the VDSNCChecker library to parse and verify the authenticity of VDS-NC JSON data as defined in the [VDS-NC Visible Digital Seal for non-constrained environments specification](https://www.icao.int/Security/FAL/TRIP/PublishingImages/Pages/Publications/Visible%20Digital%20Seal%20for%20non-constrained%20environments%20%28VDS-NC%29.pdf)

## Requirements

- iOS 13.0+ | macOS 10.15+
- Xcode 9.3+

## Usage

The `VDSNCChecker` library is used to parse and verify the VDS.

`HomeViewController.swift` demonstrates how to use this library. It demonstrates:
- how to request camera permissions if using the libraries ScanViewController
- how to show the ScanViewController to scan and verify the VDS and respond to its delegate events
- how to import a PDF doccument which contains a VDS-NC and extract the VDS JSON from it
- how to verify VDS JSON manually without the ScanViewController

`VDSViewController.swift` shows the table which contains the VDS data once its been verified.

The `TableViewCells` folder demonstrates how to display data parsed from a VDS.

`Constants.swift` contains example data (a VDS, CSCA certificate and CRL) that can be used for testing.

## Additional

There are some additional features which are not neccessary for the library usage, but just some examples on how to extend the library features or other considerations that could be included in your app. 

`VDS+UVCI.swift` contains an example of extending the library VDS object to perform additional checks, in this case checking to see what range the UVCI number is in

The `Security` folder demonstrates an implementation of performing some security checks such as detecting if the device has been compromised or if the code is being debugged, this is not part of the libary but jus

