//
//  DownloadingEpisodeList.swift
//  Podverse
//
//  Created by Creon on 12/24/16.
//  Copyright © 2016 Podverse LLC. All rights reserved.
//

import Foundation


final class DownloadingEpisodeList {
    static var shared = DownloadingEpisodeList()
    
    var downloadingEpisodes = [DownloadingEpisode]() {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: Constants.kUpdateDownloadsTable), object: nil)
            }
        }
    }
    
    static func removeDownloadingEpisodeWithMediaURL(mediaURL:String?) {
        // If the episode is currently in the episodeDownloadArray, then delete the episode from the episodeDownloadArray
        if let mediaURL = mediaURL, let index = DownloadingEpisodeList.shared.downloadingEpisodes.index(where: { $0.mediaURL == mediaURL }) {
            DownloadingEpisodeList.shared.downloadingEpisodes.remove(at: index)
        }
    }
}
