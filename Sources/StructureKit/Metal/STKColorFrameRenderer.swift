// StructureKit - A collection of extension utilities for Structure SDK
// Copyright 2022 XRPro, LLC. All rights reserved.
// http://structure.io
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
// * Neither the name of XRPro, LLC nor the names of its contributors may be
//   used to endorse or promote products derived from this software without
//   specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

import CoreMedia
import Metal
import MetalKit
import StructureKitCTypes

// Draws a color texture in the view using 2 triangles, so we can apply a transformation to correct the screen orientation of the device
public class STKColorFrameRenderer {
  private var vertexBuffer: MTLBuffer!
  private var textureCache: CVMetalTextureCache!
  private var textureY: MTLTexture?
  private var textureCbCr: MTLTexture?
  private var renderTextureState: MTLRenderPipelineState
  private var samplerState: MTLSamplerState!

  init(view: MTKView, device: MTLDevice) {
    let library = STKMetalLibLoader.load(device: device)
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.sampleCount = 1
    pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
    pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexTex")
    pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentTex")
    renderTextureState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)

    samplerState = makeDefaultSampler(device)

    CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)

    let vertexData = makeRectangularVertices()
    let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
    vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])!
  }

  func uploadColorTexture(_ colorFrame: STKColorFrame) {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(colorFrame.sampleBuffer) else { return }
    textureY = try! makeTexture(
      pixelBuffer: imageBuffer, textureCache: textureCache, planeIndex: 0, pixelFormat: .r8Unorm)
    textureCbCr = try! makeTexture(
      pixelBuffer: imageBuffer, textureCache: textureCache, planeIndex: 1, pixelFormat: .rg8Unorm)
  }

  func drawPoints(_ points: [simd_float2]) {
    guard let textureY = textureY, let textureCbCr = textureCbCr else { return }
    
    // Pure green in YCbCr: Y ~ 150, Cb ~ 43, Cr ~ 21
    let yVal: UInt8 = 150
    let cbcrVal: [UInt8] = [43, 21]
    
    let w = 4
    let h = 4
    
    let yBytes = [UInt8](repeating: yVal, count: w * h)
    var cbcrBytes = [UInt8]()
    for _ in 0..<(w/2 * h/2) {
      cbcrBytes.append(contentsOf: cbcrVal)
    }
    
    for pt in points {
      let x = Int(pt.x) - w / 2
      let y = Int(pt.y) - h / 2
      
      if x < 0 || y < 0 || x + w >= textureY.width || y + h >= textureY.height { continue }
      
      textureY.replace(region: MTLRegionMake2D(x, y, w, h), mipmapLevel: 0, withBytes: yBytes, bytesPerRow: w)
      textureCbCr.replace(region: MTLRegionMake2D(x / 2, y / 2, w / 2, h / 2), mipmapLevel: 0, withBytes: cbcrBytes, bytesPerRow: w)
    }
  }

  func renderCameraImage(
    _ commandEncoder: MTLRenderCommandEncoder,
    orientation: float4x4
  ) {
    guard let textureY = textureY, let textureCbCr = textureCbCr else { return }

    commandEncoder.pushDebugGroup("RenderColorFrame")
    commandEncoder.setRenderPipelineState(renderTextureState)

    // rotate and mirror:
    // move to [-0.5, 0.5] coordinates
    // rotate
    // mirror and apply scale to fix the ratio
    // move back to [0, 1] coordinates
    let projection = float4x4.makeTranslation(0.5, 0.5, 0) * orientation * float4x4.makeTranslation(-0.5, -0.5, 0)
    var uniforms = STKUniformsColorTexture(
      projection: projection)
    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<STKUniformsColorTexture>.stride, index: 1)

    commandEncoder.setFragmentTexture(textureY, index: 0)  // [[ texture(0) ]],
    commandEncoder.setFragmentTexture(textureCbCr, index: 1)  // [[ texture(1) ]],
    commandEncoder.setFragmentSamplerState(samplerState, index: 0)  // [[ sampler(0) ]]
    commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
    commandEncoder.popDebugGroup()
  }

}
