//
//  ViewController.swift
//  MPCardTable
//
//  Created by Jacky Tjoa on 17/11/15.
//  Copyright © 2015 Coolheart. All rights reserved.
//

import UIKit
import MultipeerConnectivity

extension Collection {
    /// Return a copy of `self` with its elements shuffled
    func shuffle() -> [Iterator.Element] {
        var list = Array(self)
        list.shuffleInPlace()
        return list
    }
}

extension MutableCollection where Index == Int {
    /// Shuffle the elements of `self` in-place.
    mutating func shuffleInPlace() {
        // empty and single-element collections don't shuffle
        if count < 2 { return }
        
        for i in startIndex ..< endIndex - 1 {
            let j = Int(arc4random_uniform(UInt32(endIndex - i))) + i
            if i != j {
                swap(&self[i], &self[j])
            }
        }
    }
}

// Swift 2 Array Extension
extension Array where Element: Equatable {
    
    mutating func removeObject(_ object: Element) {
        if let index = self.index(of: object) {
            self.remove(at: index)
        }
    }
    
    mutating func removeObjectsInArray(_ array: [Element]) {
        for object in array {
            self.removeObject(object)
        }
    }
}

enum CardStackStatus {
    
    case stacked
    case fanout
    case distributed
}

class ViewController: UIViewController, MCAdvertiserAssistantDelegate, MCBrowserViewControllerDelegate, MCSessionDelegate {
    
    //UI
    var cardDataArray:[Card] = [] // card database
    var cardDisplayArray:[CardImageView] = [] // card array (as displayed)
    var cardOriginalPositionArray:[CGPoint] = [] // card original position array
    var connectedPhoneArray:[Phone] = [] //connected phones array
    var startPoint:CGPoint = CGPoint.zero
    let maxConnections = 4
    var cardBackImage:UIImage! = nil
    var numCardsLbl:UILabel! = nil
    var cardNameLbl:UILabel! = nil
    var statusLbl:UILabel! = nil
    let kStatusTextNotAdvertising = "Status: Not Advertising"
    let kStatusTextAdvertising = "Status: Advertising..."
    let kNumCardsText = "Num of Cards"
    let kNotConnectedText = "Not Connected"
    var CARD_STACK_STATUS:CardStackStatus = .distributed
    
    //Multipeer Connectivity
    let kServiceType = "multi-peer-chat"
    var peerID:MCPeerID!
    var session:MCSession!
    var browser:MCBrowserViewController!
    var advertiser:MCAdvertiserAssistant!
    fileprivate var isAdvertising:Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //Connected phones
        let phoneOffset = self.view.frame.width * 0.2
        let phone_y:CGFloat = 120.0
        
        for i in 0 ..< maxConnections {
            
            let phoneImg = UIImage(named: "iphone6")
            let phoneImgView = UIImageView(image: phoneImg)
            phoneImgView.transform = phoneImgView.transform.scaledBy(x: 0.6, y: 0.6)//scale down
            phoneImgView.alpha = 0.5
            phoneImgView.center = CGPoint(x: CGFloat(i + 1) * phoneOffset, y: phone_y)
            self.view.addSubview(phoneImgView)
            
            //add to Phone array
            let phone = Phone(imageView: phoneImgView)
            self.connectedPhoneArray.append(phone)
            
            //phone label
            let lblFrame = CGRect(x: 0, y: 0, width: phoneImgView.frame.width + 50, height: 20)
            let phoneLbl = UILabel(frame: lblFrame)
            phoneLbl.center =  CGPoint(x: phoneImgView.center.x, y: phoneImgView.center.y + 110)
            phoneLbl.font = UIFont(name: phoneLbl.font.fontName, size: 17)
            phoneLbl.textColor = UIColor.white
            phoneLbl.textAlignment = .center
            phoneLbl.text = kNotConnectedText
            phone.nameLbl = phoneLbl
            
            self.view.addSubview(phoneLbl)
        }
        
