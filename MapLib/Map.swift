//
//  Map.swift
//  Project: NextGIS Mobile SDK
//  Author:  Dmitry Baryshnikov, dmitry.baryshnikov@nextgis.com
//
//  Created by Dmitry Baryshnikov on 13.06.17.
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
//


import Foundation
import UIKit
import ngstore

public struct Point {
    public var x = 0.0, y = 0.0
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    public init() {
        self.x = 0.0
        self.y = 0.0
    }
}

public class Map {
    
    // MARK: Properties
    static public let ext = ".ngmd"
    let id: UInt8
    let path: String
    var bkColor: ngsRGBA
    
    public var scale: Double {
        get {
            return ngsMapGetScale(id)
        }
        
        set(newScale) {
            ngsMapSetScale(id, newScale)
        }
    }
    
    public var center: Point {
        get {
            let coordinates = ngsMapGetCenter(id)
            return Point(x: coordinates.X, y: coordinates.Y)
        }
        
        set(newPoint) {
            ngsMapSetCenter(id, newPoint.x, newPoint.y)
        }
    }
    
    public var layerCount: Int32 {
        get {
            return ngsMapLayerCount(id)
        }
    }
    
    public enum SelectionStyleType: UInt32 {
        case POINT
        case LINE
        case FILL
        
        public var rawValue: UInt32 {
            switch self {
            case .POINT:
                return ST_POINT.rawValue
            case .LINE:
                return ST_LINE.rawValue
            case .FILL:
                return ST_FILL.rawValue
//            default:
//                return ST_IMAGE.rawValue
            }
        }
    }

    
    // MARK: Constructor & destructor
    init(id: UInt8, path: String) {
        self.id = id
        self.path = path
        
        bkColor = ngsMapGetBackgroundColor(id)
    }
    
    // MARK: Public
    
    public func close() {
        if ngsMapClose(id) != Int32(COD_SUCCESS.rawValue) {
            printError("Close map failed. Error message: \(String(cString: ngsGetLastErrorMessage()))")
        }
    }
    
    public func setBackgroundColor(R: UInt8, G: UInt8, B: UInt8, A: UInt8) {
        bkColor.A = A
        bkColor.R = R
        bkColor.G = G
        bkColor.B = B
        
        let result = ngsMapSetBackgroundColor(id, bkColor)
        if UInt32(result) != COD_SUCCESS.rawValue {
            printError("Failed set map background [\(R), \(G), \(B), \(A)]: error code \(result)")
        }
    }
    
    public func setSize(width: CGFloat, height: CGFloat) {
        let result = ngsMapSetSize(id, Int32(width), Int32(height), 1)
        if UInt32(result) != COD_SUCCESS.rawValue {
            printError("Failed set map size \(width) x \(height): error code \(result)")
        }
    }
    
    public func save() -> Bool {
        return ngsMapSave(id, path) == Int32(COD_SUCCESS.rawValue)
    }
    
    public func addLayer(name: String, source: Object!) -> Layer? {
        let position = ngsMapCreateLayer(id, name, source.path)
        if position == -1 {
            return nil
        }
        return getLayer(position: position)
    }
    
    public func deleteLayer(layer: Layer) -> Bool {
        return ngsMapLayerDelete(id, layer.layerH) == Int32(COD_SUCCESS.rawValue)
    }
    
    public func deleteLayer(position: Int32) -> Bool {
        if let deleteLayer = getLayer(position: position) {
            return ngsMapLayerDelete(id, deleteLayer.layerH) == Int32(COD_SUCCESS.rawValue)
        }
        return false
    }
    
    public func getLayer(position: Int32) -> Layer? {
        if let layerHandler = ngsMapLayerGet(id, position) {
            return Layer(layerH: layerHandler)
        }
        return nil
    }
    
    public func setOptions(options: [String:String]) {
        if ngsMapSetOptions(id, toArrayOfCStrings(options)) != Int32(COD_SUCCESS.rawValue) {
            printError("Set map options failed")
        }
    }
    
    public func setExtentLimits(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        if ngsMapSetExtentLimits(id, minX, minY, maxX, maxY) != Int32(COD_SUCCESS.rawValue) {
            printError("Set extent limits failed")
        }

    }
    
