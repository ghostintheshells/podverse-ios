//
//  SearchPodcastViewController.swift
//  Podverse
//
//  Created by Mitchell Downey on 10/21/17.
//  Copyright © 2017 Podverse LLC. All rights reserved.
//

import UIKit

class SearchPodcastViewController: PVViewController {

    var clipsArray = [MediaRef]()
    var searchEpisodesArray = [SearchEpisode]()
    var filterTypeOverride:SearchPodcastFilter = .episodes
    let reachability = PVReachability.shared
    var searchPodcast:SearchPodcast?
    var podcastId:String?
    
    var filterTypeSelected:SearchPodcastFilter = .episodes {
        didSet {
            self.resetClipQuery()
            self.tableViewHeader.filterTitle = self.filterTypeSelected.text
            
            if filterTypeSelected == .clips {
                self.webView.isHidden = true
                self.tableViewHeader.sortingButton.isHidden = false
                self.clipQueryStatusView.isHidden = false
            } else if filterTypeSelected == .episodes {
                self.webView.isHidden = true
                self.tableViewHeader.sortingButton.isHidden = true
                self.clipQueryStatusView.isHidden = true
            } else {
                self.webView.isHidden = false
                self.tableViewHeader.sortingButton.isHidden = true
                self.clipQueryStatusView.isHidden = true
            }
        }
    }
    
    var sortingTypeSelected:ClipSorting = .topWeek {
        didSet {
            self.resetClipQuery()
            self.tableViewHeader.sortingTitle = sortingTypeSelected.text
        }
    }
    
    var clipQueryPage:Int = 0
    var clipQueryIsLoading:Bool = false
    var clipQueryEndOfResultsReached:Bool = false
    
    @IBOutlet weak var headerActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var headerImageView: UIImageView!
    @IBOutlet weak var headerPodcastTitle: UILabel!
    @IBOutlet weak var headerSubscribe: UIButton!
    @IBOutlet weak var statusActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var statusView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeader: FiltersTableHeaderView!
    @IBOutlet weak var webView: UIWebView!
    
    @IBOutlet weak var clipQueryActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var clipQueryMessage: UILabel!
    @IBOutlet weak var clipQueryStatusView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Preview Page"
        
        self.filterTypeSelected = self.filterTypeOverride
        self.sortingTypeSelected = .topWeek
        
        self.headerActivityIndicator.hidesWhenStopped = true
        
        self.statusActivityIndicator.hidesWhenStopped = true
        
        self.tableViewHeader.delegate = self
        self.tableViewHeader.setupViews()
        
        self.clipQueryActivityIndicator.hidesWhenStopped = true
        self.clipQueryMessage.isHidden = true
        
        if let podcast = self.searchPodcast {
            let isSubscribed = PVSubscriber.checkIfSubscribed(podcastId: podcast.id)
            self.loadSubscribeButton(isSubscribed)
        }
        
        loadPodcastData()
        
