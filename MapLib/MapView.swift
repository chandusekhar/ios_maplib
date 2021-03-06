//
//  MapView.swift
//  Project: NextGIS Mobile SDK
//  Author:  Dmitry Baryshnikov, dmitry.baryshnikov@nextgis.com
//
//  Created by Dmitry Baryshnikov on 26.06.17.
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

import UIKit
import GLKit
import ngstore
import CoreLocation

/// Gesture delegate protocol. Correspondent functions will be executed on gesture events.
public protocol GestureDelegate: class {
    func onSingleTap(sender: UIGestureRecognizer)
    func onDoubleTap(sender: UIGestureRecognizer)
    func onPanGesture(sender: UIPanGestureRecognizer)
    func onPinchGesture(sender: UIPinchGestureRecognizer)
}


/// To use location capabilities you need to add to the info.plist key 
/// “Privacy - Location When In Use Usage Description” and value with description
/// shown to end user in permissions dialog.

/// Location delegate protocol. Correspondent functions will be executed on location events.
public protocol LocationDelegate: class {
    func onLocationChanged(location: CLLocation)
    func onLocationStop()
}

/// Map drawing delegate protocol. Correspondent functions will be executed on map draw events.
public protocol MapViewDelegate: class {
    func onMapDrawFinished()
    func onMapDraw(percent: Double)
}

/// Map view class.
public class MapView: GLKView {
    var map: Map? = nil
    var drawState: Map.DrawState = .PRESERVED
    weak var globalTimer: Timer? = nil
    var timerDrawState: Map.DrawState = .PRESERVED
    weak var gestureDelegate: GestureDelegate? = nil
    weak var locationDelegate: LocationDelegate? = nil
    weak var mapViewDelegate: MapViewDelegate? = nil
    let locationManager = CLLocationManager()
    
    /// Last known location or nil.
    public var currentLocation: CLLocation? = nil
        
    var showLocationVal: Bool = false
    /// Show/hide current position on map. The location overlay mast be set.
    public var showLocation: Bool {
        get {
            return showLocationVal
        }
        set {
            showLocationVal = newValue
            if showLocationVal {
//                let authorizationStatus = CLLocationManager.authorizationStatus()
//                if authorizationStatus != .authorizedWhenInUse && authorizationStatus != .authorizedAlways {
//                    // User has not authorized access to location information.
//                    return
//                }
//
//                // Do not start services that aren't available.
//                if !CLLocationManager.locationServicesEnabled() {
//                    // Location services is not available.
//                    return
//                }
                
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
                locationManager.delegate = self
                locationManager.requestWhenInUseAuthorization()
                locationManager.pausesLocationUpdatesAutomatically = true
                locationManager.startUpdatingLocation()
            }
            else {
                locationManager.stopUpdatingLocation()
            }
        }
    }
    
    /// Freeze map drawing read/write property.
    public var freeze: Bool {
        get {
            return self.freeze
        }
        
        set(newValue) {
            self.freeze = newValue
        }
    }
    
    /// Map scale read/write property.
    public var mapScale: Double {
        get {
            return map?.scale ?? 0.0000015
        }
        
        set(newScale) {
            map?.scale = newScale
        }
    }
    
    /// Map center in spatial reference coordinates read/write property.
    public var mapCenter: Point {
        get {
            return map?.center ?? Point()
        }
        
        set(newPoint) {
            map?.center = newPoint
        }
    }
    
    /// Map curremt extent read/write propertry.
    public var mapExtent: Envelope {
        get {
            return map?.extent ?? Envelope()
        }
        
        set(newExtent) {
            map?.extent = newExtent
        }
    }
    
    override init(frame: CGRect)
    {
        super.init(frame: frame, context: EAGLContext(api: .openGLES2))
        delegate = self
        freeze = true
        
    }
    
    override init(frame: CGRect, context: EAGLContext)
    {
        super.init(frame: frame, context: context)
        delegate = self
        freeze = true
    }
    
