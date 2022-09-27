//
//  File.swift
//  
//
//  Created by Tola Voeung on 26/9/22.
//
import PhotosUI
import SwiftUI
import UIKit

@available(iOS 15.0, *)
public struct CameraPhotoManager: UIViewControllerRepresentable {
    
    @Binding var pickerResult: [String]
    @Binding var selectedImage:UIImage?
    @Binding var isPresented: Bool
    
    private var sourceType: UIImagePickerController.SourceType = .camera
    
    public init(pickerResult:Binding<[String]>, selectedImage: Binding<UIImage?>, isPresented: Binding<Bool>) {
        self._pickerResult = pickerResult
        self._selectedImage = selectedImage
        self._isPresented = isPresented
        
    }
    
    public func makeCoordinator() -> ImagePickerViewCoordinator {
        return ImagePickerViewCoordinator(imageIds:$pickerResult ,selectedImage: $selectedImage, isPresented: $isPresented)
    }
    
    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let pickerController = UIImagePickerController()
        pickerController.sourceType = sourceType
        pickerController.delegate = context.coordinator
        pickerController.allowsEditing = true
        pickerController.cameraCaptureMode = .photo
        pickerController.showsCameraControls = true
        return pickerController
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Nothing to update here
    }
    
   

}

@available(iOS 15.0, *)
public class ImagePickerViewCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    @Binding var imageIds: [String]
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    
    public init(imageIds:Binding<[String]>, selectedImage: Binding<UIImage?>, isPresented: Binding<Bool>) {
        self._imageIds = imageIds
        self._selectedImage = selectedImage
        self._isPresented = isPresented
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            self.selectedImage = image
            saveImageToCameraRoll(inputImage: image)
        }
        self.isPresented = false
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.isPresented = false
    }
    
    public func saveImageToCameraRoll(inputImage:UIImage){
        let imageSaver = ImageSaver()
        
        imageSaver.successHandler = {
            print("Success!")
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 1
            let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            if let phAsset = fetchResult.firstObject {
                self.imageIds.append(phAsset.localIdentifier)
            }
            
        }

        imageSaver.errorHandler = {
            print("Oops: \($0.localizedDescription)")
           
        }
        
        imageSaver.writeToPhotoAlbum(image: inputImage)
        
    }
    
}
