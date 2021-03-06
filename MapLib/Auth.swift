//
//  Auth.swift
//  Project: NextGIS Mobile SDK
//  Author:  Dmitry Baryshnikov, dmitry.baryshnikov@nextgis.com
//
//  Created by Dmitry Baryshnikov on 02.07.17.
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


/// Callback function prototype. This function executes when authentication update filed
public typealias tokenUpdateFailedCallback = () -> Void


/// Class for holding library authentication
public class Auth : Equatable {
    
    private let tokenUpdateFailed: tokenUpdateFailedCallback?
    private let url: String
    private let authServerUrl: String
    private let accessToken: String
    private let updateToken: String
    private let expiresIn: String
    private let clientId: String
    
    
    /// Class constructor
    ///
    /// - Parameters:
    ///   - url: The http request starting from this url will be authenticated.
    ///   - clientId: client Id for oAuth2 protocol.
    ///   - authServerUrl: Authentication server url. The update request will use this url.
    ///   - accessToken: Access token for oAuth2.
    ///   - updateToken: Update token for oAuth2.
    ///   - expiresIn: The token expires period.
    ///   - callback: function executes if update failed. The function must be like prototype function tokenUpdateFailedCallback.
    public init(url: String, clientId: String, authServerUrl: String, accessToken: String,
         updateToken: String, expiresIn: String, callback: tokenUpdateFailedCallback? = nil) {
        self.url = url
        self.tokenUpdateFailed = callback
        self.authServerUrl = authServerUrl
        self.accessToken = accessToken
        self.updateToken = updateToken
        self.expiresIn = expiresIn
        self.clientId = clientId
        
        _ = API.instance.addAuth(auth: self)
    }
    
    deinit {
        API.instance.removeAuth(auth: self)
    }
    
    func onRefreshTokenFailed(url: String) {
        printMessage("Refresh oAuth token for url \(url) failed")
        if url == self.url {
            tokenUpdateFailed!()
        }
    }
    
    
    /// The http request starting from this url will be authenticated
    ///
    /// - Returns: url string
    public func getURL() -> String {
        return url
    }
    
    
    /// Compare Auth class instances.
    ///
    /// - Parameters:
    ///   - lhs: First class instance to compare
    ///   - rhs: Second class instance to compare
    /// - Returns: true if class instances are equal.
    public static func == (lhs: Auth, rhs: Auth) -> Bool {
        if ObjectIdentifier(lhs) == ObjectIdentifier(rhs) {
            return true
        }
        
        return lhs.getURL() == rhs.getURL()
    }
    
    
    /// Get current authentication options. If some options chaned via interaction with authentication server, this function returns actual values.
    ///
    /// - Returns: key-value dictionary of options
    public func options() -> [String: String] {
        return [
            "HTTPAUTH_TYPE" : "bearer",
            "HTTPAUTH_TOKEN_SERVER" : authServerUrl,
            "HTTPAUTH_ACCESS_TOKEN" : accessToken,
            "HTTPAUTH_REFRESH_TOKEN" : updateToken,
            "HTTPAUTH_EXPIRES_IN" : expiresIn,
            "HTTPAUTH_CLIENT_ID" : clientId
        ]
    }
}
