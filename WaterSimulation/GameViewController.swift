//
//  GameViewController.swift
//  WaterSimulation
//
//  Created by Enzo Maruffa on 04/12/21.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    
    var scene: GameScene?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let view = self.view as! SKView? {
            // Load the SKScene from 'GameScene.sks'
            scene = GameScene(fileNamed: "GameScene")!
         
            // Set the scale mode to scale to fit the window
            scene!.scaleMode = .aspectFill
            
            // Present the scene
            view.presentScene(scene)
        
        
            view.ignoresSiblingOrder = true
            
            view.showsFPS = true
            view.showsPhysics = true
            view.showsNodeCount = true
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
