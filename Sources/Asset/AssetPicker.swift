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
    @Binding var selectedVideoUrl:URL?
    @Binding var selectedType:String
    @Binding var isPresented: Bool
     
    public init(pickerResult:Binding<[String]>, selectedImage:Binding<UIImage?>, selectedVideoUrl:Binding<URL?>,
                selectedType:Binding<String>, isPresented:Binding<Bool>) {
        self._pickerResult = pickerResult
        self._selectedImage = selectedImage
        self._selectedVideoUrl = selectedVideoUrl
        self._selectedType = selectedType
        self._isPresented = isPresented
    }
    
    
    public func makeUIViewController(context: Context) -> PHPickerViewController {
         
        var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 1 //0 => any, set 1-2-3 for hard limit
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
                        print("picked  assetId =", assetId)
                        assetIdList.append(assetId)
                    }
                     
                }
                parent.pickerResult = assetIdList
            
                provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: [:]) { [self] (videoURL, error) in
                   
                    if let url = videoURL as? URL {
                        
                        self.parent.selectedVideoUrl = url
                         
                    }
                    self.parent.selectedType = "video"
                }
            }
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                
                self.parent.selectedType = "image"
                
                for asset in results {
                    if let assetId = asset.assetIdentifier {

                        print("picked  assetId =", assetId)
                        assetIdList.append(assetId)
                    }

                    asset.itemProvider.loadObject(ofClass: UIImage.self, completionHandler: { (object, error) in

                        if let image = object as? UIImage {
                            self.parent.selectedImage = image
                        }
                    })

                }

                parent.pickerResult = assetIdList
            }
            
            
                  
          // dissmiss the picker
          parent.isPresented = false
        }
    }
}