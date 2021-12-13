//
//  GameViewController.swift
//  WaterSimulation
//
//  Created by Enzo Maruffa on 04/12/21.
//

import UIKit
import SpriteKit
import GameplayKit
import CoreMotion

class GameViewController: UIViewController {
    
    var scene: GameScene?
    let motion = CMMotionManager()
    var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let view = self.view as! SKView? {
            // Load the SKScene from 'GameScene.sks'
            scene = GameScene(fileNamed: "GameScene")!
         
            // Set the scale mode to scale to fit the window
            scene!.scaleMode = .aspectFit
            
            // Present the scene
            view.presentScene(scene)
        
        
            view.ignoresSiblingOrder = true
            
            view.showsFPS = true
            view.showsPhysics = true
            view.showsNodeCount = true
        }
        
        startDeviceMotion()
    }
    
    func startDeviceMotion() {
        if motion.isDeviceMotionAvailable {
            self.motion.deviceMotionUpdateInterval = 1.0 / 60.0
            self.motion.showsDeviceMovementDisplay = true
            self.motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
            
            // Configure a timer to fetch the motion data.
            self.timer = Timer(fire: Date(), interval: (1.0 / 60.0), repeats: true,
                               block: { (timer) in
                if let data = self.motion.deviceMotion {
                    // Get the attitude relative to the magnetic north reference frame.
//                    print(data.gravity)
                    
                    // +X = -j
                    // -X = +j
                    // +Y = -i
                    // -Y = +i
                    let vector = CGVector(dx: CGFloat(data.gravity.x),
                                          dy: CGFloat(data.gravity.y)).normalized() // * 1.2
                    
                    self.scene?.gravity = (i: Float(vector.dy),
                                           j: Float(vector.dx))
                    
                    // Use the motion data in your app.
                }
            })
            
            // Add the timer to the current run loop.
            RunLoop.current.add(self.timer!, forMode: RunLoop.Mode.default)
        }
    }

    override var shouldAutorotate: Bool {
        return false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