        if self.filterTypeSelected == .clips {
            retrieveClips()
        } else if self.filterTypeSelected == .episodes {
            retrieveEpisodes()
        }
        
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.webView.scrollView.contentInset = UIEdgeInsets.zero
    }
    
    @IBAction func subscribeTapped(_ sender: Any) {
        if let id = self.podcastId {
            let isSubscribed = PVSubscriber.checkIfSubscribed(podcastId: id)
            
            if isSubscribed {
                PVSubscriber.unsubscribeFromPodcast(podcastId: id, feedUrl: nil)
            } else {
                DispatchQueue.global().async {
                    SearchPodcast.authorityFeedUrlForPodcast(id: id) { feedUrl in
                        if let feedUrl = feedUrl {
                            PVSubscriber.subscribeToPodcast(podcastId: id, feedUrl: feedUrl)
                        }
                    }
                }
            }
            
            loadSubscribeButton(!isSubscribed)
        }
    }
    
    func loadPodcastData() {
        if let podcast = self.searchPodcast {
            self.podcastId = podcast.id
        }
        
        if let id = self.podcastId {
            showPodcastHeaderActivity()
            showActivityIndicator()
            
            SearchPodcast.retrievePodcastFromServer(id: id, completion:{ podcast in
                self.loadPodcastHeader(podcast)
                self.loadAbout(podcast)
                
                if let podcast = podcast {
                    let isSubscribed = PVSubscriber.checkIfSubscribed(podcastId: podcast.id)
                    self.loadSubscribeButton(isSubscribed)
                }
            })
        }
    }
    
    func loadSubscribeButton(_ isSubscribed:Bool) {
        if isSubscribed {
            self.headerSubscribe.setTitle("Unsubscribe", for: .normal)
        } else {
            self.headerSubscribe.setTitle("Subscribe", for: .normal)
        }
    }
    
    func showPodcastHeaderActivity() {
        self.headerImageView.isHidden = true
        self.headerPodcastTitle.isHidden = true
        self.headerSubscribe.isHidden = true
        self.headerActivityIndicator.startAnimating()
    }
    
    func hidePodcastHeaderActivity() {
        self.headerImageView.isHidden = false
        self.headerPodcastTitle.isHidden = false
        self.headerSubscribe.isHidden = false
        self.headerActivityIndicator.stopAnimating()
    }
    
    func loadPodcastHeader(_ podcast: SearchPodcast?) {
        
        DispatchQueue.main.async {
            if let podcast = podcast {
                self.headerPodcastTitle.text = podcast.title
                
                self.headerImageView.image = Podcast.retrievePodcastImage(podcastImageURLString: podcast.imageUrl, feedURLString: nil, completion: { image in
                    self.headerImageView.image = image
                })
                
            } else {
                print("error: show not found message")
            }
            
            self.hidePodcastHeaderActivity()
        }

    }
    
    
    func loadAbout(_ podcast: SearchPodcast?) {
        
        DispatchQueue.main.async {
            if let podcast = podcast {
                
                self.webView.delegate = self
                
                var htmlString = ""
                
                if let title = podcast.title {
                    htmlString += "<strong>" + title + "</strong>"
                    htmlString += "<br><br>"
                }
                
                if let categories = podcast.categories {
                    htmlString += "<i>" + categories + "</i>"
                    htmlString += "<br><br>"
                }
                
//                if let hosts = podcast.hosts {
//                    htmlString += "Hosts: " + hosts
//                    htmlString += "<br><br>"
//                }
//
//                if let network = podcast.network {
//                    htmlString += "Network: " + network
//                    htmlString += "<br><br>"
//                }
                
                if let description = podcast.description {
                    
                    if description.trimmingCharacters(in: .whitespacesAndNewlines).count == 0 {
                        htmlString += kNoPodcastAboutMessage
                    } else {
                        htmlString += description
                    }
                    
                    htmlString += "<br><br>"
                    
                }
                
                htmlString += "<br><br>" // add extra line breaks so NowPlayingBar doesn't cover the about text
                
                self.webView.loadHTMLString(htmlString.formatHtmlString(isWhiteBg: true), baseURL: nil)
                
                if self.filterTypeSelected == .about {
                    self.showAbout()
                }
                
            }
        }
        
    }

    func showAbout() {
        DispatchQueue.main.async {
            self.hideNoDataView()
            self.webView.isHidden = false
            self.tableView.isHidden = true
            self.statusView.isHidden = true
        }
    }

    func resetClipQuery() {
        self.clipsArray.removeAll()
        self.clipQueryPage = 0
        self.clipQueryIsLoading = true
        self.clipQueryEndOfResultsReached = false
        self.clipQueryMessage.isHidden = true
        self.tableView.reloadData()
    }
    
    @objc func retrieveClips() {
        
        guard checkForConnectivity() else {
            loadNoInternetMessage()
            return
        }
        
        self.searchEpisodesArray.removeAll()
        self.tableView.reloadData()
        
        self.hideNoDataView()
        
        if self.clipQueryPage == 0 {
            showActivityIndicator()
        }
        
        self.clipQueryPage += 1
        
        if let id = self.podcastId {
            MediaRef.retrieveMediaRefsFromServer(podcastIds: [id], sortingTypeRequestParam: self.sortingTypeSelected.requestParam, page: self.clipQueryPage) { (mediaRefs) -> Void in
                self.reloadClipData(mediaRefs)
            }
        }
        
    }
    
    func retrieveEpisodes() {
        
        guard checkForConnectivity() else {
            loadNoInternetMessage()
            return
        }
        
        self.clipsArray.removeAll()
        self.searchEpisodesArray.removeAll()
        self.tableView.reloadData()
        
        self.hideNoDataView()
        
        if let id = self.podcastId {
            showActivityIndicator()
            
            SearchPodcast.retrievePodcastFromServer(id: id) { (searchPodcast) -> Void in
                let episodes = searchPodcast?.searchEpisodes
                
                let sortedEpisodes = episodes?.sorted(by: { (prevEp, nextEp) -> Bool in
                    if let prevTimeInterval = prevEp.pubDate, let nextTimeInterval = nextEp.pubDate {
                        return (prevTimeInterval > nextTimeInterval)
                    }
                    
                    return false
                })
                
                self.reloadSearchEpisodeData(sortedEpisodes)
            }
        }
        
    }
    
    func reloadClipData(_ mediaRefs: [MediaRef]? = nil) {
        
        hideActivityIndicator()
        self.clipQueryIsLoading = false
        self.clipQueryActivityIndicator.stopAnimating()
        
        guard checkForResults(results: mediaRefs) || checkForResults(results: self.clipsArray), let mediaRefs = mediaRefs else {
            loadNoClipsMessage()
            return
        }
        
        guard checkForResults(results: mediaRefs) else {
            self.clipQueryEndOfResultsReached = true
            self.clipQueryMessage.isHidden = false
            return
        }
        
        for mediaRef in mediaRefs {
            self.clipsArray.append(mediaRef)
        }
        
        self.tableView.isHidden = false
        self.tableView.reloadData()
        
    }
    
    func reloadSearchEpisodeData(_ episodes: [SearchEpisode]? = nil) {
        
        hideActivityIndicator()
        self.clipQueryIsLoading = false
        self.clipQueryActivityIndicator.stopAnimating()
        
        guard checkForResults(results: episodes) || checkForResults(results: self.searchEpisodesArray), let episodes = episodes else {
            loadNoClipsMessage()
            return
        }
        
        for episode in episodes {
            self.searchEpisodesArray.append(episode)
        }
        
        self.tableView.isHidden = false
        self.tableView.reloadData()
        
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
        
        self.tableView.isHidden = true
        
        showNoDataView()
        
    }
    
    func loadNoInternetMessage() {
        loadNoDataView(message: Strings.Errors.noClipsInternet, buttonTitle: "Retry", buttonPressed: #selector(SearchPodcastViewController.retrieveClips))
    }
    
    func loadNoClipsMessage() {
        loadNoDataView(message: Strings.Errors.noPodcastClipsAvailable, buttonTitle: nil, buttonPressed: nil)
    }
    
    func loadNoEpisodesMessage() {
        loadNoDataView(message: Strings.Errors.noPodcastEpisodesAvailable, buttonTitle: nil, buttonPressed: nil)
    }
    
    func showActivityIndicator() {
        self.tableView.isHidden = true
        self.statusActivityIndicator.startAnimating()
        self.statusView.isHidden = false
    }
    
    func hideActivityIndicator() {
        self.statusActivityIndicator.stopAnimating()
        self.statusView.isHidden = true
    }
    
    override func goToNowPlaying () {
        if let mediaPlayerVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MediaPlayerVC") as? MediaPlayerViewController {
            pvMediaPlayer.shouldAutoplayOnce = true
            self.navigationController?.pushViewController(mediaPlayerVC, animated: true)
        }
    }
    
}

