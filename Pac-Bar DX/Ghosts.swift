//
//  Ghosts.swift
//  Pac-Bar DX
//
//  Created by Henry Franks on 2/6/17.
//  Copyright © 2017 Henry Franks. All rights reserved.
//

import Cocoa
import SpriteKit
import AVFoundation

var isBlue: Bool = true

enum GhostAction {
	// TODO: (21/08/18) Move all ghost states to this rather than different booleans
	case Chasing, Fleeing, Blue, GhostHouse
}

class Ghost: Sprite {
	let atlas: SKTextureAtlas
	let nameAsString: String
	var frameNo = 1
	var targetSquare: IntCoords
	let powerAtlas = SKTextureAtlas(named: "Power")
	var animationFrame = 1
	var animationFrameCounter = 0
	let scatterCoords: IntCoords
	let originCoords: IntCoords
	var waitCount: Int = 0
	let maxWait: Int
	var state: GhostAction = .GhostHouse
	let width: Double = 1.75 * squareWidth

	init(x: Int, y: Int, name: String, scatter: IntCoords, waitCount: Int) {
		self.maxWait = waitCount
		self.nameAsString = name
		self.scatterCoords = scatter
		self.atlas = SKTextureAtlas(named: name)
		self.originCoords = IntCoords(x: Int(x), y: Int(y))
		self.targetSquare = IntCoords(x: Int(x), y: Int(y))

		super.init(
			texture: self.atlas.textureNamed("\(name)U1"),
			size: CGSize(width: self.width, height: self.width),
			x: x, y: y, z: 3,
			bitMasks: [gamePhysics.Ghost,
					   gamePhysics.PacMan],
			speed: CGFloat(squareWidth) / 8
		)

		self.inSquare.x = squareWidth / 2

		self.updatePos()
		self.generateTexture()
	}

	func availableDirections(includesReverse: Bool) -> [Direction] {
		// up > left > down
		// Is this in the wrong order? - check with changeDirection()
		// FIXME: The ghosts all go out of ghost house through walls, I think it's this logic below that breaks it
		var directions = [Direction]()
		if !map.isWall(x: self.square.x, y: self.square.y + 1, includeGhostHouse: [.Chasing, .Blue].contains(self.state) && !self.currentSquare().ghostHouse) {
			directions.append(.up)
		}
		if !map.isWall(x: self.square.x - 1, y: self.square.y, includeGhostHouse: [.Chasing, .Blue].contains(self.state) && !self.currentSquare().ghostHouse) {
			directions.append(.left)
		}
		if !map.isWall(x: self.square.x, y: self.square.y - 1, includeGhostHouse: [.Chasing, .Blue].contains(self.state) && !self.currentSquare().ghostHouse) {
			directions.append(.down)
		}
		if !map.isWall(x: self.square.x + 1, y: self.square.y, includeGhostHouse: [.Chasing, .Blue].contains(self.state) && !self.currentSquare().ghostHouse) {
			directions.append(.right)
		}
		if !includesReverse {
			if let index = directions.firstIndex(of: ~self.direction) {
				directions.remove(at: index)
			}
		}
		return directions
	}

	func nextFrame() {
		if self.animationFrame == 2 {
			self.animationFrame = 1
		} else {
			self.animationFrame += 1
		}
		self.generateTexture()
	}

