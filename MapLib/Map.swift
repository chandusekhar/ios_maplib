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

/// Point class. Store x and y coordinates.
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

/// Map class. The oredered array of layers.
public class Map {
    
    // MARK: Properties
    static public let ext = ".ngmd"
    let id: UInt8
    let path: String
    var bkColor: ngsRGBA

    
    /// Map scale read/write property.
    public var scale: Double {
        get {
            return ngsMapGetScale(id)
        }
        
        set(newScale) {
            ngsMapSetScale(id, newScale)
        }
    }
    
    /// Map center read/write property. The point coordinates should be geographic, not screen.
    public var center: Point {
        get {
            let coordinates = ngsMapGetCenter(id)
            return Point(x: coordinates.X, y: coordinates.Y)
        }
        
        set(newPoint) {
            ngsMapSetCenter(id, newPoint.x, newPoint.y)
        }
    }
    
    /// Map layer count readonly property.
    public var layerCount: Int32 {
        get {
            return ngsMapLayerCount(id)
        }
    }
    
    /// Map extent read/write property.
    public var extent: Envelope {
        get {
            let env = ngsMapGetExtent(id, Constants.Map.epsg)
            return Envelope(envelope: env)
        }
        
        set {
            ngsMapSetExtent(id, newValue.extent)
        }
    }
    
    /// Map overlay types.
    ///
    /// - UNKNOWN: unknown overlay type.
    /// - LOCATION: overlay with current location mark.
    /// - TRACK: overlay for current tracks.
    /// - EDIT: overlay for vector geometry editig.
    /// - FIGURES: overlay to show geometry primitives.
    /// - ALL: All overlays.
    public enum OverlayType: UInt32 {
        case UNKNOWN
        case LOCATION
        case TRACK
        case EDIT
        case FIGURES
        case ALL
        
        public var rawValue: UInt32 {
            switch self {
            case .UNKNOWN:
                return MOT_UNKNOWN.rawValue
            case .LOCATION:
                return MOT_LOCATION.rawValue
            case .TRACK:
                return MOT_TRACK.rawValue
            case .EDIT:
                return MOT_EDIT.rawValue
            case .FIGURES:
                return MOT_FIGURES.rawValue
            case .ALL:
                return MOT_ALL.rawValue
            }
        }
    }
    
    /// Map selection style types. In map can be configured styles for point, line and polygon (and multi...) layers.
    /// The styles are common for all layers.
    ///
    /// - POINT: point.
    /// - LINE: linestring.
    /// - FILL: polygon.
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
    
    /// Map drawing state enum
    ///
    /// - NORMAL: normal draw. Only new tiles will be filled with data to draw.
    /// - REDRAW: all cached data will be drop. Tiles deleted from meory. All tiles in screen will be filled with data to draw.
    /// - REFILL: all tiles will be mark need to fill with data to draw.
    /// - PRESERVED: just update scree with cached data.
    /// - NOTHING: no draw operation.
    public enum DrawState: UInt32 {
        case NORMAL
        case REDRAW
        case REFILL
        case PRESERVED
        case NOTHING
        
        public var rawValue: UInt32 {
            switch self {
            case .NORMAL:
                return DS_NORMAL.rawValue
            case .REDRAW:
                return DS_REDRAW.rawValue
            case .REFILL:
                return DS_REFILL.rawValue
            case .PRESERVED:
                return DS_PRESERVED.rawValue
            case .NOTHING:
                return DS_NOTHING.rawValue
            }
        }
    }

    
    // MARK: Constructor & destructor.
    init(id: UInt8, path: String) {
        self.id = id
        self.path = path
        
        bkColor = ngsMapGetBackgroundColor(id)
    }
    
    // MARK: Public
    
    /// Close map. The map resources (layers, styles, etc.) will be freed.
    public func close() {
        if ngsMapClose(id) != Int32(COD_SUCCESS.rawValue) {
            printError("Close map failed. Error message: \(String(cString: ngsGetLastErrorMessage()))")
        }
    }
    
    
    /// Set map background.
    ///
    /// - Parameters:
    ///   - R: red color.
    ///   - G: green color.
    ///   - B: blue color.
    ///   - A: alpha color.
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
    
    /// Set map viewport size. MapView executes this function on resize.
    ///
    /// - Parameters:
    ///   - width: map width in pixels.
    ///   - height: map height in pixels.
    public func setSize(width: CGFloat, height: CGFloat) {
        let result = ngsMapSetSize(id, Int32(width), Int32(height), 1)
        if UInt32(result) != COD_SUCCESS.rawValue {
            printError("Failed set map size \(width) x \(height): error code \(result)")
        }
    }
    
