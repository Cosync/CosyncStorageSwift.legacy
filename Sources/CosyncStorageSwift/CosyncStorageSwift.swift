
import Foundation
import RealmSwift
import PhotosUI


enum UploadError: Error {
    case invalidImage
    case uploadFail
    
    public var message: String {
        switch self {
        case .invalidImage:
            return "Your image is invalid"
        case .uploadFail:
            return "Whoop! Something went wrong while uploading to server"
            
        }
    
    }
}


enum UploadPhase {
    case uploadImageUrl
    case uploadImageUrlSmall
    case uploadImageUrlMedium
    case uploadImageUrlLarge
    case uploadVideoUrl
    case uploadVideoUrlPreview
    case uploadVideoUrlSmall
    case uploadVideoUrlMedium
    case uploadVideoUrlLarge
}

 

@available(iOS 15.0, *)
public class CosyncStorageSwift:NSObject, ObservableObject,  URLSessionTaskDelegate {
    
    
    public static let shared = CosyncStorageSwift()
    @Published public var uploadedAsset = CosyncAsset()
    @Published public var assetListPrivate = [CosyncAsset]()
    @Published public var assetListPublic = [CosyncAsset]()
    @Published public var allAssets = [CosyncAsset]()
    @Published public var uploadedAssetList:[String] = []
    @Published public var uploadStart = false
    @Published public var uploadTask = ""
    @Published public var uploadAmount = 0.0
    @Published public var uploadAssetId = ObjectId()
    
    private var uploadToken: NotificationToken! = nil
    private var publicAssetToken: NotificationToken! = nil
    private var privateAssetToken: NotificationToken! = nil
    
    private var uploadPhase: UploadPhase = .uploadImageUrl
    
    private var sessionId: String? {
        return UIDevice.current.identifierForVendor?.uuidString
    }
    
   
    private var privateRealm:Realm?
    private var publicRealm:Realm?
    private var app : App! = nil
    private var currentUserId: String?
    
     
    
    @available(iOS 15.0, *)
    public func configure(app: App, privateRealm:Realm, publicRealm:Realm) {
        
        self.app = app
        self.privateRealm = privateRealm
        self.publicRealm = publicRealm
        
        if  let user = self.app.currentUser {
            currentUserId = user.id
            
            
            self.privateRealm = privateRealm
            self.publicRealm = publicRealm
            
            setUpAssetListener()
            setUpUploadListener()
        }
        else{
            print("invalid realm configuration")
        }
        
       
    }
    
    
    @available(iOS 15.0, *)
    private func setUpUploadListener(){
        
        if let realm = self.privateRealm,
           let uid = currentUserId,
           let sessionId = sessionId {
            
            let results = realm.objects(CosyncAssetUpload.self)
                .filter("uid == '\(uid)' && sessionId=='\(sessionId)'")
            
            self.uploadToken = results.observe { [self] (changes: RealmCollectionChange) in
        
                switch changes {
                case .initial: break
                    
                case .update( let results, _, _, let modifications):
                    
                    if(!modifications.isEmpty){
                        for index in modifications {
                            //let asset = results[index]
                            if results[index].status == "initialized" {
                                self.uploadAsset(assetUpload: results[index])
                            }
                        }
                    }
                   
                    
                case .error(let error):
                    // An error occurred while opening the Realm file on the background worker thread
                    fatalError("\(error)")
                }
            }
        }
    }
    
