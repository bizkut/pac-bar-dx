//
//  GameScene.swift
//  Pac-Bar DX
//
//  Created by Henry Franks on 1/6/17.
//  Copyright © 2017 Henry Franks. All rights reserved.
//

/* TODO:
 * === FEATURES ==
 * Intermissions | IN PROGRESS
 * Finish scatter/chase
 *  --> Cruise Elroy
 * Make 'you need a touch bar' text 8-bit
 * Pac-Man speeds per level (e.g. level 1 is 80% of base speed)
 * http://www.gamasutra.com/db_area/images/feature/3938/tablea1.png
 *
 * FILE COMPRESSION
 * * If a block is repeated, have a bit flag for repetition and then use other 7 bits for number of repetitions - 1
 * * e.g. 00000111 = Bit mask 00000001 for repeat and 11111110 for number
 * * +-> Gives 4 repeats of previous block (0b11 + 1 because having one repeat is useless)
 *
 * === GRAPHICS ===
 * Use spritesheets for textures
 * Re-draw all sprites @2x
 * Add black screen for use on resets
 * Re-export app icons straight from pikopixel @ right sizes to avoid blur
 *
 * === CODE ===
 * Comments
 * Create a Sprite (or similar) class that ghosts and Pac-Man all inherit from - could this control movement and square handling? | IN PROGRESS
 * Check animation/sound/timing values
 * Review/test ghost behaviour
 * Create withinBounds function to check if one param is within +/-value of another - abs of difference
 * Cache audio ahead of time e.g. cache next eating sound after one's played
 * Replace throwing calls with optional returns
 * See if protocols can be used instead of classes? for ghosts?
 *
 * Map
 * * Add checks to the map to make sure it is valid for use
 * * Re-work tile data structure
 * * Map file checksum and signature (at top, for filetype)
 * * Add version number (of file data/extension, not file itself) to files (1.0 for now)
 *
 * Refactor
 * * Look at different parameter/internal function variable names e.g. with event
 * * Cleanup
 * * Could coords be replaced with two variables?
 * * Change all variable names from [adj] to is[adj] / [attr] to has[attr]
 * * Classes -> Protocols?
 *
 * === BUGS ===
 * * Ghosts can turn blue while in ghost house and get stuck |* should be fixed -- check
 * * Elliptical Pac-Man | MAYBE FIXED??
 * * Ghosts can go through pac man: e.g. go left then immediately down and wait - blinky should pass right over you
 * * Blinky's position doesn't reset when pacman dies
 *
 * === ADDITIONAL DEBUG OPTIONS ===
 * * * Control all these via buttons or keys? e.g. numbers 1-9 toggle options in debug mode like m key for mute
 * * Invincibility
 * * Move anywhere
 * * Free camera / no pacman
 */

/* MAP CO-ORDINATES
 * +y: up
 * +x: right
 */

import Cocoa
import SpriteKit
import AVFoundation

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

// --- View dimensions: 30x685 ---

var frameNo: Int = 0

var mute: Bool = UserDefaults.standard.object(forKey: "mute") as? Bool ?? false

var origin: Coords = Coords(x: 0, y: 0)

var powerTimer: Int = 0
var canResume = false
var introPlaying = false
var level = 0

var gfruits = [Fruit]()
var pMan: PacMan!
var blinky: Blinky!
var pinky: Pinky!
var inky: Inky!
var clyde: Clyde!
var dots = [Dot]()
var walls = [Wall]()
var ghostsEaten: Int = 0
var lives = 2
var gameOver: Bool = false
let ghosts = [blinky, pinky, inky, clyde] as [Ghost]
var hasStarted = false
var newLevel = true
var white = false
var whiteTimer = 0
var prevScore = 0

// Debug
var gameMode: Int = 0
// GAMEMODE
// 0 - normal gameplay
// 1 - invulnerability
// 2 - no pac-man, free control over map