    /// Save map.
    ///
    /// - Returns: true if mape saved successfuly.
    public func save() -> Bool {
        return ngsMapSave(id, path) == Int32(COD_SUCCESS.rawValue)
    }
    
    /// Add layer to map.
    ///
    /// - Parameters:
    ///   - name: layer mame.
    ///   - source: layer datasource.
    /// - Returns: Layer class instance or nil on error.
    public func addLayer(name: String, source: Object!) -> Layer? {
        let position = ngsMapCreateLayer(id, name, source.path)
        if position == -1 {
            return nil
        }
        return getLayer(by: position)
    }
    
    /// Remove layer from map.
    ///
    /// - Parameter layer: Layer class instance.
    /// - Returns: True if delete succeeded.
    public func deleteLayer(layer: Layer) -> Bool {
        return ngsMapLayerDelete(id, layer.layerH) == Int32(COD_SUCCESS.rawValue)
    }

    /// Remove layer from map.
    ///
    /// - Parameter position: Layer index.
    /// - Returns: True if delete succeeded.
    public func deleteLayer(position: Int32) -> Bool {
        if let deleteLayer = getLayer(by: position) {
            return ngsMapLayerDelete(id, deleteLayer.layerH) == Int32(COD_SUCCESS.rawValue)
        }
        return false
    }
    
    /// Get map layer.
    ///
    /// - Parameter position: Layer index.
    /// - Returns: Layer class instance.
    public func getLayer(by position: Int32) -> Layer? {
        if let layerHandler = ngsMapLayerGet(id, position) {
            return Layer(layerH: layerHandler)
        }
        return nil
    }
    
    /// Set map options.
    ///
    /// - Parameter options: key-value dictionary. The supported keys are:
    ///   - ZOOM_INCREMENT - Add integer value to zomm level correspondent to scale. May be negative.
    ///   - VIEWPORT_REDUCE_FACTOR - Reduce view size on provided value. Make sense to decrease memory usage.
    public func setOptions(options: [String:String]) {
        if ngsMapSetOptions(id, toArrayOfCStrings(options)) != Int32(COD_SUCCESS.rawValue) {
            printError("Set map options failed")
        }
    }
    
    /// Set map extent limits. This limits prevent scroll out of this bounding box.
    ///
    /// - Parameters:
    ///   - minX: minimum x coordinate.
    ///   - minY: minimum y coordinate.
    ///   - maxX: maximum x coordinate.
    ///   - maxY: maximum y coordinate.
    public func setExtentLimits(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        if ngsMapSetExtentLimits(id, minX, minY, maxX, maxY) != Int32(COD_SUCCESS.rawValue) {
            printError("Set extent limits failed")
        }

    }
    
    /// Reorder map layers.
    ///
    /// - Parameters:
    ///   - before: Before layer class instance will moved layer insert.
    ///   - moved: Layer class instance to move.
    public func reorder(before: Layer?, moved: Layer!) {
        ngsMapLayerReorder(id, before == nil ? nil : before?.layerH, moved.layerH)
    }
    
    
    /// Search features in buffer around click/tap postition.
    ///
    /// - Parameters:
    ///   - x: x position.
    ///   - y: y position.
    ///   - limit: max count return features.
    /// - Returns: array of Feature.
    public func identify(x: Float, y: Float, limit: Int = 0) -> [Feature] {
        var out: [Feature] = []
        
        let coordinate = ngsMapGetCoordinate(id, Double(x), Double(y))
        let distance = ngsMapGetDistance(id, Constants.Map.tolerance, Constants.Map.tolerance)
        let envelope = Envelope(minX: coordinate.X - distance.X,
                                minY: coordinate.Y - distance.Y,
                                maxX: coordinate.X + distance.X,
                                maxY: coordinate.Y + distance.Y)
        
        for index in 0..<layerCount {
            if let layer = getLayer(by: index) {
                if layer.visible {
                    let layerFeatures = layer.identify(envelope: envelope,
                                                       limit: limit)
                    out.append(contentsOf: layerFeatures)
                }
            }
        }
        return out
    }
    
