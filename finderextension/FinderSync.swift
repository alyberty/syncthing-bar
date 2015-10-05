//
//  FinderSync.swift
//  finderextension
//
//  Created by Albert Stark on 11.09.15.
//  Copyright © 2015 mop. All rights reserved.
//

import Cocoa
import FinderSync
import SyncthingStatus
import AlecrimCoreData


class FinderSync: FIFinderSync {
    
    let badgeIdentifiers = ["OK", "Error","Syncing","Warning"]

    override init() {
        super.init()

        NSLog("FinderSync() launched from %@", NSBundle.mainBundle().bundlePath)
        
        var syncthingFolderURLS : Set<NSURL> = []
        
        for folder in dataContext.syncthingFolders {
            print("folder is \(folder.path)")
            syncthingFolderURLS.insert(NSURL(fileURLWithPath: folder.path))
        }

        // Set up the directory we are syncing.
        FIFinderSyncController.defaultController().directoryURLs = syncthingFolderURLS
        
        FIFinderSyncController.defaultController().setBadgeImage(NSImage(named: "ok")!, label: "OK" , forBadgeIdentifier: badgeIdentifiers[0])
        FIFinderSyncController.defaultController().setBadgeImage(NSImage(named: "error")!, label: "Error" , forBadgeIdentifier: badgeIdentifiers[1])
        FIFinderSyncController.defaultController().setBadgeImage(NSImage(named: "sync")!, label: "Syncing" , forBadgeIdentifier: badgeIdentifiers[2])
        FIFinderSyncController.defaultController().setBadgeImage(NSImage(named: "warning")!, label: "Warning" , forBadgeIdentifier: badgeIdentifiers[3])
        
    }

    // MARK: - Primary Finder Sync protocol methods

    override func beginObservingDirectoryAtURL(url: NSURL) {
        // The user is now seeing the container's contents.
        // If they see it in more than one view at a time, we're only told once.
        NSLog("beginObservingDirectoryAtURL: %@", url.filePathURL!)
    }


    override func endObservingDirectoryAtURL(url: NSURL) {
        // The user is no longer seeing the container's contents.
        NSLog("endObservingDirectoryAtURL: %@", url.filePathURL!)
    }

    override func requestBadgeIdentifierForURL(url: NSURL) {
        NSLog("requestBadgeIdentifierForURL: %@", url.filePathURL!)
        
        var badgeIdentifier = badgeIdentifiers[1]
           
        let predicate = NSPredicate(format: "path CONTAINS %@", url.path!)
        
        let count = dataContext.syncthingFiles.filterUsingPredicate(predicate).count()
        
        if(count > 0) {
            badgeIdentifier = badgeIdentifiers[2]
        }
        else
        {
            badgeIdentifier = badgeIdentifiers[0]
        }
        
        NSLog("currently \(dataContext.syncthingFiles.count()) files in dataContext")
        
        
        FIFinderSyncController.defaultController().setBadgeIdentifier(badgeIdentifier, forURL: url)
    }

    // MARK: - Menu and toolbar item support

    override var toolbarItemName: String {
        return "Syncthing Finder Extension"
    }

    override var toolbarItemToolTip: String {
        return "TOOLBAR FTW 😅"
    }

    override var toolbarItemImage: NSImage {
        return NSImage(named: NSImageNameAdvanced)!
    }

    override func menuForMenuKind(menuKind: FIMenuKind) -> NSMenu {
        // Produce a menu for the extension.
        let menu = NSMenu(title: "")
        //menu.addItemWithTitle("Example Menu Item", action: "sampleAction:", keyEquivalent: "")
        return menu
    }

    @IBAction func sampleAction(sender: AnyObject?) {
        let target = FIFinderSyncController.defaultController().targetedURL()
        let items = FIFinderSyncController.defaultController().selectedItemURLs()

        let item = sender as! NSMenuItem
        NSLog("sampleAction: menu item: %@, target = %@, items = ", item.title, target!.filePathURL!)
        for obj in items! {
            NSLog("    %@", obj.filePathURL!)
        }
    }

}

