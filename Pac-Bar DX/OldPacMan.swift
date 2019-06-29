//
//  OldPacMan.swift
//  Pac-Bar DX
//
//  Created by Henry Franks on 06/06/2019.
//  Copyright © 2019 Henry Franks. All rights reserved.
//

import Foundation
import SpriteKit

class oldPacMan: SKSpriteNode {
	var square: IntCoords
	var inSquareCoords: Coords = Coords(x: squareWidth, y: squareWidth / 2)
	var globalPos: Coords = Coords(x: 0, y: 0)
	var isEating: Bool = false
	let moveConst: CGFloat = CGFloat((1.33 / 8) * Double(squareWidth))
	var direction: Direction = .left
	var startCoords: Coords = Coords(x: 342.5, y: 15)
	var hasChangedDirection: Bool = false

	// Sprite
	let atlas = SKTextureAtlas(named: "Pacman")
	let endAtlas = SKTextureAtlas(named: "PacmanD")
	let frames: [SKTexture]
	var currentFrame = 2
	var animationFrameCounter: Int = 0

	// Sounds
	var isMuted: Bool = mute
	var eatSound = false
	let munchA = SKAction.playSoundFileNamed("munch A.wav", waitForCompletion: false)
	let munchB = SKAction.playSoundFileNamed("munch B.wav", waitForCompletion: false)
	let eatFruit = SKAction.playSoundFileNamed("eat fruit.wav", waitForCompletion: false)
	let extraLife = SKAction.playSoundFileNamed("1up.wav", waitForCompletion: false)

