import SpriteKit

class LevelGenerator {
    
    let decipherer : [any Decipherer]
    let target     : SKScene
    var nodes      : [[[SKSpriteNode?]]] = []
    
    init ( for target : SKScene, decipherer: [any Decipherer] ) {
        self.decipherer = decipherer
        self.target     = target
        read()
    }
    
    
    /// Runs the decipherer to get their content
    /// 
    /// This function does not populate the target with the result, but you can do so by calling ``generate()``
    func read () {
        self.decipherer.forEach { decipherer in
            let decipheredResult = decipherer.decipher() as! ([[SKSpriteNode?]], (any Error)?)
            let usableResult     = decipheredResult.0.reversed()
            
            debug("<< generator error: " + decipheredResult.1.debugDescription + " >>")
            
            var rowNodes: [[SKSpriteNode?]] = []
            for ( rowIndex, row ) in usableResult.enumerated() {
                var columnNodes: [SKSpriteNode?] = []
                for ( columnIndex, column ) in row.enumerated() {
                    if let nodeAtHand = column {
                        nodeAtHand.position = CGPoint(columnIndex, rowIndex)
                        columnNodes.append(nodeAtHand)
                    }
                }
                rowNodes.append(columnNodes)
            }
            nodes.append(rowNodes)
        }
    }
    
    /// Populates the target scene with SKNodes which were recieved from each supplied decipherer
    /// 
    /// This function must be run ___after___ the ``read()`` method has been called. To simplify this, LevelGenerator now automatically reads off each decipherer at instanciation
    func generate () {
        for rowNodes in nodes {
            for columnNodes in rowNodes {
                for node in columnNodes {
                    if let node = node {
                        target.addChild(node)
                    }
                }
            }
        }
    }
    
    /// Returns the 3D array of SKNodes. If the 3D array were to be flattened to 2D, you'd get the level design.
    /// 
    /// 3D indicates all decipherer's results put together
    /// 2D indicates just one decipherer's result ()
    func getNodes () -> [[[SKSpriteNode?]]] {
        return nodes
    }
    
    /// Returns the SKNodes generated by only one decipherer at the supplied index.
    func getNodes ( forDecipherer: Int ) -> [[SKSpriteNode?]] {
        return nodes[forDecipherer]
    }
    
    /// Returns only the non-nil value from all decipherer's results
    func getValuedNodes () -> [SKSpriteNode] {
        return getNodes().flatMap { $0.flatMap { $0.compactMap { $0 } } }
    }
}
