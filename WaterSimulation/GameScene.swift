//
//  GameScene.swift
//  WaterSimulation
//
//  Created by Enzo Maruffa on 04/12/21.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
    let ID_BORDER: Float = -1
    let ID_STARTING: Float = 0
    let MATRIX_SIZE = 80
    
    lazy var containerNode = {
        SKSpriteNode(imageNamed: "container")
    }()
    lazy var containerBorderNode = {
        SKSpriteNode(imageNamed: "container_border")
    }()
    
    var waterTextureCache: [Float: SKTexture] = [:]
    
    var nodeMatrix: [[SKSpriteNode]] = [] // The one we use to display the simulation
    
    var cellMatrix: [[Float]] = [] // The one we use as source of truth when updating the nodes
    var cellMatrixBuffer: [[Float]] = [] // Where we store the results
    
    var cellSize: CGSize?
    
    // Water properties
    let maxMass: Float = 1.0 //The normal, un-pressurized mass of a full water cell
    let maxCompress: Float = 0.02 //How much excess water a cell can store, compared to the cell above it
    let minMass: Float = 0.0001 //Ignore cells that are almost dry
    let minFlow: Float = 0.95 // ??
    let maxSpeed: Float = 50 // ??
    
    let diagonalsVectors = [
        CGVector(dx: -1.2, dy: 0),
        CGVector(dx: -0.6, dy: 0.6),
        CGVector(dx: 0, dy: 1.2),
        CGVector(dx: 0.6, dy: 0.6),
        CGVector(dx: 1.2, dy: 0),
        CGVector(dx: -0.6, dy: -0.6),
        CGVector(dx: 0, dy: -1.2),
        CGVector(dx: 0.6, dy: -0.6)
    ]
    
    let defaultGravity: (i: Float, j: Float) = (i: -1, j: 0)
    var gravity: (i: Float, j: Float) = (i: 0, j: 0)
    {
        didSet {
            gravities[.down] = gravity
            gravities[.up] = (i: -gravity.i, j: -gravity.j)
            gravities[.left] = (i: -gravity.j, j: gravity.i)
            gravities[.right] = (i: gravity.j, j: -gravity.i)
            
            let gravityV = CGVector(dx: CGFloat(gravity.j), dy: CGFloat(gravity.i))
//            print("gravityV: \(gravityV)")
            
            let closestV = (diagonalsVectors.map({
                var angle = abs(gravityV.angle(to: $0))
                
                angle = angle > .pi ? (2 * .pi) - angle : angle
//                print("$0 is \($0), angle is \(angle)")
                return ($0, angle)
            }).min(by: { $0.1 < $1.1 }) ?? (gravityV, CGFloat(0))).0
//            print("closestV: \(closestV)")
            
            let rotatedVector = closestV.rotate(degrees: 45)
//            print("rotatedVector: \(rotatedVector)")
            
            let rotatedGravity = (i: Float(rotatedVector.dy), j: Float(rotatedVector.dx))
//            print("rotatedGravity: \(rotatedGravity)")
        
            gravities[.downRight] = rotatedGravity
            gravities[.upLeft] = (i: -rotatedGravity.i, j: -rotatedGravity.j)
            gravities[.downLeft] = (i: -rotatedGravity.j, j: rotatedGravity.i)
            gravities[.upRight] = (i: rotatedGravity.j, j: -rotatedGravity.i)
        }
    }
    var gravities: [Direction: (i: Float, j: Float)] = [:]
    
    override func didMove(to view: SKView) {
        gravity = defaultGravity
        
        print("[didMove] createWaterContainer()")
        createWaterContainer()
        
        print("[didMove] createNodeMatrix(...)")
        createNodeMatrix(count: MATRIX_SIZE, anchor: containerNode)
        
        print("[didMove] createSimulationMatrixes(...)")
        createSimulationMatrixes(count: MATRIX_SIZE, anchorNode: containerNode)
        
        print("[didMove] updateNodes()")
        updateNodes()
    }
    
    fileprivate func createWaterContainer() {
        func nodeSetup(_ node: SKSpriteNode) {
            node.size = CGSize(width: width, height: width)
            node.position = .zero
        }
        
        let width = frame.width
        
        // Add the container
        containerNode.zPosition = 1
        addChild(containerNode)
        nodeSetup(containerNode)
        
        // Add the border
        containerBorderNode.zPosition = 3
        addChild(containerBorderNode)
        nodeSetup(containerBorderNode)
    }
    
    fileprivate func createNodeMatrix(count: Int,
                                      anchor: SKSpriteNode) {
        // Assumes that anchor is a circle with equal width and height
        let anchorSize = anchor.frame.width
        let cellSideSize = anchorSize / CGFloat(count)
        
        cellSize = CGSize(width: cellSideSize, height: cellSideSize)
        
        nodeMatrix = []
        
        for i in 0..<count {
            nodeMatrix.append([])
            for j in 0..<count {
                let node = SKSpriteNode()
                node.size = cellSize!
                node.zPosition = 2
                
                addChild(node)
                nodeMatrix[i].append(node)
                
                node.position = CGPoint(
                    x: -anchorSize/2 + (CGFloat(j) * cellSideSize) + cellSideSize/2,
                    y: -anchorSize/2 + (CGFloat(i) * cellSideSize) + cellSideSize/2)
            }
        }
    }
    
    fileprivate func createSimulationMatrixes(count: Int,
                                              anchorNode: SKSpriteNode) {
        cellMatrix = []
        for _ in 0..<count {
            cellMatrix.append(Array(repeating: ID_STARTING, count: count))
        }
        
        let circleSize = containerNode.frame.width/2
        
        // This is the proportion of the external circle in relation to the internal circle
        let ringProportion = 0.095
        let ringSize = circleSize * ringProportion
        
        let actualSize = circleSize - ringSize
        
        let center = CGPoint.zero
        
        let edgePoint = CGPoint(x: actualSize, y: 0)
        let maxDistance = center.distance(to: edgePoint)
        
        let waterDistance = maxDistance / 1.8
        
//        print("[createSimulationMatrixes] maxDistance: \(maxDistance)")
        
        // Draw a circle of border in cell matrix
        for i in 0..<count {
            for j in 0..<count {
                // Get the associated node
                let node = nodeMatrix[i][j]
                
                // Check if this point belongs to the circle
                let distance = node.position.distance(to: center)
//                print("[createSimulationMatrixes] distance: \(distance)")
                
                // If the node is not intersecting with the container, mark it as a border
                if distance >= maxDistance {
                    cellMatrix[i][j] = ID_BORDER
                }
                
                if distance <= waterDistance {
                    cellMatrix[i][j] = 2
                }
            }
        }
        
        cellMatrixBuffer = cellMatrix
    }
    
    
    fileprivate func getMatrixPosition(for containerPos: CGPoint) -> (i: Int, j: Int) {
        let width = containerNode.frame.width
        let positiveX = containerPos.x + width/2
        let fractionalJ = positiveX / width * CGFloat(MATRIX_SIZE)
        let j = Int(fractionalJ.rounded(.down))
        
        let height = containerNode.frame.height
        let positiveY = (containerPos.y) + height/2
        let fractionalI = positiveY / height * CGFloat(MATRIX_SIZE)
        let i = Int(fractionalI.rounded(.down))
        
        return (i, j)
    }
    
    func touchDown(atPoint pos : CGPoint) {
        if !containerNode.contains(pos) { return }
        
        let convertedPos = containerNode.convert(pos, from: self)
        let matrixPos = getMatrixPosition(for: convertedPos)
        
        let i = matrixPos.i
        let j = matrixPos.j
        
        let coordinate = (i: i, j: j)
        
//        print("====================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================")
//        print("Gravity \(gravity)")
        
        let rotatedVector = CGVector(dx: CGFloat(gravity.j), dy: CGFloat(gravity.i)).rotate(degrees: 45)
        let rotatedGravity = (i: Float(rotatedVector.dy), j: Float(rotatedVector.dx))
        
//        print("Rotated Gravity \(rotatedGravity)")
//
//        print("(i: \(i), j: \(j))")
//
//        print("down: \(getCellCoordinates(from: coordinate, direction: .down))")
//        print("left: \(getCellCoordinates(from: coordinate, direction: .left))")
//        print("right: \(getCellCoordinates(from: coordinate, direction: .right))")
//        print("up: \(getCellCoordinates(from: coordinate, direction: .up))")
//        print("downLeft: \(getCellCoordinates(from: coordinate, direction: .downLeft))")
//        print("downRight: \(getCellCoordinates(from: coordinate, direction: .downRight))")
//        print("upLeft: \(getCellCoordinates(from: coordinate, direction: .upLeft))")
//        print("upRight: \(getCellCoordinates(from: coordinate, direction: .upRight))")
//        print("rotated down: \(getCellCoordinates(from: coordinate, direction: .downLeft))")
//        print("rotated left: \(getCellCoordinates(from: coordinate, direction: .downRight))")
//        print("rotated right: \(getCellCoordinates(from: coordinate, direction: .upLeft))")
//        print("rotated up: \(getCellCoordinates(from: coordinate, direction: .upRight))")
        
//        if (cellMatrix[i][j] == 0) {
            cellMatrix[i][j] = 1
//        }
    }
    
    func touchMoved(toPoint pos : CGPoint) {
        if !containerNode.contains(pos) { return }
        
        let convertedPos = containerNode.convert(pos, from: self)
        let matrixPos = getMatrixPosition(for: convertedPos)
        
        let i = matrixPos.i
        let j = matrixPos.j
        
//        if (cellMatrix[i][j] == 0) {
            cellMatrix[i][j] = 1
//        }
    }
    
    func touchUp(atPoint pos : CGPoint) {
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchDown(atPoint: t.location(in: self)) }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchMoved(toPoint: t.location(in: self)) }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        updateCells()
        updateNodes()
    }
    
    fileprivate func updateNodes() {
        let size = MATRIX_SIZE
        
        // Draw a circle of border in cell matrix
        for i in 0..<size {
            for j in 0..<size {
                // Get the associated node
                let node = nodeMatrix[i][j]
                
                let intensity = cellMatrix[i][j]
                
                //                print("Updating texture for \(i), \(j) with intensity \(intensity)")
                
                // If the node is not intersecting with the container, mark it as a border
                
                node.texture = getTexture(for: intensity)
            }
        }
        
//        let reference = (i: 40, j: 40)
//
//        let below = getCellCoordinates(from: reference, direction: .down)
//        nodeMatrix[below.i][below.j].texture = nil
//        nodeMatrix[below.i][below.j].color = .red
//
//
//        let left = getCellCoordinates(from: reference, direction: .left)
//        nodeMatrix[left.i][left.j].texture = nil
//        nodeMatrix[left.i][left.j].color = .yellow
//
//
//        let right = getCellCoordinates(from: reference, direction: .right)
//        nodeMatrix[right.i][right.j].texture = nil
//        nodeMatrix[right.i][right.j].color = .green
//
//
//        let top = getCellCoordinates(from: reference, direction: .up)
//        nodeMatrix[top.i][top.j].texture = nil
//        nodeMatrix[top.i][top.j].color = .blue
//
//
//        let downleft = getCellCoordinates(from: reference, direction: .downLeft)
//        nodeMatrix[downleft.i][downleft.j].texture = nil
//        nodeMatrix[downleft.i][downleft.j].color = .systemPink
//
//
//        let downRight = getCellCoordinates(from: reference, direction: .downRight)
//        nodeMatrix[downRight.i][downRight.j].texture = nil
//        nodeMatrix[downRight.i][downRight.j].color = .brown
//
//
//        let upLeft = getCellCoordinates(from: reference, direction: .upLeft)
//        nodeMatrix[upLeft.i][upLeft.j].texture = nil
//        nodeMatrix[upLeft.i][upLeft.j].color = .cyan
//
//
//        let upRight = getCellCoordinates(from: reference, direction: .upRight)
//        nodeMatrix[upRight.i][upRight.j].texture = nil
//        nodeMatrix[upRight.i][upRight.j].color = .gray
    }
    
    fileprivate func getTexture(for value: Float) -> SKTexture {
        let rounded = Float(round(value * 100) / 100)
        if let texture = waterTextureCache[rounded] { return texture }
        
        // Create texture
        
        let bytes: [UInt8]
        
        if rounded == -1 || rounded == 0 {
            bytes = [
                UInt8(0), // red
                UInt8(0), // green
                UInt8(0), // blue
                UInt8(0)              // alpha
            ]
        } else if rounded >= 0.9 {
            bytes = [
                UInt8(139), // red
                UInt8(157), // green
                UInt8(235), // blue
                UInt8(255)              // alpha
            ]
        } else if rounded >= 0.7 {
            bytes = [
                UInt8(172), // red
                UInt8(183), // green
                UInt8(245), // blue
                UInt8(255)              // alpha
            ]
        } else if rounded > 0 {
            bytes = [
                UInt8(187), // red
                UInt8(196), // green
                UInt8(245), // blue
                UInt8(255)              // alpha
            ]
        } else {
            bytes = [
                UInt8(200), // red
                UInt8(207), // green
                UInt8(243), // blue
                UInt8(255)              // alpha
            ]
        }
        
        let data = Data(bytes)
        
        let texture = SKTexture(data: data, size: CGSize(width: 1, height: 1))
        waterTextureCache[rounded] = texture
        
        return texture
    }
}