	func generateTexture() {
		self.animationFrameCounter = 0
		if self.state == .Fleeing {
			switch self.direction {
			case .up:
				self.texture = self.powerAtlas.textureNamed("eyesU")
			case .down:
				self.texture = self.powerAtlas.textureNamed("eyesD")
			case .left:
				self.texture = self.powerAtlas.textureNamed("eyesL")
			case .right:
				self.texture = self.powerAtlas.textureNamed("eyesR")
			}
		} else if self.state == .Blue {
			var name = "Ghost"
			if isBlue {
				name += "B"
			} else {
				name += "W"
			}
			self.texture = self.powerAtlas.textureNamed(name + String(self.animationFrame))
		} else {
			let nameAssignDict: [Direction: String] = [.up: "U", .down: "D", .left: "L", .right: "R"]
			self.texture = self.atlas.textureNamed(self.nameAsString + nameAssignDict[self.direction]! + String(self.animationFrame))
		}
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func changeDirection() {
		let available = self.availableDirections(includesReverse: false)
		if available.count == 0 {
			self.direction = ~self.direction
			self.hasChangedDirection = true
			return
		}

		var minDist: Double = 1000 //Larger than any possible value
		var toMove = self.direction
		for direction in available {
			var xDiff: Int = 0
			var yDiff: Int = 0

			switch self.state {
			case .Chasing:
				self.setTargetSquare()

			case .Fleeing:
				self.targetSquare = self.originCoords

			case .Blue:
				self.targetSquare = self.scatterCoords

			case .GhostHouse:
				break
			}

			switch direction {
			case .up:
				xDiff = self.square.x - self.targetSquare.x
				yDiff = self.square.y + 1 - self.targetSquare.y

			case .down:
				xDiff = self.square.x - self.targetSquare.x
				yDiff = self.square.y - 1 - self.targetSquare.y

			case .left:
				xDiff = self.square.x - 1 - self.targetSquare.x
				yDiff = self.square.y - self.targetSquare.y

			case .right:
				xDiff = self.square.x + 1 - self.targetSquare.x
				yDiff = self.square.y - self.targetSquare.y
			}
			let distance = sqrt(Double(xDiff^^2 + yDiff^^2))
			if distance < minDist {
				toMove = direction
				minDist = distance
			}
		}
		self.direction = toMove
		self.hasChangedDirection = true
		switch self.direction {
		case .up, .down:
			self.inSquare.x = 0
		case .left, .right:
			self.inSquare.y = 0
		}
	}

	func inSquareBounds(position: Double) -> Bool {
		return (1...2 ~= Int(10 * position / squareWidth))
	}

	func move() {
		// General movement function
		var spdAdj = spd

		switch self.state {
		case .GhostHouse:
			if self.direction == .up {
				if self.inSquare.y >= squareWidth {
					self.direction = .down
				}
			} else {
				self.direction = .down
				if self.inSquare.y <= 0 {
					self.waitCount += 1
					self.direction = .up
				}
			}
			spdAdj /= 2

			if self.waitCount == self.maxWait {
				self.state = .Chasing
				self.waitCount = 0
			}

		case .Chasing:
			if self.currentSquare().slow {
				spdAdj /= 2
			}

		case .Fleeing:
			if self.square == self.originCoords && self.inSquareBounds(position: self.inSquare.x) && self.inSquareBounds(position: self.inSquare.y) {
				self.state = .GhostHouse
				for ghost in ghosts {
					if ghost.state == .Fleeing {
						break
					}
				}

				// FIXME: This lags the game for a second - maybe use SKAction so it doesn't interfere with gameplay
				mainScene.initAudio(audio: &mainScene.audio, url: mainScene.bg1, loop: true, play: true)
			}

			if !self.currentSquare().slow {
				spdAdj *= 2
			} else {
				spdAdj /= 2
			}

		case .Blue:
			if !self.currentSquare().slow {
				spdAdj /= 1.5
			} else {
				spdAdj /= 2
			}
		}

		// Change direction if possible
		let available = self.availableDirections(includesReverse: false)
		if available.count > 0 && !self.hasChangedDirection {
			if ([.up, .down].contains(self.direction) && self.inSquareBounds(position: self.inSquare.y)) ||
				([.left, .right].contains(self.direction) && self.inSquareBounds(position: self.inSquare.x)) {
				self.changeDirection()
				self.generateTexture()
			}
		}

		// Move
		switch self.direction {
		case .up:
			self.inSquare.y += Double(spdAdj)
		case .down:
			self.inSquare.y -= Double(spdAdj)
		case .left:
			self.inSquare.x -= Double(spdAdj)
		case .right:
			self.inSquare.x += Double(spdAdj)
		}

		self.updateSquare()
		self.updatePos()

		if self.animationFrameCounter == 2 {
			self.nextFrame()
		} else {
			self.animationFrameCounter += 1
		}
	}

	func updatePos() {
		self.position.x = CGFloat(squareWidth * Double(self.square.x) + self.inSquare.x + origin.x)
		self.position.y = CGFloat(squareWidth * Double(self.square.y) + self.inSquare.y + origin.y)
	}

	func exitGhostHouseSquare() {
		if self.currentSquare().ghostHouse && self.state == .Chasing {
			var maxDist = 9999;
			var bestSquare: IntCoords? = nil
			for square in map.ghostHouseExits {
				let sqDist = (self.square.x - square.x)^^2 + (self.square.y - square.y)^^2
				if sqDist < maxDist {
					maxDist = sqDist
					bestSquare = IntCoords(x: square.x, y: square.y)
				}
			}
			if let best = bestSquare {
				self.targetSquare = best
			}
		}
	}

	func setTargetSquare() {
		self.targetSquare = pMan.square
		self.exitGhostHouseSquare()
	}
}

class Blinky: Ghost {

