//
//  CosyncStorageDataModel.swift
//  
//
//  Created by Tola Voeung on 23/3/22.
//

import Foundation
import RealmSwift


public class CosyncAssetUpload: Object {
    
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var _partition: String
    @Persisted(indexed: true) var uid: String
    @Persisted var sessionId: String
    @Persisted var extra: String = ""
    @Persisted var assetPartition: String
    @Persisted var filePath: String = ""
    @Persisted var path: String = ""
    @Persisted var expirationHours: Double = 24.0
    @Persisted var contentType: String?
    @Persisted var size: Int?
    @Persisted var duration: Double?
    @Persisted var color: String = "#000000"
    @Persisted var xRes: Int = 0
    @Persisted var yRes: Int = 0
    @Persisted var smallCutSize: Int?
    @Persisted var mediumCutSize: Int?
    @Persisted var largeCutSize: Int?
    @Persisted var noCuts: Bool?
    @Persisted var caption: String = ""
    @Persisted var writeUrl: String?
    @Persisted var writeUrlSmall: String?
    @Persisted var writeUrlMedium: String?
    @Persisted var writeUrlLarge: String?
    @Persisted var writeUrlVideoPreview: String?
    @Persisted var urlSmall: String?
    @Persisted var urlMedium: String?
    @Persisted var urlLarge: String?
    @Persisted var urlVideoPreview: String?
    @Persisted(indexed: true) var status: String = "pending"
    @Persisted var createdAt: Date?
    @Persisted var updatedAt: Date?
}


public class CosyncAsset: Object {
    
    @Persisted(primaryKey: true) public var _id: ObjectId
    @Persisted public var _partition: String
    @Persisted(indexed: true) public var uid: String = "" 
    @Persisted(indexed: true) public var sessionId: String
    @Persisted public var path: String = ""
    @Persisted public var expirationHours: Double = 24.0
    @Persisted public var contentType: String?
    @Persisted public var size: Int?
    @Persisted public var duration: Double?
    @Persisted public var color: String = "#000000"
    @Persisted public var xRes: Int = 0
    @Persisted public var yRes: Int = 0
    @Persisted public var caption: String = ""
    @Persisted public var url: String?
    @Persisted public var urlSmall: String?
    @Persisted public var urlMedium: String?
    @Persisted public var urlLarge: String?
    @Persisted public var urlVideoPreview: String?
    @Persisted public var status: String = "active"
    @Persisted public var createdAt: Date?
    @Persisted public var updatedAt: Date?
}



public struct AssetModel: Codable {
    public var id: String
    public var _partition: String
    public var uid: String
    public var assetPartition: String?
    public var path: String = ""
    public var expirationHours: Double = 0.0
    public var contentType: String = ""
    public var size: Int?
    public var duration: Double?
    public var color: String = ""
    public var xRes: Int?
    public var yRes: Int?
    public var caption: String = ""
    public var url: String = ""
    public var urlSmall: String?
    public var urlMedium: String?
    public var urlLarge: String?
    public var urlVideoPreview: String?
    public var status: String = ""
    public var createdAt: Date?
    public var updatedAt: Date?
}

