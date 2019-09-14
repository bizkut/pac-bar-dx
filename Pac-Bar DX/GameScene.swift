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
 * * If pacman is stuck inside a wall using gamemode 3 then gamemode 2 is used to move the camera, the map doesn't update after gamemode is switched back to 1 or 0
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

let gameModeKeyMap: [UInt16] = [29, 18, 19, 20]

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
			pMan.color = .clear
			pMan.colorBlendFactor = 0
		case 1:
			pMan.alpha = 0.7
			pMan.isHidden = false
			pMan.color = .clear
			pMan.colorBlendFactor = 0
		case 2:
			pMan.isHidden = true
			pMan.color = .clear
			pMan.colorBlendFactor = 0
		case 3:
			pMan.alpha = 0.7
			pMan.isHidden = false
			pMan.color = .green
			pMan.colorBlendFactor = 1
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
				self.updateLabel("Bad Grid")
			case .badPath:
				self.updateLabel("Bad Path")
			case .invalidSignature:
				self.updateLabel("Invalid Signature")
			case .cannotGenerateMap:
				self.updateLabel("Error Generating Map")
			default:
				self.updateLabel("Error Creating Map")
			}
			return
		}

		level = 0
		score = 0
		lives = 3

		// Init characters
		// TODO: Get positions from map data
		pMan = PacMan(x: 13, y: 7)
		blinky = Blinky(x: 13, y: 19)
		pinky = Pinky(x: 13, y: 16)
		inky = Inky(x: 11, y: 16)
		clyde = Clyde(x: 15, y: 16)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func didMove(to view: SKView) {
		super.didMove(to: view)
		self.isPaused = true // Stops update() from calling while scene is initialising

		self.updateLabel("")
		self.updateLivesTiles()
		self.updateFruitTiles()

		self.loadMapSprites()

		self.initAudio(audio: &self.secondaryAudio, url: self.eatGhostSound, loop: false, play: false)

		self.addChild(pMan)

		self.newLevel()
	}

	func newLife() {
		self.levelSetup()

		self.newLifeAnimation()
	}

	func newLevel() {
		self.levelSetup()

		if level == 0 {
			self.newGameAnimation()
		} else {
			self.newLifeAnimation()
		}
	}

	func loseLife() {
		pMan.size = CGSize(width: 1.875 * Double(squareWidth), height: 1.5 * Double(squareWidth))
		var frames = [SKTexture]()
		for i in 1...11 {
			frames.append(pMan.endAtlas.textureNamed("PacManD\(i)"))
		}
		pMan.isPaused = false
		pMan.zRotation = 0
		pMan.texture = frames[10]

		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.9) {
			self.initAudio(audio: &self.audio, url: self.deathSound, loop: false, play: true)
		}
		sleep(1)

		for ghost in ghosts {
			ghost.removeFromParent()
		}

		for reticle in [blinkyReticle, pinkyReticle, inkyReticle, clydeReticle] {
			reticle.removeFromParent()
		}

		debugLabel.removeFromParent()

		for ghostLabel in [clydeDebug, inkyDebug, pinkyDebug, blinkyDebug] {
			ghostLabel.removeFromParent()
		}

		pMan.position.y -= CGFloat(squareWidth) * 3 / 8
		pMan.run(SKAction.animate(with: frames, timePerFrame: 0.1, resize: true, restore: true), withKey: "GameOver")

		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.05) {
			pMan.removeFromParent()

			if lives > 0 {
				DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
					self.isPaused = true
					lives -= 1

					for dot in dots {
						if dot.parent != nil {
							dot.removeFromParent()
						}
					}

					self.newLife()
				}
			} else {
				self.textNode.texture = SKTexture(imageNamed: "Game Over")
				self.textNode.size = CGSize(width: 88, height: 16)
				DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
					self.addChild(mainScene.textNode)
					self.isPaused = true
					hasStarted = false
				}
			}
		}
	}

	override func update(_ currentTime: TimeInterval) {
		if gameOver {
//			if self.audio.url! == self.deathSound {
//				return
//			}
//			pMan.deathFrames()

			if self.audio.url! != self.deathSound {
				self.loseLife()
			}
		} else if whiteTimer > 0 {
			if whiteTimer == 9 {
				usleep(500000)
			}
			whiteTimer -= 1
			//			if white {
			//				self.whiteEffect.filter?.setValue(0, forKey: kCIInputBrightnessKey)
			//			} else {
			//				self.whiteEffect.filter?.setValue(1, forKey: kCIInputBrightnessKey)
			//			}
			self.whiteEffect.filter!.setValue(white ? 1 : 0, forKey: kCIInputBrightnessKey)

			if whiteTimer > 0 {
				white = !white
			} else {
				white = false
				self.reset()
			}
			usleep(200000)
		} else {
			self.updateScore()

			if gameMode == 2 {
				if let dir = toMove {
					switch dir {
					case .up:
						origin.y -= 1
					case .down:
						origin.y += 1
					case .left:
						origin.x += 1
					case .right:
						origin.x -= 1
					}
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

		if gameModeKeyMap.contains(event.keyCode) {
			gameMode = gameModeKeyMap.firstIndex(of: event.keyCode)!
		}
	}

	func didBegin(_ contact: SKPhysicsContact) {
		if gameMode == 2 {
			return
		}

		let contactMask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
		switch contactMask {
		case gamePhysics.PacMan | gamePhysics.Dot:
			if let dot = contact.bodyB.node as? Dot {
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
			if gameMode == 1 || gameMode == 3 {
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
					gameOver = true // TODO: Replace gameOver and white vars with a single gameState variable
				}
			}
		case gamePhysics.PacMan | gamePhysics.Fruit:
			if let f = contact.bodyB.node as? Fruit {
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

	func loadMapSprites() {
		// Reset all walls, dots and fruit
		walls = [Wall]()
		dots = [Dot]()
		gfruits = [Fruit]()

		for y in 0..<map.height {
			for x in 0..<map.width {
				let square = map.squares[y * map.width + x]
				if square.wall {
					// TODO: implement proper algorithm (it's on paper somewhere...): need a function in map that finds the edges of the map
					let wall = Wall(forSquare: square, x: x, y: y)
					walls.append(wall)
					self.whiteEffect.addChild(wall)
				} else if square.dot {
					let dot = Dot(x: x, y: y, power: square.power)
					dots.append(dot)
				} else if square.fruit {
					gfruits.append(Fruit(x: x, y: y, type: levelFruit[levelFruit.count - 1]))
				}
			}
		}

		self.thresh1 = dots.count / 2
		self.thresh2 = dots.count / 10
	}

	func levelSetup() {
		ghostsEaten = 0
		gameOver = false
		whiteTimer = 0
		prevScore = 0
		powerTimer = 0
		canResume = false
		introPlaying = false

		hasStarted = false
		white = false

		for f in gfruits {
			f.timer = 0
		}

		// Set up Pac-Man
		pMan.square = IntCoords(x: 13, y: 7)
		pMan.setup()

		// These can be moved into the main thing if they aren't used anywhere else
		self.addDots()
		self.addWalls()
		// ----

		// TODO: Replace all the coords here with ones obtained from the map

		// Set up ghosts

		// -------------------------------------
		// TEMPORARY - WILL BE REMOVED
		blinky.square = IntCoords(x: 13, y: 19)
		pinky.square = IntCoords(x: 13, y: 16)
		inky.square = IntCoords(x: 11, y: 16)
		clyde.square = IntCoords(x: 15, y: 16)
		// -------------------------------------

		for ghost in ghosts {
			ghost.setup()
			// Setting ghost state to .GhostHouse currently sets blinky's state to GhostHouse after a reset and causes his targetsquare to break slightly
			// but somehow he still follows Pac-Man... maybe .GhostHouse behaviour needs to be looked into as well
		}
	}

	func refreshView() {
		self.isPaused = false
		self.isPaused = true
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
			wall.updateTexture()
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

	func addGhosts() {
		for ghost in ghosts {
			ghost.updatePos()
			self.addChild(ghost)
		}

		if debug {
			for reticle in [blinkyReticle, pinkyReticle, inkyReticle, clydeReticle] {
				reticle.size = CGSize(width: squareWidth, height: squareWidth)
				self.addChild(reticle)
			}
		}
	}

	func newGameAnimation() {
		score = 0
		self.updateScore()
		self.addChild(self.textNode)
		self.initAudio(audio: &self.audio, url: self.intro, loop: false, play: true)
		introPlaying = true

		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 4.0) {
			self.textNode.removeFromParent()
			lives -= 1
			self.updateLivesTiles()
			self.refreshView()
		}

		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 4.5) {
			// TODO: The queue timer isn't pausing
			// -- possibly take the current elapsed time (cache original .now() and minus from current .now()) and create new dispatchqueue with new timer?
			self.isPaused = false
			canResume = true
			introPlaying = false

			self.addGhosts()

			self.audio.stop()
			self.initAudio(audio: &self.audio, url: self.bg1, loop: true, play: true)
			hasStarted = true
		}
	}

	func newLifeAnimation() {
		self.addChild(pMan)
		self.addGhosts()
		self.refreshView()

		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {

			blinky.spd = CGFloat(squareWidth) / 8

			// TODO: if the level isn't being reloaded anymore then this can be removed
			let remaining = dots.filter{$0.parent != nil}.count
			let audioURL: URL?

			if remaining <= self.thresh2 {
				blinky.spd *= 1.1
				audioURL = self.bg3
			} else if remaining <= self.thresh1 {
				blinky.spd *= 1.05
				audioURL = self.bg2
			} else {
				audioURL = self.bg1
			}

			if let url = audioURL {
				self.initAudio(audio: &self.audio, url: url, loop: true, play: true)
			}
			// -----

			self.isPaused = false
			canResume = true
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

	func updateScore() { // TODO: can this be moved to score didSet?
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

//	func reload() {
//		toMove = nil // FIXME: Make toMove a pMan attribute
//		for f in gfruits {
//			f.timer = 0
//		}
//
//		pMan.square = IntCoords(x: 13, y: 7)
//		pMan.inSquare = Coords(x: squareWidth, y: squareWidth / 2)
//		pMan.globalPos = Coords(x: squareWidth * Double(pMan.square.x) + pMan.inSquare.x, y: squareWidth * Double(pMan.square.y) + pMan.inSquare.y) // XXX: Is this covered in pMan.updateSquare()?
//		pMan.texture = pMan.frames[2]
//		pMan.direction = .left
//		pMan.zRotation = .pi
//		pMan.position = CGPoint(x: CGFloat(pMan.startCoords.x), y: CGFloat(pMan.startCoords.y))
//
//		blinky.square = IntCoords(x: 13, y: 19)
//		pinky.square = IntCoords(x: 13, y: 16)
//		inky.square = IntCoords(x: 11, y: 16)
//		clyde.square = IntCoords(x: 15, y: 16)
//		for ghost in ghosts {
//			ghost.inSquare = Coords(x: Double(squareWidth), y: Double(squareWidth) / 2)
//			ghost.texture = ghost.atlas.textureNamed("\(ghost.nameAsString)U1")
//			ghost.globalPos = Coords(x: squareWidth * Double(ghost.square.x) + ghost.inSquare.x,
//									 y: squareWidth * Double(ghost.square.y) + ghost.inSquare.y)
//			ghost.direction = .up
//			ghost.waitCount = 0
//			ghost.state = .GhostHouse // This currently sets blinky's state to ghosthouse and causes his targetsquare to break slightly
//										// but somehow he still follows Pac-Man... maybe .GhostHouse behaviour needs to be looked into as well
//		}
//		powerTimer = 0
//		canResume = false
//		introPlaying = false
//		ghostsEaten = 0
//		gameOver = false
//		mainScene = GameScene(size: self.size) // re-creating the scene again every time is probably not the best solution, maybe have a proper initialisation/reset function that handles all of this??
//		// This currently re-creates all of the dots
//		for dot in dots {
//			if dot.parent != nil {
//				dot.removeFromParent()
//				mainScene.addChild(dot)
//			}
//		}
//		for wall in walls {
//			wall.removeFromParent()
//		}
//		self.view!.presentScene(mainScene)
//	}

	func reset() {
		self.removeAllChildren()

		self.isPaused = true

		for wall in walls {
			wall.removeFromParent()
		}

		for dot in dots {
			if dot.parent != nil {
				dot.removeFromParent()
			}
		}

		self.newLife()
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
}
