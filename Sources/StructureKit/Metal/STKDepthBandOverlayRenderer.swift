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
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

import Metal
import MetalKit
import StructureKitCTypes

public class STKDepthBandOverlayRenderer {
  private var mtkView: MTKView
  private var renderDepthState: MTLRenderPipelineState
  private var textureDepth: MTLTexture?
  private var vertexBuffer: MTLBuffer
  private var samplerState: MTLSamplerState
  private var device: MTLDevice
  private var intr: STKIntrinsics?

  private var validRangeMinMM: Float = 200.0
  private var validRangeMaxMM: Float = 400.0
  private var validRangeColor: simd_float4 = simd_float4(0,1,0,0.5) // Green
  private var outOfRangeColor: simd_float4 = simd_float4(1,0,0,0.5) // Red
  private var feather: Float = 40.0 // in mm

  public init(view: MTKView, device: MTLDevice) {
    mtkView = view
    self.device = device

    let library = STKMetalLibLoader.load(device: device)
    let pipelineDepthDescriptor = MTLRenderPipelineDescriptor()
    pipelineDepthDescriptor.sampleCount = 1
    pipelineDepthDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
    pipelineDepthDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
    pipelineDepthDescriptor.vertexFunction = library.makeFunction(name: "vertexDepthBandOverlay")
    pipelineDepthDescriptor.fragmentFunction = library.makeFunction(name: "fragmentDepthBandOverlay")
    // blending
    pipelineDepthDescriptor.colorAttachments[0].isBlendingEnabled = true
    pipelineDepthDescriptor.colorAttachments[0].rgbBlendOperation = .add
    pipelineDepthDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    pipelineDepthDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

    renderDepthState = try! device.makeRenderPipelineState(descriptor: pipelineDepthDescriptor)

    let vertexData = makeRectangularVertices()
    let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
    vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])!

    samplerState = makeDefaultSampler(device)
  }

  public func uploadColorTextureFromDepth(_ depthFrame: STKDepthFrame) {
    if let texture = textureDepth {
      if texture.width != depthFrame.width || texture.height != depthFrame.height {
        textureDepth = nil  // invalidate texture
      }
    }

    if textureDepth == nil {
      let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .r32Float, width: Int(depthFrame.width), height: Int(depthFrame.height), mipmapped: false)
      textureDescriptor.usage = MTLTextureUsage(
        rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)
      textureDepth = device.makeTexture(descriptor: textureDescriptor)
    }

    intr = depthFrame.intrinsics()
    let depthMap = depthFrame.depthInMillimeters
    assert(MemoryLayout<Float32>.size == MemoryLayout<Float>.size)

    let bytesPerRow: Int = Int(depthFrame.width) * MemoryLayout<Float32>.stride
    let region = MTLRegionMake2D(0, 0, Int(depthFrame.width), Int(depthFrame.height))
    textureDepth?.replace(region: region, mipmapLevel: 0, withBytes: depthMap!, bytesPerRow: bytesPerRow)
  }

  public func renderDepthOverlay(
    _ commandEncoder: MTLRenderCommandEncoder,
    volumeSizeInMeters: simd_float3,
    cameraPosition: float4x4,
    textureOrientation: float4x4,
    alpha: Float
  ) {
    guard let texture = textureDepth,
      let intr = intr
    else { return }

    commandEncoder.pushDebugGroup("RenderDepthRangeOverlay")
    commandEncoder.setRenderPipelineState(renderDepthState)

    // rotate and mirror:
    // move to [-0.5, 0.5] coordinates
    // rotate
    // mirror and apply scale to fix the ratio
    // move back to [0, 1] coordinates
    let projection =
      float4x4.makeTranslation(0.5, 0.5, 0) * textureOrientation * float4x4.makeTranslation(-0.5, -0.5, 0)

    let intrinsics = STKIntrinsicsMetal(
      cx: intr.cx, cy: intr.cy, fx: intr.fx, fy: intr.fy, width: UInt32(texture.width), height: UInt32(texture.height))

    var uniforms = STKUniformsDepthBandOverlay(
      projection: projection,
      cameraPose: cameraPosition,
      cameraIntrinsics: intrinsics,
      cubeModelInv: float4x4.makeScale(volumeSizeInMeters.x, volumeSizeInMeters.y, volumeSizeInMeters.z).inverse,
      alpha: alpha,
      validRangeMinMM: validRangeMinMM,
      validRangeMaxMM: validRangeMaxMM,
      validRangeColor: validRangeColor,
      outOfRangeColor: outOfRangeColor,
      feather: feather
    )

    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<STKUniformsDepthBandOverlay>.stride, index: 1)

    commandEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<STKUniformsDepthBandOverlay>.stride, index: 0)
    commandEncoder.setFragmentTexture(texture, index: 0)  // [[ texture(0) ]],
    commandEncoder.setFragmentSamplerState(samplerState, index: 0)  // [[ sampler(0) ]]
    commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
    commandEncoder.popDebugGroup()
  }
  
  public func configure(
      validRangeMinMM: Float, validRangeMaxMM: Float,
      validRangeColor: simd_float4 = simd_float4(0,1,0,0.5),
      outOfRangeColor: simd_float4 = simd_float4(1,0,0,0.5),
      feather: Float = 40.0
  ) {
      self.validRangeMinMM = validRangeMinMM
      self.validRangeMaxMM = validRangeMaxMM
      self.validRangeColor = validRangeColor
      self.outOfRangeColor = outOfRangeColor
      self.feather = feather
  }
}