	init(x: Int, y: Int) {
		super.init(x: x, y: y, name: "Blinky", scatter: IntCoords(x: map.width - 1, y: map.width + 2), waitCount: 0)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class Pinky: Ghost {

	init(x: Int, y: Int) {
		super.init(x: x, y: y, name: "Pinky", scatter: IntCoords(x: 0, y: map.width + 2), waitCount: 15)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func setTargetSquare() {
		switch pMan.direction{
		case .up:
			self.targetSquare.x = pMan.square.x
			self.targetSquare.y = pMan.square.y + 4
		case .down:
			self.targetSquare.x = pMan.square.x
			self.targetSquare.y = pMan.square.y - 4
		case .left:
			self.targetSquare.x = pMan.square.x - 4
			self.targetSquare.y = pMan.square.y
		case .right:
			self.targetSquare.x = pMan.square.x + 4
			self.targetSquare.y = pMan.square.y
		}
		self.exitGhostHouseSquare()
	}
}

class Inky: Ghost {

	init(x: Int, y: Int) {
		super.init(x: x, y: y, name: "Inky", scatter: IntCoords(x: map.width - 1, y: 0), waitCount: 25)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func setTargetSquare() {
		var tempCoords = IntCoords(x: 0, y: 0)
		switch pMan.direction{
		case .up:
			tempCoords.x = pMan.square.x
			tempCoords.y = pMan.square.y + 2
		case .down:
			tempCoords.x = pMan.square.x
			tempCoords.y = pMan.square.y - 2
		case .left:
			tempCoords.x = pMan.square.x - 2
			tempCoords.y = pMan.square.y
		case .right:
			tempCoords.x = pMan.square.x + 2
			tempCoords.y = pMan.square.y
		}
		self.targetSquare.x = tempCoords.x + (tempCoords.x - blinky.square.x)
		self.targetSquare.y = tempCoords.y + (tempCoords.y - blinky.square.y)
		self.exitGhostHouseSquare()
	}
}

class Clyde: Ghost {
	var isNear: Bool = false

	init(x: Int, y: Int) {
		super.init(x: x, y: y, name: "Clyde", scatter: IntCoords(x: 0, y: 0), waitCount: 35)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func setTargetSquare() {
		if sqrt(Double(pMan.square.x^^2 + pMan.square.y^^2)) < 8 {
			self.targetSquare.x = 0
			self.targetSquare.y = 0
		} else {
			self.targetSquare.x = pMan.square.x
			self.targetSquare.y = pMan.square.y
		}
		self.exitGhostHouseSquare()
	}
}