    required public init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        context = EAGLContext(api: .openGLES2)
        delegate = self
        freeze = true
    }
    
    deinit {
        API.instance.removeMapView(self)
    }
    
    /// Set map class to view.
    ///
    /// - Parameter map: Map class instance.
    public func setMap(map: Map) {
        self.map = map
        map.setSize(width: bounds.width, height: bounds.height)
        
        printMessage("Map set size w: \(bounds.width) h:\(bounds.height)")
        
        API.instance.addMapView(self)
        
        refresh()
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        map?.setSize(width: bounds.width, height: bounds.height)
        
        printMessage("Map set size w: \(bounds.width) h:\(bounds.height)")
        
        refresh()
    }
    
    func draw(_ state: Map.DrawState) {
        drawState = state
        if !freeze {
            display()
        }
    }
    
    /// Cancel drawing process. Default return value is false. Using override function can cancel drawing on some cases.
    ///
    /// - Returns: True to cancel drawing.
    public func cancelDraw() -> Bool {
        return false
    }
    
    /// Refresh map.
    ///
    /// - Parameter normal: If true just refresh view, othervise refill all map tiles.
    public func refresh(normal: Bool = true) {
        if normal {
            draw(.NORMAL)
        } else {
            draw(.REFILL)
        }
    }
    
    /// Zoom in.
    ///
    /// - Parameter multiply: Multiply factor. Default is 2.
    public func zoomIn(multiply: Double = 2.0) {
        map?.zoomIn(multiply)
        draw(.PRESERVED)
        scheduleDraw(drawState: .NORMAL)
    }
    
    /// Zoom out.
    ///
    /// - Parameter multiply: Multiply factor. Default is 2.
    public func zoomOut(multiply: Double = 2.0) {
        map?.zoomOut(multiply)
        draw(.PRESERVED)
        scheduleDraw(drawState: .NORMAL)
    }
    
    /// Center map at spatial reference coordinates.
    ///
    /// - Parameter coordinate: New center coordinates.
    public func centerMap(coordinate: Point) {
        map?.center = coordinate
        draw(.PRESERVED)
        scheduleDraw(drawState: .NORMAL)
    }
    
    /// Center map in current location. If current location is nil, nothing happened.
    public func centerInCurrentLocation() {
        if currentLocation == nil {
            return
        }
        let newCenter = transformFrom(gps: currentLocation?.coordinate.longitude ?? 0.0,
                                       y: currentLocation?.coordinate.latitude ?? 0.0)
        centerMap(coordinate: newCenter)
    }
    
    /// Invalidate part of the map. The refresh function invalidates all visible screen.
    ///
    /// - Parameter envelope: Envelope to invalidate.
    public func invalidate(envelope: Envelope) {
        map?.invalidate(extent: envelope)
        scheduleDraw(drawState: .PRESERVED, timeInterval: 0.70)
    }
    
    /// Pan map to specific screen shift.
    ///
    /// - Parameters:
    ///   - w: horisontal pixel shift
    ///   - h: vertical pixel shift.
    public func pan(w: Double, h: Double) {
        map?.pan(w, h)
        draw(.PRESERVED)
        scheduleDraw(drawState: .NORMAL, timeInterval: 0.70)
    }
    
    func transformFrom(gps x: Double, y: Double) -> Point {
        let ct = CoordinateTransformation.new(fromEPSG: 4326, toEPSG: 3857)
        return ct.transform(Point(x: x, y: y))
    }
    
    func onTimer(timer: Timer) {
        globalTimer = nil
        if let drawState = timer.userInfo as? Map.DrawState {
            draw(drawState)
        }
    }
    
    /// Shedule map redraw.
    ///
    /// - Parameters:
    ///   - drawState: Draw state value. See Map.DrawState values.
    ///   - timeInterval: Time interval in seconds.
    public func scheduleDraw(drawState: Map.DrawState, timeInterval: TimeInterval = Constants.refreshTime) {
        // timer?.invalidate()
        if timerDrawState != drawState {
            globalTimer?.invalidate()
            globalTimer = nil
        }
        
        if globalTimer != nil {
            return
        }
        
        timerDrawState = drawState
        
        globalTimer = Timer.scheduledTimer(timeInterval: timeInterval,
                                     target: self,
                                     selector: #selector(onTimer(timer:)),
                                     userInfo: drawState,
                                     repeats: false)
    }
    
    /// Register gesture delegate function.
    ///
    /// - Parameter delegate: delegate function.
    public func registerGestureRecognizers(_ delegate: GestureDelegate) {
        isUserInteractionEnabled = true
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(onSingleTap(sender:)))
        singleTap.numberOfTapsRequired = 1
        addGestureRecognizer(singleTap)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(onDoubleTap(sender:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        
        singleTap.require(toFail: doubleTap)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(onPanGesture(sender:)))
        panGesture.maximumNumberOfTouches = 1
        panGesture.minimumNumberOfTouches = 1
        addGestureRecognizer(panGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(onPinchGesture(sender:)))
        addGestureRecognizer(pinchGesture)
        
        gestureDelegate = delegate
    }
    
    /// Register location delegate function.
    ///
    /// - Parameter delegate: location delegate function.
    public func registerLocation(_ delegate: LocationDelegate) {
        locationDelegate = delegate
    }
    
    /// Register map drawing delegate function.
    ///
    /// - Parameter delegate: map drawing delegate function.
    public func registerView(_ delegate: MapViewDelegate) {
        mapViewDelegate = delegate
    }
    
    func onDoubleTap(sender: UIGestureRecognizer) {
        if sender.state == UIGestureRecognizerState.ended {
            
            let position = sender.location(in: self /*sender.view*/)
            let x = Double(position.x)
            let y = Double(position.y)
            
            map?.setCenterAndZoom(x, y)
            draw(.PRESERVED)
            scheduleDraw(drawState: .NORMAL)
            
            gestureDelegate?.onDoubleTap(sender: sender)
        }
    }
    
    func onSingleTap(sender: UIGestureRecognizer) {
        // Iterate through visible map layers and return found features
        if sender.state == UIGestureRecognizerState.ended {
            gestureDelegate?.onSingleTap(sender: sender)
        }
    }
    
    func onPanGesture(sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: self)
        
        let x = Double(translation.x)
        let y = Double(translation.y)
        
        if(abs(x) > Constants.Sizes.minPanPix || abs(y) > Constants.Sizes.minPanPix) {
            pan(w: x, h: y)
            sender.setTranslation(CGPoint(x: 0.0, y: 0.0), in: self)
        }
        
        gestureDelegate?.onPanGesture(sender: sender)
    }
    
    func onPinchGesture(sender: UIPinchGestureRecognizer) {
        let scale = sender.scale
        
        map?.zoomIn(Double(scale))
        draw(.PRESERVED)
        scheduleDraw(drawState: .NORMAL)
        
        sender.scale = 1.0
        
        gestureDelegate?.onPinchGesture(sender: sender)
    }
    
    /// Get current extent in specified spatial reference system by EPSG code.
    ///
    /// - Parameter srs: EPSG code.
    /// - Returns: Envelope in specified spatial reference system.
    public func getExtent(srs: Int32) -> Envelope {
        return map?.getExtent(srs: srs) ?? Envelope()
    }
}

