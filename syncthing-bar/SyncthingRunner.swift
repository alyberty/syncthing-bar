//
//  SyncthingRunner.swift
//  syncthing-bar
//
//  Created by Andreas Streichardt on 13.12.14.
//  Copyright (c) 2014 mop. All rights reserved.
//

/*

Possible locations of syncthing executable
App resources - don't know if there are any problems with signing etc / only works if directly bundeld - no updates
App Library Folder - Preferred!
User Downloads Folder in syncthing subfolder

*/

import Foundation
import AlecrimCoreData
import Alamofire
import SyncthingStatus

let TooManyErrorsNotification = "koeln.mop.too-many-errors"
let HttpChanged = "koeln.mop.http-changed"
let FoldersDetermined = "koeln.mop.folders-determined"
let SettingsSet = "koeln.mop.settings-set"
let StartStop = "koeln.mop.start-stop"

class SyncthingRunner: NSObject {
    
    var portFinder : PortFinder = PortFinder(startPort: 8084)
    var path : String?
    var task: NSTask?
    var watchdog: NSTask = NSTask()
    var port: NSInteger?
    var lastFail : NSDate?
    var failCount : NSInteger = 0
    var notificationCenter: NSNotificationCenter = NSNotificationCenter.defaultCenter()
    var portOpenTimer : NSTimer?
    var repositoryCollectorTimer : NSTimer?
    var log : SyncthingLog
    var buf : NSString = NSString()
    var apiKey: NSString?
    var version: [Int]?
    var paused: Bool
    
    var activityMonitor : SyncthingActivityMonitor?
    
    init(log: SyncthingLog) {
        self.paused = false
        self.log = log
        
        super.init()
        
        if let syncthingPath = determineSyncthingExecutablePath() {
            path = syncthingPath
        }
        else
        {
            downloadSyncthing()
        }
        
        notificationCenter.addObserver(self, selector: "taskStopped:", name: NSTaskDidTerminateNotification, object: task)
        notificationCenter.addObserver(self, selector: "receivedOut:", name: NSFileHandleDataAvailableNotification, object: nil)
        
        self.activityMonitor = SyncthingActivityPullMonitor(runner: self)
    }
    
    func registerVersion() -> Bool {
        if let syncthingPath = self.path as String! {
            let pipe : NSPipe = NSPipe()
            let versionTask = NSTask()
            versionTask.launchPath = syncthingPath
            versionTask.arguments = ["--version"]
            versionTask.standardOutput = pipe
            versionTask.launch()
            versionTask.waitUntilExit()
            
            let versionOut = pipe.fileHandleForReading.readDataToEndOfFile()
            let versionString = NSString(data: versionOut, encoding: NSUTF8StringEncoding)
            
            let regex = try? NSRegularExpression(pattern: "^syncthing v(\\d+)\\.(\\d+)\\.(\\d+)",
                options: [])
            var results = regex!.matchesInString(versionString! as String, options: [], range: NSMakeRange(0, versionString!.length))
            if results.count == 1 {
                let major = Int((versionString?.substringWithRange(results[0].rangeAtIndex(1)))!) as Int!
                let minor = Int((versionString?.substringWithRange(results[0].rangeAtIndex(2)))!) as Int!
                let patch = Int((versionString?.substringWithRange(results[0].rangeAtIndex(3)))!) as Int!
                
                version = [ major, minor, patch ]
                print("Syncthing version \(version![0]) \(version![1]) \(version![2])")
                return true
            } else {
                return false
            }
        }
        else
        {
            return false
        }
    }
    
