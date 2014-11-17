//
//  ViewController.swift
//  4chan Image Downloader
//
//  Created by Erik Little on 11/15/14.
//  Copyright (c) 2014 Erik Little. All rights reserved.
//

import Cocoa

class ThreadDownloaderController: NSViewController  {
    
    @IBOutlet weak var downloadButton:NSButton!
    @IBOutlet weak var threadTextField:NSTextField!
    @IBOutlet var downloadTextView: NSTextView!
    
    var downloader:ChanDownloader!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleDone:", name: "done", object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override var representedObject:AnyObject? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    @IBAction func downloadWasClicked(sender:AnyObject) {
        self.downloadTextView.string = ""
        let thread = threadTextField.stringValue
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        let clicked = openPanel.runModal()
        
        if (clicked == NSFileHandlingPanelOKButton) {
            self.appendTextAndScroll("Starting Download\n")
            self.downloader = ChanDownloader(thread: thread,
                downloadPath: openPanel.URL!, downloadView: self)
            self.threadTextField.setValue("", forKey: "stringValue")
        }
    }
    
    func appendTextAndScroll(text:String) {
        dispatch_async(dispatch_get_main_queue()) {[unowned self] in
            let string = NSAttributedString(string: text)
            self.downloadTextView.textStorage?.appendAttributedString(string)
            self.downloadTextView.scrollRangeToVisible(NSMakeRange(countElements(self.downloadTextView.string!), 0))
        }
    }
    
    func handleDone(not:NSNotification) {
        dispatch_async(dispatch_get_main_queue()) {[unowned self] in
            self.downloader = nil
        }
    }
}

