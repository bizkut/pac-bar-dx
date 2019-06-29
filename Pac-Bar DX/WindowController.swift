//
//  WindowController.swift
//  Pac-Bar DX
//
//  Created by Henry Franks on 21/11/16.
//  Copyright © 2016 Henry Franks. All rights reserved.
//

import Cocoa
import SpriteKit
import AVFoundation

var hasTouchBar: Bool = false
var toMove: Direction? = nil

protocol DetailsDelegate: class {
	func updateLabel(Score: Int)
}

@available(OSX 10.12.2, *)
fileprivate extension NSTouchBar.CustomizationIdentifier {
	static let customizationIdentifier = "com.HenryFranks.touchbar.customizationIdentifier"
}

@available(OSX 10.12.2, *)
fileprivate extension NSTouchBarItem.Identifier {
	static let identifier = NSTouchBarItem.Identifier("com.HenryFranks.touchbar.items.identifier")
}

class WindowController: NSWindowController {

	override func windowDidLoad() {
		super.windowDidLoad()
		self.window?.title = "Pac-Bar DX"
		self.window?.titleVisibility = .hidden
		self.window?.titlebarAppearsTransparent = true
		self.window?.styleMask.insert(NSWindow.StyleMask.fullSizeContentView)
		self.window?.styleMask.remove(.resizable)

		if debug {
			var windowFrame = self.window!.frame
			windowFrame.size = NSMakeSize(500, 650)
			self.window?.setFrame(windowFrame, display: true)
		}
	}

	override func keyUp(with event: NSEvent) {
		mainScene.keyUp(with: event)
	}

	override func keyDown(with event: NSEvent) {
		mainScene.keyDown(with: event)
	}

	@available(OSX 10.12.2, *)
	override func makeTouchBar() -> NSTouchBar? {
		hasTouchBar = true
		let touchBar = NSTouchBar()
		touchBar.delegate = self
		touchBar.customizationIdentifier = .customizationIdentifier
		touchBar.defaultItemIdentifiers = [.identifier]
		touchBar.customizationAllowedItemIdentifiers = [.identifier]
		return touchBar
	}
}

@available(OSX 10.12.2, *)
extension WindowController: NSTouchBarDelegate {
	func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
		if identifier == NSTouchBarItem.Identifier.identifier && !debug {
			let gameView = SKView()
			let item = NSCustomTouchBarItem(identifier: identifier)
			item.view = gameView
			gameView.presentScene(mainScene)
			return item
		}
		return nil
	}
}
