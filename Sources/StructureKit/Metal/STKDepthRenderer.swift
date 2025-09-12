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

import Metal
import MetalKit
import StructureKitCTypes

// Draws various objects which require depth texture:
// 1. the depth frame
// 2. the cube
// 3. the depth overlay inside the cube

public enum STKDepthOverlayMode: Int {
    case palette = 1
    case range   = 2
}

public class STKDepthRenderer {
  private var mtkView: MTKView
  private var renderDepthState: MTLRenderPipelineState
  private var renderDepthFrameState: MTLRenderPipelineState
  private var textureDepth: MTLTexture?
  private var textureColor: MTLTexture?
  private var vertexBuffer: MTLBuffer
  private var samplerState: MTLSamplerState
  private var device: MTLDevice
  private var intr: STKIntrinsics?
  var depthRenderingColors = [simd_float4(1, 0, 0, 1), simd_float4(1, 1, 0, 1)] {  // red and yellow
    didSet { updateColorTexture() }
  }

  // cube rendering
  private var _renderCubeState: MTLRenderPipelineState!
  private var _vertexCubeBuffer: MTLBuffer!
  private var _indexCubeBuffer: MTLBuffer!
  
  private var overlayMode: STKDepthOverlayMode = .palette
  private var validRangeMinMM: Float = 0.0
  private var validRangeMaxMM: Float = 0.0
  private var validRangeColor: simd_float4 = simd_float4(0,1,0,0.5) // Green
  private var outOfRangeColor: simd_float4 = simd_float4(1,0,0,0.5) // Red

  public init(view: MTKView, device: MTLDevice) {
    mtkView = view
    self.device = device

    let library = STKMetalLibLoader.load(device: device)
    let pipelineDepthDescriptor = MTLRenderPipelineDescriptor()
    pipelineDepthDescriptor.sampleCount = 1
    pipelineDepthDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
    pipelineDepthDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
    pipelineDepthDescriptor.vertexFunction = library.makeFunction(name: "vertexDepthOverlay")
    pipelineDepthDescriptor.fragmentFunction = library.makeFunction(name: "fragmentDepthOverlay")
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

    let pipelineDepthFrameDescriptor = MTLRenderPipelineDescriptor()
    pipelineDepthFrameDescriptor.sampleCount = 1
    pipelineDepthFrameDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
    pipelineDepthFrameDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
    pipelineDepthFrameDescriptor.vertexFunction = library.makeFunction(name: "vertexTexDepthFrame")
    pipelineDepthFrameDescriptor.fragmentFunction = library.makeFunction(name: "fragmentDepthFrame")
    // blending
    pipelineDepthFrameDescriptor.colorAttachments[0].isBlendingEnabled = true
    pipelineDepthFrameDescriptor.colorAttachments[0].rgbBlendOperation = .add
    pipelineDepthFrameDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    pipelineDepthFrameDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    renderDepthFrameState = try! device.makeRenderPipelineState(descriptor: pipelineDepthFrameDescriptor)

    let pipelineCubeDescriptor = MTLRenderPipelineDescriptor()
    pipelineCubeDescriptor.sampleCount = 1
    pipelineCubeDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
    pipelineCubeDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
    pipelineCubeDescriptor.vertexFunction = library.makeFunction(name: "vertexLineOverDepth")
    pipelineCubeDescriptor.fragmentFunction = library.makeFunction(name: "fragmentLineOverDepth")
    // blending
    pipelineCubeDescriptor.colorAttachments[0].isBlendingEnabled = true
    pipelineCubeDescriptor.colorAttachments[0].rgbBlendOperation = .add
    pipelineCubeDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    pipelineCubeDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

    _renderCubeState = try! device.makeRenderPipelineState(descriptor: pipelineCubeDescriptor)

    let cubeVertices: [Float] = [
      0, 0, 0, 1, 1, 1,  // a
      1, 0, 0, 1, 1, 1,  // b
      1, 1, 0, 1, 1, 1,  // c
      0, 1, 0, 1, 1, 1,  // d

      0, 0, 1, 1, 1, 1,  // e
      1, 0, 1, 1, 1, 1,  // f
      1, 1, 1, 1, 1, 1,  // g
      0, 1, 1, 1, 1, 1,  // h
    ]

    let cubeIndices: [UInt32] = [
      0, 1,
      1, 2,
      2, 3,
      3, 0,

      4, 5,
      5, 6,
      6, 7,
      7, 4,

      0, 4,
      1, 5,
      2, 6,
      3, 7,
    ]

    _vertexCubeBuffer = device.makeBuffer(
      bytes: cubeVertices, length: MemoryLayout<Float>.stride * cubeVertices.count, options: [])!
    _indexCubeBuffer = device.makeBuffer(
      bytes: cubeIndices, length: MemoryLayout<UInt32>.stride * cubeIndices.count, options: [])!

    updateColorTexture()
  }

  private func updateColorTexture() {
    let colorTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba32Float, width: Int(depthRenderingColors.count), height: Int(1), mipmapped: false)
    colorTextureDescriptor.usage = MTLTextureUsage(
      rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)
    textureColor = device.makeTexture(descriptor: colorTextureDescriptor)

    let bytesPerRow: Int = depthRenderingColors.count * MemoryLayout<simd_float4>.stride
    let region = MTLRegionMake2D(0, 0, depthRenderingColors.count, 1)
    textureColor?.replace(region: region, mipmapLevel: 0, withBytes: &depthRenderingColors, bytesPerRow: bytesPerRow)
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
      let intr = intr,
      let textureColor = textureColor
    else { return }

    commandEncoder.pushDebugGroup("RenderDepthOverlay")
    commandEncoder.setRenderPipelineState(renderDepthState)