        //Card back image
        self.cardBackImage = UIImage(named: "card_back")
        
        //Status label
        let statLbl = UILabel(frame: CGRect(x: 40, y: 290, width: 200, height: 60))
        statLbl.text = kStatusTextNotAdvertising
        statLbl.textColor = UIColor.white
        statLbl.textAlignment = .left
        statLbl.font = UIFont(name: statLbl.font.fontName, size: 17)
        self.statusLbl = statLbl
        self.view.addSubview(self.statusLbl)
        
        //Name label
        let cardLbl = UILabel(frame: CGRect(x: 0, y: 290, width: 200, height: 60))
        cardLbl.center = CGPoint(x: self.view.frame.size.width * 0.5, y: cardLbl.center.y)
        cardLbl.text = "No Card Selected"
        cardLbl.textColor = UIColor.white
        cardLbl.textAlignment = .center
        cardLbl.font = UIFont(name: cardLbl.font.fontName, size: 17)
        self.cardNameLbl = cardLbl
        self.view.addSubview(self.cardNameLbl)
        
        //Num Cards label
        let lblWidth:CGFloat = 200
        let numLbl = UILabel(frame: CGRect(x: self.view.frame.size.width - (lblWidth + 40), y: 290, width: lblWidth, height: 60))
        numLbl.text = ""
        numLbl.textColor = UIColor.white
        numLbl.textAlignment = .right
        numLbl.font = UIFont(name: numLbl.font.fontName, size: 17)
        self.numCardsLbl = numLbl
        self.view.addSubview(self.numCardsLbl)
        
        //Load cards
        let cardTypes = ["spade", "club", "diamond", "heart"]
        
        var id:Int = 0
        for type in cardTypes {
            
            for i in 2...14 {
                
                var name = "\(i)"
                
                if i == 11 {
                    name = "Jack"
                }
                else if i == 12 {
                    name = "Queen"
                }
                else if i == 13 {
                    name = "King"
                }
                else if i == 14 {
                    name = "Ace"
                }
                
                let cardName = "\(name) of \(type.capitalized) "
                
                let imageName = String(format: "\(type)_%02d", i)
                let image = UIImage(named: imageName)!
                
                let card = Card(id: id, name: cardName, image: image)
                self.cardDataArray.append(card)
                
                id += 1
            }
        }
        
        //record number of Cards
        self.numCardsLbl.text = "\(kNumCardsText): \(self.cardDataArray.count)"
        
        //Layout cards / positioning
        let anchor = CGPoint(x: 40.0, y: 350.0)
        let offset:CGFloat = 10.0
        var index:CGFloat = 0.0
        var x:CGFloat = 0.0
        var y:CGFloat = 0.0 + anchor.y
        
