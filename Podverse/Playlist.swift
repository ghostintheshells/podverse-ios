//
//  Playlist.swift
//  Podverse
//
//  Created by Creon on 12/24/16.
//  Copyright © 2016 Podverse LLC. All rights reserved.
//

import UIKit
import CoreData

extension Notification.Name {
    static let removedPlaylistItem = Notification.Name("removedPlaylistItem")
}

class Playlist {
    
    var id: String?
    var title: String?
    var slug: String?
    var ownerId: String?
    var ownerName: String?
    var dateCreated: Date?
    var lastUpdated: Date?
    var isMyClips: Bool = false
    var mediaRefs = [MediaRef]()
    var itemCount: String?
    var itemsOrder:[String] = []
    
    static func jsonToPlaylist(item: [String:Any]) -> Playlist {
    
        let playlist = Playlist()
        
        playlist.id = item["id"] as? String
        playlist.isMyClips = item["isMyClips"] as? Bool ?? false
        playlist.slug = item["slug"] as? String
        playlist.title = item["title"] as? String
        playlist.ownerId = item["ownerId"] as? String
        playlist.ownerName = item["ownerName"] as? String
        
        if let lastUpdated = item["lastUpdated"] as? String {
            playlist.lastUpdated = lastUpdated.toServerDate()
        }
        
        if let dateCreated = item["dateCreated"] as? String {
            playlist.dateCreated = dateCreated.toServerDate()
        }
        
        if let mediaRefsJSON = item["mediaRefs"] as? [[String:Any]] {
            for item in mediaRefsJSON {
                let mediaRef = MediaRef.jsonToMediaRef(item: item)
                playlist.mediaRefs.append(mediaRef)
            }
        }
        
        playlist.itemCount = item["itemCount"] as? String

        if let itemsOrder = item["itemsOrder"] as? [String] {
            playlist.itemsOrder = itemsOrder
        }
        
        return playlist
    
    }
    
