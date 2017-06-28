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

public class Map {
    static public let ext = ".ngmd"
    let id: UInt8
    let path: String
    var bkColor: ngsRGBA
    
    init(id: UInt8, path: String) {
        self.id = id
        self.path = path
        
        bkColor = ngsMapGetBackgroundColor(id)
    }
    
    public func setBackgroundColor(R: UInt8, G: UInt8, B: UInt8, A: UInt8) {
        bkColor.A = A
        bkColor.R = R
        bkColor.G = G
        bkColor.B = B
        
        let result = ngsMapSetBackgroundColor(id, bkColor)
        if UInt32(result) != COD_SUCCESS.rawValue {
            print("Failed set map background [\(R), \(G), \(B), \(A)]: error code \(result)")
        }
    }
    
    public func setSize(width: CGFloat, height: CGFloat) {
        let result = ngsMapSetSize(id, Int32(width), Int32(height), 0)
        if UInt32(result) != COD_SUCCESS.rawValue {
            print("Failed set map size \(width) x \(height): error code \(result)")
        }
    }
    
    public func save() -> Bool {
        return ngsMapSave(id, path) == Int32(COD_SUCCESS.rawValue)
    }
    
    public func layerCount() -> UInt8 {
        return UInt8(ngsMapLayerCount(id))
    }
    
    // TODO: Return layer or null
    public func addLayer(name: String, source: Object!) -> Bool {
        return ngsMapCreateLayer(id, name, source.path) > -1
    }
    
    func draw(state: ngsDrawState, _ callback: ngstore.ngsProgressFunc!, _ callbackData: UnsafeMutableRawPointer!) {
        let result = ngsMapDraw(id, state, callback, callbackData)
        if UInt32(result) != COD_SUCCESS.rawValue {
            print("Failed draw map: error code \(result)")
        }
    }
    
}
