//
//  PlaylistsTableViewController.swift
//  Podverse
//
//  Created by Creon on 12/15/16.
//  Copyright © 2016 Podverse LLC. All rights reserved.
//

import UIKit

class PlaylistsTableViewController: PVViewController {
    
    var playlistsArray = [Playlist]()
    let reachability = PVReachability.shared

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.title = "Playlists"
        
        self.activityIndicator.hidesWhenStopped = true
        
        retrievePlaylists()
        
    }
    
    @objc func retrievePlaylists() {
        
        guard checkConnectivity(), checkForAuthorization() else {
            return
        }
        
        self.hideNoDataView()
        
        self.activityIndicator.startAnimating()
        
        Playlist.retrievePlaylistsFromServer() { (playlists) -> Void in
            self.reloadPlaylistData(playlists: playlists)
        }
    }
    
    func checkForAuthorization() -> Bool {
        
        let message = Strings.Errors.noPlaylistsNotLoggedIn
        let buttonTitle = "Login"
        let selector = #selector(PlaylistsTableViewController.presentLogin)
                
        guard PVAuth.userIsLoggedIn else {
            loadNoDataView(message: message, buttonTitle: buttonTitle, buttonPressed: selector)
            return false
        }
        
        return true
        
    }
    
    func checkConnectivity() -> Bool {
        
        let message = Strings.Errors.noPlaylistsInternet
        let buttonTitle = "Retry"
        let selector:Selector = #selector(PlaylistsTableViewController.retrievePlaylists)
        
        guard checkForConnectivity() else {
            loadNoDataView(message: message, buttonTitle: buttonTitle, buttonPressed: selector)
            return false
        }
        
        return true
        
    }
    
    func checkForResults(playlists: [Playlist]?) -> Bool {
        
        let message = Strings.Errors.noPlaylistsAvailable
        
        guard let playlists = playlists, playlists.count > 0 else {
            loadNoDataView(message: message, buttonTitle: nil, buttonPressed: nil)
            return false
        }
        
        return true
        
    }
    
    func loadNoDataView(message: String, buttonTitle: String?, buttonPressed: Selector?) {
        
        if let noDataView = self.view.subviews.first(where: { $0.tag == kNoDataViewTag}) {
            
            if let messageView = noDataView.subviews.first(where: {$0 is UILabel}), let messageLabel = messageView as? UILabel {
                messageLabel.text = message
            }
            
            if let buttonView = noDataView.subviews.first(where: {$0 is UIButton}), let button = buttonView as? UIButton {
                button.setTitle(buttonTitle, for: .normal)
                button.setTitleColor(.blue, for: .normal)
            }
            
        }
        else {
            self.addNoDataViewWithMessage(message, buttonTitle: buttonTitle, buttonImage: nil, retryPressed: buttonPressed)
        }
        
        self.activityIndicator.stopAnimating()
        self.tableView.isHidden = true
        showNoDataView()
        
    }
    
    func reloadPlaylistData(playlists: [Playlist]? = nil) {
        
        self.activityIndicator.stopAnimating()
        
        guard checkForResults(playlists: playlists), let playlists = playlists else {
            return
        }
    
        self.playlistsArray = playlists
        
        self.tableView.isHidden = false
        self.tableView.reloadData()
        
    }
    
    @objc func presentLogin() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginVC") as? LoginViewController {
            self.present(loginVC, animated: true, completion: nil)
        }
    }
    
}

extension PlaylistsTableViewController:UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 58
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 58
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.playlistsArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let playlist = self.playlistsArray[indexPath.row]
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "playlistCell", for: indexPath) as! PlaylistTableViewCell
        
        cell.title?.text = playlist.title
        
        if let lastUpdated = playlist.lastUpdated {
            cell.lastUpdated?.text = lastUpdated.toShortFormatString()
        }
        
        cell.itemCount.text = "Items: " + String(playlist.mediaRefs.count)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "Show Playlist", sender: nil)
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {

        let row = indexPath.row
        
        if self.playlistsArray.count > row {
            let playlist = self.playlistsArray[row]
            
            if let id = playlist.id {
                var actionTitle = "Unfollow"
                
                if let userId = UserDefaults.standard.string(forKey: "userId"), userId == playlist.ownerId {
                    actionTitle = "Delete"
                    
                    let deleteAction = UITableViewRowAction(style: .default, title: actionTitle, handler: {action, indexPath in

                        Playlist.deletePlaylistFromServer(id: id) { wasSuccessful in
                            DispatchQueue.main.async {
                                if (wasSuccessful) {
                                    self.playlistsArray.remove(at: row)
                                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                                } else {
                                    let actions = UIAlertController(title: "Failed to delete playlist", message: "Please check your internet connection and try again.",preferredStyle: .alert)
                                    
                                    actions.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                                    
                                    self.present(actions, animated: true, completion: nil)
                                }
                            }
                        }
                    })
                    
                    return [deleteAction]
                } else {
                    let unsubscribeAction = UITableViewRowAction(style: .default, title: actionTitle, handler: {action, indexPath in
                        
                        Playlist.unsubscribeFromPlaylistOnServer(id: id) { wasSuccessful in
                            DispatchQueue.main.async {
                                if (wasSuccessful) {
                                    self.playlistsArray.remove(at: row)
                                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                                } else {
                                    let actions = UIAlertController(title: "Failed to unsubscribe from playlist", message: "Please check your internet connection and try again.", preferredStyle: .alert)
                                    
                                    actions.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                                    
                                    self.present(actions, animated: true, completion: nil)
                                }
                            }
                        }
                    })
                    
                    return [unsubscribeAction]
                }
            }
        }
            
        return []
    }
        
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let index = self.tableView.indexPathForSelectedRow {
            if segue.identifier == "Show Playlist" {
                let playlistDetailTableViewController = segue.destination as! PlaylistDetailTableViewController
                playlistDetailTableViewController.playlistId = self.playlistsArray[index.row].id
                playlistDetailTableViewController.ownerId = self.playlistsArray[index.row].ownerId
            }
        }
    }
    
}

extension PlaylistsTableViewController {
    
    func loggedInSuccessfully(_ notification:Notification) {
        retrievePlaylists()
    }
    
}
