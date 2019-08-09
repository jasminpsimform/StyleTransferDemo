//
// BlurredVideoView.swift
//
// Created by Greg Niemann on 10/4/17.
// Copyright (c) 2017 WillowTree, Inc. All rights reserved.
//

import UIKit
import AVKit
import CoreML
import Fritz

class BlurredVideoView: UIView {
    var blurRadius: Double = 6.0
    var player: AVPlayer!
    var selectedIndex: Int = 0
    
    lazy var styleModel = FritzVisionStyleModel.horsesOnSeashore

//    lazy var udnieModel = la_muse1().model

    private var output: AVPlayerItemVideoOutput!
    private var displayLink: CADisplayLink!
    private var context: CIContext = CIContext(options: [CIContextOption.workingColorSpace : NSNull()])
    private var playerItemObserver: NSKeyValueObservation?

    func play(stream: URL, withBlur blur: Double? = nil, completion:  (()->Void)? = nil) {
        layer.isOpaque = true
        blurRadius = blur ?? blurRadius

        let item = AVPlayerItem(url: stream)
        output = AVPlayerItemVideoOutput(outputSettings: nil)
        item.add(output)

        playerItemObserver = item.observe(\.status) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            self?.playerItemObserver = nil
            self?.setupDisplayLink()

            self?.player.play()
            completion?()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(finishVideo), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)

        player = AVPlayer(playerItem: item)
    }

    @objc func finishVideo() {
        self.player.seek(to: CMTime.zero)
        self.player.play()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    func stop() {
        player.rate = 0
        displayLink.invalidate()
    }

    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkUpdated(link:)))
        displayLink.preferredFramesPerSecond = 20
        displayLink.add(to: .main, forMode: RunLoop.Mode.common)
    }

    @objc private func displayLinkUpdated(link: CADisplayLink) {
        let time = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: time),
              let pixbuf = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else { return }
//        var mlBuffer: CVPixelBuffer?
//        let model = StyleTransferNew()
//        do {
////            print("add index \(Date())")
//            let styles = try MLMultiArray(shape: [11],
//                                          dataType: .double)
//            for i in 0..<styles.count {
//                styles[i] = 0.0
//            }
//            styles[selectedIndex] = 1.0
//            do {
////                print("try predictionOutput \(Date())")
//                let mlPredicationOptions = MLPredictionOptions.init()
//                mlPredicationOptions.usesCPUOnly = false
//                let input = StyleTransferNewInput.init(image: pixbuf.mlPixelFormatBuffer(scale: 0.3)!, index: styles)
//                let predictionOutput = try model.prediction(input: input,
//                                                            options: mlPredicationOptions)
////                print("done predictionOutput \(Date())")
//                mlBuffer = predictionOutput.stylizedImage
//            } catch let error as NSError {
//                print("CoreML Model Error: \(error)")
//            }
//        } catch let error {
//            print(error)
//        }
        
//        let fritzImage = FritzVisionImage(imageBuffer: pixbuf.mlPixelFormatBuffer()!)
//
//        let options = FritzVisionStyleModelOptions()
//        options.resizeOutputToInputDimensions = true
//        options.forceCoreMLPrediction = true
//
//        let stylizedImage = try! styleModel.predict(fritzImage, options: options)
        
//        let input = StyleTransferInput(input: pixbuf.mlPixelFormatBuffer()!)
//        let outFeatures = try! udnieModel.prediction(from: input)
//        let output = outFeatures.featureValue(for: "add_37__0")!.imageBufferValue!
//
//        let baseImg = CIImage(cvImageBuffer: output)
//        guard let cgImg = context.createCGImage(baseImg, from: baseImg.extent) else { return }
//
//        layer.contents = cgImg
    }
}

