//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © 2016 Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController   {

    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    lazy var videoManager:VideoAnalgesic! = {
        let tmpManager = VideoAnalgesic(mainView: self.view)
        tmpManager.setCameraPosition(position: .back)
        return tmpManager
    }()
    
    lazy var detector:CIDetector! = {
        // create dictionary for face detection
        // HINT: you need to manipulate these properties for better face detection efficiency
        let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyHigh,
                            CIDetectorTracking:true]
        
        // setup a face detector in swift
        let detector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: self.videoManager.getCIContext(), // perform on the GPU is possible
            options: optsDetector)
        
        return detector
    }()
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // no background needed
        self.view.backgroundColor = nil
        self.setupFilters()
        
        self.videoManager.setCameraPosition(position: .front)
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
    
    }
    
    //MARK: Setup filtering
    func setupFilters(){
        filters = []
        
        // starting values for filter
        let filterPinch = CIFilter(name:"CIBumpDistortion")!
        filterPinch.setValue(0.5, forKey: "inputScale")
        filterPinch.setValue(25, forKey: "inputRadius")
        filters.append(filterPinch)
        let filterSwirl = CIFilter(name:"CITwirlDistortion")!
        filterSwirl.setValue(10, forKey: "inputRadius")
        filters.append(filterSwirl)
        
    }
    
    //MARK: Apply filters and apply feature detectors
    func applyFiltersToFaces(inputImage:CIImage,features:[CIFaceFeature])->CIImage{
        var retImage = inputImage
        var filterCenterLeftEye = CGPoint()
        var filterCenterRightEye = CGPoint()
        var filterCenterSmile = CGPoint()
        var eyeRadius = 25
        var mouthRadius = 25
        
        for f in features { // for each face
            //set where to apply filter
            let leftEyeClosed = f.leftEyeClosed
            let rightEyeClosed = f.rightEyeClosed
            let blinking = f.rightEyeClosed && f.leftEyeClosed
            let isSmiling = f.hasSmile
            print("isSmiling \(isSmiling)")
            print("blinking \(blinking)")
            print("rightEyeClosed \(rightEyeClosed)")
            print("leftEyeClosed \(leftEyeClosed)\n\n")
            
            filterCenterRightEye.x = f.rightEyePosition.x
            filterCenterRightEye.y = f.rightEyePosition.y
            filterCenterLeftEye.x = f.leftEyePosition.x
            filterCenterLeftEye.y = f.leftEyePosition.y
            filterCenterSmile.x = f.mouthPosition.x
            filterCenterSmile.y = f.mouthPosition.y
            eyeRadius = Int(f.bounds.width/2)
            mouthRadius = Int(f.bounds.width/4)

            //do for each filter (assumes all filters have property, "inputCenter")
//            for filt in filters{
            filters[0].setValue(retImage, forKey: kCIInputImageKey)
            filters[0].setValue(CIVector(cgPoint: filterCenterLeftEye), forKey: "inputCenter")
            filters[0].setValue(eyeRadius, forKey: "inputRadius")
            retImage = filters[0].outputImage!
            filters[0].setValue(retImage, forKey: kCIInputImageKey)
            filters[0].setValue(CIVector(cgPoint: filterCenterRightEye), forKey: "inputCenter")
            filters[0].setValue(eyeRadius, forKey: "inputRadius")
            retImage = filters[0].outputImage!
            filters[1].setValue(retImage, forKey: kCIInputImageKey)
            filters[1].setValue(CIVector(cgPoint: filterCenterSmile), forKey: "inputCenter")
            filters[1].setValue(mouthRadius, forKey: "inputRadius")
            retImage = filters[1].outputImage!
//            }
        }
        return retImage
    }
    
    func getFaces(img:CIImage) -> [CIFaceFeature]{
        // this ungodly mess makes sure the image is the correct orientation
        let optsFace = [CIDetectorImageOrientation:self.videoManager.ciOrientation,
                                   CIDetectorSmile: true,
                                CIDetectorEyeBlink: true] as [String : Any]
        // get Face Features
        return self.detector.features(in: img, options: optsFace) as! [CIFaceFeature]
        
    }
    
    //MARK: Process image output
    func processImage(inputImage:CIImage) -> CIImage{
        
        // detect faces
        let faces = getFaces(img: inputImage)
        
        // if no faces, just return original image
        if faces.count == 0 { return inputImage }
        
        //otherwise apply the filters to the faces
        return applyFiltersToFaces(inputImage: inputImage, features: faces)
    }
    
    

   
}

