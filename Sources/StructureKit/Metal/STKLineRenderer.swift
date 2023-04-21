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

// Draws colored lines in the world coordinate system
public class STKLineRenderer {
  private var renderLineState: MTLRenderPipelineState!
  private var vertexCubeBuffer: MTLBuffer!
  private var indexCubeBuffer: MTLBuffer!
  private var indexTriadBuffer: MTLBuffer!
  private var mtkView: MTKView
  var colorCameraGLProjectionMatrix = float4x4()
  var depthCameraGLProjectionMatrix = float4x4()

  private let cubeVertices4: [simd_float4] = [
    simd_float4(0, 0, 0, 1),
    simd_float4(1, 0, 0, 1),
    simd_float4(1, 1, 0, 1),
    simd_float4(0, 1, 0, 1),

    simd_float4(0, 0, 1, 1),
    simd_float4(1, 0, 1, 1),
    simd_float4(1, 1, 1, 1),
    simd_float4(0, 1, 1, 1),
  ]

  public init(view: MTKView, device: MTLDevice) {
    mtkView = view
    let library = STKMetalLibLoader.load(device: device)
    let pipelineCubeDescriptor = MTLRenderPipelineDescriptor()
    pipelineCubeDescriptor.sampleCount = 1
    pipelineCubeDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
    pipelineCubeDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
    pipelineCubeDescriptor.vertexFunction = library.makeFunction(name: "vertexLine")
    pipelineCubeDescriptor.fragmentFunction = library.makeFunction(name: "fragmentLine")
    renderLineState = try! device.makeRenderPipelineState(descriptor: pipelineCubeDescriptor)

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

    vertexCubeBuffer = device.makeBuffer(
      bytes: cubeVertices, length: MemoryLayout<Float>.stride * cubeVertices.count, options: [])!
    indexCubeBuffer = device.makeBuffer(
      bytes: cubeIndices, length: MemoryLayout<UInt32>.stride * cubeIndices.count, options: [])!

    let triadIndices: [UInt32] = [
      0, 1,
      2, 3,
      4, 5,
    ]
    indexTriadBuffer = device.makeBuffer(
      bytes: triadIndices, length: MemoryLayout<UInt32>.stride * triadIndices.count, options: [])!
  }

  public func renderCubeOutline(
    _ commandEncoder: MTLRenderCommandEncoder,
    volumeSizeInMeters: simd_float3,
    cameraPosition: float4x4,
    projection: float4x4,
    orientation: float4x4
  ) {
    var uniformsCube = STKUniformsLine(
      model: float4x4.makeScale(volumeSizeInMeters.x, volumeSizeInMeters.y, volumeSizeInMeters.z),
      view: cameraPosition.inverse,
      projection: orientation * projection
    )

    commandEncoder.pushDebugGroup("RenderCube")
    commandEncoder.setRenderPipelineState(renderLineState)
    commandEncoder.setVertexBuffer(vertexCubeBuffer, offset: 0, index: 0)
    commandEncoder.setVertexBytes(&uniformsCube, length: MemoryLayout<STKUniformsLine>.stride, index: 1)
    commandEncoder.drawIndexedPrimitives(
      type: .line,
      indexCount: 24,
      indexType: .uint32,
      indexBuffer: indexCubeBuffer,
      indexBufferOffset: 0)
    commandEncoder.popDebugGroup()

    renderAnchors(
      commandEncoder,
      anchors: [simd_float4x4()],
      cameraPosition: cameraPosition,
      projection: projection,
      orientation: orientation,
      triadSize: volumeSizeInMeters.x
    )
  }

  public func renderAnchors(
    _ commandEncoder: MTLRenderCommandEncoder,
    anchors: [simd_float4x4],
    cameraPosition: float4x4,
    projection: float4x4,
    orientation: float4x4,
    triadSize: Float = 0.05
  ) {
    for anchor in anchors {
      var uniforms = STKUniformsLine(
        model: anchor,
        view: cameraPosition.inverse,
        projection: orientation * projection)
      commandEncoder.pushDebugGroup("RenderAnchor")
      commandEncoder.setRenderPipelineState(renderLineState)

      var triadVertices: [Float] = [
        0, 0, 0, 1, 0, 0,  // ox
        triadSize, 0, 0, 1, 0, 0,  // x
        0, 0, 0, 0, 0, 0,  // oy
        0, triadSize, 0, 0, 1, 0,  // y
        0, 0, 0, 0, 0, 1,  // oz
        0, 0, triadSize, 0, 0, 1,  // z
      ]
      commandEncoder.setVertexBytes(&triadVertices, length: MemoryLayout<Float>.stride * triadVertices.count, index: 0)
      commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<STKUniformsLine>.stride, index: 1)
      commandEncoder.drawIndexedPrimitives(
        type: .line,
        indexCount: 3 * 2,
        indexType: .uint32,
        indexBuffer: indexTriadBuffer,
        indexBufferOffset: 0)
      commandEncoder.popDebugGroup()
    }
  }

}
