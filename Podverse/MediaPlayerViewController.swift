//
//  MediaPlayerViewController.swift
//  Podverse
//
//  Created by Mitchell Downey on 5/17/17.
//  Copyright © 2017 Podverse LLC. All rights reserved.
//

import UIKit
import CoreData
import MediaPlayer

class MediaPlayerViewController: PVViewController {
    
    let playbackController = PlaybackController.sharedController
    var playerSpeedRate:PlayingSpeed = .regular
    var shouldAutoplay = false
//    var timeOffset = Int64(0)
//    var moveToOffset = false
//    
    
    weak var currentChildViewController: UIViewController?
    private let aboutClipsStoryboardId = "AboutPlayingItemVC"
    private let clipsListStoryBoardId = "ClipsListVC"
    
    @IBOutlet weak var clipsContainerView: UIView!
    @IBOutlet weak var currentTime: UILabel!
    @IBOutlet weak var device: UIButton!
    @IBOutlet weak var duration: UILabel!
    @IBOutlet weak var episodeTitle: UILabel!
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var play: UIButton!
    @IBOutlet weak var podcastTitle: UILabel!
    @IBOutlet weak var progress: UISlider!
    @IBOutlet weak var speed: UIButton!
    
    override func viewDidLoad() {
        setupContainerView()
        
//        pvMediaPlayer.delegate = self

        let share = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.action, target: self, action: #selector(showShareMenu))
        let makeClip = UIBarButtonItem(title: "Make Clip", style: .plain, target: self, action: #selector(showMakeClip))
        let addToPlaylist = UIBarButtonItem(title: "Add to Playlist", style: .plain, target: self, action: #selector(showAddToPlaylist))
        navigationItem.rightBarButtonItems = [share, makeClip, addToPlaylist]

        self.progress.isContinuous = false
        
        let source = TestSource()
        playbackController.prepare(source)
        
        let center = NotificationCenter.default
        
        

        
//        setPlayerInfo()
        
        // TODO: does this need an unowned self or something?
//        self.pvMediaPlayer.avPlayer.addPeriodicTimeObserver(forInterval: CMTimeMake(1, 1), queue: DispatchQueue.main) {[weak self] time in
//            self?.updateCurrentTime(currentTime: CMTimeGetSeconds(time))
//        }
        
        self.tabBarController?.hidePlayerView()
        
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
//        if (shouldAutoplay) {
//            self.pvMediaPlayer.avPlayer.rate = 0
//            self.pvMediaPlayer.playOrPause()
//        }
//        
//        if moveToOffset == true && timeOffset > 0 {
//            self.pvMediaPlayer.goToTime(seconds: Double(timeOffset))
//            moveToOffset = false
//            setPlayerInfo()
//        }
//        
//        setPlayIcon()
    }
    
    override func viewWillAppear(_ animated: Bool) { /* Intentionally left blank so super won't get called */ }
    
    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
    
    @IBAction func pageControlAction(_ sender: Any) {
        if let sender = sender as? UIPageControl {
            if sender.currentPage == 1 {
                showClipsContainerView()
            } else {
                showAboutView()
            }
        }
    }
    
    @IBAction func sliderAction(_ sender: UISlider) {
        if let totalTime = playbackController.duration {
            let newTime = Double(sender.value) * totalTime
            playbackController.seekToTime(newTime)
        }
    }

    @IBAction func play(_ sender: Any) {
        pvMediaPlayer.playOrPause()
//        setPlayIcon()
    }

    @IBAction func timeJumpBackward(_ sender: Any) {
        let elapsedTime = playbackController.elapsedTime
        playbackController.seekToTime(elapsedTime - 15)
//      updateCurrentTime(currentTime: elapsedTime)
    }
    
    @IBAction func timeJumpForward(_ sender: Any) {
        let elapsedTime = playbackController.elapsedTime
        playbackController.seekToTime(elapsedTime + 15)
//      updateCurrentTime(currentTime: elapsedTime)
    }
    
    @IBAction func changeSpeed(_ sender: Any) {
        switch playerSpeedRate {
        case .regular:
            playerSpeedRate = .timeAndQuarter
            break
        case .timeAndQuarter:
            playerSpeedRate = .timeAndHalf
            break
        case .timeAndHalf:
            playerSpeedRate = .double
            break
        case .double:
            playerSpeedRate = .doubleAndHalf
            break
        case .doubleAndHalf:
            playerSpeedRate = .quarter
            break
        case .quarter:
            playerSpeedRate = .half
            break
        case .half:
            playerSpeedRate = .threeQuarts
            break
        case .threeQuarts:
            playerSpeedRate = .regular
            break
        }
        
//        pvMediaPlayer.avPlayer.rate = playerSpeedRate.speedVaue
        updateSpeedLabel()
    }
    
    fileprivate func setupContainerView() {
        if let currentVC = self.storyboard?.instantiateViewController(withIdentifier: self.aboutClipsStoryboardId) {
            self.currentChildViewController = currentVC
            self.currentChildViewController?.view.translatesAutoresizingMaskIntoConstraints = false
            self.addChildViewController(currentVC)
            self.addSubview(subView: currentVC.view, toView: self.clipsContainerView)
        }
        
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(MediaPlayerViewController.showClipsContainerView))
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(MediaPlayerViewController.showAboutView))
        swipeLeft.direction = .left
        swipeRight.direction = .right
        self.clipsContainerView.addGestureRecognizer(swipeLeft)
        self.clipsContainerView.addGestureRecognizer(swipeRight)
        
        self.clipsContainerView.layer.borderColor = UIColor.lightGray.cgColor
        self.clipsContainerView.layer.borderWidth = 1.0
        
        self.pageControl.currentPage = 0
    }
    
