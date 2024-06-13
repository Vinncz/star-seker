import SpriteKit

class Platform : SKSpriteNode {

    init ( 
        texture: SKTexture = SKTexture( imageNamed: ImageNamingConstant.Platform.Inert.base ), 
        size   : CGSize    = CGSize( width: ValueProvider.screenDimension.width, height: ValueProvider.screenDimension.height )
    ) {
        super.init (
            texture : texture, 
            color   : .clear, 
            size    : size
        )
        
        self.name = NodeNamingConstant.Platform.platform
        self.physicsBody = SKPhysicsBody(texture: texture, size: size)
        self.physicsBody?.isDynamic = false
        self.physicsBody?.friction = GameConfig.baseFrictionModifier
        
        self.physicsBody?.categoryBitMask    = BitMaskConstant.platform.rawValue
        self.physicsBody?.contactTestBitMask = BitMaskConstant.player.rawValue
    }
    
    /* Inherited from SKNode. Refrain from altering the following */
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
