import UIKit
import CoreData

protocol AutoDownloadProtocol: NSObjectProtocol {
    func podcastAutodownloadChanged(feedUrl: String)
}

class EpisodesTableViewController: PVViewController {
    
    weak var delegate: AutoDownloadProtocol?
    var clipsArray = [MediaRef]()
    var episodesArray = [Episode]()
    var feedUrl: String?
    let moc = CoreDataHelper.createMOCForThread(threadType: .privateThread)
    let reachability = PVReachability.shared
    
    var filterTypeSelected: EpisodesFilter = .downloaded {
        didSet {
            self.tableViewHeader.filterTitle = self.filterTypeSelected.text
            UserDefaults.standard.set(filterTypeSelected.text, forKey: kEpisodesTableFilterType)
            
            if filterTypeSelected == .clips {
                self.tableViewHeader.sortingButton.isHidden = false
            } else {
                self.tableViewHeader.sortingButton.isHidden = true
            }
        }
    }
    
    var sortingTypeSelected: ClipSorting = .topWeek {
        didSet {
            self.tableViewHeader.sortingTitle = sortingTypeSelected.text
            UserDefaults.standard.set(sortingTypeSelected.text, forKey: kEpisodesTableSortingType)
        }
    }
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var activityView: UIView!
    @IBOutlet weak var autoDownloadLabel: UILabel!
    @IBOutlet weak var autoDownloadSwitch: UISwitch!
    @IBOutlet weak var bottomButton: UITableView!
    @IBOutlet weak var headerImageView: UIImageView!
    @IBOutlet weak var headerPodcastTitle: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeader: FiltersTableHeaderView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNotificationListeners()
        
        self.activityIndicator.hidesWhenStopped = true
        
        self.tableViewHeader.delegate = self
        self.tableViewHeader.setupViews()
        
        if let savedFilterType = UserDefaults.standard.value(forKey: kEpisodesTableFilterType) as? String, let episodesFilterType = EpisodesFilter(rawValue: savedFilterType) {
            self.filterTypeSelected = episodesFilterType
        } else {
            self.filterTypeSelected = .downloaded
        }
        
        if let savedSortingType = UserDefaults.standard.value(forKey: kEpisodesTableSortingType) as? String, let episodesSortingType = ClipSorting(rawValue: savedSortingType) {
            self.sortingTypeSelected = episodesSortingType
        } else {
            self.sortingTypeSelected = .topWeek
        }
        
        loadPodcastHeader()
        
