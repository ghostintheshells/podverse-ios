//
//  Int+MediaPlayerString.swift
//  Podverse
//
//  Created by Mitchell Downey on 5/29/17.
//  Copyright © 2017 Podverse LLC. All rights reserved.
//

extension Int {
    func toMediaPlayerString() -> String {
        let hours = self / 3600
        let minutes = self / 60 % 60
        let seconds = self % 60
        
        var timeString = String(format:"%02i:%02i:%02i", hours, minutes, seconds)
        
        if hours < 10 {
            timeString = String(format:"%01i:%02i:%02i", hours, minutes, seconds)
        }
        
        if hours == 0 {
            if minutes > 9 {
                timeString = String(format:"%02i:%02i", minutes, seconds)
            } else {
                timeString = String(format:"%01i:%02i", minutes, seconds)
            }
        }
        
        return timeString
    }
}