    private func setUpAssetListener(){
        
        if let publicRealm = self.publicRealm,
           let uid = self.currentUserId {
            
            let publicAsset = publicRealm.objects(CosyncAsset.self).filter("uid == '\(uid)'")
            for asset in publicAsset {
                self.assetListPublic.append(asset)
                self.allAssets.append(asset)
            }
            
            
            self.publicAssetToken = publicAsset.observe { (changes: RealmCollectionChange) in
            
                switch changes {
                case .initial: break
                    
                case .update(let results, let deletions, let insertions, let modifications):
                    
                    if(!insertions.isEmpty){
                        for index in insertions {
                            let item = results[index]
                            self.assetListPublic.append(item)
                            self.allAssets.append(item)
                            self.uploadedAsset = item
                        }
                    }
                    
                    if(!modifications.isEmpty){
                        for index in modifications {
                            let asset = results[index]
                            self.assetListPublic = self.assetListPublic.map { item in
                                item._id == asset._id ? asset : item
                            }
                            self.allAssets = self.allAssets.map { item in
                                item._id == asset._id ? asset : item
                            }
                        }
                    }
                    
                    if(!deletions.isEmpty){
                        for index in deletions {
                            self.assetListPublic = self.assetListPublic.filter{$0._id != self.assetListPublic[index]._id}
                            
                            self.allAssets = self.allAssets.filter{$0._id != self.allAssets[index]._id}
                            
                            
                            
                        }
                    }
                    
                    
                case .error(let error):
                    // An error occurred while opening the Realm file on the background worker thread
                    print("\(error)")
                }
                    
            }
                    
        }
        
        
        if let userRealm = self.privateRealm,
           let uid = self.currentUserId {
            
            let privateAsset = userRealm.objects(CosyncAsset.self).filter("uid == '\(uid)'")
            
            for asset in privateAsset {
                self.assetListPrivate.append(asset)
                self.allAssets.append(asset)
            }
            
            self.privateAssetToken = privateAsset.observe { (changes: RealmCollectionChange) in
            
                switch changes {
                case .initial: break
                    
                    
                case .update(let results, let deletions, let insertions, let modifications):
                
                    if(!insertions.isEmpty){
                        for index in insertions {
                            let item = results[index]
                            self.assetListPrivate.append(item)
                            self.allAssets.append(item)
                            self.uploadedAsset = item
                        }
                    }
                    
                    if(!modifications.isEmpty){
                        
                        for index in modifications {
                            let asset = results[index]
                            self.assetListPrivate = self.assetListPrivate.map { item in
                                item._id == asset._id ? asset : item
                            }
                            
                            self.allAssets = self.allAssets.map { item in
                                item._id == asset._id ? asset : item
                            }
                            
                            
                        }
                    }
                    
                    if(!deletions.isEmpty){
                        for index in deletions {
                            self.assetListPrivate = self.assetListPrivate.filter{$0._id != self.assetListPrivate[index]._id}
                            
                            self.allAssets = self.allAssets.filter{$0._id != self.allAssets[index]._id}
                        }
                    }
                    
                    
                case .error(let error):
                    // An error occurred while opening the Realm file on the background worker thread
                    print("\(error)")
                }
                    
            }
                    
        }
    }
    
    
    