var debugLabel = SKLabelNode(text: "DEBUG MODE\n\n\n\n")
var blinkyDebug = SKLabelNode(text: "")
var pinkyDebug = SKLabelNode(text: "")
var inkyDebug = SKLabelNode(text: "")
var clydeDebug = SKLabelNode(text: "")

var blinkyReticle = SKSpriteNode(imageNamed: "BlinkyReticle")
var pinkyReticle = SKSpriteNode(imageNamed: "PinkyReticle")
var inkyReticle = SKSpriteNode(imageNamed: "InkyReticle")
var clydeReticle = SKSpriteNode(imageNamed: "ClydeReticle")

var mainScene = GameScene(size: CGSize(width: 685, height: 30))

func checkWall(direction: Direction, currentCoords: IntCoords) -> Bool {
	switch direction {
	case .up:
		return map.isWall(x: currentCoords.x, y: currentCoords.y + 1)
	case .down:
		return map.isWall(x: currentCoords.x, y: currentCoords.y - 1)
	case .left:
		return map.isWall(x: currentCoords.x - 1, y: currentCoords.y)
	case .right:
		return map.isWall(x: currentCoords.x + 1, y: currentCoords.y)
	}
}

func getPossibleDirections(coords: IntCoords) -> [Direction] {
	var returnArray = [Direction]()
	for direction in [Direction.up, Direction.down, Direction.left, Direction.right] {
		if checkWall(direction: direction, currentCoords: coords) {
			returnArray.append(direction)
		}
	}
	return returnArray
}

var score: Int = 0

class GameScene: SKScene, SKPhysicsContactDelegate { // TODO: Look into body with edge loop
	// TODO: add init and move setup to there, only add stuff that needs to be in didmovetoview there
	let intro = URL(fileURLWithPath: Bundle.main.path(forResource: "intro", ofType: "wav")!)
	let powerSound = URL(fileURLWithPath: Bundle.main.path(forResource: "power", ofType: "wav")!)
	let bg1 = URL(fileURLWithPath: Bundle.main.path(forResource: "siren slow", ofType: "wav")!)
	let bg2 = URL(fileURLWithPath: Bundle.main.path(forResource: "siren medium", ofType: "wav")!)
	let bg3 = URL(fileURLWithPath: Bundle.main.path(forResource: "siren fast", ofType: "wav")!)
	let fleeing = URL(fileURLWithPath: Bundle.main.path(forResource: "ghost eaten", ofType: "wav")!)
	let deathSound = URL(fileURLWithPath: Bundle.main.path(forResource: "death", ofType: "wav")!)
	let eatGhostSound = URL(fileURLWithPath: Bundle.main.path(forResource: "eat ghost", ofType: "wav")!)
	var audio = AVAudioPlayer() // Using AVAudioPlayer to play the intro music while the scene is paused
	var secondaryAudio = AVAudioPlayer() // SFX that play over main audio
	var ghostCache: Ghost?
	var gameOverHasRun = false
	let textNode = SKSpriteNode(texture: SKTexture(imageNamed: "Ready!"), color: .clear, size: CGSize(width: 56, height: 16))
	let effect = SKEffectNode()
	var thresh1 = 0
	var thresh2 = 0

	var levelFruit: [String] = []
	let newFruit = ["Cherry", "Strawberry", "Orange", "Orange", "Apple", "Apple", "Melon", "Melon", "Galaxian", "Galaxian", "Bell", "Bell", "Key", "Key", "Key", "Key", "Key", "Key", "Key", "Key"]

	func drawMap(map: Map) {
		var x: Int = 0
		var y: Int = 0
		for square in map.squares {
			walls.append(Wall(forSquare: square, x: x, y: y))
			x += 1
			if x > map.width {
				x = 0
				y += 1
			}
		}
	}

	func initAudio(audio: inout AVAudioPlayer, url: URL, loop: Bool, play: Bool) {
		do {
			audio = try AVAudioPlayer(contentsOf: url)
			if mute {
				audio.volume = 0
			}
			if loop {
				audio.numberOfLoops = -1
			}
			audio.prepareToPlay()
			if play {
				audio.play()
			}
		} catch {
			NSLog("Error Loading Audio File '\(url)': \(error)")
		}
	}

