//
//  ViewController.swift
//  AR ruler sceneKit
//

import UIKit
import SceneKit
import ARKit
import PusherSwift

//Create a line which connects between vector1 and vector2 in 3D vector.
extension SCNGeometry {
    class func lineFrom(vector vector1: SCNVector3, toVector vector2: SCNVector3) -> SCNGeometry {
        let indices: [Int32] = [0, 1]
        
        let source = SCNGeometrySource(vertices: [vector1, vector2])
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        
        return SCNGeometry(sources: [source], elements: [element])
    }
}
//Calculate a distance between vector1 and vector2 in 3D vector.
extension SCNVector3 {
    static func distanceFrom(vector vector1: SCNVector3, toVector vector2: SCNVector3) -> Float {
        let x0 = vector1.x
        let x1 = vector2.x
        let y0 = vector1.y
        let y1 = vector2.y
        let z0 = vector1.z
        let z1 = vector2.z
        //distance = {(x1-x0)^2 + (y1-y0)^2 + (z1-z0)^2}^(1/2)
        return sqrtf(powf(x1-x0, 2) + powf(y1-y0, 2) + powf(z1-z0, 2))
    }
}
//Convert measurments from meter to inches/cm
extension Float {
    func metersToInches() -> Float {
        return self * 39.3701
    }
    
    func metersTocm() -> Float {
        return self * 100
    }
}

//Screen view controller
class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var labelField: UITextField!
    @IBOutlet var sceneView: ARSCNView!
        
    var numberOfTaps = 0
    
    let pusher = Pusher(
          key: "",
          options: PusherClientOptions(
              authMethod: .inline(secret: ""),
              host: .cluster("us3")
          )
      )
    
    var channel: PusherChannel!
    var sendingTime : TimeInterval = 0
    var distance: Float!
    var unit: String!
    
    var startPoint: SCNVector3!
    var endPoint: SCNVector3!
    
    //called when the view finishes loading
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Set the view's delegate
        sceneView.delegate = self
        labelField.delegate = self
        distance = 0.0
        unit = "in"
        
        channel = pusher.subscribe("private-channel")
        pusher.connect()
    
        //Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        //Create a new scene
        let scene = SCNScene()

        //Set the scene to the view
        sceneView.scene = scene
        
        //Recognize single or multple taps on your screen
                //'tapped' method is called here
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapOnScreen))
        sceneView.addGestureRecognizer(gestureRecognizer)
    }
    
    func sendPusherEvent() {
        channel.trigger(eventName: "client-new-measurement", data: ["payload": labelField.text! + String(format: " %.2f " + unit, distance!)])
    }
    
    //Used to communicate the changes in screens
    //Triggered in response to a change in the state of the application
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //Tracks the device's movement with six degrees of freedom: the three rotation axes (roll, pitch, and yaw), and three translation axes (movement in x, y, and z)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal

        //Run the view's session
        sceneView.session.run(configuration)
    }
    //Called when you tap your screen
    @objc func tapOnScreen(gesture: UITapGestureRecognizer) {
        numberOfTaps += 1
                
        //Get 2D position of screen where you tapped
        let tappedPosition = gesture.location(in: sceneView)
        
        //Convert 2D position to 3D
        let hitTestResults = sceneView.hitTest(tappedPosition, types: .existingPlane)
        guard let hitPos = hitTestResults.first else { return }
        
        //First tap (Starting position)
        if numberOfTaps == 1
        {
            //Get the staring position in 3D vector
            startPoint = SCNVector3(hitPos.worldTransform.columns.3.x, hitPos.worldTransform.columns.3.y, hitPos.worldTransform.columns.3.z)
            //Display gray dot on screen
            addStartMarker(hitTestResult: hitPos)
        }
        //Second tap (Ending position)
        else
        {
            //Reset to 0
            numberOfTaps = 0
            //Get the staring position in 3D vector
            endPoint = SCNVector3(hitPos.worldTransform.columns.3.x, hitPos.worldTransform.columns.3.y, hitPos.worldTransform.columns.3.z)
            //Display gray dot on screen
            addEndMarker(hitTestResult: hitPos)
            //Display line between two gray dots
            addLineBetween(start: startPoint, end: endPoint)
            
            distance = SCNVector3.distanceFrom(vector: startPoint, toVector: endPoint)
            if unit == "in" {
                distance = distance.metersToInches()
            } else {
                distance = distance.metersTocm()
            }
            //Add the distance between two dots in text
            addDistanceText(distance: distance, at: endPoint)
        }
    }
    //Add a lightgrey dot at starting position
    func addStartMarker(hitTestResult: ARHitTestResult) {
        addMarker(hitTestResult: hitTestResult, color: .lightGray)
    }
    //Add a grey dot at ending position
    func addEndMarker(hitTestResult: ARHitTestResult) {
        addMarker(hitTestResult: hitTestResult, color: .gray)
    }
    //Add a dot at a tapped position
    func addMarker(hitTestResult: ARHitTestResult, color: UIColor) {
        //Set size of a dot
        let geometry = SCNSphere(radius: 0.003)
        //Set colot
        geometry.firstMaterial?.diffuse.contents = color
        
        let markerNode = SCNNode(geometry: geometry)
        //Set position of a dot in 3D vector
        markerNode.position = SCNVector3(hitTestResult.worldTransform.columns.3.x, hitTestResult.worldTransform.columns.3.y, hitTestResult.worldTransform.columns.3.z)
        //Add the dot in the view
        sceneView.scene.rootNode.addChildNode(markerNode)
    }
    //Add a line between two dots
    func addLineBetween(start: SCNVector3, end: SCNVector3) {
        //Create line from start to end
        let lineGeometry = SCNGeometry.lineFrom(vector: start, toVector: end)
        let lineNode = SCNNode(geometry: lineGeometry)
        //Add the line in the view
        sceneView.scene.rootNode.addChildNode(lineNode)
    }
    //Add a distance in text
    func addDistanceText(distance: Float, at point: SCNVector3) {
        //Set text style
        let textGeometry = SCNText(string: String(format: "%.2f " + unit, distance), extrusionDepth: 1)
        textGeometry.flatness = 0.005
        textGeometry.font = UIFont.systemFont(ofSize: 7)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        //Create a node
        let textNode = SCNNode(geometry: textGeometry)
        //Set position to display the text
        textNode.position = SCNVector3Make(point.x, point.y, point.z);
        //Set scale of text
        textNode.scale = SCNVector3Make(0.005, 0.005, 0.005)
        //Add text in the view
        sceneView.scene.rootNode.addChildNode(textNode)
    }
    

    @IBAction func unitChange(_ sender: UISegmentedControl) {
        if unit == "in" {
            unit = "cm"
        } else {
            unit = "in"
        }
    }
    
    func listenEvent() {
        channel.bind(eventName: "client-new-measurement", eventCallback: { (event: PusherEvent) -> Void in
            if let data: String = event.data {
                print(data)
            }
        })
    }
    
    func showAlert() {
        let alert = UIAlertController(title: "", message: "Measurement sent", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { action in print("button clicked")}))
        present(alert, animated: true)
    }
    
    @IBAction func sendButton(_ sender: UIButton) {
        sceneView.scene.rootNode.removeAllAnimations()
        sendPusherEvent()
        showAlert()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        labelField.resignFirstResponder()
    }
}

extension ViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
