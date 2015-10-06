//
//  File.swift
//  syncthing-bar
//
//  Created by Albert Stark on 29.06.15.
//  Copyright (c) 2015 mop. All rights reserved.
//

import Foundation
import CDEvents
import SyncthingStatus

public class FileSystemWatcher {
    
    var fileSystemEvent : CDEvents?
    internal var currentlyWatchedFolders : [String] = []
    
    init() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("foldersDetermined:"), name: FoldersDetermined, object: nil)
    }
    
    @objc(foldersDetermined:)
    func foldersDetermined(notification: NSNotification) {
        var fileURLS : [NSURL] = []
        
        for folder in dataContext.syncthingFolders {
            fileURLS.append( NSURL(fileURLWithPath: (folder.path as String?)!,isDirectory: true) );
        }
        
        self.fileSystemEvent = nil //Remove all old watched paths
        
        self.fileSystemEvent = CDEvents(URLs: fileURLS, block: { (watcher, event) -> Void in
            
            for folder in dataContext.syncthingFolders {
                if (event.URL.absoluteString.rangeOfString((folder.path as String?)!) != nil)
                {
                    let URL : NSURL = NSURL(fileURLWithPath: (folder.path as String?)!, isDirectory: true)
                    let changedURL : NSURL = event.URL;
                    
                    if let relativeURL = changedURL.path?.stringByReplacingOccurrencesOfString(URL.path!, withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch) {
                        let params = "folder=\(folder.id)&sub=\(relativeURL)";
                        let data = params.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
                        
                        let appDelegate = NSApplication.sharedApplication().delegate as! AppDelegate
                        let request: NSMutableURLRequest = appDelegate.getRunner().createRequest("/rest/db/scan")
                        request.HTTPMethod = "POST"
                        
                        request.HTTPBody = data;
                        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {(response, data, error) in
                            
                        }
                    }
                }
            }
        })
    }
}
