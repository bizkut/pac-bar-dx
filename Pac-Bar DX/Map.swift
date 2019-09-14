//
//  Map.swift
//  Pac-Bar DX
//
//  Created by Henry Franks on 2/6/17.
//  Copyright © 2017 Henry Franks. All rights reserved.
//

import Cocoa

var map: Map!
var data: MapData!
let fileExt = "pacmap"
let squareWidth: Double = 8

enum MapError: Error {
	// For errors relating to the map
	case badGrid // If the grid provided isn't fit for use
	case badPath // If the path to map file is invalid
	case invalidSignature // If the signature is invalid
	case cannotGenerateMap // For problems generating the map
	case outOfRange
}

struct Square {
	let data: UInt8
	let wall: Bool
	let dot: Bool
	let power: Bool
	let slow: Bool
	let fruit: Bool
	let ghostHouse: Bool
	var edge: Bool = false

	init(for byte: UInt8) {
		// Checking with bit masks for each wall in the data
		data = byte

		self.slow = byte & 0b10000000 != 0
		self.wall = byte & 0b01000000 != 0
		if self.wall {
			self.dot = false
			self.power = false
			self.fruit = false
			self.ghostHouse = byte & 0b00100000 != 0
		} else {
			self.ghostHouse = false
			self.dot = byte & 0b00100000 != 0
			if self.dot {
				self.fruit = false
				self.power = byte & 0b00010000 != 0
			} else {
				self.power = false
				self.fruit = byte & 0b00010000 != 0
			}
		}
	}
}

struct Scroll {
    var vertical: Bool
    var horizontal: Bool

	init() {
        self.vertical = true
        self.horizontal = true
	}
}

struct Map {
	let width: Int
	let height: Int
	var squares = [Square]()
	var isScrolling: Scroll = Scroll()
	var ghostHouseExits = [IntCoords]()

	init(w: Int, grid: [Square]) throws {
		// ***TEMP FIX***
		if w == 0 {
			self.width = 0
			self.height = 0
			return
		}
		// **END OF FIX**
		self.width = w
		self.height = grid.count / self.width
		// If the grid isn't a perfect rectangle, throw
		if w == 0 || grid.count % w != 0 {
			throw MapError.badGrid
		}
		var endIndex: Int = 0
		var startIndex: Int = grid.count
		while self.squares.count != grid.count {
			// WHAT DOES THIS DO?
			endIndex = startIndex - 1
			startIndex = endIndex - w + 1
			self.squares += grid[startIndex...endIndex]
		}

		// Find walls which are edges
		// TODO: There are a lot of calls to self.squares[y * self.width + x] here which could probably be reduced
		for y in 0..<self.height {
			for x in 0..<self.width {
				if !self.squares[y * self.width + x].wall {
					break
				}
				self.squares[y * self.width + x].edge = true
			}

			if !self.squares[(y + 1) * self.width - 1].edge {
				for x in (0..<self.width).reversed() {
					if self.squares[y * self.width + x].edge || !self.squares[y * self.width + x].wall {
						break
					}
					self.squares[y * self.width + x].edge = true
				}
			}
		}

		// Find exits to the ghost house
		// This is a hack currently that should be reworked with proper map data for exits
		for (i, square) in self.squares.enumerated() {
			if square.ghostHouse {
				var available = [Square]()

				if i > 0 {
					available.append(self.squares[i - 1])
				}
				if i < self.squares.count - 1 {
					available.append(self.squares[i + 1])
				}
				if i > w - 1 {
					available.append(self.squares[i - w])
				}
				if i < self.squares.count - w {
					available.append(self.squares[i + w])
				}

				for adjacent in available {
					if !adjacent.wall && !adjacent.ghostHouse {
						let x: Int = i % w
						ghostHouseExits.append(IntCoords(x: x, y: (i - x) / w))
						break
					}
				}
			}
		}
	}

	func squareWithCoords(x: Int, y: Int) -> Square? {
		// TODO: This should use IntCoords input
		let index =	(y * self.width) + x
		if 0 <= index && index < squares.count {
			return squares[index]
		} else {
			return nil
		}
	}

	func isWall(x: Int, y: Int, includeGhostHouse: Bool = false) -> Bool {
		if let testSquare = self.squareWithCoords(x: x, y: y) {
			if includeGhostHouse {
				return testSquare.wall || testSquare.ghostHouse
			} else {
				return testSquare.wall
			}
		} else {
			return true
		}
	}

	// TODO: Move availableDirections function to here
}

struct MapData {
	let width: UInt8
	let height: UInt8
	let map: Map

	init(from: String) throws {
        if let data = NSData(contentsOfFile: from) {
			var buffer = [UInt8](repeating: 0, count: data.length)
			data.getBytes(&buffer, length: data.length)
			var bytes: [UInt8] = buffer
			width = bytes[3]
			height = bytes[4]
			var squares = [Square]()
			for byte in Array(bytes.dropFirst(7)) {
				squares.append(Square(for: byte))
			}
			do {
				self.map = try Map(w: Int(self.width), grid: squares)
			} catch {
				throw MapError.cannotGenerateMap
			}
		} else {
			throw MapError.badPath
		}
	}
}
