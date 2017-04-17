//
//  CameraViewController.swift
//  AlohaGIF
//
//  Created by Michal Pyrka on 16/04/2017.
//  Copyright © 2017 Michal Pyrka. All rights reserved.
//

import UIKit
import AVFoundation

let maximumMovieLength: CGFloat = 15.0

final class CameraViewController: UIViewController {

    @IBOutlet weak var previewView: PreviewView!
    var recordButton: RecordButton!
    var recordButtonTimer: Timer!
    var recordButtonProgress: CGFloat = 0.0
    var isSimulator: Bool {
        return ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
    }
    
    private struct Constants {
        static let recordButtonIntervalIncrementTime = 0.1
        static let allPossibleCameras: [(cameraType: AVCaptureDeviceType, position: AVCaptureDevicePosition)] = [
(AVCaptureDeviceType.builtInDualCamera, AVCaptureDevicePosition.back),
(AVCaptureDeviceType.builtInWideAngleCamera, AVCaptureDevicePosition.back),
(AVCaptureDeviceType.builtInWideAngleCamera ,AVCaptureDevicePosition.front)
        ]
    }
    
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue", attributes: [], target: nil)
    private let sessionPresetQuality = AVCaptureSessionPresetHigh
    private let movieFileOutput = AVCaptureMovieFileOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    var anyCamera: AVCaptureDevice? {
        return Constants.allPossibleCameras.flatMap { AVCaptureDevice.defaultDevice(withDeviceType: $0.cameraType, mediaType: AVMediaTypeVideo, position: $0.position) }.first
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupRecordButton()
        setupSession()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) { 
            self.videosButtonAction(UIButton())
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        session.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }
    
    private func setupSession() {
        guard !isSimulator else { return }
        previewView.session = session
        checkAuthorization()
        sessionQueue.async { [unowned self] in
            self.configureSession()
        }
    }
    
    private func addVideoInput() {
        guard let anyCamera = anyCamera, let videoDeviceInput = try? AVCaptureDeviceInput(device: anyCamera) else { return }
        if session.canAddInput(videoDeviceInput) {
            session.addInput(videoDeviceInput)
            self.videoDeviceInput = videoDeviceInput
            DispatchQueue.main.async {
                self.previewView.videoPreviewLayer.connection.videoOrientation = .portrait
            }
        }
    }
    
    private func addAudioInput() {
        let audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
        let audioDeviceInput = try? AVCaptureDeviceInput(device: audioDevice)
        
        if let audioDeviceInput = audioDeviceInput, session.canAddInput(audioDeviceInput) {
            session.addInput(audioDeviceInput)
        }
    }
    
    private func configureSession() {
        addVideoInput()
        addAudioInput()

        if session.canAddOutput(movieFileOutput) {
            session.beginConfiguration()
            session.addOutput(movieFileOutput)
            session.sessionPreset = sessionPresetQuality
            if let connection = movieFileOutput.connection(withMediaType: AVMediaTypeVideo) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
            session.commitConfiguration()
        }
    }
    
    private func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .notDetermined:
            requestForCameraAccess()
        default: ()
        }
    }
    
    private func requestForCameraAccess() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { [unowned self] isGranted in
            self.sessionQueue.async { [unowned self] in
                self.configureSession()
            }
            self.sessionQueue.resume()
        })
    }
    
    private func setupRecordButton() {
        recordButton = RecordButton(frame: CGRect(x: 0, y: 0, width: 70, height: 70))
        recordButton.center = self.view.center
        view.addSubview(recordButton)
        setupRecordButtonActions()
    }
    
    private func setupRecordButtonActions() {
        recordButton.addTarget(self, action: #selector(CameraViewController.startRecording), for: .touchDown)
        recordButton.addTarget(self, action: #selector(CameraViewController.stopRecording), for: UIControlEvents.touchUpInside)
    }
    
    func updateRecordButtonProgress() {
        recordButtonProgress = recordButtonProgress + (CGFloat(Constants.recordButtonIntervalIncrementTime) / maximumMovieLength)
        recordButton.setProgress(recordButtonProgress)
        if recordButtonProgress >= 1.0 {
            recordButtonTimer.invalidate()
        }
    }
    
    
    @IBAction func videosButtonAction(_ sender: UIButton) {
        var config = Configuration()
        config.doneButtonTitle = "Finish"
        config.noImagesTitle = "Sorry! There are no images here!"
        config.allowMultiplePhotoSelection = false

        let imagePicker = ImagePickerController()
        imagePicker.view.backgroundColor = .clear
        imagePicker.modalPresentationStyle = .overCurrentContext
        
        imagePicker.configuration = config
        imagePicker.delegate = self
        present(imagePicker, animated: false, completion: nil)
    }
    
    @objc private func startRecording() {
        print("start \(Date())")
        recordButtonTimer = .scheduledTimer(timeInterval: Constants.recordButtonIntervalIncrementTime, target: self, selector: #selector(CameraViewController.updateRecordButtonProgress), userInfo: nil, repeats: true)
        let outputFileName = NSUUID().uuidString
        let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
        guard !isSimulator else { return }
        movieFileOutput.startRecording(toOutputFileURL: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
    }
    
    @objc private func stopRecording() {
        print("stop \(Date())")
        guard !isSimulator else { return }
        movieFileOutput.stopRecording()
    }
}

extension CameraViewController: AVCaptureFileOutputRecordingDelegate {
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        print("")
    }
}

extension CameraViewController: ImagePickerDelegate {
    func tooLongMovieSelected() {
        UIAlertController.showTooLongVideoAlert()
    }
    
    func wrapperDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {
        
    }
    func doneButtonDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {
        print("done")
    }
    func cancelButtonDidPress(_ imagePicker: ImagePickerController) {
        print("cancel")
    }
}
