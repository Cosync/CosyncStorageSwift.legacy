
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
    @Published public var uploadedCosyncAssetUploadList = [CosyncAssetUpload]()
    @Published public var uploadStart = false
    @Published public var uploadTask = ""
    @Published public var uploadAmount = 0.0
    @Published public var uploadAssetId = ObjectId()
    @Published public var uploadAssetFail = ""
    
    private var currentCosyncAssetUpload: CosyncAssetUpload?
    private var uploadToken: NotificationToken! = nil
    private var assetToken: NotificationToken! = nil
    private var cosyncAssetUploadQueue = [CosyncAssetUpload]()
    
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
                        print("before on delete asset assetLists = \(self.assetLists.count)")
                        self.assetLists = self.assetLists.filter{$0.isInvalidated == false}
                        self.allAssets = self.assetLists.filter{$0.isInvalidated == false}
                        print("after on delete asset assetLists = \(self.assetLists.count)")
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
        
        currentCosyncAssetUpload = assetUpload
        
        DispatchQueue.main.async {
            self.uploadStart = true
        }
        
        let assetLocalIdentifier = assetUpload.extra
        
        if let contentType = assetUpload.contentType {
            if assetLocalIdentifier.count > 0  {
                
                if contentType.contains("image"){
                    
                    let identifiers = [assetLocalIdentifier]
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
                    if let phAsset = fetchResult.firstObject {
                        let resources = PHAssetResource.assetResources(for: phAsset)
                        
                        if let fileName = resources.first?.originalFilename {
                            let imageManager = PHImageManager.default()
                            let  trimmedFileName = fileName.filter({$0 != " "})
                            let options = PHImageRequestOptions()
                            options.resizeMode = PHImageRequestOptionsResizeMode.exact
                            options.isSynchronous = true;
                            
                            imageManager.requestImage(for: phAsset, targetSize: CGSize(width: phAsset.pixelWidth, height: phAsset.pixelHeight), contentMode: .aspectFit, options: options, resultHandler: { image, _ in
                                
                                if  let image = image {
                                    self.uploadImage(assetUpload: assetUpload, image: image, fileName:trimmedFileName, contentType:contentType)
                                }
                            })
                        }
                    }
                }
                else {
                    DispatchQueue.main.async {
                        Task{
                            do {
                                try await self.uploadFileToURL(assetUpload:assetUpload ,filename: assetLocalIdentifier, writeUrl: assetUpload.writeUrl!, contentType: contentType)
                                
                            }
                            catch{
                                print("CosyncStorage: upload file fails ")
                                self.uploadError(assetUpload)
                            }
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
 
                        
                        self.uploadTask = "medium-"+fileName
                        self.uploadPhase = .uploadImageUrlMedium
                        try await self.uploadImageToURL(image: imageMedium!, fileName: "medium-"+fileName, writeUrl: writeUrlMedium, contentType: contentType)
 
                        
                        self.uploadTask = "large-"+fileName
                        self.uploadPhase = .uploadImageUrlLarge
                        try await self.uploadImageToURL(image: imageLarge!, fileName: "large-"+fileName, writeUrl: writeUrlLarge, contentType: contentType)
                   
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
    
    func getDocumentsDirectory() -> URL {
        // find all possible documents directories for this user
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)

        // just send back the first one, which ought to be the only one
        return paths[0]
    }
    
    @available(iOS 15.0, *)
    func uploadFileToURL(assetUpload: CosyncAssetUpload ,filename: String, writeUrl: String, contentType: String) async throws  {
        
        let data: Data
        
        var url = getDocumentsDirectory().appendingPathComponent(filename)
        
        if contentType.contains("video"){
            url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            if let preview = url.generateVideoThumbnail() {
                try await uploadVideoAsset(assetUpload: assetUpload, videoUrl: url, image: preview, fileName: filename, contentType: contentType)
                return
            }
            
            print("Couldn't create image video preview of \(filename) ")
        }
        
            
        do {
            data = try Data(contentsOf: url)
        } catch {
            print("CosyncStorageSwift:  read data fail: \(error.localizedDescription)")
            throw UploadError.uploadFail
        }
        
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
        else {
           
            self.uploadNextFileAsset(uploadedAsset: assetUpload)
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
    func uploadVideoAsset(assetUpload:CosyncAssetUpload, videoUrl: URL, image: UIImage, fileName: String, contentType:String) async throws{
        
        DispatchQueue.main.async {
            let imageContentType = "image/png"
            Task{
                do {
                    let writeUrl = assetUpload.writeUrl
                   
                    self.uploadAmount = 0.0
                    self.uploadPhase = .uploadVideoUrl
                    try await self.uploadVideoToURL(videoUrl: videoUrl, fileName: fileName, writeUrl: writeUrl!, contentType: contentType)
                   
                    self.uploadTask = "preview-"+fileName
                    self.uploadPhase = .uploadVideoUrlPreview
                    let writeUrlVideoPreview = assetUpload.writeUrlVideoPreview
                    try await self.uploadImageToURL(image: image, fileName: "preview-"+fileName, writeUrl: writeUrlVideoPreview!, contentType: imageContentType)
                    
                   
                    
                    self.uploadNextFileAsset(uploadedAsset: assetUpload)
                }
                catch {
                    self.uploadError(assetUpload)
                    print("CosyncStorageSwift:  upload error")
                }
            }
            
            
            if assetUpload.noCuts == true { // finished upload
                
            }
            else { // create video image thumbnail
                
                if let writeUrlSmall = assetUpload.writeUrlSmall,
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
                     
                    
                    Task{
                        do{
                            self.uploadPhase = .uploadVideoUrlSmall
                            self.uploadTask = "small-"+fileName
                            try await self.uploadImageToURL(image: imageSmall!, fileName: "small-"+fileName, writeUrl: writeUrlSmall, contentType: imageContentType)
                           
                            
                            
                            self.uploadPhase = .uploadVideoUrlMedium
                            self.uploadTask = "medium-"+fileName
                            try await self.uploadImageToURL(image: imageMedium!, fileName: "medium-"+fileName, writeUrl: writeUrlMedium, contentType: imageContentType)
                           
                            
                            self.uploadPhase = .uploadVideoUrlLarge
                            self.uploadTask = "large-"+fileName
                            try await self.uploadImageToURL(image: imageLarge!, fileName: "large-"+fileName, writeUrl: writeUrlLarge, contentType: imageContentType)
                           
                            self.uploadNextFileAsset(uploadedAsset: assetUpload)
                        }
                        catch{
                            print(error.localizedDescription)
                        }
                    }
                }
                else {
                    
                    print("CosyncStorageSwift:  invalid image thumbnail uploaded url ")
                    //self.uploadSuccess(assetUpload:assetUpload)
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
            self.uploadAssetFail = " Fail to upload asset \(assetUpload.extra)"
        }

    }
    
    func uploadSuccess( assetUpload: CosyncAssetUpload) -> Void {
        uploadStart = false
        DispatchQueue.main.async {
            
            self.uploadedCosyncAssetUploadList.append(assetUpload)
            
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
            
            var value: Float = progress
            if let contentType = self.currentCosyncAssetUpload?.contentType {
                if (contentType.contains("video") || contentType.contains("image")){
                    if( self.currentCosyncAssetUpload?.noCuts == false){
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
                    else if ((self.currentCosyncAssetUpload?.contentType?.contains("video")) != nil){
                        switch self.uploadPhase {
                        case .uploadVideoUrl:
                            value = progress * 0.85
                        case .uploadVideoUrlPreview:
                            value = 0.85 + (progress * 0.15)
                        case .uploadVideoUrlSmall: break
                            
                        case .uploadVideoUrlMedium: break
                            
                        case .uploadVideoUrlLarge: break
                            
                        case .uploadImageUrl: break
                            
                        case .uploadImageUrlSmall: break
                            
                        case .uploadImageUrlMedium: break
                            
                        case .uploadImageUrlLarge: break
                            
                        }
                    }
                }
            } 
            
            self.uploadAmount = Double(value) * 100.0
        }
    }
    
    public func createFileAssetUpload(fileURLs: [URL], path:String, expiredHours:Double, uploadQueue:Bool, noCut:Bool ) throws -> [ObjectId] {
        
        var objectIdList:[ObjectId] = []
        cosyncAssetUploadQueue.removeAll()
        do {
            for url in fileURLs {
                let attr = try FileManager.default.attributesOfItem(atPath: url.path)
                let dict = attr as NSDictionary
                let fileSize = dict.fileSize()
                
                let contentType = url.mimeType()
                print("CosyncStorageSwift createFileAssetUpload contentType : \(contentType)")
                
                let fileName = url.lastPathComponent.filter({$0 != " "})
                
                let cosyncAssetUpload = CosyncAssetUpload()
                cosyncAssetUpload.expirationHours = expiredHours
                cosyncAssetUpload._id = ObjectId.generate()
                cosyncAssetUpload.userId =  self.currentUserId!
                cosyncAssetUpload.sessionId = self.sessionId!
                cosyncAssetUpload.extra = url.lastPathComponent
                cosyncAssetUpload.noCuts = noCut
                cosyncAssetUpload.filePath = path + "/" + fileName
                cosyncAssetUpload.contentType = contentType
                cosyncAssetUpload.size = Int(fileSize)
                cosyncAssetUpload.createdAt = Date()
                cosyncAssetUpload.updatedAt = Date()
                objectIdList.append(cosyncAssetUpload._id)
                
                if (uploadQueue ) {
                    cosyncAssetUploadQueue.append(cosyncAssetUpload)
                }
                else{
                    if let userRealm = self.realm {
                        try! userRealm.write {
                            userRealm.add(cosyncAssetUpload)
                        }
                    }
                }
            }
            
            if(uploadQueue) {
                if let userRealm = self.realm {
                    try! userRealm.write {
                        userRealm.add(cosyncAssetUploadQueue[0])
                    }
                }
                else {
                    print("createFileAssetUpload invalid realm instance")
                }
            }
            
            return objectIdList
                
        }
        catch{
            print(error.localizedDescription)
            throw(error)
            
             
        }
    }
    
    private func uploadNextFileAsset(uploadedAsset:CosyncAssetUpload){
        
        uploadSuccess(assetUpload:uploadedAsset)
        
        DispatchQueue.main.async {
            if self.cosyncAssetUploadQueue.count > 0 {
                if let currentSoundIndex = self.cosyncAssetUploadQueue.firstIndex(where: {$0._id == uploadedAsset._id}){
                    let next = currentSoundIndex + 1
                    if next < self.cosyncAssetUploadQueue.count {
                        if let userRealm = self.realm {
                            try! userRealm.write {
                                userRealm.add(self.cosyncAssetUploadQueue[next])
                            }
                        }
                    }
                }
            }
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
                    let fileName = file.originalFilename.filter({$0 != " "})
                    let options = PHContentEditingInputRequestOptions()
                    options.isNetworkAccessAllowed = true
                    
                   
                    let contentType = fileName.mimeType()
                    print("CosyncStorageSwift createAssetUpload contentType : \(contentType)")
                    
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
        
        self.app.currentUser!.functions.CosyncRefreshAsset([AnyBSON(assetId)])  { result, error in
            
        
            let decoder = JSONDecoder()

            do {
                _ = try decoder.decode(AssetModel.self, from: Data(result!.stringValue!.utf8))
                
            } catch {
                print(error.localizedDescription)
                
            }
        }
        
        
    }
    
    
    public func reset(){
        uploadedCosyncAssetUploadList.removeAll()
        cosyncAssetUploadQueue.removeAll()
        uploadAmount = 0.0
        uploadStart = false
    }
    
    
}
