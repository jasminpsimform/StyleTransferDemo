//
//  StoryImageView.swift
//  SCRecorder_Swift
//
//  Created by Jasmin Patel on 09/10/18.
//  Copyright © 2018 Simform. All rights reserved.
//

import Foundation
import UIKit
import GLKit
import AVFoundation
import CoreFoundation
import CoreData
import CoreMedia
import CoreGraphics

public enum StoryExportType : Int {
    case outtakes
    case notes
    case story
    case feed
    case chat
    case trash
}

open class StoryImageView: UIView {
    /**
     The context type to use when loading the context.
     */
    var contextType: StoryContextType = .auto {
        didSet {
            context = nil
        }
    }
    /**
     The SCContext that hold the underlying CIContext for rendering the CIImage's
     Will be automatically loaded when setting the first CIImage or when rendering
     for the first if using a CoreGraphics context type.
     You can also set your own context.
     Supported contexts are Metal, CoreGraphics, EAGL
     */
    var context: SCContext? {
        didSet {
            unloadContext()
            
            if context != nil {
                switch context!.type {
                case .coreGraphics:
                    break
                case .eagl:
                    if let aContext = context?.eaglContext {
                        glkView = GLKView.init(frame: bounds, context: aContext)
                    }
                    glkView?.contentScaleFactor = contentScaleFactor
                    glkView?.delegate = self
                    insertSubview(glkView!, at: 0)
                default:
                    fatalError("InvalidContext : Unsupported context type: \(String(describing: context?.type ?? StoryContextType(rawValue: 0))). StoryImageView only supports CoreGraphics, EAGL and Metal")
                }
            }
        }
    }
    /**
     The CIImage to render.
     */
    open var ciImage: CIImage?
    /**
     The preferred transform for rendering the CIImage
     */
    var preferredCIImageTransform: CGAffineTransform?
    /**
     Whether the CIImage should be scaled and resized according to the contentMode of this view.
     Default is YES.
     */
    var scaleAndResizeCIImageAutomatically = true
    
    open var glkView: GLKView?
    open var currentSampleBuffer: CMSampleBuffer?
    
    /**
     Set the CIImage using an UIImage
     */
    open func setImageBy(_ image: UIImage?) {
        if image == nil {
            ciImage = nil
        } else {
            preferredCIImageTransform = StoryImageView.preferredCIImageTransform(from: image!)
            if let anImage = image?.cgImage {
                ciImage = CIImage(cgImage: anImage)
            }
        }
    }
    /**
     Create the CIContext and setup the underlying rendering views. This is automatically done when setting an CIImage
     for the first time to make the initialization faster. If for some reasons you want it to be done earlier
     you can call this method.
     Returns whether the context has been successfully loaded, returns NO otherwise.
     */
    func loadContextIfNeeded() -> Bool {
        if context == nil {
            var contextType: StoryContextType = self.contextType
            if contextType == .auto {
                contextType = SCContext.suggestedContextType()
            }
            
            var options: [AnyHashable : Any]? = nil
            switch contextType {
            case .coreGraphics:
                let contextRef = UIGraphicsGetCurrentContext()
                
                if contextRef == nil {
                    return false
                }
                if let aRef = contextRef {
                    options = [SCContextOptionsCGContextKey: aRef]
                }
            case .cpu:
                fatalError("UnsupportedContextType : StoryImageView does not support CPU context type.")
            default:
                break
            }
            
            context = SCContext.type(contextType: contextType, options: options)
        }
        
        return true
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        glkView?.frame = bounds
    }
    
    override open func setNeedsDisplay() {
        super.setNeedsDisplay()
        glkView?.setNeedsDisplay()
    }
    
    func unloadContext() {
        if glkView != nil {
            glkView?.removeFromSuperview()
            glkView = nil
        }
    }
    
    
    /**
     Returns the rendered CIImage in the given rect.
     It internally calls renderedCIImageInRect:
     Subclass should not override this method.
     */
    func renderedUIImage(in rect: CGRect) -> UIImage? {
        var returnedImage: UIImage? = nil
        let image = renderedCIImage(in: rect)
        
        if image != nil {
            var context: CIContext? = nil
            if !loadContextIfNeeded() {
                context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
            } else {
                context = self.context?.ciContext
            }
            
            var imageRef: CGImage? = nil
            if let anImage = image {
                imageRef = context?.createCGImage(anImage, from: image?.extent ?? CGRect.zero)
            }
            
            if imageRef != nil {
                if let aRef = imageRef {
                    returnedImage = UIImage(cgImage: aRef, scale: 1.0, orientation: .upMirrored)
                }
            }
        }
        
        return returnedImage
    }
    /**
     Returns the rendered CIImage in the given rect.
     Subclass can override this method to alterate the rendered image.
     */
    func renderedCIImage(in rect: CGRect) -> CIImage? {
        let sampleBuffer = currentSampleBuffer
        
        if sampleBuffer != nil {
            self.ciImage = CIImage(cvPixelBuffer: CMSampleBufferGetImageBuffer(sampleBuffer!)!)
            currentSampleBuffer = nil
        }
        
        var image: CIImage? = self.ciImage
        
        if image != nil {
            image = image?.transformed(by: preferredCIImageTransform!)
            
            if context?.type != .eagl {
                image = image?.oriented(forExifOrientation: 4)
            }
            
            if scaleAndResizeCIImageAutomatically {
                image = scaleAndResize(image, for: rect)
            }
        }
        
        return image
    }
    