    /// Hightlight feature in map layers. Change the feature style to selection style. The selection style mast be set in map.
    ///
    /// - Parameter features: Features array. If array is empty the current hightlighted features will get layer style and drawn not hightlited.
    public func select(features: [Feature]) {
        var env = Envelope()
        
        for index in 0..<layerCount {
            if let layer = getLayer(by: index) {
                if layer.visible {
                    if let ds = layer.dataSource as? FeatureClass {
                        var lf: [Feature] = []
                        for feature in features {
                            if feature.table?.isSame(ds) ?? false {
                                lf.append(feature)
                                if let geomEnvelope = feature.geometry?.envelope {
                                    env.merge(other: geomEnvelope)
                                }
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
    
    /// Get layer by feature belongs the datasource of correspondent layer.
    ///
    /// - Parameter feature: Feature belongs the datasource of correspondent layer.
    /// - Returns: Layer class instance or nil.
    func getLayer(for feature: Feature) -> Layer? {
        if feature.table == nil {
            return nil
        }
        for index in 0..<layerCount {
            if let layer = getLayer(by: index) {
                if let ds = layer.dataSource as? FeatureClass {
                    if ds.isSame(feature.table!) {
                        return layer
                    }
                }
            }
        }
        return nil
    }
    
    /// Invalidate part of the map.
    ///
    /// - Parameter extent: Extente to invalidate
    public func invalidate(extent: Envelope) {
        let env = ngsExtent(minX: extent.minX, minY: extent.minX,
                            maxX: extent.maxX, maxY: extent.maxY)
        ngsMapInvalidate(id, env)
    }
    
    /// Get selection style
    ///
    /// - Parameter type: Style type
    /// - Returns: Json object with style
    public func selectionStyle(for type: SelectionStyleType) -> JsonObject {
        return JsonObject(
            handle: ngsMapGetSelectionStyle(id, ngsStyleType(type.rawValue)))
    }

    /// Get selection style name
    ///
    /// - Parameter type: Style type
    /// - Returns: Style name string
    public func selectionStyleName(for type: SelectionStyleType) -> String {
        return String(
            cString: ngsMapGetSelectionStyleName(id, ngsStyleType(type.rawValue)))
    }
    
    /// Set selection style
    ///
    /// - Parameters:
    ///   - style: Json object with style. See Layer.style
    ///   - type: Selection style type
    /// - Returns: True on success.
    public func setSelectionStyle(style: JsonObject,
                                  for type: SelectionStyleType) -> Bool {
        return ngsMapSetSelectionsStyle(id, ngsStyleType(type.rawValue),
                                        style.handle) == Int32(COD_SUCCESS.rawValue)
    }
    
    /// Set selection style name
    ///
    /// - Parameters:
    ///   - name: Style name. See Layer.styleName
    ///   - type: Selection style type
    /// - Returns: True on success.
    public func setSelectionStyle(name: String,
                                  for type: SelectionStyleType) -> Bool {
        return ngsMapSetSelectionStyleName(id, ngsStyleType(type.rawValue),
                                           name) == Int32(COD_SUCCESS.rawValue)
    }
    
    /// Get map overlay
    ///
    /// - Parameter type: Overlay type.
    /// - Returns: Overlay class instance or nil.
    public func getOverlay(type: OverlayType) -> Overlay? {
        switch type {
        case .EDIT:
            return EditOverlay(map: self)
        case .LOCATION:
            return LocationOverlay(map: self)
        case .TRACK:
            return nil
        case .FIGURES:
            return nil
        default:
            return nil
        }
    }
    
    /// Add iconset to map. The iconset is square image 256 x 256 or 512 x 512 pixel with icons in it.
    ///
    /// - Parameters:
    ///   - name: Iconset name.
    ///   - path: Path to image if file system.
    ///   - move: If true the image will be deleted after successufly added to map document.
    /// - Returns: True on success.
    public func addIconSet(name: String, path: String, move: Bool) -> Bool {
        return ngsMapIconSetAdd(id, name, path, move ? 1 : 0) ==
            Int32(COD_SUCCESS.rawValue)
    }
    
    /// Remove iconset from map.
    ///
    /// - Parameter name: Iconset name.
    /// - Returns: True on success.
    public func removeIconSet(name: String) -> Bool {
        return ngsMapIconSetRemove(id, name) ==
            Int32(COD_SUCCESS.rawValue)
    }
    
    /// Validate iconset exists in map.
    ///
    /// - Parameter name: Iconset name.
    /// - Returns: True if exists.
    public func isIconSetExists(name: String) -> Bool {
        return ngsMapIconSetExists(id, name) == 2
    }
    
    // MARK: Private
        
    func draw(state: DrawState, _ callback: ngstore.ngsProgressFunc!,
              _ callbackData: UnsafeMutableRawPointer!) {
        let result = ngsMapDraw(id, ngsDrawState(rawValue: state.rawValue), callback, callbackData)
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