    @available(iOS 15.0, *)
    func uploadAsset(assetUpload: CosyncAssetUpload) {
        
        if assetUpload.status != "initialized"{
            return
        }
        
        DispatchQueue.main.async {
            self.uploadStart = true
            self.uploadedAssetList = []
        }
        
        let assetLocalIdentifier = assetUpload.extra
        if let contentType = assetUpload.contentType {
            if assetLocalIdentifier.count > 0  {
                
                let identifiers = [assetLocalIdentifier]
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
                if let phAsset = fetchResult.firstObject {
                    let resources = PHAssetResource.assetResources(for: phAsset)
                    
                    if let fileName = resources.first?.originalFilename {
                        let imageManager = PHImageManager.default()
                        
                        let options = PHImageRequestOptions()
                        options.resizeMode = PHImageRequestOptionsResizeMode.exact
                        options.isSynchronous = true;
                        
                        imageManager.requestImage(for: phAsset, targetSize: CGSize(width: phAsset.pixelWidth, height: phAsset.pixelHeight), contentMode: .aspectFit, options: options, resultHandler: { image, _ in
                            
                            if  let image = image {
                                if contentType.hasPrefix("video") {
                                    
                                     
                                    imageManager.requestAVAsset(forVideo: phAsset, options: nil) { (asset, audioMix, info) in
                                        if let asset = asset as? AVURLAsset {
                                            self.uploadVideo(assetUpload: assetUpload, videoUrl: asset.url, image: image,  fileName: fileName, contentType:contentType)
                                        }
                                    }
                                }
                                else{
                                    self.uploadImage(assetUpload: assetUpload, image: image, fileName:fileName, contentType:contentType)
                                }
                            }
                        })
                    }
                }
            }
        }
        
    }
    
    
    @available(iOS 15.0, *)
    func uploadImage(assetUpload:CosyncAssetUpload, image:UIImage, fileName:String, contentType:String){
        
        DispatchQueue.main.async {
            
            if  let writeUrl = assetUpload.writeUrl,
                let writeUrlSmall = assetUpload.writeUrlSmall,
                let writeUrlMedium = assetUpload.writeUrlMedium,
                let writeUrlLarge = assetUpload.writeUrlLarge,
                let imageSmall = image.imageCut(cutSize: 300),
                let imageMedium = image.imageCut(cutSize: 600),
                let imageLarge =  image.imageCut(cutSize: 900){
             
                self.uploadTask = "original-"+fileName
                
                Task{
                    do{
                        
                        self.uploadPhase = .uploadImageUrl
                        try await self.uploadImageToURL(image: image, fileName: "original-"+fileName, writeUrl: writeUrl, contentType: contentType)
                       
                        
                        self.uploadTask = "small-"+fileName
                        self.uploadPhase = .uploadImageUrlSmall
                        try await self.uploadImageToURL(image: imageSmall, fileName: "small-"+fileName, writeUrl: writeUrlSmall, contentType: contentType)
                        if let urlSmall = assetUpload.urlSmall {
                            self.uploadedAssetList.append(urlSmall)
                        }
                    
                        
                        self.uploadTask = "medium-"+fileName
                        self.uploadPhase = .uploadImageUrlMedium
                        try await self.uploadImageToURL(image: imageMedium, fileName: "medium-"+fileName, writeUrl: writeUrlMedium, contentType: contentType)
                        if let urlMedium = assetUpload.urlMedium {
                            self.uploadedAssetList.append(urlMedium)
                        }
                    
                        
                        self.uploadTask = "large-"+fileName
                        self.uploadPhase = .uploadImageUrlLarge
                        try await self.uploadImageToURL(image: imageLarge, fileName: "large-"+fileName, writeUrl: writeUrlLarge, contentType: contentType)
                        if let urlLarge = assetUpload.urlLarge {
                            self.uploadedAssetList.append(urlLarge)
                        }
                        
                   
                        self.uploadSuccess(assetUpload:assetUpload)
                      
                        
                        
                    }
                    catch {
                        self.uploadError(assetUpload)
                        print("upload error")
                    }
                   
                }
            }
        }
    }
    
     
    
    
    @available(iOS 15.0, *)
    func uploadImageToURL(image: UIImage, fileName: String, writeUrl: String, contentType: String) async throws {
       
        var fullImageData: Data?
        if contentType == "image/jpeg" {
            fullImageData = image.jpegData(compressionQuality: 1.0)
        }
        else if contentType == "image/png" {
            fullImageData = image.pngData()
        }
        else{
            fullImageData = image.jpegData(compressionQuality: 1.0)
        }
        
        if let fullImageData = fullImageData {
          
            var urlRequest = URLRequest(url: URL(string: writeUrl)!)
            urlRequest.httpMethod = "PUT"
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-type")
            
            let (_, response) = try await URLSession.shared.upload(for: urlRequest, from: fullImageData, delegate: self)
             
            guard let taskResponse = response as? HTTPURLResponse else {
                print("no response")
                throw UploadError.uploadFail
            }
            
            if taskResponse.statusCode != 200 {
                print("response status code: \(taskResponse.statusCode)")
                throw UploadError.uploadFail
            }
        }
        else {
            
            throw UploadError.invalidImage
        }
    }
    