    func setPlayIcon() {
//        if pvMediaPlayer.avPlayer.rate == 0 {
//            play.setImage(UIImage(named:"Play"), for: .normal)
//        } else {
//            play.setImage(UIImage(named:"Pause"), for: .normal)
//        }
    }
    
    func setPlayerInfo() {
//        if let item = pvMediaPlayer.currentlyPlayingItem {
//            podcastTitle.text = item.podcastTitle
//            episodeTitle.text = item.episodeTitle
//            
//            self.image.image = Podcast.retrievePodcastImage(podcastImageURLString: item.podcastImageUrl, feedURLString: item.podcastFeedUrl) { (podcastImage) -> Void in
//                self.image.image = podcastImage
//            }
//            
//            let lastPlaybackPosition = item.lastPlaybackPosition ?? 0
//            currentTime.text = Int64(lastPlaybackPosition).toMediaPlayerString()
//            if let currentItem = pvMediaPlayer.avPlayer.currentItem {
//                let totalTime = Int64(CMTimeGetSeconds(currentItem.asset.duration))
//                duration.text = Int64(totalTime).toMediaPlayerString()
//                progress.value = Float(Int64(lastPlaybackPosition) / totalTime)
//            }
//        }
    }

    
    func updateCurrentTime(currentTime: Double) {
//        self.currentTime.text = Int64(currentTime).toMediaPlayerString()
//        if let currentItem = pvMediaPlayer.avPlayer.currentItem {
//            let totalTime = CMTimeGetSeconds(currentItem.duration)
//            progress.value = Float(currentTime / totalTime)
//        } else {
//            DispatchQueue.main.async {
//                self.navigationController?.popViewController(animated: true)
//            }
//        }
    }
    
    func updateSpeedLabel() {
        speed.setTitle(playerSpeedRate.speedText, for: .normal)
    }
    
    func showShareMenu() {
        return
    }
    
    func showMakeClip() {
        return
    }
    
    func showAddToPlaylist() {
        return
    }
    
    func showAboutView() {
        if let newViewController = self.storyboard?.instantiateViewController(withIdentifier: self.aboutClipsStoryboardId), self.currentChildViewController is ClipsListContainerViewController {
            newViewController.view.translatesAutoresizingMaskIntoConstraints = false
            self.cycleFromViewController(oldViewController: self.currentChildViewController!, toViewController: newViewController)
            self.currentChildViewController = newViewController
            pageControl.currentPage = 0
        }
    }
    
    func showClipsContainerView() {
        if let newViewController = self.storyboard?.instantiateViewController(withIdentifier: self.clipsListStoryBoardId) as? ClipsListContainerViewController, self.currentChildViewController is AboutPlayingItemViewController {
            newViewController.view.translatesAutoresizingMaskIntoConstraints = false
            self.cycleFromViewController(oldViewController: self.currentChildViewController!, toViewController: newViewController)
            self.currentChildViewController = newViewController
            newViewController.delegate = self
            pageControl.currentPage = 1
        }    
    }
    
    private func addSubview(subView:UIView, toView parentView:UIView) {
        parentView.addSubview(subView)
        
        var viewBindingsDict = [String: AnyObject]()
        viewBindingsDict["subView"] = subView
        parentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[subView]|",
                                                                                 options: [], metrics: nil, views: viewBindingsDict))
        parentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[subView]|",
                                                                                 options: [], metrics: nil, views: viewBindingsDict))
    }
    
    private func cycleFromViewController(oldViewController: UIViewController, toViewController newViewController: UIViewController) {
        oldViewController.willMove(toParentViewController: nil)
        self.addChildViewController(newViewController)
        self.addSubview(subView: newViewController.view, toView:self.clipsContainerView)
        
        let initialX = newViewController is ClipsListContainerViewController ? self.clipsContainerView.frame.maxX : -self.clipsContainerView.frame.maxX
        newViewController.view.frame = CGRect(x: initialX, 
                                              y: 0.0, 
                                              width: newViewController.view.frame.width, 
                                              height: newViewController.view.frame.height)
        
        UIView.animate(withDuration: 0.5, animations: {
            if newViewController is ClipsListContainerViewController {
                oldViewController.view.frame = CGRect(x: -oldViewController.view.frame.width, 
                                                      y: 0.0, 
                                                      width: oldViewController.view.frame.width, 
                                                      height: oldViewController.view.frame.height)
            }
            else {
                oldViewController.view.frame = CGRect(x: oldViewController.view.frame.width, 
                                                      y: 0.0, 
                                                      width: oldViewController.view.frame.width, 
                                                      height: oldViewController.view.frame.height)
            }
            newViewController.view.frame = CGRect(x: 0.0, 
                                                  y: 0.0, 
                                                  width: newViewController.view.frame.width, 
                                                  height: newViewController.view.frame.height)
        },
           completion: { finished in
            oldViewController.view.removeFromSuperview()
            oldViewController.removeFromParentViewController()
            newViewController.didMove(toParentViewController: self)
        })
    }
}

extension MediaPlayerViewController:ClipsListDelegate {
    func didSelectClip(clip: MediaRef) {
        //Change the player data and info to the passed in clip
    }
}

//extension MediaPlayerViewController:PVMediaPlayerDelegate {
//    func didFinishPlaying() {
//        DispatchQueue.main.async {
//            self.navigationController?.popViewController(animated: true)
//        }
//    }
//}
