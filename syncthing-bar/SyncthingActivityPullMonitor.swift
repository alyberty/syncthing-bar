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
            
            var oldFiles :[SyncthingFile] = []
            
            for oldFile in dataContext.syncthingFiles {
                oldFiles.append(oldFile)
            }
            
            do{
                try dataContext.syncthingFiles.delete()
            }
            catch let err as NSError {
                print("Could not remove syncthingFiles: " + err.localizedDescription)
            }
            
            for syncthingFolder in dataContext.syncthingFolders {
                do {
                    
                    let params = "folder=\(syncthingFolder.id)";
                    
                    let request: NSMutableURLRequest = self.runner.createRequest("/rest/db/status?\(params)")
                    request.HTTPMethod = "GET"
                    
                    let response: AutoreleasingUnsafeMutablePointer<NSURLResponse?
                    >=nil
                    let statusResponseData: NSData =  try NSURLConnection.sendSynchronousRequest(request, returningResponse: response)
                    
                    syncthingFolder.setInfoWithDict(JSON(data: statusResponseData))
                    
                    if(syncthingFolder.stateEnum != SyncthingFolderState.idle) {
                        localIsInSync = false
                        
                        let request: NSMutableURLRequest = self.runner.createRequest("/rest/db/need?\(params)")
                        request.HTTPMethod = "GET"
                        
                        let response: AutoreleasingUnsafeMutablePointer<NSURLResponse?
                        >=nil
                        let needResponseData: NSData =  try NSURLConnection.sendSynchronousRequest(request, returningResponse: response)
                        
                        syncthingFolder.setInfoWithDict(JSON(data: needResponseData))
                    }
                }
                catch let error as NSError { //NSURLConnection timeout !
                    print("error while acessing REST Interface for status: \(error.localizedDescription)")
                }
            }
            
            if localIsInSync {
                super.notifyUpdatedStatus([statusDidUpdateNotificationStatusKey:true]);
            }
            else
            {
                
                //O(n^2) can be improved
                var finishedFiles:[SyncthingFile] = []
                
                for file in dataContext.syncthingFiles {
                    if oldFiles.contains(file) == false {
                        finishedFiles.append(file)
                    }
                }
                
                
                //Doesn't work - something with AlecrimCoreData and Public 
//                for oldFile in oldFiles {
//                    if (dataContext.syncthingFiles.count { $0.path == oldFile.path } ) == 0 {
//                        NSLog("file was synced!: \(oldFile.path)")
//                    }
//                }
                
                do {
                    try dataContext.save()
                }
                catch let err as NSError {
                    print("Could not save CoreData Context: \(err.localizedDescription)")
                }
                
                self.notifyDifference(finishedFiles)
                
                super.notifyUpdatedStatus([statusDidUpdateNotificationStatusKey:false]);
            }
        })

        
    }

    
}
