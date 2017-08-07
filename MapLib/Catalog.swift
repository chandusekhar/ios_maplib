//
//  Catalog.swift
//  Project: NextGIS Mobile SDK
//  Author:  Dmitry Baryshnikov, dmitry.baryshnikov@nextgis.com
//
//  Created by Dmitry Baryshnikov on 22.06.17.
//  Copyright © 2017 NextGIS, info@nextgis.com
//
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU Lesser Public License for more details.
//
//  You should have received a copy of the GNU Lesser Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation
import ngstore

public struct BBox {
    public var minx, miny, maxx, maxy: Double
    
    public init() {
        minx = 0.0
        miny = 0.0
        maxx = 0.0
        maxy = 0.0
    }
    
    public init(minx: Double, miny: Double, maxx: Double, maxy: Double) {
        self.minx = minx
        self.miny = miny
        self.maxx = maxx
        self.maxy = maxy
    }
}


public class Object {
    public let type: Int
    public let name: String
    public let path: String
    let object: CatalogObjectH!
    
    public var metadata: [String: String] {
        get {
            if let rawArray = ngsCatalogObjectMetadata(object, "user") {
                var count = 0
                var out: [String: String] = [:]
                while(rawArray[count] != nil) {
                    let metadataItem = String(cString: rawArray[count]!)
                    if let splitIndex = metadataItem.characters.index(of: "=") {
                        let key = metadataItem.substring(to: splitIndex)
                        let value = metadataItem.substring(from: splitIndex)
                        out[key] = value
                    }
                    count += 1
                }
                return out
            }
            return [:]
        }
    }
    
    init(name: String, type: Int, path: String, object: CatalogObjectH) {
        self.name = name
        self.type = type
        self.path = path
        self.object = object
    }
    
    init(object: CatalogObjectH) {
        self.object = object
        self.name = String(cString: ngsCatalogObjectName(object))
        self.type = Int(ngsCatalogObjectType(object).rawValue)
        self.path = "" // TODO: Do we need path?
    }
    
    init(copyFrom: Object) {
        self.name = copyFrom.name
        self.type = copyFrom.type
        self.path = copyFrom.path
        self.object = copyFrom.object
    }
    
    public func children() -> [Object] {
        var out: [Object] = []
        
        if let queryResult = ngsCatalogObjectQuery(object, 0) { // TODO: Add filter support
            var count: Int = 0
            while (queryResult[count].name != nil) {
                out.append(Object(name: String(cString: queryResult[count].name),
                                  type: Int(queryResult[count].type),
                                  path: path + Catalog.separator + String(cString: queryResult[count].name),
                                  object: queryResult[count].object))
                count += 1
            }
            
            ngsFree(queryResult)
        }
        
        return out
    }
    
    public func child(name: String) -> Object? {
        let childrenArray = children()
        for childItem in childrenArray {
            if childItem.name == name {
                return childItem
            }
        }
        return nil
    }
    
    public func create(name: String, options: [String:String] = [:]) -> Object? {
        if(ngsCatalogObjectCreate(object, name, options.isEmpty ? nil :
            toArrayOfCStrings(options)) == Int32(COD_SUCCESS.rawValue)) {
            return child(name: name)
        }
        return nil
    }
    
    
    /// Create TMS datasource
    ///
    /// - Parameters:
    ///   - name: TMS connection name
    ///   - url: TMS url. {x}, {y} and {z} must be present in url string
    ///   - epsg: EPSG code of TMS
    ///   - z_min: Minimum zoom. Default is 0
    ///   - z_max: Maximum zoom. Default is 18
    ///   - fullExtent: Full extent of TMS datasource. Depends on tile schema and projection
    ///   - limitExtent: Data extent. Maybe equal or less of fullExtent
    ///   - cacheExpires: Time in seconds to remove cahced tiles
    ///   - options: Addtional options as key: value array
    /// - Returns: Catalog object or nil
    public func createTMS(name: String, url: String, epsg: Int32,
                          z_min: UInt8, z_max: UInt8, fullExtent: BBox,
                          limitExtent: BBox, cacheExpires: Int,
                          options: [String: String]? = nil) -> Object? {
        var createOptions = [
            "TYPE": "\(CAT_RASTER_TMS.rawValue)",
            "CREATE_UNIQUE": "OFF",
            "url": url,
            "epsg": "\(epsg)",
            "z_min": "\(z_min)",
            "z_max": "\(z_max)",
            "x_min": "\(fullExtent.minx)",
            "y_min": "\(fullExtent.miny)",
            "x_max": "\(fullExtent.maxx)",
            "y_max": "\(fullExtent.maxy)",
            "cache_expires": "\(cacheExpires)",
            "limit_x_min": "\(limitExtent.minx)",
            "limit_y_min": "\(limitExtent.miny)",
            "limit_x_max": "\(limitExtent.maxx)",
            "limit_y_max": "\(limitExtent.maxy)"
        ]
        
        if options != nil {
            for option in options! {
                createOptions[option.key] = option.value
            }
        }
        
        return create(name: name, options: createOptions)
    }
    
    public func createDirectory(name: String) -> Object? {
        let options = [
            "TYPE": "\(CAT_CONTAINER_DIR.rawValue)",
            "CREATE_UNIQUE": "OFF"
        ]
        return create(name: name, options: options)
    }
    
    public func delete() -> Bool {
        return ngsCatalogObjectDelete(object) == Int32(COD_SUCCESS.rawValue)
    }
    
    public func delete(name: String) -> Bool {
        if let deleteObject = child(name: name) {
            return deleteObject.delete()
        }
        return false
    }

    public static func isTable(_ type: Int) -> Bool {
        return type >= 1500 && type <= 1999
    }
    
    public static func isRaster(_ type: Int) -> Bool {
        return type >= 1000 && type <= 1499
    }
    
    public static func isFeatureClass(_ type: Int) -> Bool {
        return type >= 500 && type <= 999
    }
    
    public static func isContainer(_ type: Int) -> Bool {
        return type >= 50 && type <= 499
    }
}

public class Catalog: Object {
    static public let separator = "/"
    
    init(catalog: CatalogObjectH!) {
        super.init(name: "Catalog", type: Int(CAT_CONTAINER_ROOT.rawValue),
                   path: "ngc://", object: catalog)
    }
    
    public func getCurrentDirectory() -> String {
        return String(cString: ngsGetCurrentDirectory())
    }
    
    public func childByPath(path: String) -> Object? {
        if let objectHandler = ngsCatalogObjectGet(path) {
            let objectType = Int(ngsCatalogObjectType(objectHandler).rawValue)
            let objectName = String(cString: ngsCatalogObjectName(objectHandler))
            return Object(name: objectName, type: objectType,
                          path: path,
                          object: objectHandler)
        }
        return nil
    }
    
    static func getOrCreateFolder(_ parent: Object!, _ name: String) -> Object? {
        if let dir = parent.child(name: name) {
            return dir
        }
        
        return parent.createDirectory(name: name)
    }
}