    func run() -> (String?) {
        if let syncthingPath = self.path as String! {
            
            let pipe : NSPipe = NSPipe()
            let readHandle = pipe.fileHandleForReading
            
            task = NSTask()
            task!.launchPath = syncthingPath
            var environment = NSProcessInfo.processInfo().environment
            environment["STNORESTART"] =  "1"
            task!.environment = environment
            
            let port = self.port!
            let httpData : [String: String] = ["host": "127.0.0.1", "port": String(port)];
            
            self.apiKey = randomStringWithLength(32);
            
            task!.arguments = ["-no-browser", "-gui-address=127.0.0.1:\(port)", "-gui-apikey=\(self.apiKey!)"]
            task!.standardOutput = pipe
            readHandle.waitForDataInBackgroundAndNotify()
            task!.launch()
            
            
            //Modify Child Kill - https://github.com/mralexgray/Infanticide
            
            let sleepyTime = 5;
            /** FIN CONF  */
            
            let parentPID = NSProcessInfo().processIdentifier// get parent PID (this app) to pass to watchdog
            
            let theBabyKiller = "SLEEPYTIME=\(sleepyTime); PARENTPID=\(parentPID); CHILDPID=\(task!.processIdentifier); babyRISEfromtheGRAVE () { logger \"SyncthingBar [PID = $PARENTPID] died!. Killing Syncthing, $CHILDPID, and exiting.\"; while kill -0 $PARENTPID; do sleep $SLEEPYTIME; if kill -0 $CHILDPID; then sleep $SLEEPYTIME; else exit 1; fi; done; logger \"SyncthingBar [PID = $PARENTPID] died!. Killing Syncthing, $CHILDPID, and exiting.\"; kill -9 $CHILDPID; exit 1; }; babyRISEfromtheGRAVE; exit 0";
            
            let watchdog = NSTask() // setup task
            watchdog.launchPath = "/bin/sh"
            watchdog.arguments = ["-c",theBabyKiller]
            watchdog.launch()
            //watchdog.waitUntilExit()
            
            // mop: wait until port is open :O
            portOpenTimer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: "checkPortOpen:", userInfo: httpData, repeats: true)
        }
        
