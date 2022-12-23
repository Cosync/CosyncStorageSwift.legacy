
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
    @Published public var assetLists = [CosyncAsset]()
    @Published public var allAssets = [CosyncAsset]()
    @Published public var uploadedAssetList:[String] = []
    @Published public var uploadStart = false
    @Published public var uploadTask = ""
    @Published public var uploadAmount = 0.0
    @Published public var uploadAssetId = ObjectId()
    
    private var cosyncAssetUpload: CosyncAssetUpload?
    private var uploadToken: NotificationToken! = nil
    private var assetToken: NotificationToken! = nil
    
    
    private var uploadPhase: UploadPhase = .uploadImageUrl
    
    private var sessionId: String? {
        return UIDevice.current.identifierForVendor?.uuidString
    }
    
    private var realm:Realm?
    
    private var app : App! = nil
    private var currentUserId: String?
    
    private var smallImageCutSize:Int = 300
    private var mediumImageCutSize: Int = 600
    private var largeImageCutSize: Int = 900
    
    @available(iOS 15.0, *)
    public func configure(app: App, realm:Realm) {
        
        self.app = app
        
        self.realm = realm
        
        if  let user = self.app.currentUser {
            currentUserId = user.id
            
            setUpAssetListener()
            setUpUploadListener()
        }
        else{
            print("CosyncStorageSwift: invalid realm configuration")
        }
       
    }
    
    @available(iOS 15.0, *)
    public func resetThumbnailCutSize() {
        self.smallImageCutSize = 300
        self.mediumImageCutSize = 600
        self.largeImageCutSize = 900
    }
    
    @available(iOS 15.0, *)
    public func configureThumbnailCutSize(smallSize: Int, mediumSize: Int, largeSize: Int) {
        self.smallImageCutSize = smallSize
        self.mediumImageCutSize = mediumSize
        self.largeImageCutSize = largeSize
    }
    
    
    @available(iOS 15.0, *)
    private func setUpUploadListener(){
        
        if let realm = self.realm,
           let userId = currentUserId,
           let sessionId = sessionId {
            
            let results = realm.objects(CosyncAssetUpload.self)
                .filter("userId == '\(userId)' && sessionId=='\(sessionId)'")
            
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
        
        if let realm = self.realm,
           let userId = self.currentUserId {
            
            let assetList = realm.objects(CosyncAsset.self).filter("userId == '\(userId)'")
            for asset in assetList {
                self.assetLists.append(asset)
                self.allAssets.append(asset)
            }
            
            
            self.assetToken = assetList.observe { (changes: RealmCollectionChange) in
            
                switch changes {
                case .initial: break
                    
                case .update(let results, let deletions, let insertions, let modifications):
                    
                    if(!insertions.isEmpty){
                        for index in insertions {
                            let item = results[index]
                            self.assetLists.append(item)
                            self.allAssets.append(item)
                            self.uploadedAsset = item
                        }
                    }
                    
                    if(!modifications.isEmpty){
                        for index in modifications {
                            let asset = results[index]
                            self.assetLists = self.assetLists.map { item in
                                item._id == asset._id ? asset : item
                            }
                            self.allAssets = self.allAssets.map { item in
                                item._id == asset._id ? asset : item
                            }
                        }
                    }
                    
                    if(!deletions.isEmpty){
                        for index in deletions {
                            self.assetLists = self.assetLists.filter{$0._id != self.assetLists[index]._id}
                            
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
        
        cosyncAssetUpload = assetUpload
        
        DispatchQueue.main.async {
            self.uploadStart = true
            self.uploadedAssetList = []
        }
        
        let assetLocalIdentifier = assetUpload.extra
        
        if let contentType = assetUpload.contentType {
            if assetLocalIdentifier.count > 0  {
                
                if contentType.contains("image") || contentType.contains("video"){
                    
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
                else {
                    
                    Task{
                        do {
                            try await uploadFileToURL(localSource: assetLocalIdentifier, writeUrl: assetUpload.writeUrl!, contentType: contentType)
                            
                        }
                        catch{
                            
                        }
                    }
                }
                
            }
        }
        
    }
    
    
    @available(iOS 15.0, *)
    func uploadImage(assetUpload:CosyncAssetUpload, image:UIImage, fileName:String, contentType:String){
        
        DispatchQueue.main.async {
            let noCuts = assetUpload.noCuts
            if noCuts != nil && noCuts == true {
                let writeUrl = assetUpload.writeUrl
                
                Task{
                    do {
                        if let originalSize = assetUpload.originalSize,
                           originalSize > 0 {
                            
                            let imageOriginalCut = image.imageCut(cutSize: CGFloat(originalSize))
                            try await self.uploadImageToURL(image: imageOriginalCut!, fileName: "original-"+fileName, writeUrl: writeUrl!, contentType: contentType)
                        }
                        else {
                            try await self.uploadImageToURL(image: image, fileName: "original-"+fileName, writeUrl: writeUrl!, contentType: contentType)
                        }
                        
                        self.uploadSuccess(assetUpload:assetUpload)
                        
                        if let url = assetUpload.url {
                            self.uploadedAssetList.append(url)
                        }
                    }
                    catch {
                        self.uploadError(assetUpload)
                        print("CosyncStorageSwift:  upload error")
                    }
                }
            }
            else if let writeUrl = assetUpload.writeUrl,
                let writeUrlSmall = assetUpload.writeUrlSmall,
                let writeUrlMedium = assetUpload.writeUrlMedium,
                let writeUrlLarge = assetUpload.writeUrlLarge {
                
                var smallCutSize = self.smallImageCutSize
                if (assetUpload.smallCutSize != nil && assetUpload.smallCutSize! > 0){
                    smallCutSize = assetUpload.smallCutSize!
                }
                
                var mediumCutSize = self.mediumImageCutSize
                if (assetUpload.mediumCutSize != nil && assetUpload.mediumCutSize! > 0){
                    mediumCutSize = assetUpload.mediumCutSize!
                }
                
                var largeCutSize = self.largeImageCutSize
                if (assetUpload.largeCutSize != nil && assetUpload.largeCutSize! > 0){
                    largeCutSize = assetUpload.largeCutSize!
                }
            
                let imageSmall = image.imageCut(cutSize: CGFloat(smallCutSize))
                let imageMedium = image.imageCut(cutSize: CGFloat(mediumCutSize))
                let imageLarge =  image.imageCut(cutSize: CGFloat(largeCutSize))
             
                self.uploadTask = "original-"+fileName
                
                Task{
                    do{
                        
                        self.uploadPhase = .uploadImageUrl
                        try await self.uploadImageToURL(image: image, fileName: "original-"+fileName, writeUrl: writeUrl, contentType: contentType)
                       
                        
                        self.uploadTask = "small-"+fileName
                        self.uploadPhase = .uploadImageUrlSmall
                        try await self.uploadImageToURL(image: imageSmall!, fileName: "small-"+fileName, writeUrl: writeUrlSmall, contentType: contentType)
                        if let urlSmall = assetUpload.urlSmall {
                            self.uploadedAssetList.append(urlSmall)
                        }
                    
                        
                        self.uploadTask = "medium-"+fileName
                        self.uploadPhase = .uploadImageUrlMedium
                        try await self.uploadImageToURL(image: imageMedium!, fileName: "medium-"+fileName, writeUrl: writeUrlMedium, contentType: contentType)
                        if let urlMedium = assetUpload.urlMedium {
                            self.uploadedAssetList.append(urlMedium)
                        }
                    
                        
                        self.uploadTask = "large-"+fileName
                        self.uploadPhase = .uploadImageUrlLarge
                        try await self.uploadImageToURL(image: imageLarge!, fileName: "large-"+fileName, writeUrl: writeUrlLarge, contentType: contentType)
                        if let urlLarge = assetUpload.urlLarge {
                            self.uploadedAssetList.append(urlLarge)
                        }
                        
                   
                        self.uploadSuccess(assetUpload:assetUpload)
                      
                        
                        
                    }
                    catch {
                        self.uploadError(assetUpload)
                        print("CosyncStorageSwift:  upload error")
                    }
                   
                }
            }
        }
    }
    
     
    
    
    @available(iOS 15.0, *)
    func uploadImageToURL(image: UIImage, fileName: String, writeUrl: String, contentType: String) async throws {
       
        var fullImageData: Data?
        if contentType == "image/png" {
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
                print("CosyncStorageSwift:  no response")
                throw UploadError.uploadFail
            }
            
            if taskResponse.statusCode != 200 {
                print("CosyncStorageSwift:  response status code: \(taskResponse.statusCode)")
                throw UploadError.uploadFail
            }
        }
        else {
            
            throw UploadError.invalidImage
        }
    }
    
    @available(iOS 15.0, *)
    func uploadFileToURL(localSource: String, writeUrl: String, contentType: String) async throws  {
        
        let fileData: Data? = try Data(contentsOf: URL(string: localSource)!)
        
        if let data = fileData {
            
            var urlRequest = URLRequest(url: URL(string: writeUrl)!)
            urlRequest.httpMethod = "PUT"
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-type")
            
            let (_, response) = try await URLSession.shared.upload(for: urlRequest, from: data, delegate: self)
             
            guard let taskResponse = response as? HTTPURLResponse else {
                print("CosyncStorageSwift:  no response")
                throw UploadError.uploadFail
            }
            
            if taskResponse.statusCode != 200 {
                print("CosyncStorageSwift:  response status code: \(taskResponse.statusCode)")
                throw UploadError.uploadFail
            }
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
                print("CosyncStorageSwift:  no response")
                throw UploadError.uploadFail
            }
            
            if taskResponse.statusCode != 200 {
                print("CosyncStorageSwift:  response status code: \(taskResponse.statusCode)")
                throw UploadError.uploadFail
            }
        }
    }
    
    @available(iOS 15.0, *)
    func uploadVideo(assetUpload:CosyncAssetUpload, videoUrl: URL, image: UIImage, fileName: String, contentType:String){
        
        DispatchQueue.main.async {
            
            let noCuts = assetUpload.noCuts
            
            if noCuts != nil && noCuts == true {
               let writeUrl = assetUpload.writeUrl
                let writeUrlVideoPreview = assetUpload.writeUrlVideoPreview
                
                Task{
                    do {
                        self.uploadAmount = 0.0
                        self.uploadPhase = .uploadVideoUrl
                        try await self.uploadVideoToURL(videoUrl: videoUrl, fileName: fileName, writeUrl: writeUrl!, contentType: contentType)
                        
                        
                        let imageContentType = "image/png"
                        self.uploadTask = "preview-"+fileName
                        self.uploadPhase = .uploadVideoUrlPreview
                        try await self.uploadImageToURL(image: image, fileName: "preview-"+fileName, writeUrl: writeUrlVideoPreview!, contentType: imageContentType)
                        
                        self.uploadSuccess(assetUpload:assetUpload)
                    }
                    catch {
                        self.uploadError(assetUpload)
                        print("CosyncStorageSwift:  upload error")
                    }
                }
            }
            
            else if let writeUrl = assetUpload.writeUrl,
                let writeUrlVideoPreview = assetUpload.writeUrlVideoPreview,
                let writeUrlSmall = assetUpload.writeUrlSmall,
                let writeUrlMedium = assetUpload.writeUrlMedium,
                let writeUrlLarge = assetUpload.writeUrlLarge {
                
                var smallCutSize = self.smallImageCutSize
                if (assetUpload.smallCutSize != nil && assetUpload.smallCutSize! > 0){
                    smallCutSize = assetUpload.smallCutSize!
                }
                
                var mediumCutSize = self.mediumImageCutSize
                if (assetUpload.mediumCutSize != nil && assetUpload.mediumCutSize! > 0){
                    mediumCutSize = assetUpload.mediumCutSize!
                }
                
                var largeCutSize = self.largeImageCutSize
                if (assetUpload.largeCutSize != nil && assetUpload.largeCutSize! > 0){
                    largeCutSize = assetUpload.largeCutSize!
                }
                
                let imageSmall = image.imageCut(cutSize: CGFloat(smallCutSize))
                let imageMedium = image.imageCut(cutSize: CGFloat(mediumCutSize))
                let imageLarge =  image.imageCut(cutSize: CGFloat(largeCutSize))
             
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
                        try await self.uploadImageToURL(image: imageSmall!, fileName: "small-"+fileName, writeUrl: writeUrlSmall, contentType: imageContentType)
                        if let urlSmall = assetUpload.urlSmall {
                            self.uploadedAssetList.append(urlSmall)
                        }
                        
                         
                        self.uploadPhase = .uploadVideoUrlMedium
                        self.uploadTask = "medium-"+fileName
                        try await self.uploadImageToURL(image: imageMedium!, fileName: "medium-"+fileName, writeUrl: writeUrlMedium, contentType: imageContentType)
                        if let urlMedium = assetUpload.urlMedium {
                            self.uploadedAssetList.append(urlMedium)
                        }
                        
                        
                        self.uploadPhase = .uploadVideoUrlLarge
                        self.uploadTask = "large-"+fileName
                        try await self.uploadImageToURL(image: imageLarge!, fileName: "large-"+fileName, writeUrl: writeUrlLarge, contentType: imageContentType)
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
            if let userRealm = self.realm {
                try! userRealm.write {
                    assetUpload.status = "error"
                }
            }
        }

    }
    
    func uploadSuccess( assetUpload: CosyncAssetUpload) -> Void {
        uploadStart = false
        DispatchQueue.main.async {
            if let userRealm = self.realm {
                try! userRealm.write {
                    assetUpload.status = "uploaded"
                }
            }
        }

    }
    
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
        let progress = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
        
        DispatchQueue.main.async {
            
            var value: Float = 0.0
            if( self.cosyncAssetUpload?.noCuts == false){
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
            }
            else {
                value = progress
            }
      
            self.uploadAmount = Double(value) * 100.0
        }
    }
    
    public func createFileAssetUpload(assetId: ObjectId,  path:String, expiredHours:Double, fileURL:URL ){
        
         
        
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let dict = attr as NSDictionary
            let fileSize = dict.fileSize()
           
            let cosyncAssetUpload = CosyncAssetUpload()
            cosyncAssetUpload.expirationHours = expiredHours
            cosyncAssetUpload._id = assetId
            cosyncAssetUpload.userId =  self.currentUserId!
            cosyncAssetUpload.sessionId = self.sessionId!
            cosyncAssetUpload.extra = fileURL.path
            cosyncAssetUpload.filePath = path + "/" + fileURL.lastPathComponent
            cosyncAssetUpload.contentType = fileURL.mimeType()
            cosyncAssetUpload.size = Int(fileSize)
            cosyncAssetUpload.createdAt = Date()
            cosyncAssetUpload.updatedAt = Date()
            
            if let userRealm = self.realm {
                try! userRealm.write {
                    userRealm.add(cosyncAssetUpload)
                }
            }
        }
        catch{
            
            print(error.localizedDescription)
        }
    }
    
    
    public func createAssetUpload(assetIdList: [String], expiredHours:Double, path:String, noCuts:Bool = false, originalSize:Int = 0, smallCutSize:Int = 0, mediumCutSize:Int = 0, largeCutSize:Int = 0) -> [ObjectId]{
        var objectIdList:[ObjectId] = []
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
                    var contentType = fileName.mimeType()
                    
//                    if fileName.contains(".PNG") || fileName.contains(".png") {
//                        contentType = "image/png"
//                    }
//                    else if fileName.contains(".mov") || fileName.contains(".MOV"){
//                        contentType = "video/quicktime"
//                        duration = Double(phAsset.duration)
//                    }
//                    else if fileName.contains(".m4a") {
//                        contentType = "audio/x-m4a"
//                    }
                    
                    print("CosyncStorageSwift contentType : \(contentType)")
                    
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
                            cosyncAssetUpload.userId = currentUserId
                            cosyncAssetUpload.sessionId = sessionId
                            cosyncAssetUpload.extra = phAsset.localIdentifier
                            cosyncAssetUpload.filePath = path + "/" + fileName
                            cosyncAssetUpload.contentType = contentType
                            cosyncAssetUpload.size = fileSize
                            cosyncAssetUpload.duration = duration
                            cosyncAssetUpload.color = color
                            cosyncAssetUpload.xRes = xRes
                            cosyncAssetUpload.yRes = yRes
                            cosyncAssetUpload.noCuts = noCuts
                            cosyncAssetUpload.originalSize = originalSize
                            cosyncAssetUpload.smallCutSize = smallCutSize > 0 ? smallCutSize : self.smallImageCutSize
                            cosyncAssetUpload.mediumCutSize = mediumCutSize > 0 ? mediumCutSize : self.mediumImageCutSize
                            cosyncAssetUpload.largeCutSize = largeCutSize > 0 ? largeCutSize : self.largeImageCutSize
                            cosyncAssetUpload.createdAt = Date()
                            cosyncAssetUpload.updatedAt = Date()
                            
                            self.uploadAssetId = cosyncAssetUpload._id
                            objectIdList.append(cosyncAssetUpload._id)
                            
                            if let userRealm = self.realm {
                                try! userRealm.write {
                                    userRealm.add(cosyncAssetUpload)
                                }
                            }
                        }
                    })
                }
            }
        }
        return objectIdList
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
