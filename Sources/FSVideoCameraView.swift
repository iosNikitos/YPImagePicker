//
//  FSVideoCameraView.swift
//  Fusuma
//
//  Created by Brendan Kirchner on 3/18/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import AVFoundation

@objc protocol FSVideoCameraViewDelegate: class {
    func videoFinished(withFileURL fileURL: URL)
}

final class FSVideoCameraView: UIView {

    @IBOutlet weak var previewViewContainer: UIView!
    @IBOutlet weak var shotButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var flipButton: UIButton!
    
    weak var delegate: FSVideoCameraViewDelegate? = nil
    
    var session: AVCaptureSession?
    var device: AVCaptureDevice?
    var videoInput: AVCaptureDeviceInput?
    var videoOutput: AVCaptureMovieFileOutput?
    var focusView: UIView?
    
    var flashOffImage: UIImage?
    var flashOnImage: UIImage?
    var videoStartImage: UIImage?
    var videoStopImage: UIImage?

    
    fileprivate var isRecording = false
    
    static func instance() -> FSVideoCameraView {
        
        return UINib(nibName: "FSVideoCameraView", bundle: Bundle(for: self.classForCoder())).instantiate(withOwner: self, options: nil)[0] as! FSVideoCameraView
    }
    
    func initialize() {
        if session != nil {
            return
        }
        
        backgroundColor = fusumaBackgroundColor
        isHidden = false
        
        // AVCapture
        session = AVCaptureSession()
        
        for device in AVCaptureDevice.devices() {
            if let device = device as? AVCaptureDevice , device.position == AVCaptureDevicePosition.back {
                self.device = device
            }
        }
        
        do {
            if let session = session {
                videoInput = try AVCaptureDeviceInput(device: device)
                session.addInput(videoInput)
                videoOutput = AVCaptureMovieFileOutput()
                let totalSeconds = 60.0 //Total Seconds of capture time
                let timeScale: Int32 = 30 //FPS
                
                let maxDuration = CMTimeMakeWithSeconds(totalSeconds, timeScale)
                
                videoOutput?.maxRecordedDuration = maxDuration
                videoOutput?.minFreeDiskSpaceLimit = 1024 * 1024 //SET MIN FREE SPACE IN BYTES FOR RECORDING TO CONTINUE ON A VOLUME
                
                if session.canAddOutput(videoOutput) {
                    session.addOutput(videoOutput)
                }
                let videoLayer = AVCaptureVideoPreviewLayer(session: session)
                videoLayer?.frame = previewViewContainer.bounds
                videoLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
                previewViewContainer.layer.addSublayer(videoLayer!)
                session.startRunning()
                
            }
            
            // Focus View
            focusView = UIView(frame: CGRect(x: 0, y: 0, width: 90, height: 90))
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(FSVideoCameraView.focus(_:)))
            previewViewContainer.addGestureRecognizer(tapRecognizer)
        } catch {
        }
    
        let bundle = Bundle(for: self.classForCoder)
        
        flashOnImage = fusumaFlashOnImage != nil ? fusumaFlashOnImage : UIImage(named: "ic_flash_on", in: bundle, compatibleWith: nil)
        flashOffImage = fusumaFlashOffImage != nil ? fusumaFlashOffImage : UIImage(named: "ic_flash_off", in: bundle, compatibleWith: nil)
        let flipImage = fusumaFlipImage != nil ? fusumaFlipImage : UIImage(named: "ic_loop", in: bundle, compatibleWith: nil)
        videoStartImage = fusumaVideoStartImage != nil ? fusumaVideoStartImage : UIImage(named: "video_button", in: bundle, compatibleWith: nil)
        videoStopImage = fusumaVideoStopImage != nil ? fusumaVideoStopImage : UIImage(named: "video_button_rec", in: bundle, compatibleWith: nil)

        if(fusumaTintIcons) {
            flashButton.tintColor = fusumaBaseTintColor
            flipButton.tintColor  = fusumaBaseTintColor
            shotButton.tintColor  = fusumaBaseTintColor
            
            flashButton.setImage(flashOffImage?.withRenderingMode(.alwaysTemplate), for: .normal)
            flipButton.setImage(flipImage?.withRenderingMode(.alwaysTemplate), for: .normal)
            shotButton.setImage(videoStartImage?.withRenderingMode(.alwaysTemplate), for: .normal)
        } else {
            flashButton.setImage(flashOffImage, for: .normal)
            flipButton.setImage(flipImage, for: .normal)
            shotButton.setImage(videoStartImage, for: .normal)
        }
        
        flashConfiguration()
        startCamera()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func startCamera() {
        let status = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        if status == AVAuthorizationStatus.authorized {
            session?.startRunning()
        } else if status == AVAuthorizationStatus.denied || status == AVAuthorizationStatus.restricted {
            session?.stopRunning()
        }
    }
    
