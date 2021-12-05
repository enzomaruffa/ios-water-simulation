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
    let minFlow: Float = 1.0 // ??
    let maxSpeed: Float = 8.0 // ??
    
    var gravity: (i: Float, j: Float) = (i: -1, j: 0)
    
    override func didMove(to view: SKView) {
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
//        containerBorderNode.zPosition = 3
//        addChild(containerBorderNode)
//        nodeSetup(containerBorderNode)
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
        let center = CGPoint.zero
        let edgePoint = CGPoint(x: circleSize, y: 0)
        let maxDistance = center.distance(to: edgePoint)
        
        print("[createSimulationMatrixes] maxDistance: \(maxDistance)")
        
        // Draw a circle of border in cell matrix
        for i in 0..<count {
            for j in 0..<count {
                // Get the associated node
                let node = nodeMatrix[i][j]
                
                // Check if this point belongs to the circle
                let distance = node.position.distance(to: center)
                print("[createSimulationMatrixes] distance: \(distance)")
                
                // If the node is not intersecting with the container, mark it as a border
                if distance >= maxDistance {
                    cellMatrix[i][j] = ID_BORDER
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
    }
    
    fileprivate func getTexture(for value: Float) -> SKTexture {
        let rounded = Float(round(value * 100) / 100)
        if let texture = waterTextureCache[rounded] { return texture }
        
        // Create texture
        
        let bytes: [UInt8]
        
        if rounded == -1 {
            bytes = [
                UInt8(255), // red
                UInt8(0), // green
                UInt8(0), // blue
                UInt8(1)              // alpha
            ]
        } else if rounded == 0 {
            bytes = [
                UInt8(0), // red
                UInt8(0), // green
                UInt8(0), // blue
                UInt8(0)              // alpha
            ]
        } else {
            bytes = [
                UInt8(140), // red
                UInt8(155), // green
                UInt8(248), // blue
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
        
        func transformGravity(_ gravity: (i: Float, j: Float)) -> (i: Float, j: Float) {
            let i = gravity.i
            let j = gravity.j
            if self == .up { return (i: -i, j: -j) }
            if self == .left { return (i: j, j: -i) }
            if self == .right { return (i: -j, j: i) }
            return gravity
        }
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
    
    // Applies direction in a cell using the custom gravity set. If the cell exceeds any limits, returns nil
    func getCellCoordinates(from coordinate: (i: Int, j: Int),
                 direction: Direction,
                 limits: (i: Int, j: Int)) -> (i: Int, j: Int)? {
        let force = direction.transformGravity(gravity)
        
        let newCoordinateF = (i: Float(coordinate.i) + force.i,
                             j: Float(coordinate.j) + force.j)
        
        let newCoordinate = (i: Int(newCoordinateF.i.rounded(.toNearestOrEven)),
                             j: Int(newCoordinateF.j.rounded(.toNearestOrEven)))
        
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

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow((point.x - x), 2) + pow((point.y - y), 2))
    }
}