	func updateLabel(_ value: String) {
		textField!.stringValue = value
	}

	func updateScore() {
		let scoreChars = Array(String(score))
		var lim = 6
		if scoreChars.count < 6 {
			lim = scoreChars.count
		}
		for i in lim...6 {
			if i == 1 || i == 2 {
				scoreTiles[i - 1].image = NSImage(named: "0")
			} else {
				scoreTiles[i - 1].image = nil
			}
		}
		for i in 1...lim {
			scoreTiles[i - 1].image = NSImage(named: String(scoreChars[scoreChars.count - i]))
		}
		if score > 10000 && prevScore < 10000 {
			lives += 1
			pMan.run(pMan.extraLife)
			livesTiles[(lives - 1)].image = NSImage(named: "Life")
		}
		prevScore = score
		if score > highScore {
			highScore = score
			for i in 1...lim {
				highScoreTiles[i - 1].image = NSImage(named: String(scoreChars[scoreChars.count - i]))
			}
		}
	}

	override func update(_ currentTime: TimeInterval) {
		if gameOver {
			if self.audio.url! == self.deathSound {
				return
			}
			pMan.deathFrames()
		} else if whiteTimer > 0 {
			if whiteTimer == 9 {
				usleep(500000)
			}
			whiteTimer -= 1
			if white {
				self.effect.filter?.setValue(0, forKey: kCIInputBrightnessKey)
			} else {
				self.effect.filter?.setValue(1, forKey: kCIInputBrightnessKey)
			}
			if whiteTimer > 0{
				white = !white
			} else {
				white = false
				self.reset()
			}
			usleep(200000)
		} else {
			self.updateScore()
			frameNo += 1
			pMan.move()

			for ghost in ghosts {
				ghost.move()
			}

			for f in gfruits {
				f.updatePos()
				if f.timer > 0 {
					f.timer -= 1
					if f.timer == 0 {
						f.removeFromParent()
					}
				}
			}

			for wall in walls {
				wall.updatePos()
			}

			for dot in dots {
				dot.update()
			}

			if powerTimer > 0 {
				if powerTimer < 100 {
					if powerTimer % 10 == 0 {
						isBlue = !isBlue
					}
				} else {
					isBlue = true
				}
				powerTimer -= 1
				if self.audio.url! != self.powerSound && self.audio.url! != self.fleeing {
					self.initAudio(audio: &self.audio, url: self.powerSound, loop: true, play: true)
				}
			} else {
				for ghost in ghosts {
					if ghost.state == .Blue {
						ghost.state = .Chasing
					}
				}
				if ![self.bg1, self.bg2, self.bg3].contains(self.audio.url!) {
					let remaining = dots.filter{$0.parent != nil}.count
					if remaining <= self.thresh2 {
						self.initAudio(audio: &self.audio, url: self.bg3, loop: true, play: true)
					} else if remaining <= self.thresh1 {
						self.initAudio(audio: &self.audio, url: self.bg2, loop: true, play: true)
					} else {
						self.initAudio(audio: &self.audio, url: self.bg1, loop: true, play: true)
					}
				}
			}

			if ghostCache != nil {
				eatGhost()
				// TODO: Change ghost fleeing direction -- check with game footage first
				ghostCache?.state = .Fleeing
				ghostCache = nil
			}

			if debug {
				debugLabel.text = String(format: "DEBUG MODE\nGame Mode %d\nLevel %2d\nPower Timer: %3d\n", gameMode, level, powerTimer)
				blinkyDebug.text = "BLINKY | State: \(blinky.state) | Wait Timer: \(blinky.waitCount) | Pos: \(blinky.square.x), \(blinky.square.y)"
				pinkyDebug.text = "PINKY  | State: \(pinky.state) | Wait Timer: \(pinky.waitCount) | Pos: \(pinky.square.x), \(pinky.square.y)"
				inkyDebug.text = "INKY   | State: \(inky.state) | Wait Timer: \(inky.waitCount) | Pos: \(inky.square.x), \(inky.square.y)"
				clydeDebug.text = "CLYDE  | State: \(clyde.state) | Wait Timer: \(clyde.waitCount) | Pos: \(clyde.square.x), \(clyde.square.y)"

				blinkyReticle.position = CGPoint(x: CGFloat(squareWidth * Double(blinky.targetSquare.x) + origin.x),
												 y: CGFloat(squareWidth * Double(blinky.targetSquare.y) + origin.y))
				pinkyReticle.position = CGPoint(x: CGFloat(squareWidth * Double(pinky.targetSquare.x) + origin.x),
												 y: CGFloat(squareWidth * Double(pinky.targetSquare.y) + origin.y))
				inkyReticle.position = CGPoint(x: CGFloat(squareWidth * Double(inky.targetSquare.x) + origin.x),
												 y: CGFloat(squareWidth * Double(inky.targetSquare.y) + origin.y))
				clydeReticle.position = CGPoint(x: CGFloat(squareWidth * Double(clyde.targetSquare.x) + origin.x),
												 y: CGFloat(squareWidth * Double(clyde.targetSquare.y) + origin.y))
			}
		}
	}