    // rotate and mirror:
    // move to [-0.5, 0.5] coordinates
    // rotate
    // mirror and apply scale to fix the ratio
    // move back to [0, 1] coordinates
    let projection =
      float4x4.makeTranslation(0.5, 0.5, 0) * textureOrientation * float4x4.makeTranslation(-0.5, -0.5, 0)
    let (minDistM, maxDistM) = calcVisualizationDistance(
      cameraPoint: cameraPosition.translation.xyz,
      cubeSize: volumeSizeInMeters)

    let intrinsics = STKIntrinsicsMetal(
      cx: intr.cx, cy: intr.cy, fx: intr.fx, fy: intr.fy, width: UInt32(texture.width), height: UInt32(texture.height))

    var uniforms = STKUniformsDepthOverlay(
      projection: projection,
      cameraPose: cameraPosition,
      cameraIntrinsics: intrinsics,
      cubeModelInv: float4x4.makeScale(volumeSizeInMeters.x, volumeSizeInMeters.y, volumeSizeInMeters.z).inverse,
      depthMin: minDistM * 1000,
      depthMax: maxDistM * 1000,
      alpha: alpha,
      mode: Int32(overlayMode.rawValue),
      validRangeMinMM: validRangeMinMM,
      validRangeMaxMM: validRangeMaxMM,
      validRangeColor: validRangeColor,
      outOfRangeColor: outOfRangeColor
    )

    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<STKUniformsDepthOverlay>.stride, index: 1)

    commandEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<STKUniformsDepthOverlay>.stride, index: 0)
    commandEncoder.setFragmentTexture(texture, index: 0)  // [[ texture(0) ]],
    commandEncoder.setFragmentTexture(textureColor, index: 1)  // [[ texture(1) ]],
    commandEncoder.setFragmentSamplerState(samplerState, index: 0)  // [[ sampler(0) ]]
    commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
    commandEncoder.popDebugGroup()
  }

  public func renderDepthFrame(
    _ commandEncoder: MTLRenderCommandEncoder,
    orientation: float4x4,
    minDepth: Float,
    maxDepth: Float,
    alpha: Float = 1
  ) {
    guard let textureDepth = textureDepth,
      let textureColor = textureColor
    else { return }

    commandEncoder.pushDebugGroup("RenderDepthFrame")
    commandEncoder.setRenderPipelineState(renderDepthFrameState)

    let projection = float4x4.makeTranslation(0.5, 0.5, 0) * orientation * float4x4.makeTranslation(-0.5, -0.5, 0)
    var uniforms = STKUniformsDepthTexture(projection: projection, depthMin: minDepth, depthMax: maxDepth, alpha: alpha)
    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<STKUniformsDepthTexture>.stride, index: 1)

    commandEncoder.setFragmentTexture(textureDepth, index: 0)  // [[ texture(0) ]],
    commandEncoder.setFragmentTexture(textureColor, index: 1)  // [[ texture(1) ]],
    commandEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<STKUniformsDepthTexture>.stride, index: 0)

    commandEncoder.setFragmentSamplerState(samplerState, index: 0)  // [[ sampler(0) ]]
    commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
    commandEncoder.popDebugGroup()

  }

  public func renderCubeOutline(
    _ commandEncoder: MTLRenderCommandEncoder,
    volumeSizeInMeters: simd_float3,
    cameraPosition: float4x4,
    projection: float4x4,
    orientation: float4x4,
    useOcclusion: Bool
  ) {
    guard let textureDepth = textureDepth,
      let intr = intr
    else { return }

    var uniformsCube = STKUniformsCube(
      model: float4x4.makeScale(volumeSizeInMeters.x, volumeSizeInMeters.y, volumeSizeInMeters.z),
      view: cameraPosition.inverse,
      projection: orientation * projection,
      cameraIntrinsics: STKIntrinsicsMetal(
        cx: intr.cx, cy: intr.cy,
        fx: intr.fx, fy: intr.fy,
        width: UInt32(textureDepth.width), height: UInt32(textureDepth.height)),
      useOcclusion: useOcclusion
    )

    commandEncoder.pushDebugGroup("RenderCube")
    commandEncoder.setRenderPipelineState(_renderCubeState)

    commandEncoder.setVertexBuffer(_vertexCubeBuffer, offset: 0, index: 0)
    commandEncoder.setVertexBytes(&uniformsCube, length: MemoryLayout<STKUniformsCube>.stride, index: 1)

    commandEncoder.setFragmentTexture(textureDepth, index: 0)  // [[ texture(0) ]],
    commandEncoder.setFragmentBytes(&uniformsCube, length: MemoryLayout<STKUniformsCube>.stride, index: 0)
    commandEncoder.setFragmentSamplerState(samplerState, index: 0)  // [[ sampler(0) ]]

    commandEncoder.drawIndexedPrimitives(
      type: .line,
      indexCount: 24,
      indexType: .uint32,
      indexBuffer: _indexCubeBuffer,
      indexBufferOffset: 0)
    commandEncoder.popDebugGroup()
  }
  
  public func configureDepthOverlay(
      _ mode: STKDepthOverlayMode,
      validRangeMinMM: Float = 0, validRangeMaxMM: Float = 0,
      validRangeColor: simd_float4 = simd_float4(0,1,0,0.5),
      outOfRangeColor: simd_float4 = simd_float4(1,0,0,0.5)
  ) {
      self.overlayMode = mode
      self.validRangeMinMM = validRangeMinMM
      self.validRangeMaxMM = validRangeMaxMM
      self.validRangeColor = validRangeColor
      self.outOfRangeColor = outOfRangeColor
  }

}
