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

// Draws an ARKit face geometry as a white transparent mesh
public class STKARKitOverlayRenderer {
  var arkitToWorld = simd_float4x4()
  private var depthStencilARKitState: MTLDepthStencilState
  private var renderARKitState: MTLRenderPipelineState

  public init(view: MTKView, device: MTLDevice) {
    let depthStencilDescriptor = MTLDepthStencilDescriptor()
    depthStencilDescriptor.depthCompareFunction = .less
    depthStencilDescriptor.isDepthWriteEnabled = true
    depthStencilARKitState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)!

    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0] = MTLVertexAttributeDescriptor(bufferIndex: 0, offset: 0, format: .float3)  // vertices
    vertexDescriptor.layouts[0].stride = MemoryLayout<vector_float3>.stride

    let library = STKMetalLibLoader.load(device: device)
    let pipelineMeshDescriptor = MTLRenderPipelineDescriptor()
    pipelineMeshDescriptor.sampleCount = 1
    pipelineMeshDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
    pipelineMeshDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
    pipelineMeshDescriptor.vertexDescriptor = vertexDescriptor

    pipelineMeshDescriptor.vertexFunction = library.makeFunction(name: "vertexARKit")
    pipelineMeshDescriptor.fragmentFunction = library.makeFunction(name: "fragmentARKit")

    // blending
    pipelineMeshDescriptor.colorAttachments[0].isBlendingEnabled = true
    pipelineMeshDescriptor.colorAttachments[0].rgbBlendOperation = .add
    pipelineMeshDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    pipelineMeshDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

    renderARKitState = try! device.makeRenderPipelineState(descriptor: pipelineMeshDescriptor)
  }

  public func renderARkitGeom(
    _ commandEncoder: MTLRenderCommandEncoder,
    mesh: STKDrawableObject,
    cameraPosition: float4x4,
    projection: float4x4,
    orientation: float4x4
  ) {
    guard let vertexBuffer = mesh.vertices(),
      let indexBuffer = mesh.indices()
    else { return }

    commandEncoder.pushDebugGroup("RenderARKitGeometry")
    commandEncoder.setDepthStencilState(depthStencilARKitState)
    commandEncoder.setRenderPipelineState(renderARKitState)

    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(STKVertexAttrPosition.rawValue))

    var uniforms = STKUniformsMesh(
      modelViewMatrix: float4x4.makeRotationZ(Float.pi) * cameraPosition.inverse * arkitToWorld,
      projectionMatrix: orientation * projection,
      color: vector_float4(1, 1, 1, 0.5))
    commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<STKUniformsMesh>.stride, index: 1)

    commandEncoder.drawIndexedPrimitives(
      type: .triangle,
      indexCount: mesh.triangleCount() * 3,
      indexType: .uint16,
      indexBuffer: indexBuffer,
      indexBufferOffset: 0)

    commandEncoder.popDebugGroup()
  }
}
