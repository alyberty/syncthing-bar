//
//  SyncthingActivityMonitor.swift
//  syncthing-bar
//
//  Created by Albert Stark on 31.08.15.
//  Copyright (c) 2015 mop. All rights reserved.
//

import Foundation
import SwiftyJSON
import SyncthingStatus

internal let statusDidUpdateNotification = "statusDidUpdateNotification";
internal let statusDidUpdateNotificationStatusKey = "inSync";

class SyncthingActivityMonitor {
    private var inSync : Bool = false;
    internal let runner : SyncthingRunner;
    
    init(runner: SyncthingRunner) {
        self.runner = runner;
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("foldersDetermined:"), name: FoldersDetermined, object: nil)
    }
    
    func isInSync() -> Bool {
        return self.inSync;
    }
    
    func notifyUpdatedStatus(info : [String:AnyObject]) {
        let notificationCenter = NSNotificationCenter.defaultCenter();
        
        notificationCenter.postNotificationName(statusDidUpdateNotification,object: nil, userInfo: info);
    }
    
    @objc(foldersDetermined:)
    func foldersDetermined(notification: NSNotification) {
        //let folders = dataContext.syncthingFolders
    }
    
    func notifyDifference(difference : [SyncthingFile] ) {
        if(difference.count > 0) {
            for file in difference {
                let notification = NSUserNotification()
                
                notification.deliveryDate = NSDate()
                notification.title = "File is Synced"
                notification.subtitle = "\(file.inFolder!.id) | \(file.name)";
                
                NSUserNotificationCenter.defaultUserNotificationCenter().scheduleNotification(notification)
            }
            
        }
        
    }
}