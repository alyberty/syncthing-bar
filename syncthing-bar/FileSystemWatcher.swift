//
//  File.swift
//  syncthing-bar
//
//  Created by Albert Stark on 29.06.15.
//  Copyright (c) 2015 mop. All rights reserved.
//

import Foundation
import CDEvents

public class FileSystemWatcher {
    
    var fileSystemEvent : CDEvents?
    
    public func setFolders(folders: Array<SyncthingFolder>) {
        
        var fileURLS : [NSURL] = []

        for folder in folders {
            fileURLS.append( NSURL(fileURLWithPath: folder.path as String,isDirectory: true)! );
        }
        
        self.fileSystemEvent = CDEvents(URLs: fileURLS, block: { (watcher, event) -> Void in
            
            for folder in folders {
                if (event.URL.absoluteString!.rangeOfString(folder.path as String) != nil)
                {
                    var URL : NSURL = NSURL(fileURLWithPath: folder.path as String, isDirectory: true)!
                    var changedURL : NSURL = event.URL;
                    
                    if let relativeURL = changedURL.path?.stringByReplacingOccurrencesOfString(URL.path!, withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch) {
                        let params = "folder=\(folder.id)&sub=\(relativeURL)";
                        let data = params.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
                        
                        let appDelegate = NSApplication.sharedApplication().delegate as! AppDelegate
                        let request: NSMutableURLRequest = appDelegate.getRunner().createRequest("/rest/db/scan")
                        request.HTTPMethod = "POST"
                        
                        request.HTTPBody = data;
                        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {(response, data, error) in
                            
                        }
                        
                        let notification = NSUserNotification()
                        
                        notification.deliveryDate = NSDate()
                        notification.title = "File Changed"
                        notification.subtitle = "\(folder.id) | \(event.URL.lastPathComponent!)";
                        
                        NSUserNotificationCenter.defaultUserNotificationCenter().scheduleNotification(notification)
                    }
                }
            }
        })
    }
}