	func eatGhost() {
		if mute {
			self.secondaryAudio.volume = 0
		} else {
			self.secondaryAudio.volume = 1
		}
		self.secondaryAudio.play()
		while self.secondaryAudio.isPlaying {
			// FIXME: This is atrocious
			continue
		}
		if !(self.audio.url == self.fleeing && self.audio.isPlaying) {
			self.initAudio(audio: &self.audio, url: self.fleeing, loop: true, play: true)
		}
		pMan.alpha = 1
		self.scene?.isPaused = false
	}

	func didBegin(_ contact: SKPhysicsContact) {
		if gameMode == 2 {
			return
		}

		let contactMask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
		switch contactMask {
		case gamePhysics.PacMan | gamePhysics.Dot:
			if let dot = contact.bodyA.node as? Dot {
				if dot.isPower {
					score += 50
					for ghost in ghosts {
						if ghost.state == .Chasing && !map.squareWithCoords(x: ghost.square.x, y: ghost.square.y)!.ghostHouse {
							ghost.state = .Blue
							if ghost.availableDirections(includesReverse: true).contains(~ghost.direction) {
								ghost.direction = ~ghost.direction
							}
						}
					}
					ghostsEaten = 0
					powerTimer = 600
				} else {
					score += 10
				}
				dot.remove()
				let remaining = dots.filter{$0.parent != nil}.count
				let eaten = dots.count - remaining
				if eaten == 70 || eaten == 170 {
					for f in gfruits {
						if f.parent == nil {
							f.size = CGSize(width: 14, height: 14)
							f.texture = f.atlas.textureNamed(f.type)
							self.addChild(f)
						}
						f.timer = 600
					}
				}

				if [self.bg1, self.bg2].contains(self.audio.url!) {
					if remaining == self.thresh2 {
						blinky.spd *= 1.05
						self.initAudio(audio: &self.audio, url: self.bg3, loop: true, play: true)
					} else if remaining == self.thresh1 {
						blinky.spd *= 1.05
						self.initAudio(audio: &self.audio, url: self.bg2, loop: true, play: true)
					}
				}

				if remaining == 0 {
					level += 1
					for ghost in ghosts {
						ghost.removeFromParent()
					}
					self.audio.stop()
					self.secondaryAudio.stop()
					pMan.texture = pMan.frames[2]
					whiteTimer = 9
				}
			}
		case gamePhysics.PacMan | gamePhysics.Ghost:
			if gameMode == 1 {
				break
			}
			if let ghost = contact.bodyB.node as? Ghost {
				if ghost.state == .Blue {
					ghost.size = CGSize(width: (8/7) * ghost.width, height: (8/7) * ghost.width)
					switch ghostsEaten {
					case 0:
						ghost.texture = ghost.powerAtlas.textureNamed("200pts")
						score += 200
					case 1:
						ghost.texture = ghost.powerAtlas.textureNamed("400pts")
						score += 400
					case 2:
						ghost.texture = ghost.powerAtlas.textureNamed("800pts")
						score += 800
					default:
						ghost.texture = ghost.powerAtlas.textureNamed("1600pts")
						score += 1600
					}
					pMan.alpha = 0
					ghostsEaten += 1
					self.ghostCache = ghost
				} else if ghost.state != .Fleeing {
					self.audio.stop()
					gameOver = true
				}
			}
		case gamePhysics.PacMan | gamePhysics.Fruit:
			if let f = contact.bodyA.node as? Fruit {
				if !f.texture!.description.contains("fruit") {
					if !mute {
						pMan.run(pMan.eatFruit)
					}
					f.texture = f.atlas.textureNamed("\(f.points)fruit")
					f.size = CGSize(width: 24, height: 8)
					f.timer = 100
					score += f.points
				}
			}
		default:
			break
		}
	}