        reloadEpisodeOrClipData()
        
    }
    
    deinit {
        removeObservers()
    }
    
    fileprivate func setupNotificationListeners() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.downloadStarted(_:)), name: .downloadStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.downloadResumed(_:)), name: .downloadResumed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.downloadPaused(_:)), name: .downloadPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.downloadFinished(_:)), name: .downloadFinished, object: nil)
    }
    
    fileprivate func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: .downloadStarted, object: nil)
        NotificationCenter.default.removeObserver(self, name: .downloadResumed, object: nil)
        NotificationCenter.default.removeObserver(self, name: .downloadPaused, object: nil)
        NotificationCenter.default.removeObserver(self, name: .downloadFinished, object: nil)
    }
    
    @IBAction func autoDownloadSwitchTouched(_ sender: Any) {
        if let feedUrl = feedUrl, let podcast = Podcast.podcastForFeedUrl(feedUrlString: feedUrl, managedObjectContext: moc) {
            if podcast.shouldAutoDownload() {
                podcast.removeFromAutoDownloadList()
            } else {
                podcast.addToAutoDownloadList()
            }
            self.delegate?.podcastAutodownloadChanged(feedUrl: podcast.feedUrl)
        }
    }
    
    func loadPodcastHeader() {
        if let feedUrl = feedUrl, let podcast = Podcast.podcastForFeedUrl(feedUrlString: feedUrl, managedObjectContext: moc) {
            
            self.headerPodcastTitle.text = podcast.title
            
            self.headerImageView.image = Podcast.retrievePodcastImage(podcastImageURLString: podcast.imageUrl, feedURLString: podcast.feedUrl, managedObjectID: podcast.objectID, completion: { _ in
                self.headerImageView.sd_setImage(with: URL(string: podcast.imageUrl ?? ""), placeholderImage: #imageLiteral(resourceName: "PodverseIcon"))
            })
            
            self.autoDownloadSwitch.isOn = podcast.shouldAutoDownload() ? true : false
        }
    }
    
    func downloadPlay(sender: UIButton) {
        if let cell = sender.superview?.superview as? EpisodeTableViewCell,
            let indexRow = self.tableView.indexPath(for: cell)?.row {
            
            let episode = episodesArray[indexRow]
            if episode.fileName != nil {
                
                let playerHistoryItem: PlayerHistoryItem?
                
                if let mediaUrl = episode.mediaUrl, let item = playerHistoryManager.retrieveExistingPlayerHistoryItem(mediaUrl: mediaUrl) {
                    playerHistoryItem = item
                } else {
                    playerHistoryItem = playerHistoryManager.convertEpisodeToPlayerHistoryItem(episode: episode)
                }
                
                goToNowPlaying()
                
                if let item = playerHistoryItem {
                    pvMediaPlayer.loadPlayerHistoryItem(item: item)
                }
                
            } else {
                if reachability.hasWiFiConnection() == false {
                    showInternetNeededAlertWithDesciription(message: "Connect to WiFi to download an episode.")
                    return
                }
                PVDownloader.shared.startDownloadingEpisode(episode: episode)
            }
        }
    }
    
    func reloadEpisodeOrClipData() {
        if self.filterTypeSelected == .clips {
            retrieveClips()
        } else {
            reloadEpisodeData()
        }
    }
    
    func loadAllEpisodeData() {
        self.filterTypeSelected = .allEpisodes
        reloadEpisodeData()
    }
    
    func reloadEpisodeData() {
        
        self.hideNoDataView()
        self.tableView.isHidden = false
        
        if let feedUrl = feedUrl, let podcast = Podcast.podcastForFeedUrl(feedUrlString: feedUrl, managedObjectContext: moc) {
            
            self.episodesArray.removeAll()
            
            if self.filterTypeSelected == .downloaded {
                episodesArray = Array(podcast.episodes.filter { $0.fileName != nil } )
                let downloadingEpisodes = DownloadingEpisodeList.shared.downloadingEpisodes.filter({$0.podcastFeedUrl == podcast.feedUrl})
                
                for dlEpisode in downloadingEpisodes {
                    if let mediaUrl = dlEpisode.mediaUrl, let episode = Episode.episodeForMediaUrl(mediaUrlString: mediaUrl, managedObjectContext: self.moc), !episodesArray.contains(episode) {
                        episodesArray.append(episode)
                    }
                }
                
                guard checkForDownloadedEpisodeResults(episodes: episodesArray) else {
                    return
                }
                
            } else if self.filterTypeSelected == .allEpisodes {
                episodesArray = Array(podcast.episodes)
                
                guard checkForAllEpisodeResults(episodes: episodesArray) else {
                    return
                }
            }
            
            episodesArray.sort(by: { (prevEp, nextEp) -> Bool in
                if let prevTimeInterval = prevEp.pubDate, let nextTimeInterval = nextEp.pubDate {
                    return (prevTimeInterval > nextTimeInterval)
                }
                
                return false
            })
            
            self.tableView.reloadData()
            
        }
        
    }
    
    func retrieveClips() {
            
        guard checkForConnectivity() else {
            return
        }

        self.episodesArray.removeAll()
        self.tableView.reloadData()
        
        self.hideNoDataView()
        self.activityIndicator.startAnimating()
        self.activityView.isHidden = false
        
        if let feedUrl = feedUrl {
            MediaRef.retrieveMediaRefsFromServer(podcastFeedUrls: [feedUrl], sortingType: self.sortingTypeSelected, page: 1) { (mediaRefs) -> Void in
                self.reloadClipData(mediaRefs)
            }
        }
    }
    
    func reloadClipData(_ mediaRefs: [MediaRef]? = nil) {
        
        guard let mediaRefs = mediaRefs, checkForClipResults(mediaRefs: mediaRefs) else {
            return
        }

        for mediaRef in mediaRefs {
            self.clipsArray.append(mediaRef)
        }
        
        self.tableView.isHidden = false
        self.tableView.reloadData()
        
    }
    
    func checkForConnectivity() -> Bool {
        
        let message = ErrorMessages.noClipsInternet.text
        
        if self.reachability.hasInternetConnection() == false {
            loadNoDataView(message: message, buttonTitle: "Retry", buttonPressed: #selector(EpisodesTableViewController.reloadEpisodeOrClipData))
            return false
        } else {
            return true
        }
        
    }
    
    func checkForClipResults(mediaRefs: [MediaRef]?) -> Bool {
        
        let message = ErrorMessages.noEpisodeClipsAvailable.text
        
        guard let mediaRefs = mediaRefs, mediaRefs.count > 0 else {
            loadNoDataView(message: message, buttonTitle: nil, buttonPressed: #selector(EpisodesTableViewController.reloadEpisodeOrClipData))
            return false
        }
        
        return true
        
    }
    
    func checkForDownloadedEpisodeResults(episodes: [Episode]?) -> Bool {
        
        var message = ErrorMessages.noDownloadedEpisodesAvailable.text
        
        guard let episodes = episodes, episodes.count > 0 else {
            loadNoDataView(message: message, buttonTitle: "Show All Episodes", buttonPressed: #selector(EpisodesTableViewController.loadAllEpisodeData))
            return false
        }
        
        return true
        
    }
    
    func checkForAllEpisodeResults(episodes: [Episode]?) -> Bool {
        
        var message = ErrorMessages.noEpisodesAvailable.text
        
        guard let episodes = episodes, episodes.count > 0 else {
            loadNoDataView(message: message, buttonTitle: nil, buttonPressed: #selector(EpisodesTableViewController.reloadEpisodeData))
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
            }
        }
        else {
            self.addNoDataViewWithMessage(message, buttonTitle: buttonTitle, buttonImage: nil, retryPressed: buttonPressed)
        }
        
        self.activityIndicator.stopAnimating()
        self.activityView.isHidden = true
        self.tableView.isHidden = true
        showNoDataView()
        
    }

    override func goToNowPlaying () {
        if let mediaPlayerVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MediaPlayerVC") as? MediaPlayerViewController {
            pvMediaPlayer.shouldAutoplayOnce = true
            self.navigationController?.pushViewController(mediaPlayerVC, animated: true)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Show Episode" {
            if let episodeTableViewController = segue.destination as? EpisodeTableViewController, let feedUrl = self.feedUrl, let index = self.tableView.indexPathForSelectedRow {
                episodeTableViewController.feedUrl = feedUrl
                episodeTableViewController.mediaUrl = self.episodesArray[index.row].mediaUrl
            }
        }
    }
}

extension EpisodesTableViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if self.filterTypeSelected == .clips {
            return self.clipsArray.count
        } else {
            return self.episodesArray.count
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if self.filterTypeSelected == .clips {
            
            let cell = self.tableView.dequeueReusableCell(withIdentifier: "clipCell", for: indexPath as IndexPath) as! ClipPodcastTableViewCell
            
            let clip = clipsArray[indexPath.row]
            
            cell.episodeTitle.text = clip.episodeTitle
            cell.clipTitle.text = clip.readableClipTitle()
            cell.time.text = clip.readableStartAndEndTime()
            cell.episodePubDate.text = clip.episodePubDate?.toShortFormatString()
            
            return cell
            
        } else {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "episodeCell", for: indexPath as IndexPath) as! EpisodeTableViewCell
            
            let episode = episodesArray[indexPath.row]
            
            cell.title?.text = episode.title
            
            if let summary = episode.summary {
                
                let trimmed = summary.replacingOccurrences(of: "\\n*", with: "", options: .regularExpression)
                
                cell.summary?.text = trimmed.removeHTMLFromString()?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            let totalClips = String(123)
            cell.totalClips?.text = String(totalClips + " clips")
            
            if let pubDate = episode.pubDate {
                cell.pubDate?.text = pubDate.toShortFormatString()
            }
            
            if (DownloadingEpisodeList.shared.downloadingEpisodes.contains(where: {$0.mediaUrl == episode.mediaUrl})) {
                cell.button.setTitle("DLing", for: .normal)
            } else if episode.fileName != nil {
                cell.button.setTitle("Play", for: .normal)
            } else {
                cell.button.setTitle("DL", for: .normal)
            }
            
            cell.button.addTarget(self, action: #selector(downloadPlay(sender:)), for: .touchUpInside)
            
            return cell
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)
        
        if self.filterTypeSelected == .clips {
            let clip = clipsArray[indexPath.row]
            let playerHistoryItem = self.playerHistoryManager.convertMediaRefToPlayerHistoryItem(mediaRef: clip)
            self.goToNowPlaying()
            self.pvMediaPlayer.loadPlayerHistoryItem(item: playerHistoryItem)
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        if self.filterTypeSelected != .clips {
            let episodeToEdit = episodesArray[indexPath.row]
            
            let deleteAction = UITableViewRowAction(style: .default, title: "Delete", handler: {action, indexpath in
                self.episodesArray.remove(at: indexPath.row)
                self.tableView.deleteRows(at: [indexPath], with: .fade)
                if self.pvMediaPlayer.nowPlayingItem?.episodeMediaUrl == episodeToEdit.mediaUrl {
                    self.tabBarController?.hidePlayerView()
                }
                
                PVDeleter.deleteEpisode(episodeId: episodeToEdit.objectID, fileOnly: true, shouldCallNotificationMethod: true)
                
                if self.filterTypeSelected == .downloaded {
                    self.checkForDownloadedEpisodeResults(episodes: self.episodesArray)
                }
            })
            
            return [deleteAction]
        } else {
            return []
        }
        
    }
}

extension EpisodesTableViewController {
    
    func updateCellByNotification(_ notification:Notification) {
        reloadEpisodeData()
        if let downloadingEpisode = notification.userInfo?[Episode.episodeKey] as? DownloadingEpisode, let mediaUrl = downloadingEpisode.mediaUrl, let index = self.episodesArray.index(where: { $0.mediaUrl == mediaUrl }) {
            
            self.moc.refresh(self.episodesArray[index], mergeChanges: true)
            self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)            
        }
    }
    
    func downloadFinished(_ notification:Notification) {
        updateCellByNotification(notification)
    }
    
    func downloadPaused(_ notification:Notification) {
        updateCellByNotification(notification)
    }

    func downloadResumed(_ notification:Notification) {
        updateCellByNotification(notification)
    }
    
    func downloadStarted(_ notification:Notification) {
        updateCellByNotification(notification)
    }
    
    override func episodeDeleted(_ notification:Notification) {
        super.episodeDeleted(notification)
        
        if let mediaUrl = notification.userInfo?["mediaUrl"] as? String, let index = self.episodesArray.index(where: { $0.mediaUrl == mediaUrl }), let _ = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? EpisodeTableViewCell {
            if self.filterTypeSelected == .downloaded {
                self.episodesArray.remove(at: index)
                self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                self.moc.refreshAllObjects()
            }
        }
    }

}

extension EpisodesTableViewController:FilterSelectionProtocol {
    func filterButtonTapped() {
        
        let alert = UIAlertController(title: "Show", message: nil, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: EpisodesFilter.downloaded.text, style: .default, handler: { action in
            self.filterTypeSelected = .downloaded
            self.reloadEpisodeData()
        }))
        
        alert.addAction(UIAlertAction(title: EpisodesFilter.allEpisodes.text, style: .default, handler: { action in
            self.filterTypeSelected = .allEpisodes
            self.reloadEpisodeData()
        }))
        
        alert.addAction(UIAlertAction(title: EpisodesFilter.clips.text, style: .default, handler: { action in
            self.filterTypeSelected = .clips
            self.retrieveClips()
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func sortingButtonTapped() {
        self.tableViewHeader.showSortByMenu(vc: self)
    }
    
    func sortByRecent() {
        self.sortingTypeSelected = .recent
        self.retrieveClips()
    }
    
    func sortByTop() {
        self.tableViewHeader.showSortByTimeRangeMenu(vc: self)
    }
    
    func sortByTopWithTimeRange(timeRange: SortingTimeRange) {
        
        if timeRange == .day {
            self.sortingTypeSelected = .topDay
        } else if timeRange == .week {
            self.sortingTypeSelected = .topWeek
        } else if timeRange == .month {
            self.sortingTypeSelected = .topMonth
        } else if timeRange == .year {
            self.sortingTypeSelected = .topYear
        } else if timeRange == .allTime {
            self.sortingTypeSelected = .topAllTime
        }
        
        self.retrieveClips()
        
    }
    
}

