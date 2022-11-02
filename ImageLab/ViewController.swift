//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController   {

    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
    let bridge = OpenCVBridge()
    
    //MARK: Outlets in view
    @IBOutlet weak var flashSlider: UISlider!
    @IBOutlet weak var toggleCamera: UIButton!
    @IBOutlet weak var stageLabel: UILabel!
    
    @IBOutlet weak var bpm: UILabel!
    @IBOutlet weak var toggleFlash: UIButton!
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        
        // setup the OpenCV bridge nose detector, from file
        self.bridge.loadHaarCascade(withFilename: "nose")
        
        self.videoManager = VideoAnalgesic(mainView: self.view)
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.back)
        
        // create dictionary for face detection
        // HINT: you need to manipulate these properties for better face detection efficiency
        let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyLow,CIDetectorTracking:true] as [String : Any]
        
        // setup a face detector in swift
        self.detector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: self.videoManager.getCIContext(), // perform on the GPU is possible
            options: (optsDetector as [String : AnyObject]))
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImageSwift, showCamera: false)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.videoManager.stop()
        self.videoManager.turnOffFlash()
    }
    
    //MARK: Process image output
    func processImageSwift(inputImage:CIImage) -> CIImage{
        self.videoManager.turnOnFlashwithLevel(1.0) // turn on flash
        
        var retImage = inputImage // do the image stuff
        self.bridge.setImage(retImage, withBounds: retImage.extent, andContext: self.videoManager.getCIContext())
        self.bridge.setTransforms(self.videoManager.transform)

        let fingerFound = self.bridge.processFinger()
        
        DispatchQueue.main.async {
            self.toggleFlash.isEnabled = !fingerFound
            self.toggleCamera.isEnabled = !fingerFound
            if fingerFound {
                if(self.bridge.getPeaks() < 20) { // if not enough data show calculating bpm
                    self.bpm.font = self.bpm.font.withSize(16)
                    self.bpm.textColor = .none
                    self.bpm.text = "Calculating BPM..."
                } else { // if enough data show bpm
                    self.bpm.font = self.bpm.font.withSize(38)
                    self.bpm.textColor = UIColor.systemRed
                    self.bpm.text = String(Int(self.bridge.getHeartRate()))
                }
            }
            else { // show instruction if finger not on camera
                self.bpm.textColor = .none
                self.bpm.font = self.bpm.font.withSize(16)
                self.bpm.text = "Place your finger on the camera"
            }
        }
        
        retImage = self.bridge.getImageComposite() // get back opencv processed part of the image (overlayed on original)
        
        return retImage
    }
    
    //MARK: Setup Face Detection
    
    func getFaces(img:CIImage) -> [CIFaceFeature]{
        // this ungodly mess makes sure the image is the correct orientation
        let optsFace = [CIDetectorImageOrientation:self.videoManager.ciOrientation]
        // get Face Features
        return self.detector.features(in: img, options: optsFace) as! [CIFaceFeature]
        
    }
    
    
    // change the type of processing done in OpenCV
    @IBAction func swipeRecognized(_ sender: UISwipeGestureRecognizer) {
        switch sender.direction {
        case .left:
            self.bridge.processType += 1
        case .right:
            self.bridge.processType -= 1
        default:
            break
            
        }
        
        stageLabel.text = "Stage: \(self.bridge.processType)"

    }
    
    //MARK: Convenience Methods for UI Flash and Camera Toggle
    @IBAction func flash(_ sender: AnyObject) {
        if(self.videoManager.toggleFlash()){
            self.flashSlider.value = 1.0
        }
        else{
            self.flashSlider.value = 0.0
        }
    }
    
    @IBAction func switchCamera(_ sender: AnyObject) {
        self.videoManager.toggleCameraPosition()
    }
    
    @IBAction func setFlashLevel(_ sender: UISlider) {
        if(sender.value>0.0){
            let val = self.videoManager.turnOnFlashwithLevel(sender.value)
            if val {
                print("Flash return, no errors.")
            }
        }
        else if(sender.value==0.0){
            self.videoManager.turnOffFlash()
        }
    }

   
}