	func getEdgeStates() -> [Bool] {
		var result = [Bool]()
		for wall in walls {
			result.append(wall.edge)
		}
		return result
	}

	func updateEdges() {
		// TODO: Delete
		for (i, wall) in walls.enumerated() {
			var up = false
			var down = false
			var left = false
			var right = false
			if i >= map.width {
				up = walls[i - map.width].edge
			}
			if i <= walls.count - map.width - 1 {
				down = walls[i + map.width].edge
			}
			if i > 0 {
				left = walls[i - 1].edge
			}
			if i < walls.count - 2 {
				right = walls[i + 1].edge
			}
			if up || down || left || right {
				wall.edge = true
			}
		}
	}

	func reload() {
		toMove = nil
		for f in gfruits {
			f.timer = 0
		}
		pMan.square = IntCoords(x: 13, y: 7)
		pMan.inSquare = Coords(x: squareWidth, y: squareWidth / 2)
		pMan.globalPos = Coords(x: squareWidth * Double(pMan.square.x) + pMan.inSquare.x, y: squareWidth * Double(pMan.square.y) + pMan.inSquare.y)
		pMan.texture = pMan.frames[2]
		pMan.direction = .left
		pMan.zRotation = .pi
		pMan.position = CGPoint(x: CGFloat(pMan.startCoords.x), y: CGFloat(pMan.startCoords.y))
		blinky.square = IntCoords(x: 13, y: 19)
		pinky.square = IntCoords(x: 13, y: 16)
		inky.square = IntCoords(x: 11, y: 16)
		clyde.square = IntCoords(x: 15, y: 16)
		for ghost in ghosts {
			ghost.inSquare = Coords(x: Double(squareWidth), y: Double(squareWidth) / 2)
			ghost.texture = ghost.atlas.textureNamed("\(ghost.nameAsString)U1")
			ghost.globalPos = Coords(x: squareWidth * Double(ghost.square.x) + ghost.inSquare.x,
									 y: squareWidth * Double(ghost.square.y) + ghost.inSquare.y)
			ghost.direction = .up
			ghost.waitCount = 0
			ghost.state = .GhostHouse
		}
		powerTimer = 0
		canResume = false
		introPlaying = false
		ghostsEaten = 0
		gameOver = false
		mainScene = GameScene(size: self.size)
		for dot in dots {
			if dot.parent != nil {
				dot.removeFromParent()
				mainScene.addChild(dot)
			}
		}
		for wall in walls {
			wall.removeFromParent()
		}
		self.view?.presentScene(mainScene)
	}

	func reset() {
		self.removeAllChildren()
		newLevel = true
		self.reload()
	}