    public func reorder(before: Layer?, moved: Layer!) {
        ngsMapLayerReorder(id, before == nil ? nil : before?.layerH, moved.layerH)
    }
    
    
    /// Search features in buffer around click/tap postition
    ///
    /// - Parameters:
    ///   - x: x position
    ///   - y: y position
    ///   - limit: max count return features
    /// - Returns: array of Feature
    public func identify(x: Float, y: Float, limit: Int = 0) -> [Feature] {
        var out: [Feature] = []
        
        let coordinate = ngsMapGetCoordinate(id, Double(x), Double(y))
        let distance = ngsMapGetDistance(id, Constants.Map.tolerance, Constants.Map.tolerance)
        let envelope = Envelope(minX: coordinate.X - distance.X,
                                minY: coordinate.Y - distance.Y,
                                maxX: coordinate.X + distance.X,
                                maxY: coordinate.Y + distance.Y)
        
        for index in 0..<layerCount {
            if let layer = getLayer(position: index) {
                if layer.visible {
                    let layerFeatures = layer.identify(envelope: envelope,
                                                       limit: limit)
                    out.append(contentsOf: layerFeatures)
                }
            }
        }
        return out
    }
    
    public func select(features: [Feature]) {
        var env = Envelope()
        
        for index in 0..<layerCount {
            if let layer = getLayer(position: index) {
                if layer.visible {
                    if let ds = layer.dataSource as? FeatureClass {
                        var lf: [Feature] = []
                        for feature in features {
                            if ds.path == feature.featureClass?.path {
                                lf.append(feature)
                                let geomEnvelope = feature.geometry.envelope
                                env.merge(other: geomEnvelope)
                            }
                        }
                        layer.select(features: lf)
                    }
                }
            }
        }
        if !env.isInit() {
            env = Envelope(minX: -1.0, minY: -1.0, maxX: 1.0, maxY: 1.0)
        }
        ngsMapInvalidate(id, env.extent)
    }
    
    public func selectionStyle(for type: SelectionStyleType) -> JsonObject {
        return JsonObject(
            handle: ngsMapGetSelectionStyle(id, ngsStyleType(type.rawValue)))
    }

    public func selectionStyleName(for type: SelectionStyleType) -> String {
        return String(
            cString: ngsMapGetSelectionStyleName(id, ngsStyleType(type.rawValue)))
    }
    
    public func setSelectionStyle(style: JsonObject,
                                  for type: SelectionStyleType) -> Bool {
        return ngsMapSetSelectionsStyle(id, ngsStyleType(type.rawValue),
                                        style.handle) == Int32(COD_SUCCESS.rawValue)
    }
    
    public func setSelectionStyle(name: String,
                                  for type: SelectionStyleType) -> Bool {
        return ngsMapSetSelectionStyleName(id, ngsStyleType(type.rawValue),
                                           name) == Int32(COD_SUCCESS.rawValue)
    }
    
    // MARK: Private
        
    func draw(state: ngsDrawState, _ callback: ngstore.ngsProgressFunc!,
              _ callbackData: UnsafeMutableRawPointer!) {
        let result = ngsMapDraw(id, state, callback, callbackData)
        if UInt32(result) != COD_SUCCESS.rawValue {
            printError("Failed draw map: error code \(result)")
        }
    }
    
    func zoomIn(_ multiply: Double = 2.0) {
        let scale = ngsMapGetScale(id) * multiply
        ngsMapSetScale(id, scale)
    }

    func zoomOut(_ multiply: Double = 2.0) {
        let scale = ngsMapGetScale(id) / multiply
        ngsMapSetScale(id, scale)
    }
    
    func pan(_ w: Double, _ h: Double) {
        
        let offset = ngsMapGetDistance(id, w, h)
        var center = ngsMapGetCenter(id)
        center.X -= offset.X
        center.Y -= offset.Y
        
        ngsMapSetCenter(id, center.X, center.Y)
    }
    
    func setCenterAndZoom(_ w: Double, _ h: Double, _ multiply: Double = 2.0) {
        let scale = ngsMapGetScale(id) * multiply
        let pos = ngsMapGetCoordinate(id, w, h)
        
        ngsMapSetScale(id, scale)
        ngsMapSetCenter(id, pos.X, pos.Y)
    }
    
    func getExtent(srs: Int32) -> Envelope {
        let ext = ngsMapGetExtent(id, srs)
        return Envelope(minX: ext.minX, minY: ext.minY, maxX: ext.maxX, maxY: ext.maxY)
    }
    
}