	init(x: Int, y: Int) {
		if debug {
			self.startCoords = Coords(x: 250, y: 150)
		}

		self.square = IntCoords(x: x, y: y)
		self.frames = [self.atlas.textureNamed("PacMan1"), self.atlas.textureNamed("PacMan2"), self.atlas.textureNamed("PacMan3")]
		self.globalPos = Coords(x: squareWidth * Double(self.square.x) + self.inSquareCoords.x, y: squareWidth * Double(self.square.y) + self.inSquareCoords.y)
		super.init(texture: self.frames[2], color: .clear, size: CGSize(width: 1.625 * Double(squareWidth), height: 1.625 * Double(squareWidth)))
		self.zRotation = .pi
		self.position = CGPoint(x: CGFloat(self.startCoords.x), y: CGFloat(self.startCoords.y))
		self.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: self.size.width / 3, height: self.size.height / 3)) // TODO: Check the sizing
		self.physicsBody?.categoryBitMask = gamePhysics.PacMan
		self.physicsBody?.contactTestBitMask = gamePhysics.Dot | gamePhysics.Ghost
		self.physicsBody?.collisionBitMask = gamePhysics.Dot // FIXME: is this needed with contacttestbitmask?
		self.physicsBody?.isDynamic = true
		self.physicsBody?.affectedByGravity = false
		self.zPosition = 2
		self.updateSquare()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func nextFrame() {
		// Advancing animation frame
		if self.currentFrame == 2 {
			self.currentFrame = 0
		} else {
			self.currentFrame += 1
		}
		self.texture = self.frames[currentFrame]
	}

	func munch() {
		// Playing sound
		if !isMuted {
			if self.eatSound {
				self.run(munchA)
			} else {
				self.run(munchB)
			}
		}
		self.eatSound = !self.eatSound
		self.isEating = true
	}

	func changeDirection(to: Direction) {
		if (self.scene?.isPaused)! || self.hasChangedDirection {
			return
		}
		// Changing the direction Pac-Man faces
		// The function will return (exit) if there is a corresponding wall on the square next to the player, or if the direction chosen is the direction already facing
		switch to {
		case self.direction:
			return
		case .up:
			if map.isWall(x: self.square.x, y: self.square.y + 1, includeGhostHouse: true) {
				return
			} else {
				self.zRotation = CGFloat(0.5 * .pi)
			}
		case .down:
			if map.isWall(x: self.square.x, y: self.square.y - 1, includeGhostHouse: true) {
				return
			} else {
				self.zRotation = CGFloat(1.5 * .pi)
			}
		case .left:
			if map.isWall(x: self.square.x - 1, y: self.square.y, includeGhostHouse: true) {
				return
			} else {
				self.zRotation = CGFloat(1.0 * .pi)
			}
		case .right:
			if map.isWall(x: self.square.x + 1, y: self.square.y, includeGhostHouse: true) {
				return
			} else {
				self.zRotation = 0
			}
		}
		self.direction = to
		switch self.direction {
		case .up, .down:
			let old = self.inSquareCoords.x
			self.inSquareCoords.x = Double(squareWidth) / 2
			if !map.isScrolling.horizontal {
				self.position.x += CGFloat(self.inSquareCoords.x - old)
			}
		case .left, .right:
			let old = self.inSquareCoords.y
			self.inSquareCoords.y = Double(squareWidth) / 2
			if !map.isScrolling.vertical {
				self.position.y += CGFloat(self.inSquareCoords.y - old)
			}
		}
		self.hasChangedDirection = true
	}

	func currentSquare() -> Square {
		if let square = map.squareWithCoords(x: self.square.x, y: self.square.y) {
			return square
		} else {
			NSLog("Error: Index out of range, returning empty square")
			return Square(for: 0)
		}
	}

	func updateSquare() {
		// Re-evaluting which square the player is in
		if self.inSquareCoords.x > Double(squareWidth) {
			self.square.x += 1
			self.inSquareCoords.x -= Double(squareWidth)
			self.hasChangedDirection = false
		} else if self.inSquareCoords.x < 0 {
			self.square.x -= 1
			self.inSquareCoords.x += Double(squareWidth)
			self.hasChangedDirection = false
		}

		if self.inSquareCoords.y > Double(squareWidth) {
			self.square.y += 1
			self.inSquareCoords.y -= Double(squareWidth)
			self.hasChangedDirection = false
		} else if self.inSquareCoords.y < 0 {
			self.square.y -= 1
			self.inSquareCoords.y += Double(squareWidth)
			self.hasChangedDirection = false
		}
		if self.square.x > map.width - 1 {
			self.square.x = 0
			if map.isScrolling.horizontal {
				self.position.x = CGFloat(squareWidth / 2)
			} else {
				self.position.x -= CGFloat(Double(map.width) * squareWidth)
			}
		}
		if self.square.x < 0 {
			self.square.x = map.width - 1
			if map.isScrolling.horizontal {
				self.position.x = CGFloat(685 - squareWidth / 2)
			} else {
				self.position.x += CGFloat(Double(map.width) * squareWidth)
			}
		}
		self.globalPos = Coords(x: squareWidth * Double(self.square.x) + self.inSquareCoords.x, y: squareWidth * Double(self.square.y) + self.inSquareCoords.y)
		origin = Coords(x: Double(self.position.x) - self.globalPos.x + 4, y: Double(self.position.y) - self.globalPos.y + 4)
	}

	func availableDirections() -> [Direction] {
		var directions = [Direction]()
		if !map.isWall(x: self.square.x + 1, y: self.square.y, includeGhostHouse: true) {
			directions.append(.right)
		}
		if !map.isWall(x: self.square.x - 1, y: self.square.y, includeGhostHouse: true) {
			directions.append(.left)
		}
		if !map.isWall(x: self.square.x, y: self.square.y + 1, includeGhostHouse: true) {
			directions.append(.up)
		}
		if !map.isWall(x: self.square.x, y: self.square.y - 1, includeGhostHouse: true) {
			directions.append(.down)
		}
		return directions
	}

	func canContinue() -> Bool {
		let available = self.availableDirections()
		switch self.direction {
		case .up:
			if self.inSquareCoords.y >= Double(squareWidth / 2) {
				return available.contains(.up)
			}
		case .down:
			if self.inSquareCoords.y <= Double(squareWidth / 2)  {
				return available.contains(.down)
			}
		case .left:
			if self.square.x == 0 {
				return true
			}
			if self.inSquareCoords.x <= Double(squareWidth / 2)  {
				return available.contains(.left)
			}
		case .right:
			if self.square.x == map.width - 1 {
				return true
			}
			if self.inSquareCoords.x >= Double(squareWidth / 2) {
				return available.contains(.right)
			}
		}
		return true
	}

	func move() {
		if gameOver {
			return
		}
		if self.isEating {
			self.isEating = false
			return
		}

		map.isScrolling.horizontal = self.square.x > 40 && (map.width - self.square.x) > 40
		map.isScrolling.vertical = self.square.y > 0 && self.square.y < map.height

		if let dir = toMove {
			self.changeDirection(to: dir)
		}
		if !canContinue() {
			// TODO: adjust these by squareWidth / 16 or something because the alignment is bad
			// -- also change the values in canContinue
			let mapAdjustX = self.inSquareCoords.x
			let mapAdjustY = self.inSquareCoords.y
			self.inSquareCoords.x = Double(squareWidth) / 2
			self.inSquareCoords.y = Double(squareWidth) / 2
			if !map.isScrolling.horizontal {
				self.position.x += CGFloat(self.inSquareCoords.x - mapAdjustX)
			}
			if !map.isScrolling.vertical {
				self.position.y += CGFloat(self.inSquareCoords.y - mapAdjustY)
			}
			return
		}
		switch self.direction {
		case .up:
			self.inSquareCoords.y += Double(self.moveConst)
			if !map.isScrolling.vertical {
				self.position.y += self.moveConst
			}
		case .down:
			self.inSquareCoords.y -= Double(self.moveConst)
			if !map.isScrolling.vertical {
				self.position.y -= self.moveConst
			}
		case .left:
			self.inSquareCoords.x -= Double(self.moveConst)
			if !map.isScrolling.horizontal {
				self.position.x -= self.moveConst
			}
		case .right:
			self.inSquareCoords.x += Double(self.moveConst)
			if !map.isScrolling.horizontal {
				self.position.x += self.moveConst
			}
		}
		if self.animationFrameCounter == 2 {
			self.animationFrameCounter = 0
			self.nextFrame()
		} else {
			self.animationFrameCounter += 1
		}
		self.updateSquare()
	}

	func deathFrames() {
		// FIXME: Check/adjust timing
		self.size = CGSize(width: 1.875 * Double(squareWidth), height: 1.5 * Double(squareWidth))
		var frames = [SKTexture]()
		for i in 1...11 {
			frames.append(self.endAtlas.textureNamed("PacManD\(i)"))
		}
		self.isPaused = false
		self.zRotation = 0
		self.texture = self.endAtlas.textureNamed("PacManD11")
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.9) {
			mainScene.initAudio(audio: &mainScene.audio, url: mainScene.deathSound, loop: false, play: true)
		}
		sleep(1)
		for ghost in ghosts {
			ghost.removeFromParent()
		}
		for reticle in [blinkyReticle, pinkyReticle, inkyReticle, clydeReticle] {
			reticle.removeFromParent()
		}
		debugLabel.removeFromParent()
		for debugLabel in [clydeDebug, inkyDebug, pinkyDebug, blinkyDebug] {
			debugLabel.removeFromParent()
		}
		self.position.y -= CGFloat(squareWidth) * 3 / 8
		self.run(SKAction.animate(with: frames, timePerFrame: 0.1, resize: true, restore: true), withKey: "GameOver")
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.05) {
			self.removeFromParent()
			if lives <= 0 {
				mainScene.textNode.texture = SKTexture(imageNamed: "Game Over")
				mainScene.textNode.size = CGSize(width: 88, height: 16)
				DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
					mainScene.addChild(mainScene.textNode)
					self.scene?.isPaused = true
					hasStarted = false
				}
			} else {
				DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
					self.scene?.isPaused = true
					lives -= 1
					mainScene.reload()
				}
			}
		}

	}
}
