//
//  DebugReticle.swift
//  Pac-Bar DX
//
//  Created by Henry Franks on 14/09/2019.
//  Copyright © 2019 Henry Franks. All rights reserved.
//

import Cocoa
import SpriteKit

class DebugReticle: SKSpriteNode {
	var coords: IntCoords

	init(name: String) {
		self.coords = IntCoords(x: 0, y: 0)

		var textureName: String = ""

		switch name {
		case "Blinky":
			textureName = "BlinkyReticle"
		case "Pinky":
			textureName = "PinkyReticle"
		case "Inky":
			textureName = "InkyReticle"
		case "Clyde":
			textureName = "ClydeReticle"
		default:
			textureName = "Blinky"
		}

		super.init(texture: SKTexture(imageNamed: textureName), color: .clear, size: CGSize(width: squareWidth, height: squareWidth))
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func update() {
		self.position = CGPoint(
			x: CGFloat(squareWidth * Double(self.coords.x) + origin.x),
			y: CGFloat(squareWidth * Double(self.coords.y) + origin.y)
		)
	}
}
