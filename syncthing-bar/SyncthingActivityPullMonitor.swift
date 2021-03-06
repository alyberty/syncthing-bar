//
//  SyncthingActivityPullMonitor.swift
//  syncthing-bar
//
//  Created by Albert Stark on 31.08.15.
//  Copyright (c) 2015 mop. All rights reserved.
//

import Foundation
import SwiftyJSON
import SyncthingStatus

class SyncthingActivityPullMonitor : SyncthingActivityMonitor {
    
    var pullTimer : NSTimer?
    
    override init(runner: SyncthingRunner) {
        super.init(runner: runner);
        self.pullTimer = NSTimer.scheduledTimerWithTimeInterval( 10, target: self, selector: Selector("updateStatus:"), userInfo: nil, repeats: true)
    }
    
    @objc(updateStatus:)
    func updateStatus(timer:NSTimer) {
        
        let qualityOfServiceClass = QOS_CLASS_BACKGROUND
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
        
        dispatch_async(backgroundQueue, {
            var localIsInSync = true
            
            var updatedFiles : [SyncthingFile] = []
            
            for syncthingFolder in dataContext.syncthingFolders {
                do {
                    
                    let params = "folder=\(syncthingFolder.id)";
                    
                    let request: NSMutableURLRequest = self.runner.createRequest("/rest/db/status?\(params)")
                    request.HTTPMethod = "GET"
                    
                    let response: AutoreleasingUnsafeMutablePointer<NSURLResponse?> = nil
                    let statusResponseData: NSData =  try NSURLConnection.sendSynchronousRequest(request, returningResponse: response)
                    
                    let jsonConvertedResponse = JSON(data: statusResponseData)
                    
                    syncthingFolder.setInfoWithDict(jsonConvertedResponse)
                    
                    if(syncthingFolder.stateEnum != SyncthingFolderState.idle) {
                        localIsInSync = false
                        
                        let request: NSMutableURLRequest = self.runner.createRequest("/rest/db/need?\(params)")
                        request.HTTPMethod = "GET"
                        
                        let response: AutoreleasingUnsafeMutablePointer<NSURLResponse?
                        >=nil
                        let needResponseData: NSData =  try NSURLConnection.sendSynchronousRequest(request, returningResponse: response)
                        
                        updatedFiles.appendContentsOf( syncthingFolder.updateSyncedFiles(JSON(data: needResponseData)) )
                    }
                }
                catch let error as NSError { //NSURLConnection timeout !
                    print("error while acessing REST Interface for status: \(error.localizedDescription)")
                }
            }
            
            var syncedFiles : [SyncthingFile] = []
            
            for file in dataContext.syncthingFiles {
                if updatedFiles.contains(file) == false {
                    syncedFiles.append(file)
                }
                
                dataContext.syncthingFiles.deleteEntity(file)
            }
            
            if(syncedFiles.count > 0 ) {
                self.notifyDifference(syncedFiles)
            }
            
            if (localIsInSync == false) {
                do {
                    try dataContext.save()
                }
                catch let err as NSError {
                    print("Could not save CoreData Context: \(err.localizedDescription)")
                }
            }
            
            if localIsInSync {
                super.notifyUpdatedStatus([statusDidUpdateNotificationStatusKey:true]);
            }
            else
            {
                super.notifyUpdatedStatus([statusDidUpdateNotificationStatusKey:false]);
            }
        })

        
    }

    
}
