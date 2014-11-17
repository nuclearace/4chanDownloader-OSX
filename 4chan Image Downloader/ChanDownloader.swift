//
//  Downloader.swift
//  4chan Image Downloader
//
//  Created by Erik Little on 11/15/14.
//  Copyright (c) 2014 Erik Little. All rights reserved.
//

import Foundation

class ChanDownloader: NSObject {
    weak var downloadView:ThreadDownloaderController!
    let thread:String!
    let manager = NSFileManager()
    let limiter = RateLimiter(tokensPerInterval: 1, interval: "second")
    var board:String!
    var downloadPath:NSURL!
    var getNum = 0
    var gotNum = 0
    var numPosts = 0
    var posts:NSArray!
    var threadNumber:String!
    
    init(thread:String, downloadPath:NSURL, downloadView:ThreadDownloaderController) {
        super.init()
        self.downloadView = downloadView
        self.thread = thread
        self.downloadPath = downloadPath
        self.limiter.removeTokens(count: 1, callback: self.retrieveThreadJSON)
    }
    
    deinit {
        println("Downloader is being released")
    }
    
    private func checkDone() -> Bool {
        if (self.gotNum == self.numPosts) {
            return true
        }
        return false
    }
    
    private func getImages() {
        println("Getting thread images")
        self.numPosts = 0
        
        // Creates a function that can be called to download the image
        func createFun(filename:String, ext:String, tim:String, num:Int) -> (String?, Double?) -> Void  {
            // The download function
            func getImage(err:String?, tokensRemaining:Double?) {
                var lastImage = false
                self.downloadView.appendTextAndScroll("GET: " + tim + ext + "\n")
                if (num == self.numPosts) {
                    lastImage = true
                    self.getNum = 0
                }
                let imageURL = NSString(format: "https://i.4cdn.org/%@/%@%@", self.board, tim, ext)
                let req = NSURLRequest(URL: NSURL(string: imageURL)!)
                NSURLConnection.sendAsynchronousRequest(req, queue: NSOperationQueue()) {[unowned self] res, data, err in
                    self.gotNum++
                    self.downloadView.appendTextAndScroll("GOT: " + tim + ext + "\n")
                    self.manager.createFileAtPath(self.downloadPath.path! + "/" + tim + ext,
                        contents: data, attributes: nil)
                    if (self.checkDone()) {
                        self.downloadView.appendTextAndScroll("DONE\n")
                    }
                }
            }
            return getImage
        }
        
        for (var i = 0; i < posts.count; i++) {
            if let filename = posts[i]["filename"] as? String {
                let ext = posts[i]["ext"] as String
                let tim = String(posts[i]["tim"] as Int)
                let fun = createFun(filename, ext, tim, self.numPosts + 1)
                limiter.removeTokens(count: 1, callback: fun)
                self.numPosts++
            }
        }
    }
    
    private func retrieveThreadJSON(err:String?, remainingTokens:Double?) {
        if (!self.verifyTheadURL()) {
            NSNotificationCenter.defaultCenter().postNotificationName("invalidThread", object: nil)
            return
        } else if (err != nil) {
            return
        }
        let newPath = "file:///" + self.downloadPath.path! + "/" + self.board + "/" + self.threadNumber
        self.downloadPath = NSURL(string: newPath)
        var err:NSError?
        
        self.manager.createDirectoryAtURL(self.downloadPath, withIntermediateDirectories: true,
            attributes: nil, error: &err)
        
        if (err != nil) {
            println(err?.localizedDescription)
            return
        }
        println("Getting thread JSON")
        let requestString = NSString(format: "http://a.4cdn.org/%@/thread/%@.json", self.board, self.threadNumber)
        let request = NSURLRequest(URL: NSURL(string: requestString)!)
        var jsonError:NSError?
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue()) {[unowned self] res, data, err in
            var realJSON = NSJSONSerialization.JSONObjectWithData(data!, options: nil, error: &jsonError) as NSDictionary
            if let posts = realJSON["posts"] as? NSArray {
                self.posts = posts
                self.getImages()
                
            }
        }
    }
    
    private func verifyTheadURL() -> Bool {
        let mutRegex = RegexMutable(self.thread)
        let matches = mutRegex["https?\\:\\/\\/boards\\.4chan\\.org\\/(.*)\\/thread\\/(\\d*)"].matches()
        let groups = mutRegex["https?\\:\\/\\/boards\\.4chan\\.org\\/(.*)\\/thread\\/(\\d*)"].groups()
        if (matches.count == 0) {
            return false
        }
        self.board = groups[1] as String
        self.threadNumber = groups[2] as String
        return true
    }
}