//
//  ViewController.swift
//  4chan Image Downloader
//
//  Created by Erik Little on 11/15/14.
//  Copyright (c) 2014 Erik Little. All rights reserved.
//

import Cocoa

class ThreadDownloaderController: NSViewController  {
    
    @IBOutlet weak var threadTextField:NSTextField!
    @IBOutlet var downloadTextView:NSTextView!
    var downloader:ChanDownloader!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.downloader = ChanDownloader(downloadView: self)
    }
    
    override var representedObject:AnyObject? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    @IBAction func downloadWasClicked(sender:AnyObject) {
        self.downloadTextView.string = ""
        let thread = threadTextField.stringValue
        
        self.appendTextAndScroll("Starting Download\n")
        self.downloader.setThreadAndBeginDownload(thread)
        self.threadTextField.setValue("", forKey: "stringValue")
    }
    
    @IBAction func downloadFolderWasClicked(sender:AnyObject) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        let clicked = openPanel.runModal()
        
        if (clicked == NSFileHandlingPanelOKButton) {
            self.downloader.changeDownloadFolder(openPanel.URL!)
        }
    }
    
    func appendTextAndScroll(text:String) {
        dispatch_async(dispatch_get_main_queue()) {[unowned self] in
            let string = NSAttributedString(string: text)
            self.downloadTextView.textStorage?.appendAttributedString(string)
            self.downloadTextView.scrollRangeToVisible(NSMakeRange(countElements(self.downloadTextView.string!), 0))
        }
    }
}

