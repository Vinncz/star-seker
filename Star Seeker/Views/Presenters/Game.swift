import SpriteKit
import SwiftUI

/// An object that organizes all of the active SpriteKit content contained within it.
///
/// ## Overview
/// Game, as the name suggest, is the location of where everything happen.
/// To display and interact with the game, you present an instance of this, inside an SKView from your SwiftUI file.
@Observable class Game : SKScene, SKPhysicsContactDelegate {
    /** The previous state of self */
    var previousState : GameState = .notYetStarted
    /** An instance of generator object which renders the needed level to the scene. Level generator object persists between game resets */
    var generator     : LevelGenerator?
    /** An instance of SKNode which represents the player in game. Player object does not persist between game resets */
    var player        : Player?
    /** An instance of SKNode which controls another SKNode. Controller object persists between game resets, but require its target attribute to be updated to the new target */
    var controller    : MovementController?
    var darkness       : Darkness?
    var currentMovingPlatform: SKSpriteNode?
    var currentMovingPlatformPosition: CGPoint?
    var outboundIndicator: SKSpriteNode?
    static var levelCounter : Int = 2
    
    override init ( size: CGSize ) {
        self.state = .startScreen
        
        super.init(size: size)
        
        self.name      = NodeNamingConstant.game
        self.scaleMode = .resizeFill
        self.physicsWorld.contactDelegate = self
    }
    
    /** Called after an instace of Game is ready to be shown at some SKView instance. */
    override func didMove ( to view: SKView ) {
        ValueProvider.screenDimension = UIScreen.main.bounds.size
        
        setup(view)
        attachElements()
        
        self.player      = try? findPlayerElement()
        self.controller  = setupMovementController(for: self.player!)
        self.controller?.isHidden = true
        addChild(controller!)
        self.outboundIndicator = setupOutboundIndicator()
        addChild(outboundIndicator!)
        
        attachDarkness()
    }
    
    /** The state of situation for self */
    var state         : GameState {
        didSet {
            previousState = oldValue
            switch ( state ) {
            case .startScreen:
                exitGame()
                break
            case .playing:
                let moveAction = SKAction.move(to: CGPoint(5, 11), duration: 100)
                self.darkness?.run(moveAction)
                self.controller?.isHidden = false
                self.isPaused = false
                break
            case .paused:
                self.isPaused = true
                break
            case .finished:
                let slowDownAction = SKAction.customAction(withDuration: 6) { _, elapsedTime in
                    let progress = elapsedTime / 6
                    self.speed = 1 - progress
                }
                self.run(slowDownAction, withKey: ActionNamingConstant.gameSlowingDown)
            default:
                break
            }
            
            debug("Game state was updated to: \(state)")
        }
    }
    
    /* Inherited from SKScene. Refrain from altering the following */
    required init? ( coder aDecoder: NSCoder ) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

/* MARK: -- Extension which gives Game the ability to recieve and respond to contact between two physics bodies within its physicsWorld. */
extension Game {
    
    override func update ( _ currentTime: TimeInterval ) {
        if let platform = currentMovingPlatform {
            if let previousPosition = currentMovingPlatformPosition {
                let deltaX = platform.position.x - previousPosition.x
                currentMovingPlatformPosition = platform.position
                self.player?.position.x += deltaX
            } else {
                currentMovingPlatformPosition = currentMovingPlatform?.position
            }
        }
        
        guard let playerPosition = self.player?.position,
              let outboundIndicatorNode = self.outboundIndicator else {
            fatalError("player and outbound indicator not found")
        }
        let isPlayerOutbound = playerPosition.x < 0 || playerPosition.x > ValueProvider.screenDimension.width || playerPosition.y > ValueProvider.screenDimension.height
        if isPlayerOutbound {
            let indicatorVerticalOffset = outboundIndicatorNode.size.width / 2
            let indicatorHeightOffset = outboundIndicatorNode.size.height / 2
            outboundIndicatorNode.isHidden = false
            if (playerPosition.y < ValueProvider.screenDimension.height){
                if (playerPosition.x < ValueProvider.screenDimension.width / 2) {
                    outboundIndicatorNode.position = CGPoint(x: 0 + indicatorVerticalOffset, y: playerPosition.y)
                    outboundIndicatorNode.zRotation = 1.6
                } else {
                    outboundIndicatorNode.position = CGPoint(x: ValueProvider.screenDimension.width - indicatorVerticalOffset, y: playerPosition.y)
                    outboundIndicatorNode.zRotation = -1.6
                }
            } else {
                outboundIndicatorNode.position = CGPoint(x: playerPosition.x, y: ValueProvider.screenDimension.height - indicatorHeightOffset)
                outboundIndicatorNode.zRotation = 0
            }
        } else {
            outboundIndicatorNode.isHidden = true
        }
    }
    