	override init(size: CGSize) {
		super.init(size: size)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func keyUp(with event: NSEvent) {
		if gameOver {
			return
		}
		switch event.keyCode {
		case 123:
			if toMove == .left {
				toMove = nil
			}
		case 124:
			if toMove == .right {
				toMove = nil
			}
		case 125:
			if toMove == .down {
				toMove = nil
			}
		case 126:
			if toMove == .up {
				toMove = nil
			}
		default:
			break
		}
	}

	override func keyDown(with event: NSEvent) {
		if event.keyCode == 46 {
			toggleMute()
			return
		}

		if gameOver {
			if event.keyCode == 49 && mainScene.textNode.size == CGSize(width: 88, height: 16) {
				level = 0
				lives = 2
				mainScene.reset()
			}
			return
		}

		switch event.keyCode {
		case 18:
			gameMode = 1
			pMan.alpha = 0.7
		case 29:
			gameMode = 0
			pMan.alpha = 1
		case 123:
			toMove = .left
		case 124:
			toMove = .right
		case 125:
			toMove = .down
		case 126:
			toMove = .up
		default: break
		}
	}

	override func didMove(to view: SKView) {
		super.didMove(to: view)
        self.isPaused = true // Stops update() from calling while scene is initialising

		if debug {
			self.size = view.bounds.size
			self.textNode.position = CGPoint(x: 250, y: 150)

			// TODO: Maybe work this into the loop to avoid repeating code -- is this comment meant for the debuglabel code below??
			debugLabel.position = CGPoint(x: 0, y: 230)
			debugLabel.fontSize = 12
			debugLabel.fontName = "Monaco"
			debugLabel.fontColor = NSColor.white
			debugLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.left
			debugLabel.zPosition = 5
			debugLabel.numberOfLines = 5
			self.addChild(debugLabel)

			for (i, ghostLabel) in [clydeDebug, inkyDebug, pinkyDebug, blinkyDebug].enumerated() {
				ghostLabel.position = CGPoint(x: 0, y: 15 * i + 5)
				ghostLabel.fontSize = 12
				ghostLabel.fontName = "Monaco"
				ghostLabel.fontColor = [NSColor.yellow, NSColor.cyan, NSColor.magenta, NSColor.red][i]
				ghostLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.left
				ghostLabel.zPosition = 5
				self.addChild(ghostLabel)
			}
		} else {
			self.textNode.position = CGPoint(x: 342.5, y: 15)
		}

		self.scaleMode = .resizeFill
		self.backgroundColor = .black
		physicsWorld.contactDelegate = self
		let border = SKPhysicsBody(edgeLoopFrom: self.frame)
		border.friction = 0
		self.physicsBody = border

		self.textNode.zPosition = 5
		self.textNode.size = CGSize(width: 56, height: 16)
		updateLabel("")
        
        do {
            try map = MapData(from: Bundle.main.path(forResource: "default", ofType: fileExt) ?? "").map
        } catch {
			switch error as! MapError {
			case .badGrid:
				updateLabel("Bad Grid")
			case .badPath:
				updateLabel("Bad Path")
			case .invalidSignature:
				updateLabel("Invalid Signature")
			case .cannotGenerateMap:
				updateLabel("Error Generating Map")
			default:
				updateLabel("Error Creating Map")
			}
            return
        }
        pMan = PacMan(x: 13, y: 7)
        blinky = Blinky(x: 13, y: 19)
        pinky = Pinky(x: 13, y: 16)
        inky = Inky(x: 11, y: 16)
        clyde = Clyde(x: 15, y: 16)

		if lives > 0 {
			for i in 0...(lives - 1) {
				livesTiles[i].image = NSImage(named: "Life")
			}
		}

		for i in lives...(livesTiles.count - 1) {
			livesTiles[i].image = nil
		}

		if level < 6 {
			levelFruit = Array(self.newFruit[0...level])
		} else {
			levelFruit = Array(self.newFruit[level-6...level])
		}

		for (i, name) in levelFruit.enumerated() {
			if i < levelFruit.count {
				fruitTiles[i].image = NSImage(named: name)
			} else {
				fruitTiles[i].image = nil
			}
		}

		/*func wallFor(x: Int, y: Int) -> Wall {
			return walls[x + y * map.width]
		}*/

		self.initAudio(audio: &self.secondaryAudio, url: self.eatGhostSound, loop: false, play: false)
		origin = Coords(x: Double(pMan.position.x) - pMan.globalPos.x + 4, y: Double(pMan.position.y) - pMan.globalPos.y + 4)
		var x: Int = 0
		var y: Int = 0

		effect.filter = CIFilter(name: "CIColorControls")
		self.addChild(effect)

		pMan.size = CGSize(width: 1.625 * Double(squareWidth), height: 1.625 * Double(squareWidth))

		if newLevel {
			walls = [Wall]()
			dots = [Dot]()
			gfruits = [Fruit]()
			for square in map.squares {
				if square.wall {
					let wall = Wall(forSquare: square, x: x, y: y)
					wall.edge = x == 0 || x == map.width - 1 || y == 0 || y == (map.squares.count / map.width) - 1
					walls.append(wall)
					effect.addChild(wall)
				} else if square.dot {
					let dot = Dot(x: x, y: y, power: square.power)
					dots.append(dot)
					self.addChild(dot)
				} else if square.fruit {
					gfruits.append(Fruit(x: x, y: y, type: levelFruit[levelFruit.count - 1]))
				}
				x += 1
				if x == map.width {
					x = 0
					y += 1
				}
			}
			newLevel = false
		} else {
			for wall in walls {
				effect.addChild(wall)
				wall.updatePos()
			}
			for dot in dots {
				dot.update()
			}
		}

		self.thresh1 = dots.count / 2
		self.thresh2 = dots.count / 10

		for wall in walls {
			wall.updateTexture()
		}

		if gameMode != 2 {
			self.addChild(pMan)
		}

		ghostsEaten = 0
		if level == 0 && !hasStarted {
			score = 0
			self.updateScore()
			self.addChild(self.textNode)
			self.initAudio(audio: &self.audio, url: self.intro, loop: false, play: true)
			introPlaying = true

			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 4.0) {
				self.textNode.removeFromParent()
				self.isPaused = false
				self.isPaused = true
			}
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 4.5) {
				// TODO: The queue timer isn't pausing
				// -- possibly take the current elapsed time (cache original .now() and minus from current .now()) and create new dispatchqueue with new timer?
				self.isPaused = false
				canResume = true
				introPlaying = false
				for ghost in ghosts {
					self.addChild(ghost)
				}

				if debug {
					for reticle in [blinkyReticle, pinkyReticle, inkyReticle, clydeReticle] {
						reticle.size = CGSize(width: squareWidth, height: squareWidth)
						self.addChild(reticle)
					}
				}
				
				self.audio.stop()
				self.initAudio(audio: &self.audio, url: self.bg1, loop: true, play: true)
				hasStarted = true
			}
		} else {
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {
				self.textNode.removeFromParent()
				self.isPaused = false
				self.isPaused = true
				blinky.spd = CGFloat(squareWidth) / 8
				let remaining = dots.filter{$0.parent != nil}.count
				if remaining <= self.thresh2 {
					blinky.spd *= 1.1
					self.initAudio(audio: &self.audio, url: self.bg3, loop: true, play: true)
				} else if remaining <= self.thresh1 {
					blinky.spd *= 1.05
					self.initAudio(audio: &self.audio, url: self.bg2, loop: true, play: true)
				} else {
					self.initAudio(audio: &self.audio, url: self.bg1, loop: true, play: true)
				}
				for ghost in ghosts {
					self.addChild(ghost)
				}
				if debug {
					for reticle in [blinkyReticle, pinkyReticle, inkyReticle, clydeReticle] {
						self.addChild(reticle)
					}
				}
				self.isPaused = false
				canResume = true
			}
		}
	}
}
