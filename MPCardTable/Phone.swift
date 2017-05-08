//
//  Phone.swift
//  CardTable
//
//  Created by Jacky Tjoa on 16/11/15.
//  Copyright © 2015 Coolheart. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class Phone: NSObject {
    
    var peerID:MCPeerID? = nil
    var nameLbl:UILabel? = nil
    var imageView:UIImageView? = nil
    var isConnected:Bool = false
    var cardArray:[CardImageView] = []//holder for 'out' Cards
    
    init(imageView:UIImageView) {
        self.imageView = imageView
    }
}
