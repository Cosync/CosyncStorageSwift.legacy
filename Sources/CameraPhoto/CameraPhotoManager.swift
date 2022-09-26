//
//  File.swift
//  
//
//  Created by Tola Voeung on 26/9/22.
//

import SwiftUI
import UIKit

@available(iOS 15.0, *)
public struct CameraPhotoManager: UIViewControllerRepresentable {
    
    
    @Binding var selectedImage:Image?
    @Binding var isPresented: Bool
    
    private var sourceType: UIImagePickerController.SourceType = .camera
    
    public init(selectedImage: Binding<Image?>, isPresented: Binding<Bool>) {
        self._selectedImage = selectedImage
        self._isPresented = isPresented
        
    }
    
    public func makeCoordinator() -> ImagePickerViewCoordinator {
        return ImagePickerViewCoordinator(selectedImage: $selectedImage, isPresented: $isPresented)
    }
    
    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let pickerController = UIImagePickerController()
        pickerController.sourceType = sourceType
        pickerController.delegate = context.coordinator
        return pickerController
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Nothing to update here
    }

}

@available(iOS 15.0, *)
public class ImagePickerViewCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    @Binding var selectedImage: Image?
    @Binding var isPresented: Bool
    
    public init(selectedImage: Binding<Image?>, isPresented: Binding<Bool>) {
        self._selectedImage = selectedImage
        self._isPresented = isPresented
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            self.selectedImage = Image(uiImage: image)
        }
        self.isPresented = false
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.isPresented = false
    }
    
}