func drawingProgressFunc(code: ngsCode, percent: Double,
                         message: UnsafePointer<Int8>?,
                         progressArguments: UnsafeMutableRawPointer?) -> Int32 {
    let view: MapView = bridge(ptr: progressArguments!)
    if(code == COD_FINISHED) {
        view.mapViewDelegate?.onMapDrawFinished()
        return 1
    }
    
    if (progressArguments != nil) {
        view.scheduleDraw(drawState: .PRESERVED) //display()
        view.mapViewDelegate?.onMapDraw(percent: percent)
        return view.cancelDraw() ? 0 : 1
    }
    
    return 1
}


extension MapView: GLKViewDelegate {
    public func glkView(_ view: GLKView, drawIn rect: CGRect) {
        
        let processFunc: ngstore.ngsProgressFunc = drawingProgressFunc
        map?.draw(state: drawState, processFunc, bridge(obj: self))

        drawState = .PRESERVED
    }
}

extension MapView: CLLocationManagerDelegate {
    
    public func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation])
    {
        if let location = locations.last {
// Don't need as iOS filter it manually
//        if location.coordinate.latitude == currentLocation?.coordinate.latitude &&
//            location.coordinate.longitude == currentLocation?.coordinate.longitude &&
//            location.altitude == currentLocation?.altitude &&
//            location.course == currentLocation?.course &&
//            location.horizontalAccuracy == currentLocation?.horizontalAccuracy {
//            return // Nothing changed
//        }
        
            currentLocation = location
            if showLocation {
                let position = transformFrom(gps: location.coordinate.longitude,
                                             y: location.coordinate.latitude)
                
                if let locationOverlay = map?.getOverlay(type: Map.OverlayType.LOCATION) as? LocationOverlay {
                
                    locationOverlay.location(update: position,
                                             direction: Float(location.course),
                                             accuracy: Float(location.horizontalAccuracy))
                    draw(.PRESERVED)
                }
            }
        
            printMessage("Location. Lat: \(location.coordinate.latitude) Long:\(location.coordinate.longitude) Alt:\(location.altitude) Dir:\(location.course), Accuracy: \(location.horizontalAccuracy)")
        
            locationDelegate?.onLocationChanged(location: location)
            
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError {
            if error.code == .denied {
                locationManager.stopUpdatingLocation()
            }
            else if error.code != .locationUnknown {
                if let locationOverlay = map?.getOverlay(type: Map.OverlayType.LOCATION) as? LocationOverlay {
                    locationOverlay.visible = false
                    draw(.PRESERVED)
                }
            }
        }
    }
    
    public func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        if let locationOverlay = map?.getOverlay(type: Map.OverlayType.LOCATION) as? LocationOverlay {
            locationOverlay.visible = false
            draw(.PRESERVED)
        }
    }
}