    /**
     Returns the rendered CIImage in its natural size.
     Subclass should not override this method.
     */
    func renderedCIImage() -> CIImage? {
        return self.renderedCIImage(in: (self.ciImage?.extent)!)
    }
    
    /**
     Returns the rendered UIImage in its natural size.
     Subclass should not override this method.
     */
    func renderedUIImage() -> UIImage? {
        return self.renderedUIImage(in: (self.ciImage?.extent)!)
    }
    
    func scaleAndResize(_ image: CIImage?, for rect: CGRect) -> CIImage? {
        let imageSize: CGSize? = image?.extent.size
        
        var horizontalScale: CGFloat = rect.size.width / (imageSize?.width ?? 0.0)
        var verticalScale: CGFloat = rect.size.height / (imageSize?.height ?? 0.0)
        
        let mode: UIView.ContentMode = contentMode
        
        if mode == .scaleAspectFill {
            horizontalScale = max(horizontalScale, verticalScale)
            verticalScale = horizontalScale
        } else if mode == .scaleAspectFit {
            horizontalScale = min(horizontalScale, verticalScale)
            verticalScale = horizontalScale
        }
        
        return image?.transformed(by: CGAffineTransform(scaleX: horizontalScale, y: verticalScale))
    }
    
    override open func draw(_ rect: CGRect) {
        super.draw(rect)
        
        if (ciImage != nil || currentSampleBuffer != nil) && loadContextIfNeeded() {
            if context?.type == .coreGraphics {
                let image = renderedCIImage(in: rect)
                if image != nil {
                    context?.ciContext?.draw(image!, in: rect, from: (image?.extent)!)
                }
            }
        }
    }
    
    class func preferredCIImageTransform(from image: UIImage) -> CGAffineTransform {
        if image.imageOrientation == .up {
            return .identity
        }
        var transform: CGAffineTransform = .identity
        
        switch image.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: image.size.width, y: image.size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: image.size.width, y: 0)
            transform = transform.rotated(by: CGFloat(Double.pi/2))
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: image.size.height)
            transform = transform.rotated(by: CGFloat(-Double.pi/2))
        default:
            break
        }
        
        switch image.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: image.size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: image.size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        return transform
    }
    /**
     Set the CIImage using a sampleBuffer. The CIImage will be automatically generated
     when needed. This avoids creating multiple CIImage if the StoryImageView can't render them
     as fast.
     */
    func setImageBy(_ sampleBuffer: CMSampleBuffer?) {
        if let aBuffer = sampleBuffer {
            currentSampleBuffer = aBuffer
        }
        setNeedsDisplay()
    }
    
    private func CGRectMultiply(rect: CGRect, contentScale: CGFloat) -> CGRect {
        var rect = rect
        rect.origin.x = rect.origin.x*contentScale
        rect.origin.y = rect.origin.y*contentScale
        rect.size.width = rect.size.width*contentScale
        rect.size.height = rect.size.height*contentScale
        
        return rect
    }
    
    func setCIImage(_ CIImage: CIImage?) {
        self.ciImage = CIImage
        if CIImage != nil {
            _ = loadContextIfNeeded()
        }
        setNeedsDisplay()
    }
    
    func setPixelBuffer(_ CIImage: CIImage?) {
        self.ciImage = CIImage
        if CIImage != nil {
            _ = loadContextIfNeeded()
        }
        setNeedsDisplay()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        _imageViewCommonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _imageViewCommonInit()
    }
    
    func _imageViewCommonInit() {
        preferredCIImageTransform = CGAffineTransform.identity
    }
}
//MARK: -- GLKViewDelegate
extension StoryImageView: GLKViewDelegate {
    public func glkView(_ view: GLKView, drawIn rect: CGRect) {
        var rect = rect
        autoreleasepool {
            rect = CGRectMultiply(rect: rect, contentScale: contentScaleFactor)
            glClearColor(0, 0, 0, 0)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            
            let image = renderedCIImage(in: rect)
            
            if image != nil {
                context?.ciContext?.draw(image!, in: rect, from: image!.extent)
            }
        }
    }
}