    /** Called after an instace of SKPhysicsBody collided with another instance of SKPhysicsBody inside self's physicsWorld attribute. Their contactBitMask attribute must match the bitwise operation "OR" in order for this method to be called. */
    func didBegin ( _ contact: SKPhysicsContact ) {
        let collisionHandlers : [Set<UInt32>: (SKPhysicsContact) -> Void] = [
            [BitMaskConstant.player, BitMaskConstant.platform]: Player.intoContactWithPlatform,
            [BitMaskConstant.player, BitMaskConstant.levelChangePlatform]: { contact in
                Player.intoContactWithPlatform(contact: contact)
                self.advanceToNextLevel()
            },
            [BitMaskConstant.player, BitMaskConstant.movingPlatform]: { contact in
                Player.intoContactWithPlatform(contact: contact)
                // TODO: -- Fix this mess
                if (contact.bodyA.node?.name == NodeNamingConstant.Platform.Inert.Dynamic.moving){
                    self.currentMovingPlatform = contact.bodyA.node as? SKSpriteNode
                } else {
                    self.currentMovingPlatform = contact.bodyB.node as? SKSpriteNode
                }
            },
            [BitMaskConstant.player, BitMaskConstant.darkness]: { contact in
                if ( self.state != .finished ) {
                    self.state = .finished
                    SoundManager.instance.playSound(.GameOver)
                }
                Player.intoContactWithDarkness(contact: contact)
            }
        ]
        let collision         = Set([contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask])
        
        collisionHandlers[collision]?(contact)
    }
    
    /** Called after an instance of SKPhysicsBody no longer made contact with the previously connected instance of SKPhysicsBody inside self's physicsWorld attribute. */
    func didEnd ( _ contact: SKPhysicsContact ) {
        let collisionHandlers : [Set<UInt32>: (SKPhysicsContact) -> Void] = [
            [BitMaskConstant.player, BitMaskConstant.platform]: Player.releaseContactWithPlatform,
            [BitMaskConstant.player, BitMaskConstant.levelChangePlatform]: Player.releaseContactWithPlatform,
            [BitMaskConstant.player, BitMaskConstant.movingPlatform]: { contact in
                self.currentMovingPlatform = nil
                self.currentMovingPlatformPosition = nil
                Player.releaseContactWithPlatform(contact: contact)
            },
            [BitMaskConstant.player, BitMaskConstant.darkness]: Player.releaseContactWithDarkness
        ]
        let collision         = Set([contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask])
        
        collisionHandlers[collision]?(contact)
    }
    
}

/* MARK: -- Extension which gives Game the ability to attend to itself. */
extension Game {
    /** Sets the required one-time configurations to the passed SKView */
    func setup ( _ view: SKView ) {
        view.allowsTransparency = true
        self.view!.isMultipleTouchEnabled = true
        self.backgroundColor = .clear
        self.physicsWorld.speed = 1
        self.physicsWorld.gravity = GameConfig.playerGravity
    }
    
    /** Renders all platforms to the scene */
    func attachElements ( fromLevelOf: String = "easy-01" ) {
        self.generator = LevelGenerator( for: self, decipherer: CSVtoNodesDecipherer( csvFileName: fromLevelOf, nodeConfigurations: GameConfig.characterMapping ) )
        self.generator?.generate()
    }
    
