//
//  Card.swift
//  CardTable
//
//  Created by Jacky Tjoa on 13/11/15.
//  Copyright © 2015 Coolheart. All rights reserved.
//

import UIKit

class Card: NSObject {

    var id:Int = -1
    var name:String = ""
    var image:UIImage! = nil
    
    init(id:Int, name:String, image:UIImage) {
        self.id = id
        self.name = name
        self.image = image
    }
    
    func clearData() {
        //self.image = nil
    }
}
