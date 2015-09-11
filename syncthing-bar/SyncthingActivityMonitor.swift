//
//  SyncthingActivityMonitor.swift
//  syncthing-bar
//
//  Created by Albert Stark on 31.08.15.
//  Copyright (c) 2015 mop. All rights reserved.
//

import Foundation
import SwiftyJSON

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
}