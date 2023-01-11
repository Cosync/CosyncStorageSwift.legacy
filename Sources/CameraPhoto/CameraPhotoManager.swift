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
    
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    var cameraCaptureMode:UIImagePickerController.CameraCaptureMode = .photo
    @Binding var pickerResult: [String]
    @Binding var selectedImage:UIImage?
    @Binding var isPresented: Bool
    @Binding var errorMessage: String?
    
    
    public init(sourceType:UIImagePickerController.SourceType, captureMode:UIImagePickerController.CameraCaptureMode, pickerResult:Binding<[String]>, selectedImage: Binding<UIImage?>, isPresented: Binding<Bool>, errorMessage:Binding<String?>) {
        
        self.sourceType = sourceType
        self.cameraCaptureMode = captureMode
        self._pickerResult = pickerResult
        self._selectedImage = selectedImage
        self._isPresented = isPresented
        self._errorMessage = errorMessage
    }
    
    public func makeCoordinator() -> ImagePickerViewCoordinator {
        return ImagePickerViewCoordinator(sourceType: sourceType ,imageIds:$pickerResult ,selectedImage: $selectedImage, isPresented: $isPresented, errorMessage:$errorMessage)
    }
    
    public func makeUIViewController(context: Context) -> UIImagePickerController {
        
        let pickerController = UIImagePickerController()
        
        if sourceType == .camera {
            if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.camera) {
                pickerController.sourceType = sourceType
                pickerController.cameraCaptureMode = cameraCaptureMode
                pickerController.cameraDevice = cameraCaptureMode == .photo ? .front : .rear
                pickerController.delegate = context.coordinator
                pickerController.allowsEditing = true
                pickerController.showsCameraControls = true
                pickerController.modalPresentationStyle = .fullScreen
            }
            else{
                self.errorMessage = "You dont have camera."
            }
           
        }
        else {
            
            if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.photoLibrary){
                pickerController.sourceType = sourceType
                pickerController.delegate = context.coordinator
                pickerController.allowsEditing = true
            }
            else{
                self.errorMessage = "You don't have permission to access gallery."
            }
        }
        
        
        
        
        return pickerController
        
    }
    
   

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Nothing to update here
    }
    
   

}

@available(iOS 15.0, *)
public class ImagePickerViewCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Binding var imageIds: [String]
    @Binding var selectedImage: UIImage?
     
    @Binding var isPresented: Bool
    @Binding var errorMessage: String?
    
    public init(sourceType:UIImagePickerController.SourceType, imageIds:Binding<[String]>, selectedImage: Binding<UIImage?>, isPresented: Binding<Bool>, errorMessage:Binding<String?>) {
        self.sourceType = sourceType
        self._imageIds = imageIds
        self._selectedImage = selectedImage
        self._isPresented = isPresented
        self._errorMessage = errorMessage
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            self.selectedImage = image
            
            if sourceType == .camera {
                saveImageToCameraRoll(inputImage: image)
            }
            
            else {
                self.errorMessage = "This class cannot get image indentifier. Please use asset picker instead."
            }
        }
        self.isPresented = false
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.isPresented = false
    }
    
    public func saveImageToCameraRoll(inputImage:UIImage){
        let imageSaver = ImageSaver()
        
        imageSaver.successHandler = {
           
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 1
             
            let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            if let phAsset = fetchResult.firstObject {
                self.imageIds.append(phAsset.localIdentifier)
                //print("Success! \( self.imageIds)")
            }
            
        }

        imageSaver.errorHandler = {
            print("Oops: \($0.localizedDescription)")
            self.errorMessage = $0.localizedDescription
        }
        
        imageSaver.writeToPhotoAlbum(image: inputImage)
        
    }
    
}
