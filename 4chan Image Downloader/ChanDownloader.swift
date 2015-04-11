//
//  Downloader.swift
//  4chan Image Downloader
//

import Foundation

let downloadQueue = NSOperationQueue()

class ChanDownloader: NSObject {
    weak var downloadView:ThreadDownloaderController?
    let manager = NSFileManager()
    let limiter = RateLimiter(tokensPerInterval: 1, interval: "second")
    let applicationSupportDir = NSURL(string: "file:///" +
        NSString(string:
            "~/Library/Application%20Support/4chan%20Image%20Downloader").stringByExpandingTildeInPath)!
    var board:String!
    var downloadPath = NSURL(string: "file:///"
        + NSString(string: "~/Pictures/4chanDownloads/").stringByExpandingTildeInPath)!
    var getNum = 0
    var gotNum = 0
    var jsonPath:NSURL?
    var numPosts = 0
    var posts:NSArray!
    var thread:String!
    var threadDownloadPath:NSURL!
    var threadNumber:String!
    
    init(downloadView:ThreadDownloaderController) {
        self.downloadView = downloadView
        self.jsonPath = NSURL(string: self.applicationSupportDir.absoluteString! + "/lastdir.json")!
        var err:NSError?
        
        if !self.manager.fileExistsAtPath(self.applicationSupportDir.path!) {
            println("creating application support dir")
            self.manager.createDirectoryAtPath(self.applicationSupportDir.path!,
                withIntermediateDirectories: false, attributes: nil, error: &err)
        }
        
        super.init()
        
        if self.manager.fileExistsAtPath(self.jsonPath!.path!) {
            let data = NSData(contentsOfFile: self.jsonPath!.path!)
            if let lastPath:NSDictionary = NSJSONSerialization.JSONObjectWithData(data!,
                options: NSJSONReadingOptions.AllowFragments, error: &err) as? NSDictionary {
                    self.downloadPath = NSURL(string: lastPath["lastDir"] as! String)!
            }
        } else {
            self.changeDownloadFolder(self.downloadPath)
        }
        
        if !self.manager.fileExistsAtPath(self.downloadPath.path!) {
            self.manager.createDirectoryAtPath(self.downloadPath.path!,
                withIntermediateDirectories: true, attributes: nil, error: &err)
            if err != nil {
                println(err?.localizedDescription)
            }
        }
        
    }
    
    init(thread:String, downloadPath:NSURL, downloadView:ThreadDownloaderController) {
        self.downloadView = downloadView
        self.thread = thread
        self.downloadPath = downloadPath
        
        super.init()

        self.limiter.removeTokens(count: 1, callback: self.retrieveThreadJSON)
    }
    
    deinit {
        println("Downloader is being released")
    }
    
    func changeDownloadFolder(path:NSURL) {
        var err:NSError?
        self.downloadPath = path
        let pathForSave = [
            "version": 1.0,
            "lastDir": self.downloadPath.path!
        ]
        
        let jsonForWriting = NSJSONSerialization.dataWithJSONObject(pathForSave,
            options: NSJSONWritingOptions.PrettyPrinted, error: &err)
        
        self.manager.createFileAtPath(self.jsonPath!.path!,
            contents: jsonForWriting, attributes: nil)
    }
    
    private func checkDone() -> Bool {
        if self.gotNum == self.numPosts {
            return true
        }
        
        return false
    }
    
    private func getImages() {
        println("Getting thread images")
        self.numPosts = 0
        
        // Creates a function that can be called to download the image
        func createFun(filename:String, ext:String, tim:String, num:Int) {
            if (self.manager.fileExistsAtPath(self.threadDownloadPath.path! + "/" + tim + ext)) {
                self.gotNum++
                self.downloadView?.appendTextAndScroll("File: \(tim + ext) already exists.\n")
                return
            }
            
            // The download function
            func getImage(err:String?, tokensRemaining:Double?) {
                var lastImage = false
                
                self.downloadView?.appendTextAndScroll("GET: " + tim + ext + "\n")
                
                if (num == self.numPosts) {
                    lastImage = true
                    self.getNum = 0
                }
                
                let imageURL = NSString(format: "https://i.4cdn.org/%@/%@%@", self.board, tim, ext)
                let req = NSURLRequest(URL: NSURL(string: imageURL as String)!)
                
                NSURLConnection.sendAsynchronousRequest(req, queue: downloadQueue) {[unowned self] res, data, err in
                    self.gotNum++
                    self.downloadView?.appendTextAndScroll("GOT: " + tim + ext + "\n")
                    self.manager.createFileAtPath(self.threadDownloadPath.path! + "/" + tim + ext,
                        contents: data, attributes: nil)
                    if self.checkDone() {
                        self.downloadView?.appendTextAndScroll("DONE\n")
                    }
                }
            }
            
            return self.limiter.removeTokens(count: 1, callback: getImage)
        }
        
        for i in 0..<posts.count {
            if let filename = posts[i]["filename"] as? String {
                let ext = posts[i]["ext"] as! String
                let tim = String(posts[i]["tim"] as! Int)
                createFun(filename, ext, tim, i)
                self.numPosts++
            }
        }
        
        if self.checkDone() {
            self.downloadView?.appendTextAndScroll("DONE\n")
        }
    }
    
    private func retrieveThreadJSON(err:String?, remainingTokens:Double?) {
        if !self.verifyTheadURL() {
            NSNotificationCenter.defaultCenter().postNotificationName("invalidThread", object: nil)
            return
        } else if err != nil {
            return
        }
        
        let newPath = "file:///" + self.downloadPath.path! + "/" + self.board + "/" + self.threadNumber
        self.threadDownloadPath = NSURL(string: newPath)!
        var err:NSError?
        
        self.manager.createDirectoryAtURL(self.threadDownloadPath, withIntermediateDirectories: true,
            attributes: nil, error: &err)
        
        if err != nil {
            println(err?.localizedDescription)
            return
        }
        
        println("Getting thread JSON")
        
        let requestString = NSString(format: "http://a.4cdn.org/%@/thread/%@.json", self.board, self.threadNumber)
        let request = NSURLRequest(URL: NSURL(string: requestString as String)!)
        var jsonError:NSError?
        
        NSURLConnection.sendAsynchronousRequest(request, queue: downloadQueue) {[unowned self] res, data, err in
            var realJSON = NSJSONSerialization.JSONObjectWithData(data!, options: nil, error: &jsonError) as! NSDictionary
            if let posts = realJSON["posts"] as? NSArray {
                self.posts = posts
                self.getImages()
                
            }
        }
    }
    
    func setThreadAndBeginDownload(thread:String) {
        self.thread = thread
        self.gotNum = 0
        self.limiter.removeTokens(count: 1, callback: self.retrieveThreadJSON)
    }
    
    private func verifyTheadURL() -> Bool {
        let matches = self.thread["https?\\:\\/\\/boards\\.4chan\\.org\\/(.*)\\/thread\\/(\\d*)"].matches()
        let groups = self.thread["https?\\:\\/\\/boards\\.4chan\\.org\\/(.*)\\/thread\\/(\\d*)"].groups()
        
        if matches.count == 0 {
            return false
        }
        
        self.board = groups?[1]
        self.threadNumber = groups?[2]
        return true
    }
}