extension SearchPodcastViewController:UIWebViewDelegate {
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        if navigationType == UIWebViewNavigationType.linkClicked {
            if let url = request.url {
                UIApplication.shared.open(url)
            }
            return false
        }
        return true
    }
}

extension SearchPodcastViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.filterTypeSelected == .episodes {
            return self.searchEpisodesArray.count
        } else {
            return self.clipsArray.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if self.filterTypeSelected == .episodes {
            
            let cell = self.tableView.dequeueReusableCell(withIdentifier: "episodeCell", for: indexPath as IndexPath) as! EpisodeTableViewCell
            
            let episode = self.searchEpisodesArray[indexPath.row]
            
            cell.title.text = episode.title
            
            if let summary = episode.summary {

                let trimmed = summary.replacingOccurrences(of: "\\n*", with: "", options: .regularExpression)

                cell.summary?.text = trimmed.removeHTMLFromString()?.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                cell.summary?.text = "No show notes available"
            }
            
            if let duration = episode.duration {
                cell.duration?.text = String(describing: duration)
            } else {
                cell.duration?.text = nil
            }

            cell.pubDate.text = episode.pubDate?.toServerDate()?.toShortFormatString()
            
            return cell
            
        } else {
            
            let cell = self.tableView.dequeueReusableCell(withIdentifier: "clipCell", for: indexPath as IndexPath) as! ClipPodcastTableViewCell
            
            let clip = clipsArray[indexPath.row]
            
            cell.clipTitle.text = clip.readableClipTitle()
            cell.episodeTitle.text = clip.episodeTitle
            cell.episodePubDate.text = clip.episodePubDate?.toShortFormatString()
            cell.time.text = clip.readableStartAndEndTime()
            
            return cell
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let searchPodcast = self.searchPodcast {
            if self.filterTypeSelected == .episodes {
                let searchEpisode = searchEpisodesArray[indexPath.row]
                let playerHistoryItem = self.playerHistoryManager.convertSearchPodcastEpisodeToPlayerHistoryItem(searchPodcast: searchPodcast, searchEpisode: searchEpisode)
                self.goToNowPlaying()
                self.pvMediaPlayer.loadPlayerHistoryItem(item: playerHistoryItem)
            } else {
                let clip = clipsArray[indexPath.row]
                let playerHistoryItem = self.playerHistoryManager.convertMediaRefToPlayerHistoryItem(mediaRef: clip)
                self.goToNowPlaying()
                self.pvMediaPlayer.loadPlayerHistoryItem(item: playerHistoryItem)
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Bottom Refresh
        if scrollView == self.tableView && self.filterTypeSelected == .clips {
            if ((scrollView.contentOffset.y + scrollView.frame.size.height) >= scrollView.contentSize.height) && !self.clipQueryIsLoading && !self.clipQueryEndOfResultsReached {
                self.clipQueryIsLoading = true
                self.clipQueryActivityIndicator.startAnimating()
                self.retrieveClips()
            }
        }
    }
    
}

extension SearchPodcastViewController:FilterSelectionProtocol {
    func filterButtonTapped() {
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: SearchPodcastFilter.episodes.text, style: .default, handler: { action in
            self.filterTypeSelected = .episodes
            self.retrieveEpisodes()
        }))
        
        alert.addAction(UIAlertAction(title: SearchPodcastFilter.clips.text, style: .default, handler: { action in
            self.filterTypeSelected = .clips
            self.retrieveClips()
        }))
        
        alert.addAction(UIAlertAction(title: SearchPodcastFilter.about.text, style: .default, handler: { action in
            self.filterTypeSelected = .about
            self.showAbout()
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
