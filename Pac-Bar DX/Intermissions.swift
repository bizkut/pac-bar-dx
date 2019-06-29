//
//  Intermissions.swift
//  Pac-Bar DX
//
//  Created by Henry Franks on 27/12/17.
//  Copyright © 2017 Henry Franks. All rights reserved.
//

import Cocoa
import SpriteKit
import AVFoundation

class Intermission: SKScene, SKPhysicsContactDelegate {
	override func didMove(to view: SKView) {
		super.didMove(to: view)
		self.scaleMode = .resizeFill
		self.backgroundColor = .black
		physicsWorld.contactDelegate = self
		let border = SKPhysicsBody(edgeLoopFrom: self.frame)
		border.friction = 0
		self.physicsBody = border
		self.addChild(pMan)
	}

	override func update(_ currentTime: TimeInterval) {

	}
}

class Intermission1: Intermission {

}
