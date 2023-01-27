//
//  AssetPicker.swift
//
//
//  Created by Tola Voeung on 28/3/22.
//

import Foundation
import PhotosUI
import SwiftUI

 

@available(iOS 15, *)
public struct AssetPicker: UIViewControllerRepresentable {
    
    @Binding var pickerResult: [String]
    @Binding var selectedImage:UIImage?
    @Binding var selectedAsset:[String:String]?
    @Binding var selectedVideoUrl:URL?
    @Binding var selectedType:String
    @Binding var isPresented: Bool
    @Binding var errorMessage:String?
    var preferredType:String = "all"
    var isMultipleSelection:Bool = false
     
    
    

    
    public init(pickerResult:Binding<[String]>, selectedImage:Binding<UIImage?>, selectedAsset:Binding<[String:String]?>, selectedVideoUrl:Binding<URL?>,
                selectedType:Binding<String>, isPresented:Binding<Bool>, errorMessage:Binding<String?>, preferredType:String, isMultipleSelection:Bool) {
        self._pickerResult = pickerResult
        self._selectedImage = selectedImage
        self._selectedAsset = selectedAsset
        self._selectedVideoUrl = selectedVideoUrl
        self._selectedType = selectedType
        self._isPresented = isPresented
        self._errorMessage = errorMessage
        self.preferredType = preferredType
        self.isMultipleSelection = isMultipleSelection
    }
    
    
    public func makeUIViewController(context: Context) -> PHPickerViewController {
         
        var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        
        if(preferredType == "image"){
            config.filter = .any(of: [.images])
        }
        else if(preferredType == "video"){
            config.filter = .all(of: [.videos])
             
        }
        else {
            config.filter = .any(of: [.images, .videos])
        }
        
        
        config.selectionLimit = isMultipleSelection ? 0 : 1 //0 => any, set 1-2-3 for hard limit
        
        config.preferredAssetRepresentationMode = .current
        config.selection = .ordered
        
        let controller = PHPickerViewController(configuration: config)
        controller.delegate = context.coordinator
        return controller
    }
    
     
    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// PHPickerViewControllerDelegate => Coordinator
    public class Coordinator: PHPickerViewControllerDelegate {
        
        private var parent: AssetPicker
        
        init(_ parent: AssetPicker) {
            self.parent = parent
        }
        
       
            
        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true, completion: nil)
            
            var assetIdList = [String]()
           
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                
                for asset in results {
                    if let assetId = asset.assetIdentifier {
                        assetIdList.append(assetId)
                    }
                     
                }
                parent.pickerResult = assetIdList
                let progress:Progress = provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { fileURL, err in
                //provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier, options: [:]) { [self] (videoURL, error) in
                    do {
                        if let url = fileURL {
                            let fm = FileManager.default
                            let filename = url.lastPathComponent
                            let destination = fm.temporaryDirectory.appendingPathComponent(filename)
                            if fm.fileExists(atPath: destination.path) {
                                try fm.removeItem(at: destination)
                            }
                            
                            try fm.copyItem(at: url, to: destination)
                            self.parent.selectedVideoUrl = destination
                            
                        }
                        else {
                            self.parent.errorMessage = "Can not load this video."
                        }
                        self.parent.selectedType = "video"
                    }
                    catch{
                        self.parent.errorMessage = "Can not load this video."
                    }
                }
                
                print("load progress \(String(describing: progress.estimatedTimeRemaining))")
            }
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                
                self.parent.selectedType = "image"
                
                for asset in results {
                    
                    if asset.itemProvider.canLoadObject(ofClass: UIImage.self) {
                        
                        asset.itemProvider.loadObject(ofClass: UIImage.self, completionHandler: { (object, error) in
                             
                            if let err = error {
                                self.parent.errorMessage = err.localizedDescription
                            }
                            else if let image = object as? UIImage {
                                
                                self.parent.selectedImage = image
                                
                                if let assetId = asset.assetIdentifier {
                                    assetIdList.append(assetId)
                                }
                                
                                if let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: assetIdList, options: nil).firstObject,
                                   let assetType = asset.value(forKey: "UniformTypeIdentifiers") as? String {
                                    
                                    let assetModel:[String:String] = ["assetIdentifier":asset.assetIdentifier!, "localIdentifier":phAsset.localIdentifier
                                                                  , "pixelWidth" : "\(phAsset.pixelWidth)", "pixelHeight": "\(phAsset.pixelHeight)",
                                                                  "mediaType":"\(phAsset.mediaType)", "assetType":assetType]
                                    
                                    self.parent.selectedAsset = assetModel
                                    
                                    self.parent.pickerResult = assetIdList
                                }
                            }
                        })
                        
                    }
                    else {
                        self.parent.errorMessage = "Can not load this image."
                    }
                }

                parent.pickerResult = assetIdList
            }
            
            
                  
          // dissmiss the picker
          parent.isPresented = false
        }
    }
}
