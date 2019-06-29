//
//  Fruit.swift
//  Pac-Bar DX
//
//  Created by Henry Franks on 29/9/17.
//  Copyright © 2017 Henry Franks. All rights reserved.
//

import Cocoa
import SpriteKit

class Fruit: SKSpriteNode {
	let type: String
	let atlas = SKTextureAtlas(named: "Fruit")
	let square: IntCoords
	var globalPos: Coords = Coords(x: 0, y: 0)
	let inSquare = Coords(x: squareWidth - 1, y: squareWidth / 2 - 4)
	var timer: Int = 0
	let points: Int

	init(x: Int, y: Int, type: String) {
		self.type = type
		self.square = IntCoords(x: Int(x), y: Int(y))
		self.points = {
			switch type {
			case "Cherry": return 100
			case "Strawberry": return 300
			case "Orange": return 500
			case "Apple": return 700
			case "Melon": return 1000
			case "Galaxian": return 2000
			case "Bell": return 3000
			case "Key": return 5000
			default: return 100
			}
		}()
		super.init(texture: self.atlas.textureNamed(type), color: .clear, size: CGSize(width: 14, height: 14))
		self.globalPos = Coords(x: squareWidth * Double(self.square.x) + self.inSquare.x, y: squareWidth * Double(self.square.y) + self.inSquare.y)
		self.physicsBody = SKPhysicsBody(rectangleOf: self.size)
		self.physicsBody?.categoryBitMask = gamePhysics.Fruit
		self.physicsBody?.contactTestBitMask = gamePhysics.PacMan
		self.physicsBody?.isDynamic = false
		self.physicsBody?.affectedByGravity = false
		self.updatePos()
	}

	func updatePos() {
		self.position.x = CGFloat(squareWidth * Double(self.square.x) + self.inSquare.x + origin.x)
		self.position.y = CGFloat(squareWidth * Double(self.square.y) + self.inSquare.y + origin.y)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
