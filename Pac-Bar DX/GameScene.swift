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
 * * Could coords be replaced with two variables? CGPoint maybe?
 * * Change all variable names from [adj] to is[adj] / [attr] to has[attr]
 *
 * === BUGS ===
 * * Ghost target squares don't update after dying -- possibly when switching to gamemode 2 while respawning | Cause found, solution in the worls
 * * Blinky's position doesn't reset when pacman dies sometimes
 *
 * === ADDITIONAL DEBUG OPTIONS ===
 * * Move anywhere
 */

/* MAP CO-ORDINATES
 * +y: up
 * +x: right
 */

import Cocoa
import SpriteKit
import AVFoundation

// --- View dimensions: 30x685 ---
var mainScene = GameScene(size: CGSize(width: 685, height: 30))

var mute: Bool = UserDefaults.standard.object(forKey: "mute") as? Bool ?? false

var origin: Coords!

var score: Int!
var lives: Int!
var level: Int!
var prevScore: Int!
var whiteTimer: Int!
var powerTimer: Int!
var ghostsEaten: Int!

var white: Bool!
var newLevel: Bool!
var gameOver: Bool!
var canResume: Bool!
var hasStarted: Bool!
var introPlaying: Bool!

var pMan: PacMan!

var blinky: Blinky!
var pinky: Pinky!
var inky: Inky!
var clyde: Clyde!
let ghosts = [blinky, pinky, inky, clyde] as [Ghost]

var dots = [Dot]()
var walls = [Wall]()
var gfruits = [Fruit]() // TODO: This needs renaming

let directionKeyMap: [UInt16: Direction] = [
	123: .left,
	124: .right,
	125: .down,
	126: .up
]

// Debug
var gameMode: Int = 0 {
	// GAMEMODE
	// 0 - normal gameplay
	// 1 - invulnerability
	// 2 - no pac-man, free control over map

	didSet {
		switch gameMode {
		case 0:
			pMan.alpha = 1
			pMan.isHidden = false
		case 1:
			pMan.alpha = 0.7
			pMan.isHidden = false
		case 2:
			pMan.isHidden = true
		default:
			break
		}
	}
}

var debugLabel = SKLabelNode(text: "DEBUG MODE\n\n\n\n")
var blinkyDebug = SKLabelNode(text: "")
var pinkyDebug = SKLabelNode(text: "")
var inkyDebug = SKLabelNode(text: "")
var clydeDebug = SKLabelNode(text: "")

var blinkyReticle = SKSpriteNode(imageNamed: "BlinkyReticle")
var pinkyReticle = SKSpriteNode(imageNamed: "PinkyReticle")
var inkyReticle = SKSpriteNode(imageNamed: "InkyReticle")
var clydeReticle = SKSpriteNode(imageNamed: "ClydeReticle")

