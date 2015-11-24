//
//  Phone.swift
//  CardTable
//
//  Created by Jacky Tjoa on 16/11/15.
//  Copyright © 2015 Coolheart. All rights reserved.
//

import UIKit

class Phone: NSObject {

    var name:String = "Not Connected"
    var imageView:UIImageView! = nil
    var isConnected:Bool = false
    var cardArray:[CardImageView] = []//holder for 'out' Cards
    
    init(imageView:UIImageView) {
        self.imageView = imageView
    }
}
