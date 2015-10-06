//
//  SyncthingFolder.swift
//  syncthing-bar
//
//  Created by Andreas Streichardt on 14.12.14.
//  Copyright (c) 2014 mop. All rights reserved.
//

import Foundation
import AlecrimCoreData
import CoreData
import SwiftyJSON

public let dataContext = DataContext()

public enum SyncthingFolderState : Int32, CustomDebugStringConvertible {
    case syncing
    case scanning
    case idle
    case unknown
    
    public var debugDescription : String {
        switch self {
        case SyncthingFolderState.syncing:
            return "syncing"
        case SyncthingFolderState.scanning:
            return "scanning"
        case SyncthingFolderState.idle:
            return "idle"
        default:
            return "unknown"
        }
    }
    
    init(state : String) {
        switch state {
        case "syncing":
            self = SyncthingFolderState.syncing
        case "scanning":
            self = SyncthingFolderState.scanning
        case "idle":
            self = SyncthingFolderState.idle
        default:
            self = SyncthingFolderState.unknown
        }
    }
}


public extension SyncthingFolder {
    
    public var stateEnum:SyncthingFolderState {                    //  ↓ If self.state is invalid. - Taken from http://stackoverflow.com/questions/26900302/swift-storing-states-in-coredata-with-enums
        get { return SyncthingFolderState(rawValue: self.state) ?? .idle }
        set { self.state = newValue.rawValue }
    }
    
    private func addSyncedFile(withPath path:String, withName name:String){
        
        if dataContext.syncthingFiles.count({$0.path == path}) == 0 {
            let file = dataContext.syncthingFiles.createEntity()
            let URL = NSURL(fileURLWithPath: self.path).URLByAppendingPathComponent(name)
            
            file.path = URL.path!
            file.name = URL.lastPathComponent!
            
            self.addSyncedFile(file)
        }
    }
    
    public func setInfoWithDict(dict: JSON) {
        
        if let statusString = dict["state"].string {
            self.stateEnum = SyncthingFolderState(state: statusString)
        }

        
        if let progress = dict["progress"].array, queued = dict["queued"].array, let rest = dict["rest"].array {
            
            for file in progress {
                if let name = file["name"].string {
                    self.addSyncedFile(withPath: path, withName: name)
                }
            }
            
            for file in queued {
                if let name = file["name"].string {
                    self.addSyncedFile(withPath: path, withName: name)
                }
            }
            
            for file in rest {
                if let name = file["name"].string {
                    self.addSyncedFile(withPath: path, withName: name)
                }
            }
        }
        
        do {
            try dataContext.save()
        }
        catch let err as NSError {
            print("Could not save CoreData Context: \(err.localizedDescription)")
        }
    }
}

extension SyncthingFolder : CustomDebugStringConvertible {
    
    public override var debugDescription : String {
        return "[\(self.id)] \(self.state) \(self.path)"
    }
}

extension SyncthingFile : CustomDebugStringConvertible {
    override public var debugDescription : String {
        return "[\(self.name)] \(self.path)"
    }
}


public func ==(folderOne: SyncthingFolder, folderTwo: SyncthingFolder) -> Bool {
    return folderOne.id == folderTwo.id
}

public func ==(fileOne: SyncthingFile, fileTwo: SyncthingFile) -> Bool {
    return fileOne.path == fileTwo.path
}

public extension DataContext {
    
    convenience init() {
        let frameworkBundle = NSBundle(identifier: "SyncthingStatus")!
        
        let contextOptions = DataContextOptions(managedObjectModelBundle: frameworkBundle, managedObjectModelName: "SyncthingStatusDataModel",
            bundleIdentifier: frameworkBundle.bundleIdentifier!,
            applicationGroupIdentifier: "group.com.alyberty.syncthing-bar" )
        
        self.init(dataContextOptions: contextOptions);
    }
   
}