    /** Removes all elements from the scene */
    func detachAllElements () {
        self.removeAllChildren()
    }
    
    /** After the generator has been ran, this function is called to find the attached Player node. Player object does not persist between game resets and should NOT be reattached to instance of self. */
    func findPlayerElement () throws -> Player? {
        let player : Player? = self.childNode(withName: NodeNamingConstant.player) as? Player
        if ( player == nil ) {
            print("Did not find player node after generating the level. Did you forget to write one \"PLY\" node to your file?")
            throw GeneratorError.playerIsNotAdded("Did not find player node after generating the level. Did you forget to write one \"PLY\" node to your file?")
        }
        return player
    }
    
    /** Instanciates a movement controller that controls something. Controller object deos not persist  between game reset. */
    func setupMovementController ( for target: Player ) -> MovementController {
        let controller = JoystickMovementController( controls: target )
        controller.position = CGPoint(5, 4)
        controller.zPosition = 20
        
        return controller
    }
    
    func setupOutboundIndicator () -> SKSpriteNode {
        let indicatorNode = OutBoundIndicator()
        indicatorNode.isHidden = true
        return indicatorNode
    }
    
    func attachDarkness () {
        let darkness = Darkness()
        darkness.position = CGPoint(5, -7)
        self.darkness = darkness
        
        addChild(darkness)
    }
    
    func slideEverythingDown () {
        let moveAction = SKAction.move(by: CGVector(dx: 0, dy: -899), duration: 5)
        for node in self.children {
            node.removeAllActions()
            node.run(moveAction)
        }
    }
    
    func advanceToNextLevel () {
        guard ( self.state != .levelChange ) else {return}
        self.state = .levelChange
        slideEverythingDown()
        self.run(.wait(forDuration: 5)) {
            self.detachAllElements()
            self.player = nil
            self.controller = nil
            self.attachElements(fromLevelOf: "easy-0" + String(Game.levelCounter))
            Game.levelCounter += 1
            self.player = try? self.findPlayerElement()
            self.controller = self.setupMovementController(for: self.player!)
            self.attachDarkness()
            self.addChild(self.controller!)
            self.state = .playing
            self.outboundIndicator = self.setupOutboundIndicator()
            self.addChild(self.outboundIndicator!)
        }
    }
    
    /// Resets the game, and returns it to how it initially was after self's state becomes .playing
    ///
    /// The logic is as follows:
    /// 1. It resets the state to .notYetStarted
    /// 2. It removes all elements from screen
    /// 3. It regenerates all elements anew again
    /// 4. It finds the player node from the generated level
    /// 5. It attaches the found player node
    /// 6. it attaches the controller node
    func restart () {
        self.state = .notYetStarted
        self.removeAction( forKey: ActionNamingConstant.gameSlowingDown  )
        self.speed = 1
        self.isPaused = false
        Game.levelCounter = 2
        detachAllElements()
        attachElements()
        self.player = try? findPlayerElement()
        self.controller = setupMovementController(for: self.player!)
        self.controller?.isHidden = false
        attachDarkness()
        addChild(controller!)
        self.outboundIndicator = setupOutboundIndicator()
        self.addChild(outboundIndicator!)
        self.state = .playing
    }
    
    func exitGame() {
        self.removeAction( forKey: ActionNamingConstant.gameSlowingDown  )
        self.speed = 1
        self.isPaused = false
        Game.levelCounter = 2
        detachAllElements()
        attachElements()
        self.player = try? findPlayerElement()
        self.controller = setupMovementController(for: self.player!)
        self.controller?.isHidden = true
        attachDarkness()
        addChild(controller!)
        self.outboundIndicator = setupOutboundIndicator()
        self.addChild(outboundIndicator!)
    }
    
}

/* MARK: -- Extension which lets Game track "in what state its in". */
extension Game {
    enum GameState {
        case playing,
             paused,
             notYetStarted,
             levelChange,
             finished,
             startScreen
    }
    enum GeneratorError : Error {
        case playerIsNotAdded(String)
    }
}