        for card:Card in self.cardDataArray {
            
            //view
            let cardImgView = CardImageView(image: card.image)
            cardImgView.transform = cardImgView.transform.scaledBy(x: 0.7, y: 0.7)//scale down
            cardImgView.isUserInteractionEnabled = true//enable this for gesture !
            cardImgView.card = card
            cardImgView.tag = card.id
            cardImgView.position = card.id
            
            //tap gesture (single tap)
            let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleSingleTap(_:)))
            singleTapGesture.numberOfTapsRequired = 1
            singleTapGesture.numberOfTouchesRequired = 1
            cardImgView.addGestureRecognizer(singleTapGesture)
            
            //tap gesture (double tap)
            let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleDoubleTap(_:)))
            doubleTapGesture.numberOfTapsRequired = 2
            doubleTapGesture.numberOfTouchesRequired = 1
            cardImgView.addGestureRecognizer(doubleTapGesture)
            
            //pan gesture
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(ViewController.handlePan(_:)))
            panGesture.minimumNumberOfTouches = 1
            panGesture.maximumNumberOfTouches = 1
            cardImgView.addGestureRecognizer(panGesture)//add to view
            
            //positioning
            if (index + 1).truncatingRemainder(dividingBy: 14) == 0 {
                
                index = 0.0
                y += (cardImgView.frame.size.height + offset)
            }
            
            x = anchor.x + index * (cardImgView.frame.size.width + offset)
            cardImgView.frame.origin = CGPoint(x: x, y: y)
            
            //arrays
            self.cardDisplayArray.append(cardImgView)//add to array
            self.cardOriginalPositionArray.append(cardImgView.center)//card position
            self.view.addSubview(cardImgView)//add to view
            
            index += 1
        }
        
        //Tap gesture on self.view
        let singleTapGestureOnView = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleTapOnView(_:)))
        singleTapGestureOnView.numberOfTapsRequired = 1
        singleTapGestureOnView.numberOfTouchesRequired = 1
        self.view.addGestureRecognizer(singleTapGestureOnView)
        
        //Two finger swipe on self.view
        
        //(Left)
        let twoFingerSwipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(ViewController.handleTwoFingerSwipe(_:)))
        twoFingerSwipeLeft.numberOfTouchesRequired = 2
        twoFingerSwipeLeft.direction = .left
        self.view.addGestureRecognizer(twoFingerSwipeLeft)
        
        //(Right)
        let twoFingerSwipeRight = UISwipeGestureRecognizer(target: self, action: #selector(ViewController.handleTwoFingerSwipe(_:)))
        twoFingerSwipeRight.numberOfTouchesRequired = 2
        twoFingerSwipeRight.direction = .right
        self.view.addGestureRecognizer(twoFingerSwipeRight)
        
        //Three finger swipe on self.view
        
        //(Left)
        let threeFingerSwipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(ViewController.handleThreeFingerSwipe(_:)))
        threeFingerSwipeLeft.numberOfTouchesRequired = 3
        threeFingerSwipeLeft.direction = .left
        self.view.addGestureRecognizer(threeFingerSwipeLeft)
        
        //(Right)
        let threeFingerSwipeRight = UISwipeGestureRecognizer(target: self, action: #selector(ViewController.handleThreeFingerSwipe(_:)))
        threeFingerSwipeRight.numberOfTouchesRequired = 3
        threeFingerSwipeRight.direction = .right
        self.view.addGestureRecognizer(threeFingerSwipeRight)
        
        //Multipeer Connectivity
        
        //session
        self.peerID = MCPeerID(displayName: UIDevice.current.name)
        self.session = MCSession(peer: self.peerID, securityIdentity: nil, encryptionPreference: .required)
        self.session.delegate = self
        self.advertiser = MCAdvertiserAssistant(serviceType: kServiceType, discoveryInfo: nil, session: self.session)
        self.browser = MCBrowserViewController(serviceType: kServiceType, session: self.session)
        self.browser.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: - IBActions
    
    @IBAction func startAdvertising(_ sender: AnyObject) {
        
        let btn = sender as! UIButton
        
        if !self.isAdvertising {
            
            btn.setTitle("Stop Advertising", for: UIControlState())
            self.statusLbl.text = kStatusTextAdvertising
            self.advertiser.start()
            
        } else {
            
            btn.setTitle("Start Advertising", for: UIControlState())
            self.statusLbl.text = kStatusTextNotAdvertising
            self.advertiser.stop()
        }
        
        self.isAdvertising = !self.isAdvertising //toggle
    }
    
    @IBAction func flip(_ sender: AnyObject) {
        
        UIView.animate(withDuration: 0.5, animations: { () -> Void in
            
            for cardImgView in self.cardDisplayArray {
                
                //get card data
                let card = self.cardDataArray[cardImgView.tag]
                
                //animate flip
                let animationOptions:UIViewAnimationOptions = .transitionFlipFromLeft
                
                if cardImgView.isFront {
                    cardImgView.image = self.cardBackImage //shows card back
                } else {
                    cardImgView.image = card.image
                }
                
                UIView.transition(with: cardImgView, duration: 0.5, options: animationOptions, animations: { () -> Void in
                    },
                    completion: nil)
                
                cardImgView.isFront = !cardImgView.isFront //toggle front/back
            }
            
            }, completion: { (success) -> Void in
                
        }) 
    }
    
    @IBAction func shuffle(_ sender: AnyObject) {
        
        //do the magic !
        self.cardDisplayArray.shuffleInPlace()
        
        //try this later....
        //let firstCardView = self.cardViewArray[0]
        //let diff_x:CGFloat = 72.475
        //let diff_y:CGFloat = 97.5
        
        self.CARD_STACK_STATUS = .distributed
        
        UIView.animate(withDuration: 0.5, animations: { () -> Void in
            
            for i in 0..<self.cardDisplayArray.count {
                
                //x = (pos)%13 * diff_x + x
                //y = (pos)/13 * diff_y + y
                
                //cardView.center = CGPointMake(CGFloat(pos)%13 * diff_x + firstCardView.center.x, CGFloat(pos)/13 * diff_y +  firstCardView.center.y)
                
                let cardImgView = self.cardDisplayArray[i]
                
                //move cards to the shuffled position
                let centerPos = self.cardOriginalPositionArray[i]
                cardImgView.center = centerPos
                cardImgView.position = i
            }
            
            }, completion: { (success) -> Void in
        }) 
    }
    
    //MARK: - Helpers
    
    func showCardName(_ cardImgView: CardImageView) {
        
        let card = self.cardDataArray[cardImgView.tag] //retrieve Card
        self.cardNameLbl.text = card.name
        
        print("cardpos: \(cardImgView.position)")
    }
    
    func displayCardCounter() {

        let inHouseCardArray = self.cardDisplayArray.filter() { $0.isOut == false }
        self.numCardsLbl.text = "\(self.kNumCardsText): \(inHouseCardArray.count)"
    }
    
    //MARK: - UIGestureRecognizers
    
    func handleSingleTap(_ recognizer:UITapGestureRecognizer) {
        
        //single tap
        
        if recognizer.view is CardImageView {
            
            let imgView = recognizer.view as! CardImageView
            self.showCardName(imgView)//display card name
        }
    }
    
    func handleDoubleTap(_ recognizer:UITapGestureRecognizer) {
        
        //double tap
        
        if recognizer.view! is CardImageView {
            
            let cardImgView = recognizer.view as! CardImageView
            
            //retrieve Card
            let card = self.cardDataArray[cardImgView.tag]
            
            //animate flip
            var animationOptions:UIViewAnimationOptions = .transitionFlipFromLeft
            
            if cardImgView.isFront {
                cardImgView.image = self.cardBackImage //shows card back
            } else {
                animationOptions = .transitionFlipFromRight
                cardImgView.image = card.image
            }
            
            UIView.transition(with: recognizer.view!, duration: 0.5, options: animationOptions, animations: { () -> Void in
                },
                completion: nil)
            
            cardImgView.isFront = !cardImgView.isFront //toggle front/back
        }
    }
    
    func handlePan(_ recognizer:UIPanGestureRecognizer) {
        
        /*
        var dictionaryExample : [String:AnyObject] = ["user":"UserName", "pass":"password", "token":"0123456789", "image":0] // image should be either NSData or empty
        let dataExample : NSData = NSKeyedArchiver.archivedDataWithRootObject(dictionaryExample)
        let dictionary:NSDictionary = NSKeyedUnarchiver.unarchiveObjectWithData(dataExample)! as NSDictionary
        */
        
        let cardImgView = recognizer.view as! CardImageView
        
        if recognizer.state == .cancelled {
            
            print("cancelled\n")
        }
        else if recognizer.state == .began {
            
            self.startPoint = recognizer.view!.center
            self.showCardName(cardImgView)//display card name
        }
        else if recognizer.state == .changed {
            
            let translation = recognizer.translation(in: self.view)
            recognizer.view!.center = CGPoint(x: recognizer.view!.center.x + translation.x, y: recognizer.view!.center.y + translation.y)
            recognizer.setTranslation(CGPoint.zero, in: self.view)
            
            for phone in self.connectedPhoneArray {
                
                if phone.isConnected {
                
                    let phoneImgView = phone.imageView
                    
                    if (phoneImgView?.frame.contains(recognizer.view!.center))! {
                        
                        phoneImgView?.layer.opacity = 0.5
                    
                    } else {
                    
                        phoneImgView?.layer.opacity = 1.0
                    }
                }
            }
        }
        else if recognizer.state == .ended {
            
            var isSendingData = false
            var phoneIndex:Int = 0
            for phone in self.connectedPhoneArray {
                
                if phone.isConnected {
                    
                    let phoneImgView = phone.imageView
                    
                    if (phoneImgView?.frame.contains(recognizer.view!.center))! {
                        
                        phoneImgView?.layer.opacity = 1.0
                        
                        //send data
                        if self.session.connectedPeers.count > 0 {
                            
                            let cardDict = ["id":cardImgView.tag, "isFront":cardImgView.isFront] as [String : Any]
                            let cardArchivedData = NSKeyedArchiver.archivedData(withRootObject: cardDict)
                            let peerID = self.session.connectedPeers[phoneIndex]
                            
                            do {
                                
                                isSendingData = true
                                
                                try self.session.send(cardArchivedData, toPeers: [peerID], with: .reliable)
                                
                                //add card to Phone's card array
                                phone.cardArray.append(cardImgView)
                                
                                //animate card flying out
                                UIView.animate(withDuration: 0.5, animations: { () -> Void in
                                    
                                    cardImgView.center = CGPoint(x: cardImgView.center.x, y: -50.0)
                                
                                }, completion: { (success) -> Void in
                                    
                                    self.cardNameLbl.text = "No Card Selected"
                                    cardImgView.isOut = true
                                    cardImgView.isHidden = true
                                    
                                    //display number of cards
                                    self.displayCardCounter()
                                })
                            }
                            catch {
                                print("send data failed: \(error)")
                            }
                        }
                        break
                    }
                }
                
                phoneIndex += 1
            }

            if !isSendingData {
                
                //if not sending data, return card
            
                UIView.animate(withDuration: 0.5, animations: { () -> Void in
                    
                    recognizer.view!.center = self.startPoint
                    
                    }, completion: { (success) -> Void in
                        
                })
            }
        }
    }
    
    func handleTapOnView(_ recognizer:UITapGestureRecognizer) {
        
        self.cardNameLbl.text = "No Card Selected"
    }
    
    func handleTwoFingerSwipe(_ recognizer:UISwipeGestureRecognizer) {
    
        //Card must be in 'Stacked' position !
        if self.CARD_STACK_STATUS == .stacked {
            
            if recognizer.direction == .right {
            
                //set card status
                self.CARD_STACK_STATUS = .fanout
                
                //animate position
                let offset:CGFloat = 15.0
                UIView.animate(withDuration: 0.5, animations: { () -> Void in
                    
                    for i in 1..<self.cardDisplayArray.count {
                        
                        let cardImgView = self.cardDisplayArray[i]
                        cardImgView.frame = cardImgView.frame.offsetBy(dx: offset * CGFloat(i), dy: 0.0)
                    }
                })
            }//end Right
        }
        else if self.CARD_STACK_STATUS == .fanout {
        
            if recognizer.direction == .left {

                //set card status
                self.CARD_STACK_STATUS = .stacked
                
                //animate position
                if self.cardDisplayArray.count > 0 {
                    
                    //get first card position
                    let firstCardImgView = self.cardDisplayArray[0]
                    
                    UIView.animate(withDuration: 0.5, animations: { () -> Void in
                        
                        for cardImgView in self.cardDisplayArray {
                            
                            cardImgView.center = firstCardImgView.center
                        }
                    })
                }
            }//end Left
        }
    }
    
    func handleThreeFingerSwipe(_ recognizer:UISwipeGestureRecognizer) {
        
        if recognizer.state == .ended {
            
            if recognizer.direction == .left {
            
                print("(three) swipe left !")
                
                //set card status
                self.CARD_STACK_STATUS = .stacked
                
                //animate position
                if self.cardDisplayArray.count > 0 {
                
                    //get first card position
                    let firstCardImgView = self.cardDisplayArray[0]
                    
                    UIView.animate(withDuration: 0.5, animations: { () -> Void in
                        
                        for cardImgView in self.cardDisplayArray {
                        
                            cardImgView.center = firstCardImgView.center
                        }
                    })
                }
            }
            else if recognizer.direction == .right {
                
                print("(three) swipe right !")
                
                //set card status
                self.CARD_STACK_STATUS = .distributed
                
                //animate position
                UIView.animate(withDuration: 0.5, animations: { () -> Void in
                    
                    for i in 0..<self.cardDisplayArray.count {
                        
                        let cardImgView = self.cardDisplayArray[i]
                        
                        //move cards to the distributed position
                        let centerPos = self.cardOriginalPositionArray[i]
                        cardImgView.center = centerPos
                    }
                    
                    }, completion: { (success) -> Void in
                }) 
            }
        }
    }
    
    //MARK: - MCBrowserViewControllerDelegate
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        
        self.browser.dismiss(animated: true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        
        self.browser.dismiss(animated: true, completion: nil)
    }
    
    //MARK: - MCAdvertiserAssistantDelegate
    
    func advertiserAssistantDidDismissInvitation(_ advertiserAssistant: MCAdvertiserAssistant) {
        
        print("advertiserAssistantDidDismissInvitation")
        print("connectedPeers: \(self.session.connectedPeers)")
    }
    
    //MARK: - MCSessionDelegate
    
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
     
        return certificateHandler(true)
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        print("myPeerID: \(self.session.myPeerID)")
        print("connectd peerID: \(peerID)")
        
        switch state {
            
        case .connecting:
            print("Connecting..")
            
            print("peers count: \(session.connectedPeers.count)")
            if (session.connectedPeers.count > 0){
            
                let index = self.session.connectedPeers.index(of: peerID)!
                print("index: \(index)")
            }
            break
            
        case .connected:
            print("Connected..")
        
            if (session.connectedPeers.count > 0){
                let index = self.session.connectedPeers.index(of: peerID)!
                let phone = self.connectedPhoneArray[index] as Phone
                phone.isConnected = true
                phone.peerID = peerID
                
                DispatchQueue.main.async(execute: { () -> Void in
                
                    phone.imageView?.alpha = 1.0
                    phone.nameLbl?.text = peerID.displayName
                })

                print("index: \(index)")
            }
            break
            
        case .notConnected:
            
            print("Not Connected..")
        
            print("peers count: \(session.connectedPeers.count)")
            
            if (session.connectedPeers.count == 0){
            
                DispatchQueue.main.async {
                    for phone in self.connectedPhoneArray {
                        phone.isConnected = false
                        phone.imageView?.alpha = 0.5
                    }
                }
            }
            else if (session.connectedPeers.count > 0){
                
                var index = 0
                for phone in self.connectedPhoneArray {
                 
                    if phone.peerID == peerID {
                    
                        let phone = self.connectedPhoneArray[index]
                        phone.isConnected = false
                        print("index: \(index)")
                        
                        DispatchQueue.main.async(execute: { () -> Void in
                            
                            phone.imageView?.alpha = 0.5
                        })
                        
                        break
                    }
                    
                    index += 1
                }
            }
            
            DispatchQueue.main.async(execute: { () -> Void in
            
                var index = 0
                for phone in self.connectedPhoneArray {
                
                    if phone.peerID == peerID {
                    
                        //animate card return back
                        let phone = self.connectedPhoneArray[index]
                        phone.nameLbl?.text = self.kNotConnectedText
                        
                        for cardImgView in phone.cardArray {
                            
                            self.animateCardReturned(index, cardID: cardImgView.tag, isFront: cardImgView.isFront)
                        }
                        
                        break
                    }
                    
                    index += 1
                }
            })
            
            break
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        let cardDict:NSDictionary = NSKeyedUnarchiver.unarchiveObject(with: data) as! NSDictionary
        let cardID = cardDict["id"] as! Int
        let isFront = cardDict["isFront"] as! Bool
        
        print("didReceiveData: \(cardDict)")
        
        DispatchQueue.main.async { () -> Void in
            
            //Do animation on main thread
            
            let peerIndex = self.session.connectedPeers.index(of: peerID)!
            //let phone = self.connectedPhoneArray[peerIndex]
            //let phoneImgView = phone.imageView
            
            self.animateCardReturned(peerIndex, cardID: cardID, isFront: isFront)
            
            /*
            //get the card view
            let filteredArray = self.cardDisplayArray.filter() { $0.card.id == cardID }
            
            if filteredArray.count == 1 {
                
                //exactly one match
                let cardImgView = filteredArray.first!
                cardImgView.isFront = isFront
                cardImgView.image = isFront ? cardImgView.card.image : self.cardBackImage
                cardImgView.center = phoneImgView.center
                cardImgView.hidden = false
                self.view.insertSubview(cardImgView, belowSubview: phoneImgView)
                
                let pos = cardImgView.position
                let centerPos = self.cardOriginalPositionArray[pos]
                
                //remove card to Phone's card array
                phone.cardArray.removeObject(cardImgView)
                
                UIView.animateWithDuration(0.7, animations: { () -> Void in
                    
                    cardImgView.center = centerPos
                    
                    }, completion: { (success) -> Void in
                        
                        cardImgView.isOut = false   //returning Card
                        
                        //display number of cards
                        self.displayCardCounter()
                })
            }//end if
            */
        }
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
        print("table didStartReceivingResourceWithName")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?) {
        
        print("table didFinishReceivingResourceWithName")
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
        print("table didReceiveStream")
    }
    
    //MARK: - Card Animation Helper
    
    func animateCardReturned(_ peerIndex: Int, cardID: Int, isFront:Bool) {
    
        //Connected phone
        let phone = self.connectedPhoneArray[peerIndex]
        let phoneImgView = phone.imageView
        
        //Get the card view
        let filteredArray = self.cardDisplayArray.filter() { $0.card.id == cardID }
        
        if filteredArray.count == 1 {
            
            //exactly one match
            let cardImgView = filteredArray.first!
            cardImgView.isFront = isFront
            cardImgView.image = isFront ? cardImgView.card.image : self.cardBackImage
            cardImgView.center = (phoneImgView?.center)!
            cardImgView.isHidden = false
            self.view.insertSubview(cardImgView, belowSubview: phoneImgView!)//reposition views
            
            let pos = cardImgView.position
            var centerPos = self.cardOriginalPositionArray[pos!]
            
            if self.CARD_STACK_STATUS == .stacked || self.CARD_STACK_STATUS == .fanout {
                
                centerPos = self.cardOriginalPositionArray[0]
            }
            
            //remove card to Phone's card array
            phone.cardArray.removeObject(cardImgView)
            
            UIView.animate(withDuration: 0.7, animations: { () -> Void in
                
                cardImgView.center = centerPos
                
                }, completion: { (success) -> Void in
                    
                    cardImgView.isOut = false   //returning Card
                    
                    //display number of cards
                    self.displayCardCounter()
            })
        }//end if
    }
}
