//
//  StoryContext.swift
//  Camera
//
//  Created by Jasmin Patel on 26/11/18.
//

import Foundation
import Metal
import MetalKit
import CoreImage

public enum StoryContextType : Int {
    /**
     Automatically choose an appropriate SCContext context
     */
    case auto
    /**
     Create a hardware accelerated SCContext with CoreGraphics
     */
    case coreGraphics
    /**
     Create a hardware accelerated SCContext with EAGL (OpenGL)
     */
    case eagl
    /**
     Creates a standard SCContext hardware accelerated.
     */
    case `default`
    /**
     Create a software rendered SCContext (no hardware acceleration)
     */
    case cpu
}

func SCContextCreateCIContextOptions() -> [CIContextOption : Any] {
    return [CIContextOption.workingColorSpace: NSNull(), CIContextOption.outputColorSpace: NSNull()]
}

let SCContextOptionsCGContextKey = "CGContext"
let SCContextOptionsEAGLContextKey = "EAGLContext"

open class SCContext: NSObject {
    
    /**
     The CIContext
     */
    private(set) var ciContext: CIContext!
    /**
     The type with with which this SCContext was created
     */
    private(set) var type: StoryContextType = .default
    /**
     Will be non null if the type is SCContextTypeEAGL
     */
    private(set) var eaglContext: EAGLContext?
    /**
     Will be non null if the type is SCContextTypeCoreGraphics
     */
    private(set) var cgContext: CGContext?
    
    public init(softwareRenderer: Bool) {
        super.init()
        var options = SCContextCreateCIContextOptions()
        options[CIContextOption.useSoftwareRenderer] = softwareRenderer
        ciContext = CIContext(options: options)
        if softwareRenderer {
            type = .cpu
        } else {
            type = .default
        }
    }
    
    public init(cgContextRef contextRef: CGContext) {
        super.init()
        ciContext = CIContext(cgContext: contextRef, options: SCContextCreateCIContextOptions())
        type = .coreGraphics
    }
    
    public init(eaglContext context: EAGLContext?) {
        super.init()
        eaglContext = context
        if let eaglContext = eaglContext {
            ciContext = CIContext(eaglContext: eaglContext, options: SCContextCreateCIContextOptions())
        }
        type = .eagl
    }
    
    open class func supportsType(_ contextType: StoryContextType) -> Bool {
        let CIContextClass = CIContext.self
        switch contextType {
        case .coreGraphics:
            return CIContextClass.responds(to: #selector(CIContext.init(cgContext:options:)))
        case .eagl:
            return CIContextClass.responds(to: #selector(CIContext.init(eaglContext:options:)))
        case .auto, .default, .cpu:
            return true
        }
    }
    
    open class func suggestedContextType() -> StoryContextType {
        if SCContext.supportsType(.eagl) {
            return .eagl
        } else if SCContext.supportsType(.coreGraphics) {
            return .coreGraphics
        } else {
            return .default
        }
    }
    
    open class func type(contextType: StoryContextType, options: [AnyHashable : Any]?) -> SCContext? {
        switch contextType {
        case .auto:
            return SCContext.type(contextType: SCContext.suggestedContextType(), options: options)
        case .coreGraphics:
            let context = options?[SCContextOptionsCGContextKey]
            
            if context == nil {
                fatalError("MissingCGContext : SCContextTypeCoreGraphics needs to have a CGContext attached to the SCContextOptionsCGContextKey in the options")
            }
            
            return SCContext(cgContextRef: context as! CGContext)
        case .cpu:
            return SCContext(softwareRenderer: true)
        case .default:
            return SCContext(softwareRenderer: false)
        case .eagl:
            var context = options?[SCContextOptionsEAGLContextKey] as? EAGLContext
            
            if context == nil {
                let shareGroup: EAGLSharegroup = EAGLSharegroup()
                context = EAGLContext(api: .openGLES2, sharegroup: shareGroup)
            }
            
            return SCContext(eaglContext: context)
        }
    }
}