    static func retrievePlaylistFromServer(id: String, completion: @escaping (_ playlist: Playlist?) -> Void) {
        
        if let url = URL(string: BASE_URL + "api/playlist") {
            var request = URLRequest(url: url, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
            
            request.httpMethod = "POST"
            
            let postString = "id=" + id
            
            request.httpBody = postString.data(using: .utf8)
            
            showNetworkActivityIndicator()
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                hideNetworkActivityIndicator()
                
                guard error == nil else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                if let data = data {
                    do {
                        let playlist: Playlist?
                        
                        if let item = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] {
                            playlist = jsonToPlaylist(item: item)
                            
                            DispatchQueue.main.async {
                                completion(playlist)
                            }
                        }
                        
                    } catch {
                        print("Error: " + error.localizedDescription)
                    }
                }
                
            }
            
            task.resume()
            
        }
        
    }
    
    static func retrievePlaylistsFromServer(completion: @escaping (_ playlists: [Playlist]) -> Void) {
        
        if let url = URL(string: BASE_URL + "api/user/playlists") {
            var request = URLRequest(url: url, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
            request.httpMethod = "POST"
            
            if let idToken = UserDefaults.standard.string(forKey: "idToken") {
                request.setValue(idToken, forHTTPHeaderField: "Authorization")
            }
            
            showNetworkActivityIndicator()
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                
                hideNetworkActivityIndicator()
                
                guard error == nil else {
                    DispatchQueue.main.async {
                        completion([])
                    }
                    return
                }
                
                if let data = data {
                    do {
                        var playlists = [Playlist]()
                        
                        if let playlistsJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [[String:Any]] {
                            
                            for item in playlistsJSON {
                                let playlist = jsonToPlaylist(item: item)
                                playlists.append(playlist)
                            }
                            
                        }
                        
                        DispatchQueue.main.async {
                            completion(playlists)
                        }
                        
                    } catch {
                        print("Error: " + error.localizedDescription)
                    }
                }
                
                
                
            }
            
            task.resume()
            
        }
        
    }
    
    static func createPlaylist (title: String?, completion: @escaping (_ playlist: Playlist?) -> Void) {
        
        if let url = URL(string: BASE_URL + "playlists/") {
            
            var request = URLRequest(url: url, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
            request.httpMethod = "POST"
            
            guard let idToken = UserDefaults.standard.string(forKey: "idToken") else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            request.setValue(idToken, forHTTPHeaderField: "Authorization")
            
            var postString = ""
            
            if let title = title {
                postString += "title=" + title
            }
            
            if let userName = UserDefaults.standard.string(forKey: "userName") {
                postString += "&userName=" + userName
            }
            
            request.httpBody = postString.data(using: .utf8)
            
            showNetworkActivityIndicator()
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                
                hideNetworkActivityIndicator()
                
                guard error == nil else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                if let data = data {
                    do {
                        let playlist: Playlist?
                        
                        if let item = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] {
                            playlist = jsonToPlaylist(item: item)
                            
                            DispatchQueue.main.async {
                                completion(playlist)
                            }
                            
                        }
                    } catch {
                        print("Error: " + error.localizedDescription)
                    }
                }
                
            }
            
            task.resume()
            
        }

    }
    
    static func deletePlaylistFromServer(id:String, completion: @escaping (Bool) -> Void) {
        if let url = URL(string: BASE_URL + "playlists/" + id), let idToken = UserDefaults.standard.string(forKey: "idToken") {
            showNetworkActivityIndicator()
            
            let request = NSMutableURLRequest(url: url, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
            
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(idToken, forHTTPHeaderField: "Authorization")
            
            request.httpMethod = "DELETE"
            
            let task = URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
                hideNetworkActivityIndicator()
                guard error == nil else {
                    print("Error: \(error?.localizedDescription ?? "Unknown Error")")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
                
                completion(true)
            }
            
            task.resume()
        }
    }
    
    static func convertToPlaylistUpdateBody(title:String?, itemsOrder:[String]? = []) -> [String: Any] {
        var body:[String: Any] = [:]
        
        if let title = title {
            body["title"] = title
        }
        
        if let itemsOrder = itemsOrder {
            body["itemsOrder"] = itemsOrder
        }
        
        return body
    }
    
    static func updatePlaylistOnServer(id: String, title:String?, itemsOrder:[String]? = [], completion: @escaping (Bool) -> Void) {
        if let url = URL(string: BASE_URL + "playlists/" + id) {
            
            var request = URLRequest(url: url, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 20)
            
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            request.httpMethod = "PUT"
            
            if let idToken = UserDefaults.standard.string(forKey: "idToken") {
                request.setValue(idToken, forHTTPHeaderField: "Authorization")
            }
            
            let putBody = self.convertToPlaylistUpdateBody(title: title, itemsOrder: itemsOrder)
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: putBody, options: JSONSerialization.WritingOptions())
                
                showNetworkActivityIndicator()
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    hideNetworkActivityIndicator()
                    
                    guard error == nil else {
                        DispatchQueue.main.async {
                            completion(false)
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        completion(true)
                    }
                }
                
                task.resume()
                
            } catch {
                print(error)
                DispatchQueue.main.async {
                    completion(false)
                }
            }
            
        }
    }
    
    static func subscribeToPlaylistOnServer(id:String, completion: @escaping (Bool) -> Void) {
        if let url = URL(string: BASE_URL + "playlists/subscribe/" + id), let idToken = UserDefaults.standard.string(forKey: "idToken") {
            showNetworkActivityIndicator()
            
            let request = NSMutableURLRequest(url: url, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
            
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(idToken, forHTTPHeaderField: "Authorization")
            
            request.httpMethod = "POST"
            
            let task = URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
                hideNetworkActivityIndicator()
                guard error == nil else {
                    print("Error: \(error?.localizedDescription ?? "Unknown Error")")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
                
                completion(true)
            }
            
            task.resume()
        }
    }
    
    static func unsubscribeFromPlaylistOnServer(id:String, completion: @escaping (Bool) -> Void) {
        if let url = URL(string: BASE_URL + "playlists/unsubscribe/" + id), let idToken = UserDefaults.standard.string(forKey: "idToken") {
            showNetworkActivityIndicator()
            
            let request = NSMutableURLRequest(url: url, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
            
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(idToken, forHTTPHeaderField: "Authorization")
            
            request.httpMethod = "POST"
            
            let task = URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
                hideNetworkActivityIndicator()
                guard error == nil else {
                    print("Error: \(error?.localizedDescription ?? "Unknown Error")")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
                
                completion(true)
            }
            
            task.resume()
        }
    }
    
    // TODO: addToPlaylist and removeFromPlaylist are identical except the urlString. How can we rewrite/consolidate them?
    static func addToPlaylist(playlistId: String, item: PlayerHistoryItem, shouldSaveFullEpisode: Bool = false, completion: @escaping (_ itemCount: Int?) -> Void) {
        
        let urlString = BASE_URL + "playlists/" + playlistId + "/addItem"
        
        if let url = URL(string: urlString) {
            
            var request = URLRequest(url: url, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpMethod = "POST"
            
            if let idToken = UserDefaults.standard.string(forKey: "idToken") {
                request.setValue(idToken, forHTTPHeaderField: "Authorization")
            }
            
            let postBody = item.convertToMediaRefPostString(shouldSaveFullEpisode: shouldSaveFullEpisode)
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: postBody, options: JSONSerialization.WritingOptions())
                
                showNetworkActivityIndicator()
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    
                    showNetworkActivityIndicator()
                    
                    guard error == nil else {
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                        return
                    }
                    
                    if let data = data {
                        do {
                            if let itemCount = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? Int {
                                DispatchQueue.main.async {
                                    completion(itemCount)
                                }
                            }
                        } catch {
                            print(error.localizedDescription)
                            DispatchQueue.main.async {
                                completion(nil)
                            }
                        }
                    }
                }
                
                task.resume()
            } catch {
                print(error.localizedDescription)
            }
            
        }
        
    }
    
    // TODO: addToPlaylist and removeFromPlaylist are identical except the urlString. How can we rewrite/consolidate them?
    static func removeFromPlaylist(playlistId: String, mediaRefId: String, completion: @escaping (_ itemCount: Int?) -> Void) {
        
        let urlString = BASE_URL + "playlists/" + playlistId + "/removeItem"
        
        if let url = URL(string: urlString) {
            
            var request = URLRequest(url: url, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
            request.httpMethod = "POST"
            
            if let idToken = UserDefaults.standard.string(forKey: "idToken") {
                request.setValue(idToken, forHTTPHeaderField: "Authorization")
            }
            
            let postString = "mediaRefId=" + mediaRefId
            
            request.httpBody = postString.data(using: .utf8)
            
            showNetworkActivityIndicator()
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                
                hideNetworkActivityIndicator()
                
                guard error == nil else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                if let data = data {
                    do {
                        if let itemCount = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? Int {
                            DispatchQueue.main.async {
                                completion(itemCount)
                                NotificationCenter.default.post(name: .removedPlaylistItem, object: [playlistId, mediaRefId], userInfo: nil)
                            }
                        }
                    } catch {
                        print("Error: " + error.localizedDescription)
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    }
                }
            }
            
            task.resume()
            
        }
        
    }
    
}
