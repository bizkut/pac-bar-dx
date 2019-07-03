//
//  Wall.swift
//  Pac-Bar DX
//
//  Created by Henry Franks on 2/6/17.
//  Copyright © 2017 Henry Franks. All rights reserved.
//

import Cocoa
import SpriteKit

class Wall: SKSpriteNode {
	let byteString: String
	let wallString: String
	let square: Square
	let atlas = SKTextureAtlas(named: "Walls")
	var coords: IntCoords = IntCoords(x: 0, y: 0)
	var edge: Bool
	var facing: Direction? = nil

	init(forSquare: Square, x: Int, y: Int) {
		self.byteString = String(forSquare.data, radix: 2)
		self.square = forSquare
		self.coords = IntCoords(x: x, y: y)
		self.edge = forSquare.edge
		self.wallString = ""
		super.init(texture: self.atlas.textureNamed(self.wallString), color: .clear, size: CGSize(width: squareWidth, height: squareWidth))
		self.zPosition = 0
		self.updatePos()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func updatePos() {
		self.position.x = CGFloat(squareWidth * Double(self.coords.x) + origin.x)
		self.position.y = CGFloat(squareWidth * Double(self.coords.y) + origin.y)
	}

	func ease(x: Int, y: Int) -> Bool {
		return map.isWall(x: self.coords.x + x, y: self.coords.y + y)
	}

	func updateEdge() {
		var x = 0
		var y = 1
		while true {
			if ease(x: x, y: y) {
				break
			} else if self.coords.y + y == (map.squares.count / map.width) - 1 {
				self.edge = true
				return
			} else {
				y += 1
			}
		}
		x = 0
		y = -1
		while true {
			if ease(x: x, y: y) {
				break
			} else if self.coords.y + y == 0 {
				self.edge = true
				return
			} else {
				y -= 1
			}
		}
		x = -1
		y = 0
		while true {
			if ease(x: x, y: y) {
				break
			} else if self.coords.x + x == 0 {
				self.edge = true
				return
			} else {
				x -= 1
			}
		}
		x = 1
		y = 0
		while true {
			if ease(x: x, y: y) {
				break
			} else if self.coords.x + x == map.width - 1 {
				self.edge = true
				return
			} else {
				x += 1
			}
		}
		self.edge = false
	}

	enum curve {
		case straight, up, down, upextend, downextend, extend, leftend, upend, downend, none
	}

	func findCurve(edgeDir: Direction) -> curve {
		var grid = [Bool]()
		switch edgeDir {
		case .up:
			grid = [ease(x: self.coords.x - 1, y: self.coords.y), ease(x: self.coords.x, y: self.coords.y), ease(x: self.coords.x + 1, y: self.coords.y), ease(x: self.coords.x - 1, y: self.coords.y - 1), ease(x: self.coords.x, y: self.coords.y - 1), ease(x: self.coords.x + 1, y: self.coords.y - 1)]
		case .down:
			grid = [ease(x: self.coords.x + 1, y: self.coords.y), ease(x: self.coords.x, y: self.coords.y), ease(x: self.coords.x - 1, y: self.coords.y), ease(x: self.coords.x + 1, y: self.coords.y + 1), ease(x: self.coords.x, y: self.coords.y + 1), ease(x: self.coords.x - 1, y: self.coords.y + 1)]
		case .left:
			grid = [ease(x: self.coords.x, y: self.coords.y - 1), ease(x: self.coords.x, y: self.coords.y), ease(x: self.coords.x, y: self.coords.y + 1), ease(x: self.coords.x + 1, y: self.coords.y - 1), ease(x: self.coords.x + 1, y: self.coords.y), ease(x: self.coords.x + 1, y: self.coords.y + 1)]
		case.right:
			grid = [ease(x: self.coords.x, y: self.coords.y + 1), ease(x: self.coords.x, y: self.coords.y), ease(x: self.coords.x, y: self.coords.y - 1), ease(x: self.coords.x - 1, y: self.coords.y + 1), ease(x: self.coords.x - 1, y: self.coords.y), ease(x: self.coords.x + 1, y: self.coords.y - 1)]
		}

		/* Grid Layout:
		*
		* [3][0]    |
		* [4][1] -> edge
		* [5][2]    |
		*
		*/
		if grid[0] && grid[2] {
			if grid[4] {
				if grid[5] {
					return curve.upextend
				} else if grid[3] {
					return curve.downextend
				} else {
					return curve.extend
				}
			} else {
				return curve.straight
			}
		} else if grid[4] {
			if grid[0] {
				return curve.up
			} else if grid[2] {
				return curve.down
			} else {
				return curve.upend
			}
		} else if grid[0] {
			return curve.upend
		} else if grid[2] {
			return curve.downend
		} else {
			return curve.none
		}
	}

	func setEdgeTexture(edgeDirection: Direction) {
		let curve = self.findCurve
		switch curve {
			// Add all 10 primary cases with 4 switch statements in each except none (37 total textures) - GOOD LUCK!
		default:
			break
		}
	}

	func updateTexture() {
		let adjacent = [
			ease(x: -1, y: 1),  ease(x: 0, y: 1),  ease(x: 1, y: 1),
			ease(x: -1, y: 0),                     ease(x: 1, y: 0),
			ease(x: -1, y: -1), ease(x: 0, y: -1), ease(x: 1, y: -1)
		]
		/*var binaryString: String = ""
		for tile in adjacent {
			binaryString.append(String(describing: NSNumber(booleanLiteral: tile)))
		}*/
		// TODO: Source/Dest system
		let isEdge = self.coords.x == 0 || self.coords.x == map.width - 1 || self.coords.y == 0 || self.coords.y == (map.squares.count / map.width) - 1
		self.edge = isEdge
		let U = adjacent[1]
		let D = adjacent[6]
		let L = adjacent[3]
		let R = adjacent[4]
		let UD = U && D
		let LR = L && R

		if UD && LR {
			if !adjacent[0] {
				if self.edge {
					if self.coords.x == map.width - 1 {
						self.texture = SKTexture(imageNamed: "UL2")
					} else if self.coords.y == 0 {
						self.texture = SKTexture(imageNamed: "UL3")
					} else {
						self.texture = SKTexture(imageNamed: "UL1")
					}
				} else {
					self.texture = SKTexture(imageNamed: "UL")
				}
			} else if !adjacent[2] {
				if self.edge {
					if self.coords.x == 0 {
						self.texture = SKTexture(imageNamed: "UR2")
					} else if self.coords.y == 0 {
						self.texture = SKTexture(imageNamed: "UR3")
					} else {
						self.texture = SKTexture(imageNamed: "UR1")
					}
				} else {
					self.texture = SKTexture(imageNamed: "UR")
				}
			} else if !adjacent[5] {
				if self.edge {
					if self.coords.x == map.width - 1 {
						self.texture = SKTexture(imageNamed: "DL2")
					} else if self.coords.y == (map.squares.count / map.width) - 1 {
						self.texture = SKTexture(imageNamed: "DL3")
					} else {
						self.texture = SKTexture(imageNamed: "DL1")
					}
				} else {
					self.texture = SKTexture(imageNamed: "DL")
				}
			} else if !adjacent[7] {
				if self.edge {
					if self.coords.x == 0 {
						self.texture = SKTexture(imageNamed: "DR2")
					} else if self.coords.y == (map.squares.count / map.width) - 1 {
						self.texture = SKTexture(imageNamed: "DR3")
					} else {
						self.texture = SKTexture(imageNamed: "DR1")
					}
				} else {
					self.texture = SKTexture(imageNamed: "DR")
				}
			} else {
				self.removeFromParent()
			}
		} else if UD {
			if L {
				if self.edge {
					self.texture = SKTexture(imageNamed: "L1")
				} else {
					self.texture = SKTexture(imageNamed: "L")
				}
			} else if R {
				if self.edge {
					self.texture = SKTexture(imageNamed: "R1")
				} else {
					self.texture = SKTexture(imageNamed: "R")
				}
			} else {
				if self.edge {
					print("test")
				}
				self.texture = SKTexture(imageNamed: "LR")
			}
		} else if LR {
			if U {
				if self.edge {
					self.texture = SKTexture(imageNamed: "U1")
				} else {
					self.texture = SKTexture(imageNamed: "U")
				}
			} else if D {
				if self.edge {
					self.texture = SKTexture(imageNamed: "D1")
				} else {
					self.texture = SKTexture(imageNamed: "D")
				}
			} else {
				if self.edge {
					print("test")
				}
				self.texture = SKTexture(imageNamed: "UD")
			}
		} else if U {
			if L {
				if self.edge {
					self.texture = SKTexture(imageNamed: "UL1")
				} else {
					self.texture = SKTexture(imageNamed: "UL")
				}
			} else if R {
				if self.edge {
					self.texture = SKTexture(imageNamed: "UR1")
				} else {
					self.texture = SKTexture(imageNamed: "UR")
				}
			} else {
				self.texture = SKTexture(imageNamed: "U2")
			}
		} else if D {
			if L {
				if self.edge {
					self.texture = SKTexture(imageNamed: "DL1")
				} else {
					self.texture = SKTexture(imageNamed: "DL")
				}
			} else if R {
				if self.edge {
					self.texture = SKTexture(imageNamed: "DR1")
				} else {
					self.texture = SKTexture(imageNamed: "DR")
				}
			} else {
				self.texture = SKTexture(imageNamed: "D2")
			}
		} else if L {
			self.texture = SKTexture(imageNamed: "L2")
		} else if R {
			self.texture = SKTexture(imageNamed: "R2")
		} else {
			self.removeFromParent()
		}
	}
}
