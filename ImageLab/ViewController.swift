//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation
import Charts
import Metal
import Accelerate

class ViewController: UIViewController  {

    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
    let bridge = OpenCVBridge()
    let baseArray : [Float] = Array(repeating: 0.0, count: 50)
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.view)
    }()
    
    //MARK: Outlets in view
    @IBOutlet weak var bpm: UILabel!
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()

        graph?.addGraph(withName: "ppg",
                        shouldNormalize: false,
                        numPointsInGraph: 50)
        
//        self.view.backgroundColor = nil
        
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
        
        Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateGraph), userInfo: nil, repeats: true)
    }
    
    @objc func updateGraph() {
        if let hues = self.bridge.getHues() {
            if(hues.count >= 50) {
                var temp : [Double] = []
                for i in ((hues.count - 50)..<hues.count) {
                    var tempNum = hues[i] as! NSNumber
                    //                            print(tempNum.floatValue)
                    //                            var tempNum1 = ((tempNum.floatValue * 100) - Float(Int(tempNum.floatValue * 100)))
                    temp.append(tempNum.doubleValue)
                }
                var mn: Double = 0.0 // mean value
                vDSP_meanvD(temp, 1, &mn, vDSP_Length(temp.count))

                var ms: Double = 0.0 // mean square value
                vDSP_measqvD(temp, 1, &ms, vDSP_Length(temp.count))

                let sddev = sqrt(ms - mn * mn) * sqrt(Double(temp.count)/Double(temp.count - 1))
                
                let results = temp.map { Float(($0 - mn) / sddev) / 10.0 }
                self.graph?.updateGraph(data: results, forKey: "ppg")
            } //else {
//                self.graph?.updateGraph(data: self.baseArray, forKey: "ppg")
//            }
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
            if fingerFound {
//                if let hues = self.bridge.getHues() {
//                    if(hues.count >= 500) {
//                        var temp : [Float] = []
//                        for i in hues.count - 500..<hues.count {
//                            var tempNum = hues[i] as! NSNumber
////                            print(tempNum.floatValue)
////                            var tempNum1 = ((tempNum.floatValue * 100) - Float(Int(tempNum.floatValue * 100)))
//                            temp.append(tempNum.floatValue)
//                        }
//                        print(temp)
//                        self.graph?.updateGraph(data: temp, forKey: "ppg")
//                    } else {
//                        self.graph?.updateGraph(data: self.baseArray, forKey: "ppg")
//                    }
//                }
                
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
}

