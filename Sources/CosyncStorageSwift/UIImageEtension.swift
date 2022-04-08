//
//  UIImageEtension.swift
//  
//
//  Created by Tola Voeung on 23/3/22.
//

import Foundation
import UIKit

extension UIImage {
    
    @MainActor func imageCut(cutSize: CGFloat) -> UIImage? {
        
        let sizeOriginal = self.size
        if sizeOriginal.width > 0 && sizeOriginal.height > 0 {
            var newSize = sizeOriginal

            if sizeOriginal.width < sizeOriginal.height {
                // portrait
                if sizeOriginal.height > cutSize {
                    newSize.width = (cutSize * sizeOriginal.width) / sizeOriginal.height
                    newSize.height = cutSize
                }
                
            } else {
                // landscape
                if sizeOriginal.width > cutSize {
                    newSize.width = cutSize
                    newSize.height = (cutSize * sizeOriginal.height) / sizeOriginal.width
                }
            }
            
            let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            self.draw(in: rect)
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return newImage
        }
        return nil
    }
    
    func averageColor() -> String {

        var bitmap = [UInt8](repeating: 0, count: 4)

        let context = CIContext(options: nil)
        let cgImg = context.createCGImage(CoreImage.CIImage(cgImage: self.cgImage!), from: CoreImage.CIImage(cgImage: self.cgImage!).extent)

        let inputImage = CIImage(cgImage: cgImg!)
        let extent = inputImage.extent
        let inputExtent = CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height)
        let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: inputExtent])!
        let outputImage = filter.outputImage!
        let outputExtent = outputImage.extent
        assert(outputExtent.size.width == 1 && outputExtent.size.height == 1)

        // Render to bitmap.
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: CIFormat.RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        // Compute result.
        let red = String(format:"%02X", bitmap[0])
        let green = String(format:"%02X", bitmap[1])
        let blue = String(format:"%02X", bitmap[2])
        let color = "#" + red + green + blue
        return color

    }
    
}

