//
//  Definitions.swift
//  Pac-Bar DX
//
//  Created by Henry Franks on 02/07/2019.
//  Copyright © 2019 Henry Franks. All rights reserved.
//

// This file contains all the structs, operators, etc. used in the project

import Foundation

// For integer indices
precedencegroup PowerPrecedence {
	higherThan: MultiplicationPrecedence
}
infix operator ^^ : PowerPrecedence
func ^^ (radix: Int, power: Int) -> Int {
	return Int(pow(Double(radix), Double(power)))
}

// *** TODO: Remove any of these that aren't needed
func +(left: Coords, right: Coords) -> Coords {
	return Coords(x: left.x + right.x, y: left.y + right.y)
}

func -(left: Coords, right: Coords) -> Coords {
	return Coords(x: left.x - right.x, y: left.y - right.y)
}

// Opposite direction operator (looks nicer than function - but reduces readability)
// --> see .inverse() function in direction class
prefix operator ~
prefix func ~ (direction: Direction) -> Direction {
	switch direction {
	case .up:
		return .down
	case .down:
		return .up
	case .left:
		return .right
	case .right:
		return .left
	}
}

struct Coords {
	// Is this necessary? Maybe add some appropriate (and used) functions to make it worth having, otherwise it's useless
	var x: Double = 0
	var y: Double = 0

	init(x: Double, y: Double) {
		self.x = x
		self.y = y
	}

	init(x: Int, y: Int) {
		self.x = Double(x)
		self.y = Double(y)
	}
}

struct IntCoords: Equatable {
	var x: Int
	var y: Int

	init(x: Int, y: Int) {
		self.x = x
		self.y = y
	}

	static func ==(lhs: IntCoords, rhs: IntCoords) -> Bool {
		return lhs.x == rhs.x && lhs.y == rhs.y
	}
}

var highScore: Int {
	set {
		UserDefaults.standard.set(newValue, forKey: "highScore")
		UserDefaults.standard.synchronize()
	}

	get {
		return UserDefaults.standard.object(forKey: "highScore") as? Int ?? 0
	}
}

struct gamePhysics {
	static let PacMan: UInt32 = 1 << 0
	static let Dot: UInt32 = 1 << 1
	static let Ghost: UInt32 = 1 << 2
	static let Wall: UInt32 = 1 << 3
	static let Fruit: UInt32 = 1 << 4
}

enum Direction {
	case up, down, left, right

	func inverse() -> Direction {
		// I don't know if I should use this or an operator but I've put this here anyway
		switch self {
		case .up:
			return .down
		case .down:
			return .up
		case .left:
			return .right
		case .right:
			return .left
		}
	}
}