extension GameScene {
    
    enum Direction {
        case up // multiplies by -1
        case down
        case left // rotates 90 degrees left
        case right // rotates 90 degrees right
        
        case upLeft
        case upRight
        case downLeft
        case downRight
    }
    
    // Water Simulation
    //Returns the amount of water that should be in the bottom cell.
    func getStableState(totalMass: Float) -> Float {
        if (totalMass <= 1) {
            return 1
        } else if (totalMass < 2 * maxMass + maxCompress) {
            return (maxMass*maxMass + totalMass*maxCompress)/(maxMass + maxCompress)
        } else {
            return (totalMass + maxCompress)/2
        }
    }
    
    func getCellCoordinates(from coordinate: (i: Int, j: Int),
                           direction: Direction) -> (i: Int, j: Int) {
        let force = gravities[direction]!
        
        let newCoordinateF = (i: Float(coordinate.i) + force.i,
                             j: Float(coordinate.j) + force.j)
        
        let newCoordinate = (i: Int(newCoordinateF.i.rounded(.toNearestOrEven)),
                             j: Int(newCoordinateF.j.rounded(.toNearestOrEven)))
        
        return newCoordinate
    }
    
    // Applies direction in a cell using the custom gravity set. If the cell exceeds any limits, returns nil
    func getCellCoordinates(from coordinate: (i: Int, j: Int),
                 direction: Direction,
                 limits: (i: Int, j: Int)) -> (i: Int, j: Int)? {
        let newCoordinate = getCellCoordinates(from: coordinate, direction: direction)
        
        if newCoordinate.i >= limits.i
            || newCoordinate.j >= limits.j
            || newCoordinate.i < 0
            || newCoordinate.j < 0 { return nil }
        
        return newCoordinate
    }
    