    @available(iOS 15.0, *)
    func uploadVideoToURL(videoUrl: URL, fileName: String, writeUrl: String, contentType: String) async throws  {
        
        let fullVideoData: Data? = try Data(contentsOf: videoUrl)
        
        if let fullVideoData = fullVideoData {
            
            var urlRequest = URLRequest(url: URL(string: writeUrl)!)
            urlRequest.httpMethod = "PUT"
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-type")
            
            let (_, response) = try await URLSession.shared.upload(for: urlRequest, from: fullVideoData, delegate: self)
             
            guard let taskResponse = response as? HTTPURLResponse else {
                print("no response")
                throw UploadError.uploadFail
            }
            
            if taskResponse.statusCode != 200 {
                print("response status code: \(taskResponse.statusCode)")
                throw UploadError.uploadFail
            }
        }
    }
    
    @available(iOS 15.0, *)
    func uploadVideo(assetUpload:CosyncAssetUpload, videoUrl: URL, image: UIImage, fileName: String, contentType:String){
        
        DispatchQueue.main.async {
            
            if  let writeUrl = assetUpload.writeUrl,
                let writeUrlVideoPreview = assetUpload.writeUrlVideoPreview,
                let writeUrlSmall = assetUpload.writeUrlSmall,
                let writeUrlMedium = assetUpload.writeUrlMedium,
                let writeUrlLarge = assetUpload.writeUrlLarge,
                let imageSmall = image.imageCut(cutSize: 300),
                let imageMedium = image.imageCut(cutSize: 600),
                let imageLarge =  image.imageCut(cutSize: 900){
             
                self.uploadTask = "video-"+fileName
                
                Task{
                    do{
                        self.uploadAmount = 0.0
                        self.uploadPhase = .uploadVideoUrl
                        try await self.uploadVideoToURL(videoUrl: videoUrl, fileName: fileName, writeUrl: writeUrl, contentType: contentType)
                        
                        
                        let imageContentType = "image/png"
                        self.uploadTask = "preview-"+fileName
                        self.uploadPhase = .uploadVideoUrlPreview
                        try await self.uploadImageToURL(image: image, fileName: "preview-"+fileName, writeUrl: writeUrlVideoPreview, contentType: imageContentType)
                        
                        self.uploadPhase = .uploadVideoUrlSmall
                        self.uploadTask = "small-"+fileName
                        try await self.uploadImageToURL(image: imageSmall, fileName: "small-"+fileName, writeUrl: writeUrlSmall, contentType: imageContentType)
                        if let urlSmall = assetUpload.urlSmall {
                            self.uploadedAssetList.append(urlSmall)
                        }
                        
                         
                        self.uploadPhase = .uploadVideoUrlMedium
                        self.uploadTask = "medium-"+fileName
                        try await self.uploadImageToURL(image: imageMedium, fileName: "medium-"+fileName, writeUrl: writeUrlMedium, contentType: imageContentType)
                        if let urlMedium = assetUpload.urlMedium {
                            self.uploadedAssetList.append(urlMedium)
                        }
                        
                        
                        self.uploadPhase = .uploadVideoUrlLarge
                        self.uploadTask = "large-"+fileName
                        try await self.uploadImageToURL(image: imageLarge, fileName: "large-"+fileName, writeUrl: writeUrlLarge, contentType: imageContentType)
                        if let urlLarge = assetUpload.urlLarge {
                            self.uploadedAssetList.append(urlLarge)
                        }
                        
                        self.uploadSuccess(assetUpload:assetUpload)
                        
                    }
                    catch{
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }
    
     
    
    func uploadError(_ assetUpload: CosyncAssetUpload) -> Void {
        uploadStart = false
        DispatchQueue.main.async {
            if let userRealm = self.privateRealm {
                try! userRealm.write {
                    assetUpload.status = "error"
                }
            }
        }

    }
    
    func uploadSuccess( assetUpload: CosyncAssetUpload) -> Void {
        uploadStart = false
        DispatchQueue.main.async {
            if let userRealm = self.privateRealm {
                try! userRealm.write {
                    assetUpload.status = "uploaded"
                }
            }
        }

    }
    
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
        let progress = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
       
            
        var value: Float = 0.0
        switch self.uploadPhase {
        // Image upload
        case .uploadImageUrl:
            value = progress * 0.50
        case .uploadImageUrlSmall:
            value = 0.50 + (progress * 0.10)
        case .uploadImageUrlMedium:
            value = 0.60 + (progress * 0.10)
        case .uploadImageUrlLarge:
            value = 0.65 + (progress * 0.30)
            
        // Video upload
        case .uploadVideoUrl:
            value = progress * 0.70
        case .uploadVideoUrlPreview:
            value = 0.70 + (progress * 0.05)
        case .uploadVideoUrlSmall:
            value = 0.75 + (progress * 0.05)
        case .uploadVideoUrlMedium:
            value = 0.80 + (progress * 0.05)
        case .uploadVideoUrlLarge:
            value = 0.85 + (progress * 0.10)
        }
        
        DispatchQueue.main.async {
            self.uploadAmount = Double(value) * 100.0
        }
    }
    
    
    
    public func createAssetUpload(assetIdList: [String], expiredHours:Double, path:String){
         
        if let currentUserId = self.currentUserId,
           let sessionId = self.sessionId {
            
       
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIdList, options: nil)
            fetchResult.enumerateObjects { object, index, stop in
                let phAsset = object as PHAsset
                let resources = PHAssetResource.assetResources(for: phAsset)
                if let file = resources.first {
                    let fileSize = file.value(forKey: "fileSize") as? Int
                    let fileName = file.originalFilename
                    let options = PHContentEditingInputRequestOptions()
                    options.isNetworkAccessAllowed = true
                    
                    var duration = 0.0
                    var contentType = "image/jpeg"
                    if fileName.contains(".PNG") || fileName.contains(".png") {
                        contentType = "image/png"
                    }
                    else if fileName.contains(".mov") || fileName.contains(".MOV"){
                        contentType = "video/quicktime"
                        duration = Double(phAsset.duration)
                    }
                    
            
                    let xRes = phAsset.pixelWidth
                    let yRes = phAsset.pixelHeight
                    let imageManager = PHImageManager.default()
                    
                    let phOptions = PHImageRequestOptions()
                    phOptions.resizeMode = PHImageRequestOptionsResizeMode.exact
                    phOptions.isSynchronous = true;
                    
                    imageManager.requestImage(for: phAsset,
                                              targetSize: CGSize(width: xRes, height: yRes),
                                              contentMode: .aspectFit,
                                              options: phOptions,
                                              resultHandler: { image, _ in
                        
                        if  let image = image {
                            
                            let color = image.averageColor()
                            
                            let cosyncAssetUpload = CosyncAssetUpload()
                            cosyncAssetUpload.expirationHours = expiredHours
                            cosyncAssetUpload._id = ObjectId.generate()
                            cosyncAssetUpload._partition = "user_id=\(currentUserId)"
                            cosyncAssetUpload.uid = currentUserId
                            cosyncAssetUpload.sessionId = sessionId
                            cosyncAssetUpload.extra = phAsset.localIdentifier
                            cosyncAssetUpload.assetPartition = "public"
                            cosyncAssetUpload.filePath = path + "/" + fileName
                            cosyncAssetUpload.contentType = contentType
                            cosyncAssetUpload.size = fileSize
                            cosyncAssetUpload.duration = duration
                            cosyncAssetUpload.color = color
                            cosyncAssetUpload.xRes = xRes
                            cosyncAssetUpload.yRes = yRes
                            
                            self.uploadAssetId = cosyncAssetUpload._id
                            
                            if let userRealm = self.privateRealm {
                                try! userRealm.write {
                                    userRealm.add(cosyncAssetUpload)
                                }
                            }
                        }
                    })
                }
            }
        }
    }
    
    
    @MainActor public func refreshAsset(assetId:String)  {
        
        do {
            
            self.app.currentUser!.functions.CosyncRefreshAsset([AnyBSON(assetId)])  { result, error in
                let decoder = JSONDecoder()

                do {
                    _ = try decoder.decode(AssetModel.self, from: Data(result!.stringValue!.utf8))
                    
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
        
    }
    
    
    public func reset(){
        uploadedAssetList = []
        uploadAmount = 0.0
        uploadStart = false
    }
    
    
}
