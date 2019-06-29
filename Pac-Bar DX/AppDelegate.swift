//
//  AppDelegate.swift
//  Pac-Bar DX
//
//  Created by Henry Franks on 21/11/16.
//  Copyright © 2016 Henry Franks. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		if hasTouchBar && mainScene.audio.url != nil && mainScene.audio.isPlaying { // XXX: the url check still doesn't work
			mainScene.audio.stop()
		}
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		return true
	}

	func applicationDidBecomeActive(_ notification: Notification) {
		DispatchQueue.main.resume()
		if canResume {
			mainScene.isPaused = false
		}
		if introPlaying && mainScene.audio.url != nil {
			mainScene.audio.play()
		}
	}

	func applicationWillResignActive(_ notification: Notification) {
		mainScene.isPaused = true
		if mainScene.audio.url != nil {
			mainScene.audio.pause()
		}
		DispatchQueue.main.suspend()
	}
}
