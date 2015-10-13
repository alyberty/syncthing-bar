This is a fork, which is still under heavy development.

It adds status awareness to the app.
The icon changes in accordance to the current syncthing status.
It also adds a finder extension which shows the current staus of the files.
An OSX specific implementation of a file system notifier ( like syncthing-inotify ) is added.

I changed the App identifier so I don't have to sign an ID which doesn't belong to me. ( Intended to be reverted )

syncthing-bar
=============

A little statusbar for http://syncthing.net/ on OSX

Be aware that i am NOT a swift developer. I am not even a cocoa developer. This is more or less a weekend experiment. It should be useable but the code is a mess :O (so much i can tell :D)

## What will it do?

Syncthing bar has syncthing bundled. Once started it will try to upgrade and then keep the bundled syncthing running. It will automatically select a port.
When clicking on the statusbar icon it will offer quick access to the UI and will allow you to open any shared folder in finder. Syncthing log may be examined as well. That's it

## Requirements

OS X 10.10 is required

## To build/run

1. Clone the repository in X-Code
2. Download syncthing from http://syncthing.net/
3. Extract the archive
4. Locate the "syncthing" binary
5. Copy the binary to your syncthing-bar source repository in the folder "syncthing"
6. Open X-Code (binary/syncthing should NOT be marked RED anymore)
7. Hit the fancy play button :S
8. it SHOULD run :S

## Demo :O

![alt tag](https://m0ppers.github.io/syncthing-bar.gif)

## Caveats

Syncthingbar is intended for local usage only. It will hardcode host and port and apikey. If you want to access the UI from within your network use a standalone syncthing.

## Installation Package

The latest release can be found on the [releases tab](https://github.com/m0ppers/syncthing-bar/releases)

## 
FinderSync Staus icons from Owncloud OSX client.
Status bar icon when syncing from Syncthing-GTK. ( Intended to be changed to monochromatic image )
