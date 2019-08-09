//
//  StoryPlayer.swift
//  SCRecorder_Swift
//
//  Created by Jasmin Patel on 08/10/18.
//  Copyright © 2018 Simform. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage
import CoreML

public protocol StoryPlayerDelegate: class {
    /**
     Called when the player has played some frames. The loopsCount will contains the number of
     loop if the curent item was set using setSmoothItem.
     */
    func player(_ player: StoryPlayer, didPlay currentTime: CMTime, loopsCount: Int)
    
    /**
     Called when the item has been changed on the StoryPlayer
     */
    func player(_ player: StoryPlayer, didChange item: AVPlayerItem?)
    
    /**
     Called when the item has reached end
     */
    func player(_ player: StoryPlayer, didReachEndFor item: AVPlayerItem)
    
    /**
     Called when the item is ready to play
     */
    func player(_ player: StoryPlayer, itemReadyToPlay item: AVPlayerItem)
    
    /**
     Called when the player has setup the renderer so it can receive the image in the
     proper orientation.
     */
    func player(_ player: StoryPlayer, didSetupSCImageView StoryImageView: StoryImageView)
    
    /**
     Called when the item has updated the time ranges that have been loaded
     */
    func player(_ player: StoryPlayer, didUpdateLoadedTimeRanges timeRange: CMTimeRange)
    
    /**
     Called when the item playback buffer is empty
     */
    func player(_ player: StoryPlayer, itemPlaybackBufferIsEmpty item: AVPlayerItem?)
}

open class StoryPlayer: AVPlayer, AVPlayerItemOutputPullDelegate, AVPlayerItemOutputPushDelegate {
    
    weak open var delegate: StoryPlayerDelegate?
    /**
     Whether the video should start again from the beginning when its reaches the end
     */
    open var loopEnabled = false {
        didSet {
            actionAtItemEnd = loopEnabled ? .none : .pause
        }
    }
    /**
     Will be true if beginSendingPlayMessages has been called.
     */
    var isSendingPlayMessages: Bool {
        return timeObserver != nil
    }
    /**
     Whether this instance is currently playing.
     */
    var isPlaying: Bool {
        return rate > 0
    }
    /**
     Whether this instance displays default rendered video
     */
    var shouldSuppressPlayerRendering = false
    /**
     The actual item duration.
     */
    var itemDuration: CMTime? {
        guard let currentItem = self.currentItem else {
            return nil
        }
        let ratio = Float64(1.0 / itemsLoopLength)
        return CMTimeMultiply(currentItem.duration, multiplier: Int32(ratio))
    }
    /**
     The total currently loaded and playable time.
     */
    var playableDuration: CMTime {
        guard let currentItem = currentItem else {
            return CMTime.zero
        }
        let item = currentItem
        var playableDuration: CMTime = CMTime.zero
        
        if item.status != .failed {
            for value in item.loadedTimeRanges {
                let timeRange = value.timeRangeValue
                playableDuration = CMTimeAdd(playableDuration, timeRange.duration)
            }
        }
        
        return playableDuration
        
    }
    /**
     If true, the player will figure out an affine transform so the video best fits the screen. The resulting video may not be in the correct device orientation though.
     For example, if the video is in landscape and the current device orientation is in portrait mode,
     with this property enabled the video will be rotated so it fits the entire screen. This avoid
     showing the black border on the sides. If your app supports multiple orientation, you typically
     wouldn't want this feature on.
     */
    var autoRotate = false
    private(set) var itemVideoOutput: AVPlayerItemVideoOutput?
    /**
     The renderer for the CIImage. If this property is set, the player will set the CIImage
     property when the current frame changes.
     */
    open var scImageView: StoryImageView? {
        didSet {
            if scImageView == nil {
                unsetupDisplayLink()
            } else {
                setupDisplayLink()
            }
        }
    }

    
    private var displayLink: CADisplayLink?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var oldItem: AVPlayerItem?
    private var itemsLoopLength: Float64 = 1
    private var timeObserver: Any?
    private var rendererWasSetup = false
    private var rendererTransform: CGAffineTransform?
    
    static var StatusChanged = "StatusContext"
    static var ItemChanged = "CurrentItemContext"
    static var PlaybackBufferEmpty = "PlaybackBufferEmpty"
    static var LoadedTimeRanges = "LoadedTimeRanges"
    
    override public init() {
        super.init()
        shouldSuppressPlayerRendering = true
        addObserver(self as NSObject, forKeyPath: "currentItem", options: .new, context: &StoryPlayer.ItemChanged)
    }
    
    deinit {
        endSendingPlayMessages()
        unsetupDisplayLink()
        unsetupVideoOutput(to: currentItem)
        removeObserver(self, forKeyPath: "currentItem")
        removeOldObservers()
        endSendingPlayMessages()
    }
    
