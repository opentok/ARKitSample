//
//  VideoRender.swift
//  ARKit Sample
//
//  Created by Roberto Perez Cubero on 26/09/2017.
//  Copyright © 2017 tokbox. All rights reserved.
//

import Foundation
import OpenTok
import MetalKit
import SceneKit

class OpenTokMetalVideoRender : NSObject, OTVideoRender {
    // This is the target SceneKit node used to render the video stream
    fileprivate var node: SCNNode?
    fileprivate var device: MTLDevice?
    fileprivate var outTexture: MTLTexture?
    fileprivate var yTexture: MTLTexture?
    fileprivate var uTexture: MTLTexture?
    fileprivate var vTexture: MTLTexture?
    fileprivate var textureDesc: MTLTextureDescriptor?
    fileprivate var defaultLibrary: MTLLibrary?
    fileprivate var commandQueue: MTLCommandQueue?
    fileprivate var threadsPerThreadgroup:MTLSize?
    fileprivate var threadgroupsPerGrid: MTLSize?
    fileprivate var pipelineState: MTLComputePipelineState?
    
    init(_ node: SCNNode) {
        defer {
            if device == nil || defaultLibrary == nil || commandQueue == nil {
                print("ERROR in metal initialization, renderer will not work")
            }
        }
        
        super.init()
        
        self.node = node
        self.device = MTLCreateSystemDefaultDevice()
        self.defaultLibrary = device?.makeDefaultLibrary()
        self.commandQueue = device?.makeCommandQueue()
        
        guard let kernelFunction = defaultLibrary?.makeFunction(name: "YUVColorConversion")
            else {
                print("Error creating compute shader")
                return
        }
        do {
            pipelineState = try device?.makeComputePipelineState(function: kernelFunction)
        } catch {
            print("Error creating the pipeline state")
            return
        }
        
        self.threadsPerThreadgroup = MTLSizeMake(16, 16, 1)
        self.threadgroupsPerGrid = MTLSizeMake(2048 / (threadsPerThreadgroup?.width ?? 16),
                                               1536 / (threadsPerThreadgroup?.height ?? 16), 1)
    }
    
    fileprivate func createTextures(withFormat format: OTVideoFormat) {
        guard let device = self.device,
            let node = self.node
        else { return }
        
        print("Creating textures with width: \(format.imageWidth), height: \(format.imageHeight)")
        
        self.textureDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
                                                                   width: Int(format.imageWidth),
                                                                   height: Int(format.imageHeight),
                                                                   mipmapped: false)
        guard let rgbTextureDesc = textureDesc else { return }
        rgbTextureDesc.usage = [.shaderWrite, .shaderRead]
        
        outTexture = device.makeTexture(descriptor: rgbTextureDesc)
        guard let rgbTexture = self.outTexture else { return }
        
        // This is the RGB texture where the video stream will be renderer
        // Let's assign it to the material of the target node
        node.geometry?.firstMaterial?.diffuse.contents = rgbTexture
        
        // Y Texture
        // Since this will hold a single byte, the pixelFormat is r8Uint
        let yTextureDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Uint,
                                                                    width: Int(format.imageWidth),
                                                                    height: Int(format.imageHeight),
                                                                    mipmapped: false)
        yTexture = device.makeTexture(descriptor: yTextureDesc)
        
        // U and V planes are 2:2 subsampled. That means its size is half on width and height
        // U Texture
        let uTextureDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Uint,
                                                                    width: Int(format.imageWidth) / 2,
                                                                    height: Int(format.imageHeight) / 2,
                                                                    mipmapped: false)
        uTexture = device.makeTexture(descriptor: uTextureDesc)
        
        // V Texture
        let vTextureDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Uint,
                                                                    width: Int(format.imageWidth) / 2,
                                                                    height: Int(format.imageHeight) / 2,
                                                                    mipmapped: false)
        vTexture = device.makeTexture(descriptor: vTextureDesc)
    }
    
    fileprivate func updateTextureContents(withPlanes planes: NSPointerArray, andFormat format: OTVideoFormat) {
        yTexture?.replace(region: MTLRegionMake2D(0, 0, Int(format.imageWidth), Int(format.imageHeight)),
                          mipmapLevel: 0,
                          withBytes: planes.pointer(at: 0)!,
                          bytesPerRow: (format.bytesPerRow.object(at: 0) as! Int))
        
        uTexture?.replace(region: MTLRegionMake2D(0, 0, Int(format.imageWidth) / 2, Int(format.imageHeight) / 2),
                          mipmapLevel: 0,
                          withBytes: planes.pointer(at: 1)!,
                          bytesPerRow: (format.bytesPerRow.object(at: 1) as! Int))
        
        vTexture?.replace(region: MTLRegionMake2D(0, 0, Int(format.imageWidth) / 2, Int(format.imageHeight) / 2),
                          mipmapLevel: 0,
                          withBytes: planes.pointer(at: 2)!,
                          bytesPerRow: (format.bytesPerRow.object(at: 2) as! Int))
    }
    
    fileprivate func executeMetalShader() {
        guard let pipelineState = self.pipelineState,
            let threadgroupsPerGrid = self.threadgroupsPerGrid,
            let threadsPerThreadgroup = self.threadsPerThreadgroup
        else { return }
        
        let commandBuffer = commandQueue?.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(pipelineState)
        
        commandEncoder?.setTexture(yTexture, index: 0)
        commandEncoder?.setTexture(uTexture, index: 1)
        commandEncoder?.setTexture(vTexture, index: 2)
        commandEncoder?.setTexture(outTexture, index: 3)
        
        commandEncoder?.dispatchThreadgroups(threadgroupsPerGrid,
                                             threadsPerThreadgroup: threadsPerThreadgroup)
        commandEncoder?.endEncoding()
        
        commandBuffer?.commit()
    }
    
    fileprivate func areTexturesStillValid(_ format: OTVideoFormat) -> Bool {
        guard let textDesc = textureDesc else { return false }
        return outTexture != nil
            && textDesc.width == format.imageWidth
            && textDesc.height == format.imageHeight
    }
    
    // MARK: OTVideoRender implementation
    func renderVideoFrame(_ frame: OTVideoFrame) {
        guard let format = frame.format else {
            print("Video Frame format is nil, exiting rendering function")
            return
        }
        guard let planes = frame.planes else {
            print("Video frame contents are nil, exiting rendering function")
            return
        }
        
        if  !areTexturesStillValid(format){
            // VideoFrames can change in size according to the video stream quality
            // If the video frame changes its size we need to re-create the textures
            // This also will be called with the first video frame
            createTextures(withFormat: format)
        }
        
        updateTextureContents(withPlanes: planes, andFormat: format)
        executeMetalShader()
    }
}