/// Map view with vector feature editing functions.
public class MapViewEdit : MapView {
    
    var editMode: Bool = false
    var editOverlay: EditOverlay? = nil
    var editMoveSelectedPoint: Bool = false
    var beginTouchLocation: CGPoint? = nil
    
    /// Is in edit mode or not.
    public var isEditMode: Bool {
        get {
            return editMode
        }
        
        set {
            editMode = newValue
            if(editMode) {
                editOverlay?.visible = true
            }
            else {
                editOverlay?.visible = false
                editMoveSelectedPoint = false
            }
        }
    }
    
    override public func setMap(map: Map) {
        super.setMap(map: map)
        editOverlay = map.getOverlay(type: .EDIT) as? EditOverlay
    }
    
    override public func onPanGesture(sender: UIPanGestureRecognizer) {

        if(editMode) {
            if sender.state == .began {
                let x = Double(beginTouchLocation?.x ?? 10000.0)
                let y = Double(beginTouchLocation?.y ?? 10000.0)
                printMessage("Edit mode begin pan x: \(x), y: \(y)")
                if let touchResult = editOverlay?.touch(down: x, y: y) {
                    editMoveSelectedPoint = touchResult.pointId != -1
                }
                gestureDelegate?.onPanGesture(sender: sender)
            } else if sender.state == .changed {
                if editMoveSelectedPoint {
                    let position = sender.location(in: sender.view)
                    let x = Double(position.x)
                    let y = Double(position.y)
                    
                    _ = editOverlay?.touch(move: x, y: y)
                    draw(.PRESERVED)
                    gestureDelegate?.onPanGesture(sender: sender)
                }
            } else if sender.state == .ended {
                if editMoveSelectedPoint {
                    let position = sender.location(in: sender.view)
                    let x = Double(position.x)
                    let y = Double(position.y)
                    
                    _ = editOverlay?.touch(up: x, y: y)
                    draw(.PRESERVED)
                    editMoveSelectedPoint = false
                    
                    gestureDelegate?.onPanGesture(sender: sender)
                    return
                }
            }
        }
        
        if !editMoveSelectedPoint {
            super.onPanGesture(sender: sender)
        }
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch: UITouch = touches.first {
        
            if (touch.view == self) {
                beginTouchLocation = touch.location(in: self)
            }
        }
        
        super.touchesBegan(touches, with: event)
    }
    
    /// Undo edit operation.
    public func undoEdit() {
        if editOverlay?.undo() ?? false {
            draw(.PRESERVED)
        }
    }
    
    /// Redo edit operation.
    public func redoEdit() {
        if editOverlay?.redo() ?? false {
            draw(.PRESERVED)
        }
    }
    
    /// Add geometry part.
    public func addGeometryPart() {
        if editOverlay?.addGeometryPart() ?? false {
            draw(.PRESERVED)
        }
    }
    
    /// Add geometry point.
    public func addGeometryPoint() {
        if editOverlay?.addGeometryPoint() ?? false {
            draw(.PRESERVED)
        }
    }
    
    /// Add geometry point in specified coordinates.
    ///
    /// - Parameter coordinates: Point coordinates.
    public func addGeometryPoint(with coordinates: Point) {
        if editOverlay?.addGeometryPoint(with: coordinates) ?? false {
            draw(.PRESERVED)
        }
    }
    
    /// Deletes selected geometry part
    ///
    /// - Returns: delete result type value. EditOverlay.DeleteResultType. 
    public func deleteGeometryPart() -> EditOverlay.DeleteResultType {
        let result = editOverlay?.deleteGeometryPart() ?? .NON_LAST
        draw(.PRESERVED)
        return result
    }
    
    /// Delete point from geometry.
    ///
    /// - Returns: delete result type value. EditOverlay.DeleteResultType.
    public func deleteGeometryPoint() -> EditOverlay.DeleteResultType {
        let result = editOverlay?.deleteGeometryPoint() ?? .NON_LAST
        draw(.PRESERVED)
        return result
    }
    
    /// Delete the whole geometry.
    public func deleteGeometry() {
        if editOverlay?.deleteGeometry() ?? false {
            draw(.PRESERVED)
        }
    }
    
    /// Add hole to geometry.
    public func addGeometryHole() {
        if editOverlay?.addGeometryHole() ?? false {
            draw(.PRESERVED)
        }
    }
    
    /// Delete geometry hole.
    ///
    /// - Returns: delete result type value. EditOverlay.DeleteResultType.
    public func deleteGeometryHole() -> EditOverlay.DeleteResultType {
        let result = editOverlay?.deleteGeometryHole() ?? .NON_LAST
        draw(.PRESERVED)
        return result
    }
}