// TODO: eliminate these global functions by moving them to appropriate classes
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
	let whiteEffect = SKEffectNode()
	var thresh1 = 0
	var thresh2 = 0

	var levelFruit: [String] = []
	let newFruit = ["Cherry", "Strawberry", "Orange", "Orange", "Apple", "Apple", "Melon", "Melon", "Galaxian", "Galaxian", "Bell", "Bell", "Key", "Key", "Key", "Key", "Key", "Key", "Key", "Key"]

	override init(size: CGSize) {
		super.init(size: size)

		self.scaleMode = .resizeFill
		self.backgroundColor = .black

		let border = SKPhysicsBody(edgeLoopFrom: self.frame)
		border.friction = 0
		self.physicsBody = border

		physicsWorld.contactDelegate = self

		self.textNode.zPosition = 5
		self.textNode.size = CGSize(width: 56, height: 16)

		if debug {
			self.textNode.position = CGPoint(x: 250, y: 150)

			for (i, label) in [debugLabel, clydeDebug, inkyDebug, pinkyDebug, blinkyDebug].enumerated() {
				if i == 0 {
					label.position = CGPoint(x: 0, y: 230)
					debugLabel.numberOfLines = 4
				} else {
					label.position = CGPoint(x: 0, y: 15 * i - 10)
				}
				label.fontSize = 12
				label.fontName = "Monaco"
				label.fontColor = [NSColor.white, NSColor.yellow, NSColor.cyan, NSColor.magenta, NSColor.red][i]
				label.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.left
				label.zPosition = 5
				self.addChild(label)
			}
		} else {
			self.textNode.position = CGPoint(x: 342.5, y: 15)
		}

		self.whiteEffect.filter = CIFilter(name: "CIColorControls")
		self.addChild(self.whiteEffect)

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

		level = 0
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func setup() {
		// TODO: Copy stuff from reload() into here and stop using reload
		score = 0
		lives = 3
		ghostsEaten = 0
		gameOver = false
		whiteTimer = 0
		prevScore = 0
		powerTimer = 0
		canResume = false
		introPlaying = false

		hasStarted = false
		newLevel = true // XXX
		white = false

		self.addDots()
		self.addWalls()
	}

	func addDots() {
		for dot in dots {
			dot.update()
			self.addChild(dot)
		}
	}

	func addWalls() {
		for wall in walls {
			wall.updatePos()
			self.addChild(wall)
		}
	}

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

	func updateScore() { //TODO: can this be moved to score didSet?
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
				self.whiteEffect.filter?.setValue(0, forKey: kCIInputBrightnessKey)
			} else {
				self.whiteEffect.filter?.setValue(1, forKey: kCIInputBrightnessKey)
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
			if gameMode == 2 {
				switch toMove {
				case .up?:
					origin.y -= 1
				case .down?:
					origin.y += 1
				case .left?:
					origin.x += 1
				case .right?:
					origin.x -= 1
				default:
					break
				}
			} else {
				pMan.move()
			}

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
		// TODO: This is a bit of a hack and could probably do with a proper rework
		toMove = nil // FIXME: Make toMove a pMan attribute
		for f in gfruits {
			f.timer = 0
		}
		pMan.square = IntCoords(x: 13, y: 7)
		pMan.inSquare = Coords(x: squareWidth, y: squareWidth / 2)
		pMan.globalPos = Coords(x: squareWidth * Double(pMan.square.x) + pMan.inSquare.x, y: squareWidth * Double(pMan.square.y) + pMan.inSquare.y) // XXX: Is this covered in pMan.updateSquare()?
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
			ghost.state = .GhostHouse // This currently sets blinky's state to ghosthouse and causes his targetsquare to break slightly
										// but somehow he still follows Pac-Man... maybe .GhostHouse behaviour needs to be looked into as well
		}
		powerTimer = 0
		canResume = false
		introPlaying = false
		ghostsEaten = 0
		gameOver = false
		mainScene = GameScene(size: self.size) // re-creating the scene again every time is probably not the best solution, maybe have a proper initialisation/reset function that handles all of this??
		// This currently re-creates all of the dots
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

	override func keyUp(with event: NSEvent) {
		if gameOver {
			return
		}

		if directionKeyMap.keys.contains(event.keyCode) {
			if toMove == directionKeyMap[event.keyCode] {
				toMove = nil
			}
		}
	}

	override func keyDown(with event: NSEvent) {
		if event.keyCode == 46 {
			toggleMute()
			return
		}

		if gameOver {
			if event.keyCode == 49 && mainScene.textNode.size == CGSize(width: 88, height: 16) { // XXX: The size check is a hack, maybe need to set a resettable flag
				level = 0
				lives = 2
				mainScene.reset()
			}
			return
		}

		if directionKeyMap.keys.contains(event.keyCode) {
			toMove = directionKeyMap[event.keyCode]
		}

		switch event.keyCode {
		case 18:
			gameMode = 1
		case 19:
			gameMode = 2
		case 29:
			gameMode = 0
		default:
			break
		}
	}

	func updateLivesTiles() {
		for i in 0...(livesTiles.count - 1) {
			if i < lives {
				livesTiles[i].image = NSImage(named: "Life")
			} else {
				livesTiles[i].image = nil
			}
		}
	}

	func updateFruitTiles() {
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
	}

	override func didMove(to view: SKView) {
		super.didMove(to: view)
		self.isPaused = true // Stops update() from calling while scene is initialising

		self.setup()

		updateLabel("")

		// TODO: These should be moved out of didMove and Sprite should have a reset/setup method
        pMan = PacMan(x: 13, y: 7)
        blinky = Blinky(x: 13, y: 19)
        pinky = Pinky(x: 13, y: 16)
        inky = Inky(x: 11, y: 16)
        clyde = Clyde(x: 15, y: 16)

		self.updateLivesTiles()
		self.updateFruitTiles()
		// TODO: Animation at start of game where life disappears: start lives on 3 then decrease by 1

		self.initAudio(audio: &self.secondaryAudio, url: self.eatGhostSound, loop: false, play: false)

		// ==========================================================
		// TODO: Add a createWalls() or similar function that creates all the walls and sets them up correctly
		// TODO: Replace x and y with enumerations or similar?
		// -- Maybe `for x in 0...map.width`
		// -- and `for y in 0...map.height`
		// -- then do `squares[y+map.width + x]`??
		var x: Int = 0
		var y: Int = 0
		if newLevel {
			walls = [Wall]()
			dots = [Dot]()
			gfruits = [Fruit]()

			for square in map.squares {
				if square.wall {
					// TODO: implement proper algorithm (it's on paper somewhere...): need a function in map that finds the edges of the map
					// IDEA FOR A NEW ALGORITHM:
					// Fill in from each edge until a non-wall square is found, each wall is marked as an edge
					// --> just need to do each row horizontally from both ends (or only 1 end if all walls are edge)
					let wall = Wall(forSquare: square, x: x, y: y)
					walls.append(wall)
					self.whiteEffect.addChild(wall)
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
				self.whiteEffect.addChild(wall)
				wall.updatePos()
			}
			for dot in dots {
				dot.update()
			}
		}
		// ==========================================================

		self.thresh1 = dots.count / 2
		self.thresh2 = dots.count / 10

		for wall in walls {
			wall.updateTexture()
		}
		// FIXME: There are a lot of calls of `for wall in walls` above, maybe look into reducing that?

		self.addChild(pMan)

		ghostsEaten = 0
		if level == 0 && !hasStarted {
			score = 0
			self.updateScore()
			self.addChild(self.textNode)
			self.initAudio(audio: &self.audio, url: self.intro, loop: false, play: true)
			introPlaying = true

			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 4.0) {
				self.textNode.removeFromParent()
				lives -= 1
				self.updateLivesTiles()
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
