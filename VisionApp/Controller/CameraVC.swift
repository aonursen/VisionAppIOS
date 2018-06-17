//
//  ViewController.swift
//  VisionApp
//
//  Created by Arif Onur Şen on 27.02.2018.
//  Copyright © 2018 LiniaTech. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision


enum flashState {
    case on
    case off
}

class CameraVC: UIViewController {
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    var photoData: Data?
    var flashControl: flashState = .off
    var speech = AVSpeechSynthesizer()
    var captureSession: AVCaptureSession!
    var cameraOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    @IBOutlet weak var itemName: UILabel!
    @IBOutlet weak var confidenceLbl: UILabel!
    @IBOutlet weak var flashBtn: RoundedButton!
    @IBOutlet weak var capturedImage: UIImageView!
    @IBOutlet weak var roundedLabelView: ShadowView!
    override func viewDidLoad() {
        super.viewDidLoad()
        speech.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        activityIndicator.isHidden = true
        previewLayer.frame = cameraView.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector (didTapCameraView))
        
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        
        let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera!)
            if captureSession.canAddInput(input) == true {
                captureSession.addInput(input)
            }
            
            cameraOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddOutput(cameraOutput) == true {
                captureSession.addOutput(cameraOutput)
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                
                previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
                previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                
                cameraView.layer.addSublayer(previewLayer!)
                cameraView.addGestureRecognizer(tap)
                captureSession.startRunning()
            }
        } catch {
            debugPrint(error)
        }
    }
    
    @objc func didTapCameraView() {
        self.cameraView.isUserInteractionEnabled = false
        self.activityIndicator.isHidden = false
        self.activityIndicator.startAnimating()
        
        let settings = AVCapturePhotoSettings()
        
        settings.previewPhotoFormat = settings.embeddedThumbnailPhotoFormat
        
        if flashControl == .off {
            settings.flashMode = .off
        } else {
            settings.flashMode = .on
        }
        
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func resultMethod(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation] else {return}
        
        for classification in results {
            if classification.confidence < 0.5 {
                let message = "I'm not sure what this is.Please try again!"
                self.itemName.text = message
                synthesizeSpeech(speechString: message)
                self.confidenceLbl.text = ""
                break
            } else {
                let identification = classification.identifier
                let confidence = Int(classification.confidence * 100)
                self.itemName.text = identification
                let message = "This looks like a \(identification) and I'm \(confidence) percent sure."
                synthesizeSpeech(speechString: message)
                self.confidenceLbl.text = "Confidence: \(confidence)%"
                break
            }
        }
    }
    
    func synthesizeSpeech(speechString: String) {
        let speechUtterance = AVSpeechUtterance(string: speechString)
        speech.speak(speechUtterance)
    }


    @IBAction func flashBtnPressed(_ sender: Any) {
        switch flashControl {
        case .off:
            flashBtn.setTitle("FLASH ON", for: .normal)
            flashControl = .on
        case .on:
            flashBtn.setTitle("FLASH OFF", for: .normal)
            flashControl = .off
        }
    }
    
}

extension CameraVC: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            debugPrint(error)
        } else {
            photoData = photo.fileDataRepresentation()
            
            do {
                let model = try VNCoreMLModel(for: SqueezeNet().model)
                let request = VNCoreMLRequest(model: model, completionHandler: resultMethod)
                let handler = VNImageRequestHandler(data: photoData!)
                try handler.perform([request])
            } catch {
                debugPrint(error)
            }
            
            let image = UIImage(data: photoData!)
            self.capturedImage.image = image
        }
    }
}


extension CameraVC: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.cameraView.isUserInteractionEnabled = true
        self.activityIndicator.isHidden = true
        self.activityIndicator.stopAnimating()
    }
}
