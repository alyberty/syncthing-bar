//
//  SyncthingFolder.swift
//  syncthing-bar
//
//  Created by Andreas Streichardt on 14.12.14.
//  Copyright (c) 2014 mop. All rights reserved.
//

import Foundation

enum SyncthingFolderState : DebugPrintable {
    case syncing
    case scanning
    case idle
    case unknown
    
    internal var debugDescription : String {
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
}

public class SyncthingFolder : Equatable, DebugPrintable {
    var id: NSString
    var path: NSString
    var state : SyncthingFolderState
    
    public init(id: NSString, path: NSString) {
        self.id = id
        self.path = path
        self.state = SyncthingFolderState.unknown
    }
    
    public func setInfoWithDict(dict: NSDictionary) {
        if let state: String = dict.objectForKey("state") as? String {
            switch state {
            case "syncing":
                self.state = SyncthingFolderState.syncing
            case "scanning":
                self.state = SyncthingFolderState.scanning
            case "idle":
                self.state = SyncthingFolderState.idle
            default:
                self.state = SyncthingFolderState.unknown
            }
        }
    }
    
    public var debugDescription : String {
        return "[\(self.id)] \(self.state) \(self.path)"
    }
    
}

public func ==(folderOne: SyncthingFolder, folderTwo: SyncthingFolder) -> Bool {
    return folderOne.id == folderTwo.id
}