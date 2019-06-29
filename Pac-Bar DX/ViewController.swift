//
//  ViewController.swift
//  Pac-Bar DX
//
//  Created by Henry Franks on 21/11/16.
//  Copyright © 2016 Henry Franks. All rights reserved.
//

import Cocoa
import SpriteKit

var debug: Bool {
	return ProcessInfo.processInfo.environment["debug"] != nil
}

var textField: NSTextField?

var scoreTiles = [NSImageView]()
var highScoreTiles = [NSImageView]()
var livesTiles = [NSImageView]()
var fruitTiles = [NSImageView]()

let muteButton = NSButton(frame: NSRect(x: 218, y: 38, width: 45, height: 45))
func toggleMute() {
	mute = !mute
    pMan.isMuted = mute
    mainScene.audio.volume = Float(truncating: NSNumber(value:!mute))
    UserDefaults.standard.set(mute, forKey: "mute")
    UserDefaults.standard.synchronize()

	if mute {
		muteButton.image = NSImage(named: "Mute")
	} else {
		muteButton.image = NSImage(named: "Sound")
	}
}

class ViewController: NSViewController {

	override func viewWillAppear() {
		super.viewWillAppear()
		self.view.window!.titleVisibility = .hidden
		self.view.addSubview(muteButton)
		if mute {
			muteButton.image = NSImage(named: "Mute")
		} else {
			muteButton.image = NSImage(named: "Sound")
		}
		muteButton.isBordered = false
		muteButton.bezelStyle = .texturedSquare
		muteButton.action = #selector(muteWrapper)

		let scoreTitle = NSImageView(frame: NSRect(x: 72, y: 224, width: 72, height: 24))
		scoreTitle.image = NSImage(named: "1up")
		self.view.addSubview(scoreTitle)

		let highScoreTitle = NSImageView(frame: NSRect(x: 216, y: 224, width: 240, height: 24))
		highScoreTitle.image = NSImage(named: "hscore")
		self.view.addSubview(highScoreTitle)

		let scoreChars = Array(String(highScore))
		var lim = 6
		if scoreChars.count < 6 {
			lim = scoreChars.count
		}

		for i in 0...6 {
			if i < 6 {
				let tempScore = NSImageView(frame: NSRect(x: 144 - 24 * i, y: 200, width: 24, height: 24))
				let tempHighScore = NSImageView(frame: NSRect(x: 384 - 24 * i, y: 200, width: 24, height: 24))
				if i == 0 || i == 1 {
					tempScore.image = NSImage(named: "0")
					tempHighScore.image = NSImage(named: "0")
				}
				if i < lim {
					tempHighScore.image = NSImage(named: String(scoreChars[scoreChars.count - i - 1]))
				}
				scoreTiles.append(tempScore)
				highScoreTiles.append(tempHighScore)
				self.view.addSubview(tempScore)
				self.view.addSubview(tempHighScore)

				if i < 5 {
					livesTiles.append(NSImageView(frame: NSRect(x: 137 + 42 * i, y: 139, width: 39, height: 39)))
					self.view.addSubview(livesTiles[i])
				}
			}
			fruitTiles.append(NSImageView(frame: NSRect(x: 351 - 44 * i, y: 90, width: 42, height: 42)))
			self.view.addSubview(fruitTiles[i])
		}

		if debug {
			let gameView = SKView()
			gameView.frame.origin = CGPoint(x: 0, y: 300)
			gameView.frame.size = CGSize(width: 500, height: 330)
			if debug {
				gameView.showsFPS = true
			}
			self.view.addSubview(gameView)
			gameView.presentScene(mainScene)
		}
	}

	@objc func muteWrapper() {
		toggleMute() //TODO: function calling another function? Surely there must be a better way
		// Can toggleMute be an @objc func?
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		self.view.wantsLayer = true
		self.view.layer?.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1.0)
		textField = NSTextField(frame: NSRect(x: 0, y: 105, width: self.view.frame.width, height: 50))
		textField!.font = .systemFont(ofSize: 35)
		textField!.alignment = NSTextAlignment.center
		textField!.isBezeled = false
		textField!.drawsBackground = false
		textField!.isEditable = false
		textField!.isSelectable = false
		textField!.stringValue = "You need a Touch Bar"
		textField!.textColor = NSColor(deviceRed: 0.870, green: 0.870, blue: 0.996, alpha: 1)
		self.view.addSubview(textField!)
	}
}
