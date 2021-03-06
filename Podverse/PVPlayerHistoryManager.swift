//
//  PVPlayerHistoryManager.swift
//  Podverse
//
//  Created by Mitchell Downey on 5/21/17.
//  Copyright © 2017 Podverse LLC. All rights reserved.
//

import Foundation

class PlayerHistory {
    static let manager = PlayerHistory()
    var historyItems = [PlayerHistoryItem]() {
        didSet {
            self.saveData()
        }
    }
    
    //save data
    func saveData() {
        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: data)
        archiver.encode(historyItems, forKey: "userHistory")
        archiver.finishEncoding()
        data.write(toFile: dataFilePath(), atomically: true)
    }
    
    //read data
    func loadData() {
        let path = self.dataFilePath()
        let defaultManager = FileManager()
        if defaultManager.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path)
            do {
                let data = try Data(contentsOf: url)
                let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
                if let hItems = unarchiver.decodeObject(forKey: "userHistory") as? Array<PlayerHistoryItem> {
                    historyItems = hItems
                }
                unarchiver.finishDecoding()
            } catch {
                print("Decoding failed: \(error.localizedDescription)")
            }
            

        }
    }
    
    func documentsDirectory()->String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                        .userDomainMask, true)
        return paths.first ?? ""
    }
    
    func dataFilePath ()->String{
        return self.documentsDirectory().appendingFormat("/.plist")
    }
    
    func addOrUpdateItem(item: PlayerHistoryItem?) {
        
        if let item = item {
            let previousIndex = historyItems.index(where: { (previousItem) -> Bool in // thanks sschuth https://stackoverflow.com/a/24069331/2608858
                previousItem.episodeMediaUrl == item.episodeMediaUrl
            })
            
            if let index = previousIndex {
                historyItems[index] = item
                historyItems.rearrange(from: index, to: 0)
            } else {
                historyItems.insert(item, at: 0)
            }    
        }
        
    }
    
    func retrieveExistingPlayerHistoryItem(mediaUrl: String) -> PlayerHistoryItem? {
        
        let previousIndex = historyItems.index(where: { (previousItem) -> Bool in // thanks sschuth https://stackoverflow.com/a/24069331/2608858
            previousItem.episodeMediaUrl == mediaUrl
        })
        
        if let index = previousIndex {
            return historyItems[index]
        }
        
        return nil

    }

    func convertSearchPodcastEpisodeToPlayerHistoryItem(searchPodcast: SearchPodcast, searchEpisode: SearchEpisode) -> PlayerHistoryItem {
        let playerHistoryItem = PlayerHistoryItem(
            podcastId: searchPodcast.id,
            podcastFeedUrl: nil, // Since it is a searchPodcast, we can use podcastId instead of podcastFeedUrl
            podcastTitle: searchPodcast.title,
            podcastImageUrl: searchPodcast.imageUrl,
            episodeId: searchEpisode.id,
            episodeMediaUrl: searchEpisode.mediaUrl,
            episodeTitle: searchEpisode.title,
            episodeSummary: searchEpisode.summary,
            episodePubDate: searchEpisode.pubDate?.toServerDate(),
            hasReachedEnd: false,
            lastPlaybackPosition: 0)
        
        return playerHistoryItem
    }
    
    func convertEpisodeToPlayerHistoryItem(episode: Episode) -> PlayerHistoryItem {
        let playerHistoryItem = PlayerHistoryItem(
            podcastId: episode.podcast.id,
            podcastFeedUrl: episode.podcast.feedUrl,
            podcastTitle: episode.podcast.title,
            podcastImageUrl: episode.podcast.imageUrl,
            episodeMediaUrl: episode.mediaUrl,
            episodeTitle: episode.title,
            episodeSummary: episode.summary,
            episodePubDate: episode.pubDate,
            hasReachedEnd: false,
            lastPlaybackPosition: 0)
        
        return playerHistoryItem
    }
    
    func convertMediaRefToPlayerHistoryItem(mediaRef: MediaRef) -> PlayerHistoryItem {
        let playerHistoryItem = PlayerHistoryItem(
            mediaRefId: mediaRef.id,
            podcastId: mediaRef.podcastId,
            podcastFeedUrl: mediaRef.podcastFeedUrl,
            podcastTitle: mediaRef.podcastTitle,
            podcastImageUrl: mediaRef.podcastImageUrl,
            episodeId: mediaRef.episodeId,
            episodeMediaUrl: mediaRef.episodeMediaUrl,
            episodeTitle: mediaRef.episodeTitle,
            episodeSummary: mediaRef.episodeSummary,
            episodePubDate: mediaRef.episodePubDate,
            startTime: mediaRef.startTime,
            endTime: mediaRef.endTime,
            clipTitle: mediaRef.title,
            ownerName: mediaRef.ownerName,
            ownerId: mediaRef.ownerId,
            hasReachedEnd: false,
            lastPlaybackPosition: 0,
            isPublic: mediaRef.isPublic)
        
        return playerHistoryItem
    }
    
    func checkIfPodcastWasLastPlayed(podcastId:String?, feedUrl:String?) -> Bool {
        if let _ = podcastId, historyItems.first?.podcastId == podcastId {
            return true
        } else if let feedUrl = feedUrl, historyItems.first?.podcastFeedUrl == feedUrl {
            return true
        } else {
            return false
        }
    }
    
    func checkIfEpisodeWasLastPlayed(mediaUrl: String) -> Bool {
        if historyItems.first?.episodeMediaUrl == mediaUrl {
            return true
        } else {
            return false
        }
    }

}