    func stopCamera() {
        if isRecording {
            toggleRecording()
        }
        session?.stopRunning()
    }
    
    @IBAction func shotButtonPressed(_ sender: UIButton) {
        toggleRecording()
    }
    
    fileprivate func toggleRecording() {
        guard let videoOutput = videoOutput else {
            return
        }
        
        isRecording = !isRecording
        
        let shotImage: UIImage?
        if isRecording {
            shotImage = videoStopImage
        } else {
            shotImage = videoStartImage
        }
        shotButton.setImage(shotImage, for: .normal)
        
        if isRecording {
            let outputPath = "\(NSTemporaryDirectory())output.mov"
            let outputURL = URL(fileURLWithPath: outputPath)
            
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: outputPath) {
                do {
                    try fileManager.removeItem(atPath: outputPath)
                } catch {
                    print("error removing item at path: \(outputPath)")
                    isRecording = false
                    return
                }
            }
            flipButton.isEnabled = false
            flashButton.isEnabled = false
            videoOutput.startRecording(toOutputFileURL: outputURL, recordingDelegate: self)
        } else {
            videoOutput.stopRecording()
            flipButton.isEnabled = true
            flashButton.isEnabled = true
        }
        return
    }
    
    @IBAction func flipButtonPressed(_ sender: UIButton) {
        session?.stopRunning()
        do {
            session?.beginConfiguration()
            if let session = session {
                for input in session.inputs {
                    session.removeInput(input as! AVCaptureInput)
                }
                
                let position = (videoInput?.device.position == AVCaptureDevicePosition.front) ? AVCaptureDevicePosition.back : AVCaptureDevicePosition.front
                for device in AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) {
                    if let device = device as? AVCaptureDevice , device.position == position {
                        videoInput = try AVCaptureDeviceInput(device: device)
                        session.addInput(videoInput)
                    }
                }
            }
            session?.commitConfiguration()
        } catch {
        }
        session?.startRunning()
    }
    
    @IBAction func flashButtonPressed(_ sender: UIButton) {
        do {
            if let device = device {
                try device.lockForConfiguration()
                let mode = device.flashMode
                if mode == AVCaptureFlashMode.off {
                    device.flashMode = AVCaptureFlashMode.on
                    flashButton.setImage(flashOnImage, for: .normal)
                } else if mode == AVCaptureFlashMode.on {
                    device.flashMode = AVCaptureFlashMode.off
                    flashButton.setImage(flashOffImage, for: .normal)
                }
                device.unlockForConfiguration()
            }
        } catch _ {
            flashButton.setImage(flashOffImage, for: .normal)
            return
        }
    }
}

extension FSVideoCameraView: AVCaptureFileOutputRecordingDelegate {
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        print("started recording to: \(fileURL)")
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        print("finished recording to: \(outputFileURL)")
        delegate?.videoFinished(withFileURL: outputFileURL)
    }
}

extension FSVideoCameraView {
    
    func focus(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        let viewsize = bounds.size
        let newPoint = CGPoint(x: point.y/viewsize.height, y: 1.0-point.x/viewsize.width)
        let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        do {
            try device?.lockForConfiguration()
        } catch _ {
            return
        }
        
        if device?.isFocusModeSupported(AVCaptureFocusMode.autoFocus) == true {
            device?.focusMode = AVCaptureFocusMode.autoFocus
            device?.focusPointOfInterest = newPoint
        }
        
        if device?.isExposureModeSupported(AVCaptureExposureMode.continuousAutoExposure) == true {
            device?.exposureMode = AVCaptureExposureMode.continuousAutoExposure
            device?.exposurePointOfInterest = newPoint
        }
        
        device?.unlockForConfiguration()
        
        focusView?.alpha = 0.0
        focusView?.center = point
        focusView?.backgroundColor = UIColor.clear
        focusView?.layer.borderColor = UIColor.white.cgColor
        focusView?.layer.borderWidth = 1.0
        focusView!.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        addSubview(focusView!)
        
        UIView.animate(withDuration: 0.8, delay: 0.0, usingSpringWithDamping: 0.8,
                                   initialSpringVelocity: 3.0, options: UIViewAnimationOptions.curveEaseIn, // UIViewAnimationOptions.BeginFromCurrentState
            animations: {
                self.focusView!.alpha = 1.0
                self.focusView!.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            }, completion: {(finished) in
                self.focusView!.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                self.focusView!.removeFromSuperview()
        })
    }
    
    func flashConfiguration() {
        do {
            if let device = device {
                try device.lockForConfiguration()
                device.flashMode = AVCaptureFlashMode.off
                flashButton.setImage(flashOffImage, for: .normal)
                device.unlockForConfiguration()
            }
        } catch _ {
            return
        }
    }
}
