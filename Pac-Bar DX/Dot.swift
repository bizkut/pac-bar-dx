//
//  Dot.swift
//  Pac-Bar DX
//
//  Created by Henry Franks on 3/8/17.
//  Copyright © 2017 Henry Franks. All rights reserved.
//

import Cocoa
import SpriteKit
import AVFoundation

var totalDots: Int = 0

class Dot: SKSpriteNode {
	let coords: IntCoords
	let atlas = SKTextureAtlas(named: "Dot")
	var audio = AVAudioPlayer()
	var isPower: Bool
	var blinkCounter: Int = 0

	init(x: Int, y: Int, power: Bool) {
		self.isPower = power
		self.coords = IntCoords(x: x, y: y)
		var width = squareWidth / 4
		var sprite: SKTexture = self.atlas.textureNamed("Dot")
		if self.isPower {
			width = squareWidth
			sprite = self.atlas.textureNamed("Power")
		}
		super.init(texture: sprite, color: .clear, size: CGSize(width: width, height: width))
		self.update()
		self.physicsBody = SKPhysicsBody(rectangleOf: self.size)
		self.physicsBody?.categoryBitMask = gamePhysics.Dot
		self.physicsBody?.contactTestBitMask = gamePhysics.PacMan
		self.physicsBody?.isDynamic = false
		self.physicsBody?.affectedByGravity = false
		self.zPosition = 1
		totalDots += 1
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func remove() {
		pMan.munch()
		pMan.isEating = true
		self.removeFromParent()
	}

	func update() {
		if self.isPower {
			if self.blinkCounter == 20 {
				self.blinkCounter = 0
				self.isHidden = !self.isHidden
			} else {
				self.blinkCounter += 1
			}
		}
		self.position.x = CGFloat(squareWidth * Double(self.coords.x) + origin.x)
		self.position.y = CGFloat(squareWidth * Double(self.coords.y) + origin.y)
	}
}
