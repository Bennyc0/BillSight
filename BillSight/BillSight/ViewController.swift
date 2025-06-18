//
//  ViewController.swift
//  BillSight
//
//  Created by Student on 6/14/25.
//

import SwiftUI
import AVFoundation // For camera access
import Vision      // For image processing with Core ML
import CoreML      // To use your Core ML model

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // MARK: - Properties
    private let mlModel = {
        do {
            let config = MLModelConfiguration()
            return try BillSight_ImageClassifier(configuration: config).model // !!! IMPORTANT: Replace USBillClassifierModel with your model's actual generated class name
        } catch {
            fatalError("Failed to load Core ML model: \(error)")
        }
    }()
    
    // UI Elements
    private let cameraView = UIView()
    private let resultLabel = UILabel()

    // Camera properties
    private var captureSession: AVCaptureSession!
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer!

    // Core ML and Vision properties
    private var visionRequests = [VNRequest]()

    // Speech synthesizer
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var lastSpokenResult: String?

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupVision() // Keep setupVision here as it doesn't depend on view bounds for the model itself
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Only setup camera if it hasn't been set up yet
        // This prevents re-setting up the camera if the view reappears (e.g., from background)
        if captureSession == nil {
            setupCamera()
        }

        // Ensure the preview layer frame is updated, especially on first appearance
        // It's good to keep this in viewDidLayoutSubviews, but this can be a safety
        videoPreviewLayer?.frame = cameraView.bounds
        print("DEBUG: viewDidAppear - videoPreviewLayer frame set to: \(videoPreviewLayer?.frame ?? .zero)")
    }

    // MARK: - UI Setup
    private func setupUI() {
        // Setup camera view
        cameraView.backgroundColor = .clear
        view.addSubview(cameraView)
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        DispatchQueue.main.async { // Ensure this prints AFTER constraints are applied
                    print("DEBUG: setupUI - cameraView bounds: \(self.cameraView.bounds)")
                    print("DEBUG: setupUI - cameraView layer bounds: \(self.cameraView.layer.bounds)")
                }

        // Setup result label
        resultLabel.textAlignment = .center
        resultLabel.textColor = .white
        resultLabel.font = .systemFont(ofSize: 30, weight: .bold)
        resultLabel.numberOfLines = 0 // Allow multiple lines
        resultLabel.backgroundColor = UIColor.black.withAlphaComponent(0.2) // Semi-transparent background
        view.addSubview(resultLabel)
        resultLabel.translatesAutoresizingMaskIntoConstraints = false 
        NSLayoutConstraint.activate([
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            resultLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            resultLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }

    // MARK: - Camera Setup
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .hd1280x720

        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("ERROR: Failed to get the camera device.")
            return
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("ERROR: Failed to create video input: \(error)")
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            print("ERROR: Could not add video input to the session.")
            return
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
                print("DEBUG: Video output orientation set to portrait.")
            } else {
                print("DEBUG: Video orientation not supported on this device.")
            }
        }

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            print("ERROR: Could not add video output to the session.")
            return
        }

        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.frame = cameraView.bounds // Use cameraView.bounds here!
        cameraView.layer.addSublayer(videoPreviewLayer)
        videoPreviewLayer.zPosition = 1 // Ensure video layer is above default background
        resultLabel.layer.zPosition = 2 // Ensure label is above video layer
        print("DEBUG: videoPreviewLayer added as sublayer to cameraView.layer.")
        print("DEBUG: videoPreviewLayer frame at addition: \(videoPreviewLayer.frame)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Unwrap self here before accessing its properties
            guard let self = self else { return }

            self.captureSession.startRunning()
            // Now you can safely access self.captureSession
            print("DEBUG: AVCaptureSession started running. Is session running? \(self.captureSession.isRunning)")
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update the preview layer frame if the view's bounds change (e.g., orientation change)
        videoPreviewLayer?.frame = cameraView.bounds // CORRECTED LINE
        print("DEBUG: viewDidLayoutSubviews - videoPreviewLayer frame updated to: \(videoPreviewLayer?.frame ?? .zero)")
    }

    // MARK: - Vision Setup
    private func setupVision() {
        // Create a VNCoreMLModel from your Core ML model
        guard let visionModel = try? VNCoreMLModel(for: mlModel) else {
            fatalError("Failed to create VNCoreMLModel from your model.")
        }

        // Create a VNCoreMLRequest to perform classification
        let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: { [weak self] request, error in
            self?.processClassifications(for: request, error: error)
        })

        // Resize the image to match the model's input size (if necessary)
        // Make sure this matches your CreateML model's expected image size
        // CreateML models typically expect 299x299 or 224x224.
        classificationRequest.imageCropAndScaleOption = .centerCrop // Or .scaleFill, .scaleFit

        self.visionRequests = [classificationRequest]
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Get the image buffer from the sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Create a VNImageRequestHandler for the current image buffer
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        // Perform the Vision requests
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print("Failed to perform Vision request: \(error)")
        }
    }

    // MARK: - Process Classifications
    private func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let error = error {
                self.resultLabel.text = "Error: \(error.localizedDescription)"
                print("Classification error: \(error)")
                return
            }

            guard let classifications = request.results as? [VNClassificationObservation] else {
                self.resultLabel.text = "No classifications found."
                print("No classifications found.")
                return
            }

            // --- ADDED DEBUGGING CODE HERE ---
            print("\n--- NEW CLASSIFICATION FRAME ---")
            if classifications.isEmpty {
                print("DEBUG: Classifications array is empty.")
            } else {
                for (index, classification) in classifications.prefix(3).enumerated() { // Print top 3
                    print("DEBUG: Top \(index + 1): \(classification.identifier) Confidence: \(String(format: "%.4f", classification.confidence))")
                }
            }
            // --- END ADDED DEBUGGING CODE ---

            if let topClassification = classifications.first {
                let confidenceThreshold: Float = 0.6 // Adjust this value as needed

                if topClassification.confidence > confidenceThreshold {
                    let resultText = "\(topClassification.identifier) (\(String(format: "%.2f", topClassification.confidence * 100))%)"
                    self.resultLabel.text = resultText
                    self.speakResult(topClassification.identifier)
                } else {
                    self.resultLabel.text = "No clear denomination detected."
                    self.lastSpokenResult = nil
                }
            } else {
                self.resultLabel.text = "No clear denomination detected."
                self.lastSpokenResult = nil
            }
        }
    }

    // MARK: - Speech Synthesis
    private func speakResult(_ text: String) {
        // Prevent repeating the same result multiple times in quick succession
        guard text != lastSpokenResult else { return }

        // Stop any ongoing speech
        speechSynthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate // You can adjust this
        utterance.pitchMultiplier = 1.0 // You can adjust this
        utterance.volume = 1.0 // You can adjust this

        speechSynthesizer.speak(utterance)
        lastSpokenResult = text // Store the last spoken result
    }
}

#Preview {
    ViewController()
}
