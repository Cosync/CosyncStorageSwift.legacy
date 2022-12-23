//
//  File.swift
//  
//
//  Created by Tola Voeung on 23/12/22.
//

import Foundation
import UniformTypeIdentifiers


extension NSURL {
    public func mimeType() -> String {
        if #available(iOS 14.0, *) {
            if let pathExt = self.pathExtension,
               let mimeType = UTType(filenameExtension: pathExt)?.preferredMIMEType {
                return mimeType
            }
            else {
                return "application/octet-stream"
            }
        } else {
            // Fallback on earlier versions
            return "application/octet-stream"
        }
    }
}

extension URL {
    public func mimeType() -> String {
        if #available(iOS 14.0, *) {
            if let mimeType = UTType(filenameExtension: self.pathExtension)?.preferredMIMEType {
                return mimeType
            }
            else {
                return "application/octet-stream"
            }
        } else {
            return "application/octet-stream"
            // Fallback on earlier versions
        }
    }
}

extension NSString {
    public func mimeType() -> String {
        if #available(iOS 14.0, *) {
            if let mimeType = UTType(filenameExtension: self.pathExtension)?.preferredMIMEType {
                return mimeType
            }
            else {
                return "application/octet-stream"
            }
        } else {
            return "application/octet-stream"
            // Fallback on earlier versions
        }
    }
}

extension String {
    public func mimeType() -> String {
        return (self as NSString).mimeType()
    }
}
