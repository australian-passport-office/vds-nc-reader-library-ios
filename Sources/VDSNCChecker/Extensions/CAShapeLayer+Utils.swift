//
//  CAShapeLayer+Utils.swift
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

import UIKit
import AVFoundation
import CoreImage

enum Shape {
    case rectangle
    case triangle
    case circle
    case oval
}

extension CAShapeLayer {

    func drawShapeMaskLayer(boundingViewBox: CGRect,
                            shape: Shape,
                            boundingBox: CGRect,
                            fillColor: CGColor,
                            strokeColor: CGColor) {
        var viewPath = UIBezierPath()
        viewPath = UIBezierPath(rect: boundingViewBox)
        
        let shapePath = silhouetteShapePath(boundingBox: boundingBox, shape: shape)
        viewPath.append(shapePath)

        self.path = viewPath.cgPath
        self.fillRule = CAShapeLayerFillRule.evenOdd
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.lineWidth = 2
        self.opacity = 0.5
    }

    fileprivate func silhouetteShapePath(boundingBox: CGRect, shape: Shape) -> UIBezierPath {
        // Create cut out geometry
        let yShapeTop = boundingBox.minY
        let yShapeBottom = boundingBox.maxY
        let xShapeLeft = boundingBox.minX
        let xShapeRight = boundingBox.maxX
        let circleShapeRadius = (boundingBox.maxY - boundingBox.minY) / 2
        let xShapeCtr = (boundingBox.maxX - boundingBox.minX) / 2 + xShapeLeft
        let yShapeCtr = (boundingBox.maxY - boundingBox.minY) / 2 + yShapeTop
        let xCircleLeft = xShapeCtr - circleShapeRadius
        let yCircleTop = yShapeCtr - circleShapeRadius

        var shapePath = UIBezierPath()

        switch shape {
        case Shape.rectangle:
            shapePath = UIBezierPath(rect: boundingBox)
        case Shape.triangle:
            shapePath.addLine(to: CGPoint(x: (xShapeLeft + xShapeRight) / 2, y: yShapeTop))
            shapePath.addLine(to: CGPoint(x: xShapeLeft, y: yShapeBottom))
            shapePath.addLine(to: CGPoint(x: xShapeRight, y: yShapeBottom))
        case Shape.circle:
            shapePath = UIBezierPath(rect: CGRect(x: xCircleLeft, y: yCircleTop, width: 2 * circleShapeRadius, height: 2 * circleShapeRadius))
        case Shape.oval:
            shapePath = UIBezierPath(ovalIn: boundingBox)
        }

        return shapePath
    }
}