        return nil
    }
    
    func receivedOut(notif : NSNotification) {
        // Unpack the FileHandle from the notification
        let fh:NSFileHandle = notif.object as! NSFileHandle
        // Get the data from the FileHandle
        let data = fh.availableData
        // Only deal with the data if it actually exists
        if data.length > 1 {
            // Since we just got the notification from fh, we must tell it to notify us again when it gets more data
            fh.waitForDataInBackgroundAndNotify()
            // Convert the data into a string
            let string = (buf as String) + (NSString(data: data, encoding: NSUTF8StringEncoding)! as String)
            var lines = string.componentsSeparatedByString("\n")
            buf = lines.removeLast()
            for line in lines {
                log.log("OUT: \(line)")
            }
        }
    }
    
    func ensureRunning() -> (String?) {
        if !registerVersion() {
            return "Could not determine syncthing version"
        }
        let result = portFinder.findPort()
        // mop: ITS GO :O ZOMG!!111
        if (result.err != nil) {
            return "Could not find a port!"
        }
        self.port = result.port
        let err = run()
        return err
    }
    
    // mop: copy paste :D http://stackoverflow.com/questions/26845307/generate-random-alphanumeric-string-in-swift looks good to me
    func randomStringWithLength (len : Int) -> NSString {
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        
        let randomString : NSMutableString = NSMutableString(capacity: len)
        
        for (var i=0; i < len; i++){
            let length = UInt32 (letters.length)
            let rand = arc4random_uniform(length)
            randomString.appendFormat("%C", letters.characterAtIndex(Int(rand)))
        }
        
        return randomString
    }
    
    internal func createRequest(path: NSString) -> NSMutableURLRequest {
        let url = NSURL(string: "http://localhost:\(self.port!)\(path)")
        let request = NSMutableURLRequest(URL: url!)
        request.addValue(self.apiKey! as String, forHTTPHeaderField: "X-API-Key")
        return request
    }
    
    func collectRepositories(timer: NSTimer) {
        // mop: jaja copy paste...must fix somewhen
        if let info = timer.userInfo as? Dictionary<String,String> {

            var request: NSMutableURLRequest
            var idElement: NSString
            var pathElement: NSString
            var foldersElement: NSString
            if version![0] == 0 && version![1] == 10 {
                request = createRequest("/rest/config")
                idElement = "ID"
                pathElement = "Path"
                foldersElement = "Folders"
            } else {
                request = createRequest("/rest/system/config")
                idElement = "id"
                pathElement = "path"
                foldersElement = "folders"
            }
            
            NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {(response, data, error) in
                if (error != nil) {
                    print("Got error collecting repositories \(error)")
                    return;
                }
                let httpResponse = response as? NSHTTPURLResponse;
                if httpResponse == nil {
                    print("Unexpected response");
                    return;
                }
                
                if httpResponse!.statusCode != 200 {
                    print("Got non 200 HTTP Response \(httpResponse!.statusCode)");
                    return;
                }
                if (error == nil) {
                    let jsonResult: NSDictionary = (try! NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary
                    
                    //TODO - not recognicing removed folders
                    // mop: WTF am i typing :S
                    let folders = jsonResult[foldersElement] as? Array<AnyObject>
                    if folders != nil {
                        
                        var foldersChanged = false
                        
                        let folderStructArr = folders!.filter({(object: AnyObject) -> (Bool) in
                            let id = object[idElement] as? String
                            let path = object[pathElement] as? String
                            
                            return id != nil && path != nil
                        }).map({(object: AnyObject) -> (SyncthingFolder) in
                            let id = object[idElement] as? String
                            let pathTemp = object[pathElement] as? String
                            let path = pathTemp // changed !
                            
                            if let folder = dataContext.syncthingFolders.filter({ $0.id == id! }).first() {
                                return folder
                            }
                            else {
                                let folder = dataContext.syncthingFolders.createEntity()
                                folder.id = id!
                                folder.path = path!
                                folder.stateEnum = SyncthingFolderState.idle
                                
                                foldersChanged = true
                                
                                return folder
                            }
                            
                        })
                        
                        if( foldersChanged ) {
                            do {
                                try dataContext.save()
                            }
                            catch let err as NSError {
                                print("Could not save CoreData Context: \(err.localizedDescription)")
                            }
                            
                            let folderData = ["folders": folderStructArr]
                            self.notificationCenter.postNotificationName(FoldersDetermined, object: self, userInfo: folderData)
                        }
                        
                    } else {
                        print("Failed to parse folders :(")
                    }
                    
                    
                } else {
                    print("Got error collecting repositories \(error)")
                }
            }
            
        }
    }
    
    func checkPortOpen(timer: NSTimer) {
        if (timer.valid) {
            if let info = timer.userInfo as? Dictionary<String,String> {
                let host = info["host"]
                let port = info["port"]
                let request = createRequest("/rest/version")
                
                NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {(response, data, error) in
                    if (error == nil) {
                        let httpData = ["host": host!, "port": port!]
                        self.notificationCenter.postNotificationName(HttpChanged, object: self, userInfo: httpData)
                        if (self.portOpenTimer!.valid) {
                            self.portOpenTimer!.invalidate()
                        }
                        self.repositoryCollectorTimer = NSTimer.scheduledTimerWithTimeInterval(10.0, target: self, selector: "collectRepositories:", userInfo: info, repeats: true)
                        self.repositoryCollectorTimer!.fire()
                    }
                }
            }
        }
    }
    
    func taskStopped(sender: AnyObject) {
        let task = sender.object as! NSTask
        if (task != self.task) {
            return
        }
        
        self.notificationCenter.postNotificationName(HttpChanged, object: self)
        
        if (self.paused) {
            // ctp: DO NOT attempt restart when paused ...
            return
        }
        
        stopTimers()
        
        let current = NSDate()
        // mop: retry 5 times :S
        if (lastFail != nil) {
            let timeDiff = current.timeIntervalSinceDate(lastFail!)
            if (timeDiff > 5) {
                failCount = 0
            } else if (failCount <= 5) {
                failCount++
            } else {
                notificationCenter.postNotificationName(TooManyErrorsNotification, object: self)
                print("Too many errors. Stopping")
                return
            }
        }
        lastFail = current
        run()
    }
    
    func stopTimers() {
        if (portOpenTimer != nil && portOpenTimer!.valid) {
            portOpenTimer!.invalidate()
        }
        
        if (repositoryCollectorTimer != nil) {
            if (repositoryCollectorTimer!.valid) {
                repositoryCollectorTimer!.invalidate()
            }
        }
    }
    
    func pause() {
        if (self.paused) {
            return
        }
        
        self.paused = true
        self.stop()
    }
    
    func play() {
        if (!self.paused) {
            return
        }
        
        self.paused = false
        self.run()
    }
    
    func stop() {
        if (task != nil) {
            task!.terminate();
        }
        stopTimers()
    }
    
    //MARK: - SyncthingDownloader
    
    func determineSyncthingExecutablePath() -> String? {
        let syncthingSubPath = "syncthing/syncthing"
        
        if let possiblePath = NSBundle.mainBundle().pathForResource(syncthingSubPath, ofType: "") {
            return possiblePath
        }
        
        let downloadDirectoryPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.DownloadsDirectory, .UserDomainMask, true)[0])
        
        if let possiblePath = determineSyncthingExecutable(downloadDirectoryPath) {
            return possiblePath
        }
        
        let libraryDirectoryPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.LibraryDirectory, .UserDomainMask, true)[0])
        
        if let possiblePath = determineSyncthingExecutable(libraryDirectoryPath) {
            return possiblePath
        }
        
        return nil
    }
    
    func determineSyncthingExecutable(inSubDirectory: NSURL) -> String? {
        
        let subDirectoryFolders = NSFileManager.defaultManager().subpathsAtPath(inSubDirectory.path!)
        
        for subPath : String in subDirectoryFolders! {
            if (subPath.rangeOfString("syncthing-macosx-amd64-v([.0-9])+", options: NSStringCompareOptions.RegularExpressionSearch) != nil) {
                return inSubDirectory.URLByAppendingPathComponent(subPath).URLByAppendingPathComponent("syncthing").path!
            }
        }
        
        return nil
    }
    
    func downloadSyncthing() {
        let syncthingOSXDownloadLink : URLStringConvertible = "https://github.com/syncthing/syncthing/releases/download/v0.11.24/syncthing-macosx-amd64-v0.11.24.tar.gz"
        
        
        let destination = Alamofire.Request.suggestedDownloadDestination(directory: .DownloadsDirectory, domain: .UserDomainMask)
        //let destination = Alamofire.Request.suggestedDownloadDestination(directory: NSSearchPathDirectory.LibraryDirectory, domain: .UserDomainMask)
        
        Alamofire.download(.GET, syncthingOSXDownloadLink, destination: destination).progress
            { bytesRead, totalBytesRead, totalBytesExpectedToRead in
                
                // This closure is NOT called on the main queue for performance
                // reasons. To update your ui, dispatch to the main queue.
                
            }
            .response
            { request, response, _, error in
                let syncthingSubPath = "syncthing-macosx-amd64-v0.11.24.tar.gz"
                
                let checkValidation = NSFileManager.defaultManager()
                
                let downloadDirectoryPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.DownloadsDirectory, .UserDomainMask, true)[0].URLString)
                
                let downloadPath = downloadDirectoryPath.URLByAppendingPathComponent(syncthingSubPath)
                
                if ( checkValidation.fileExistsAtPath( downloadPath.path! ) )
                {
                    system("tar -zxvf \(downloadPath.path!) -C \(downloadDirectoryPath.path!)")
                    do {
                        try checkValidation.removeItemAtURL(downloadPath)
                    }
                    catch let err as NSError {
                        print("Cloud not remove syncthing archive: \(err.localizedDescription)")
                    }
                    self.ensureRunning()
                }
                
        }
    }
    
}
