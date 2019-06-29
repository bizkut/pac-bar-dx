//
//  Sprite.swift
//  Pac-Bar DX
//
//  Created by Henry Franks on 3/8/17.
//  Copyright © 2017 Henry Franks. All rights reserved.
//

import Cocoa
import SpriteKit

class Sprite: SKSpriteNode {
	var square: IntCoords
	var inSquare: Coords = Coords(x: squareWidth, y: squareWidth/2)
	var globalPos: Coords
	var direction: Direction = .up
	var hasChangedDirection: Bool = false
	var spd: CGFloat

	init(texture: SKTexture, size: CGSize, x: Int, y: Int, z: CGFloat, bitMasks: [UInt32], speed: CGFloat) {
		self.square = IntCoords(x: x, y: y)
		self.globalPos = Coords(x: squareWidth * Double(self.square.x) + self.inSquare.x, y: squareWidth * Double(self.square.y) + self.inSquare.y)
		self.spd = speed
		super.init(texture: texture, color: .clear, size: size)
		self.zPosition = z
		self.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: self.size.width / 3, height: self.size.height / 3))
		self.physicsBody!.isDynamic = true
		self.physicsBody!.affectedByGravity = false
		self.physicsBody!.categoryBitMask = bitMasks[0]
		self.physicsBody!.contactTestBitMask = bitMasks[1]
		self.physicsBody!.collisionBitMask = 0
        self.texture!.filteringMode = .linear
	}

	func updateSquare() {
		// Re-evaluting which square the sprite is in
		if self.inSquare.x > Double(squareWidth) {
			self.square.x += 1
			self.inSquare.x -= Double(squareWidth)
			self.hasChangedDirection = false
		} else if self.inSquare.x < 0 {
			self.square.x -= 1
			self.inSquare.x += Double(squareWidth)
			self.hasChangedDirection = false
		}

		if self.inSquare.y > Double(squareWidth) {
			self.square.y += 1
			self.inSquare.y -= Double(squareWidth)
			self.hasChangedDirection = false
		} else if self.inSquare.y < 0 {
			self.square.y -= 1
			self.inSquare.y += Double(squareWidth)
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
		self.globalPos = Coords(x: squareWidth * Double(self.square.x) + self.inSquare.x, y: squareWidth * Double(self.square.y) + self.inSquare.y)
	}

	func currentSquare() -> Square {
		if let square = map.squareWithCoords(x: self.square.x, y: self.square.y) {
			return square
		} else {
			NSLog("Error: Index out of range, returning empty square")
			return Square(for: 0)
		}
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