    open func beginSendingPlayMessages() {
        if !isSendingPlayMessages {
            timeObserver = addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 24), queue: DispatchQueue.main, using: { [weak self] time in
                guard let `self` = self else { return }
                if let delegate = self.delegate {
                    let itemsLoopLength = self.itemsLoopLength
                    
                    let ratio = Float64(1.0 / Double(itemsLoopLength))
                    let currentTime: CMTime = CMTimeMultiplyByFloat64(time, multiplier: ratio)
                    
                    let loopCount = Int(CMTimeGetSeconds(time) / (CMTimeGetSeconds(self.currentItem?.duration ?? CMTime.zero) / Float64(itemsLoopLength)))
                    
                    delegate.player(self, didPlay: currentTime, loopsCount: loopCount)
                }
            })
        }
    }
    
    open func endSendingPlayMessages() {
        if let observer = timeObserver {
            removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    @objc func playReachedEnd(_ notification: Notification) {
        if (notification.object as? AVPlayerItem) == currentItem {
            if loopEnabled {
                seek(to: CMTime.zero)
                if isPlaying {
                    play()
                }
            }
            if let delegate = self.delegate {
                delegate.player(self, didReachEndFor: self.currentItem!)
            }
        }
    }

    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "currentItem" {
            initObserver()
        } else if keyPath == "status" {
            let block: (() -> ()) = {
                self.setupVideoOutput(to: self.currentItem)
                if let delegate = self.delegate {
                    delegate.player(self, itemReadyToPlay: self.currentItem!)
                }
            }
            if Thread.isMainThread {
                block()
            } else {
                DispatchQueue.main.async(execute: block)
            }
        } else if keyPath == "loadedTimeRanges" {
            let block: (() -> ()) = {
                if let delegate = self.delegate {
                    let array = self.currentItem?.loadedTimeRanges
                    let range = array?.first?.timeRangeValue
                    delegate.player(self, didUpdateLoadedTimeRanges: range!)
                }
            }
            if Thread.isMainThread {
                block()
            } else {
                DispatchQueue.main.async(execute: block)
            }
        } else if keyPath == "playbackBufferEmpty" {
            let block: (() -> ()) = {
                if let delegate = self.delegate {
                    delegate.player(self, itemPlaybackBufferIsEmpty: self.currentItem)
                }
            }
            if Thread.isMainThread {
                block()
            } else {
                DispatchQueue.main.async(execute: block)
            }
        }
    }
    
    func removeOldObservers() {
        if oldItem != nil {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: oldItem)
            oldItem?.removeObserver(self, forKeyPath: "status")
            oldItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty")
            oldItem?.removeObserver(self, forKeyPath: "loadedTimeRanges")
            
            unsetupVideoOutput(to: oldItem)
            
            oldItem = nil
        }
    }
    
    public func outputMediaDataWillChange(_ sender: AVPlayerItemOutput) {
        displayLink?.isPaused = false
    }
    
    func renderVideo(_ hostFrameTime: CFTimeInterval) {
        let outputItemTime: CMTime = videoOutput!.itemTime(forHostTime: hostFrameTime)
        
        if videoOutput!.hasNewPixelBuffer(forItemTime: outputItemTime) {
            
            let renderer: StoryImageView? = scImageView
            
            if renderer != nil {
                if !rendererWasSetup {
                    renderer?.preferredCIImageTransform = rendererTransform
                    if let delegate = self.delegate {
                        delegate.player(self, didSetupSCImageView: renderer!)
                    }
                    rendererWasSetup = true
                }
                let pixelBuffer = videoOutput!.copyPixelBuffer(forItemTime: outputItemTime, itemTimeForDisplay: nil)
                if pixelBuffer != nil {
                    var inputImage: CIImage? = nil
                    if let aBuffer = pixelBuffer {
//                        inputImage = CIImage(cvPixelBuffer: aBuffer)
                        let model = StyleTransferNew()
                        do {
                            let styles = try MLMultiArray(shape: [StyleData.numberOfStyles],
                                                          dataType: .double)
                            for i in 0..<styles.count {
                                styles[i] = 0.0
                            }
                            styles[0] = 1.0
                            do {
                                let predictionOutput = try model.prediction(image: aBuffer, index: styles)
                                inputImage = CIImage(cvPixelBuffer: predictionOutput.stylizedImage)
                            } catch let error as NSError {
                                print("CoreML Model Error: \(error)")
                            }
                        } catch let error {
                            print(error)
                        }
                        renderer?.setCIImage(inputImage)
                    }
                }
            }
        }
    }

    override open func replaceCurrentItem(with item: AVPlayerItem?) {
        itemsLoopLength = 1
        super.replaceCurrentItem(with: item)
        suspendDisplay()
    }
    
    @objc func willRenderFrame(_ sender: CADisplayLink?) {
        let nextFrameTime: CFTimeInterval = (sender?.timestamp ?? 0) + (sender?.duration ?? 0)
        renderVideo(nextFrameTime)
    }
    
    func suspendDisplay() {
        displayLink?.isPaused = true
        videoOutput?.requestNotificationOfMediaDataChange(withAdvanceInterval: 0.1)
    }
    
    func setupDisplayLink() {
        if displayLink == nil {
           
            displayLink = CADisplayLink(target: self, selector: #selector(self.willRenderFrame(_:)))
            displayLink?.preferredFramesPerSecond = 60
            
            setupVideoOutput(to: currentItem)
            
            displayLink?.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
            
            suspendDisplay()
        }
        rendererWasSetup = false
    }
    
    func unsetupDisplayLink() {
        if displayLink != nil {
            displayLink?.invalidate()
            displayLink = nil
            
            unsetupVideoOutput(to: currentItem)
            
            videoOutput = nil
        }
    }
    
    func setupVideoOutput(to item: AVPlayerItem?) {
        if displayLink != nil && item != nil && videoOutput == nil && item?.status == .readyToPlay {
            let pixBuffAttributes = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            
            videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: pixBuffAttributes as [String : Any])
            
            videoOutput?.setDelegate(self, queue: DispatchQueue.main)
            videoOutput?.suppressesPlayerRendering = shouldSuppressPlayerRendering
            
            item?.add(videoOutput!)
            
            displayLink?.isPaused = false
            
            var transform: CGAffineTransform = .identity
            let renderer: StoryImageView? = scImageView
            
            let videoTracks = item?.asset.tracks(withMediaType: .video)
            
            if (videoTracks?.count ?? 0) > 0 {
                let track: AVAssetTrack? = videoTracks?.first
                
                if let aTransform = track?.preferredTransform {
                    transform = aTransform
                }
                
                // Return the video if it is upside down
                if transform.b == 1 && transform.c == -1 {
                    transform = transform.rotated(by: .pi)
                }
                
                if autoRotate {
                    let videoSize = track?.naturalSize
                    let viewSize = renderer?.frame.size
                    let outRect = CGRect(x: 0, y: 0, width: videoSize?.width ?? 0.0, height: videoSize?.height ?? 0.0).applying(transform)
                    
                    let viewIsWide: Bool = (viewSize?.width ?? 0.0) / (viewSize?.height ?? 0.0) > 1
                    let videoIsWide: Bool = outRect.size.width / outRect.size.height > 1
                    
                    if viewIsWide != videoIsWide {
                        transform = transform.rotated(by: .pi/2)
                    }
                }
            }
            rendererTransform = transform
            rendererWasSetup = false
        }
    }
    
    func unsetupVideoOutput(to item: AVPlayerItem?) {
        if videoOutput != nil && item != nil {
            if item?.outputs.contains(videoOutput!) ?? false {
                item?.remove(videoOutput!)
            }
            videoOutput = nil
        }
    }
    
    func initObserver() {
        removeOldObservers()
        
        if currentItem != nil {
            NotificationCenter.default.addObserver(self, selector: #selector(self.playReachedEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
            oldItem = currentItem
            currentItem?.addObserver(self, forKeyPath: "status", options: .new, context: &StoryPlayer.StatusChanged)
            currentItem?.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: &StoryPlayer.PlaybackBufferEmpty)
            currentItem?.addObserver(self, forKeyPath: "loadedTimeRanges", options: .new, context: &StoryPlayer.LoadedTimeRanges)
            
            setupVideoOutput(to: currentItem)
        }
        
        if let delegate = self.delegate {
            delegate.player(self, didChange: currentItem)
        }
        
    }
    
    class func player() -> StoryPlayer {
        return StoryPlayer()
    }
    
    open func setShouldSuppressPlayerRendering(_ shouldSuppressPlayerRendering: Bool) {
        self.shouldSuppressPlayerRendering = shouldSuppressPlayerRendering
        
        videoOutput?.suppressesPlayerRendering = shouldSuppressPlayerRendering
    }
    
    open func setItemByStringPath(_ stringPath: String?) {
        setItemBy(URL(string: stringPath ?? ""))
    }
    
    open func setItemBy(_ url: URL?) {
        if let anUrl = url {
            setItemBy(AVURLAsset(url: anUrl, options: nil))
        }
    }
    
    open func setItemBy(_ asset: AVAsset?) {
        if let anAsset = asset {
            setItem(AVPlayerItem(asset: anAsset))
        }
    }
    
    open func setItem(_ item: AVPlayerItem?) {
        replaceCurrentItem(with: item)
    }
    
    func setSmoothLoopItemByStringPath(_ stringPath: String?, smoothLoopCount loopCount: Int) {
        setSmoothLoopItemBy(URL(string: stringPath ?? ""), smoothLoopCount: loopCount)
    }
    
    func setSmoothLoopItemBy(_ url: URL?, smoothLoopCount loopCount: Int) {
        if let anUrl = url {
            setSmoothLoopItemBy(AVURLAsset(url: anUrl, options: nil), smoothLoopCount: loopCount)
        }
    }
    
    func setSmoothLoopItemBy(_ asset: AVAsset?, smoothLoopCount loopCount: Int) {
        let composition = AVMutableComposition()
        
        let timeRange: CMTimeRange = CMTimeRangeMake(start: CMTime.zero, duration: (asset?.duration)!)
        
        for _ in 0..<loopCount {
            if let anAsset = asset {
                try? composition.insertTimeRange(timeRange, of: anAsset, at: composition.duration)
            }
        }
        
        setItemBy(composition)
        
        itemsLoopLength = Float64(loopCount)
    }
    
}