    func updateCells() {
        var flow: Float = 0
        var remainingMass: Float = 0
        
        let limits = (i: MATRIX_SIZE, j: MATRIX_SIZE)
        
        cellMatrixBuffer = cellMatrix

        for i in 0..<MATRIX_SIZE {
            for j in 0..<MATRIX_SIZE {
                let currentValue = cellMatrix[i][j]
                
                guard currentValue != ID_BORDER else { continue }
                
                //Custom push-only flow
                flow = 0
                remainingMass = cellMatrix[i][j]
                
                guard remainingMass > 0 else { continue }
                
                let downCoordinates = getCellCoordinates(
                    from: (i: i, j: j),
                    direction: .down,
                    limits: limits)
                
                //The block below this one
                if let downCoordinates = downCoordinates,
                   cellMatrix[downCoordinates.i][downCoordinates.j] != ID_BORDER {
                    
                    let belowValue = cellMatrix[downCoordinates.i][downCoordinates.j]
                    
                    flow = getStableState(totalMass: remainingMass + belowValue) - belowValue
                    
                    if flow > minFlow {
                        flow *= 0.5 //leads to smoother flow
                    }
                    
                    flow = clamp(flow, 0, min(maxSpeed, remainingMass))
                    
                    cellMatrixBuffer[i][j] -= flow
                    cellMatrixBuffer[downCoordinates.i][downCoordinates.j] += flow
                    remainingMass -= flow
                }
                
                guard remainingMass > 0 else { continue }
                
                
                
                let downLeftCoordinates = getCellCoordinates(
                    from: (i: i, j: j),
                    direction: .downLeft,
                    limits: limits)
                
            
            // Downleft
            if let downCoordinates = downCoordinates,
               let downLeftCoordinates = downLeftCoordinates,
               downCoordinates != downLeftCoordinates,
               cellMatrix[downLeftCoordinates.i][downLeftCoordinates.j] != ID_BORDER {
                
                let downLeftValue = cellMatrix[downLeftCoordinates.i][downLeftCoordinates.j]
                
                flow = getStableState(totalMass: (remainingMass/2) + downLeftValue) - downLeftValue
                
                if flow > minFlow {
                    flow *= 0.5 //leads to smoother flow
                }
                
                flow = clamp(flow, 0, min(maxSpeed, remainingMass/2))
                
                cellMatrixBuffer[i][j] -= flow
                cellMatrixBuffer[downLeftCoordinates.i][downLeftCoordinates.j] += flow
                remainingMass -= flow
            }
                
                
                let downRightCoordinates = getCellCoordinates(
                    from: (i: i, j: j),
                    direction: .downRight,
                    limits: limits)
                
            
            // DownRight
            if let downCoordinates = downCoordinates,
               let downRightCoordinates = downRightCoordinates,
               downCoordinates != downRightCoordinates,
               cellMatrix[downRightCoordinates.i][downRightCoordinates.j] != ID_BORDER {
                
                let downRightValue = cellMatrix[downRightCoordinates.i][downRightCoordinates.j]
                
                flow = getStableState(totalMass: (remainingMass/2) + downRightValue) - downRightValue
                
                if flow > minFlow {
                    flow *= 0.5 //leads to smoother flow
                }
                
                flow = clamp(flow, 0, min(maxSpeed, remainingMass/2))
                
                cellMatrixBuffer[i][j] -= flow
                cellMatrixBuffer[downRightCoordinates.i][downRightCoordinates.j] += flow
                remainingMass -= flow
            }
                
                //Left
                let leftCoordinates = getCellCoordinates(
                    from: (i: i, j: j),
                    direction: .left,
                    limits: limits)
                
                if let leftCoordinates = leftCoordinates,
                   cellMatrix[leftCoordinates.i][leftCoordinates.j] != ID_BORDER {
                    //Equalize the amount of water in this block and it's neighbour
                    
                    let leftValue = cellMatrix[leftCoordinates.i][leftCoordinates.j]
                    
                    flow = (currentValue - leftValue)/4
                    
                    if flow > minFlow { flow *= 0.5 }
                    
                    flow = clamp(flow, 0, remainingMass)
                    
                    cellMatrixBuffer[i][j] -= flow
                    cellMatrixBuffer[leftCoordinates.i][leftCoordinates.j] += flow
                    remainingMass -= flow
                }
                
                guard remainingMass > 0 else { continue }
                
                //Right
                let rightCoordinates = getCellCoordinates(
                    from: (i: i, j: j),
                    direction: .right,
                    limits: limits)
                
                if let rightCoordinates = rightCoordinates,
                   cellMatrix[rightCoordinates.i][rightCoordinates.j] != ID_BORDER {
                    //Equalize the amount of water in this block and it's neighbour
                    
                    let rightValue = cellMatrix[rightCoordinates.i][rightCoordinates.j]
                    
                    flow = (currentValue - rightValue)/4
                    
                    if flow > minFlow { flow *= 0.5 }
                    
                    flow = clamp(flow, 0, remainingMass)
                    
                    cellMatrixBuffer[i][j] -= flow
                    cellMatrixBuffer[rightCoordinates.i][rightCoordinates.j] += flow
                    remainingMass -= flow
                }
                
                guard remainingMass > 0 else { continue }
                
                let upCoordinates = getCellCoordinates(
                    from: (i: i, j: j),
                    direction: .up,
                    limits: limits)
                
                if let upCoordinates = upCoordinates,
                   cellMatrix[upCoordinates.i][upCoordinates.j] != ID_BORDER {
                    //Equalize the amount of water in this block and it's neighbour
                    
                    let upValue = cellMatrix[upCoordinates.i][upCoordinates.j]
                    
                    flow = remainingMass - getStableState(totalMass: remainingMass + upValue)
                    
                    if flow > minFlow { flow *= 0.5 }
                    
                    flow = clamp(flow, 0, min(maxSpeed, remainingMass))
                    
                    cellMatrixBuffer[i][j] -= flow
                    cellMatrixBuffer[upCoordinates.i][upCoordinates.j] += flow
                    remainingMass -= flow
                }
            }
        }
        
        cellMatrix = cellMatrixBuffer
    }
}

func clamp(_ x: Float, _ minv: Float, _ maxv: Float) -> Float {
    max(minv, min(maxv, x))
}
