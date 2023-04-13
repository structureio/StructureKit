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

import GLKit
import MetalKit
import StructureKitCTypes

public protocol STKShader {
  func render(
    _ commandEncoder: MTLRenderCommandEncoder,
    node: STKDrawableObject,
    worldModelMatrix: float4x4,
    projectionMatrix: float4x4
  )
}

// Renders a mesh as a solid body, in grayscale by default, uses the mesh normals to calculate light
public class STKMeshRendererSolid: STKShader {
  private var depthStencilState: MTLDepthStencilState
  private var pipelineState: MTLRenderPipelineState

  public init(colorFormat: MTLPixelFormat, depthFormat: MTLPixelFormat, device: MTLDevice) {
    depthStencilState = makeDepthStencilState(device)

    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0] = MTLVertexAttributeDescriptor(bufferIndex: 0, offset: 0, format: .float3)  // vertices
    vertexDescriptor.attributes[1] = MTLVertexAttributeDescriptor(
      bufferIndex: Int(STKVertexAttrAddition.rawValue), offset: 0, format: .float3)  // normals
    vertexDescriptor.layouts[0].stride = MemoryLayout<GLKVector3>.stride
    vertexDescriptor.layouts[1].stride = MemoryLayout<GLKVector3>.stride

    pipelineState = makePipeline(
      device,
      "vertexSolid",
      "fragmentSolid",
      vertexDescriptor,
      colorFormat,
      depthFormat,
      blending: true)
  }

  public convenience init(view: MTKView, device: MTLDevice) {
    self.init(colorFormat: view.colorPixelFormat, depthFormat: view.depthStencilPixelFormat, device: device)
  }

  public func render(
    _ commandEncoder: MTLRenderCommandEncoder,
    node: STKDrawableObject,
    worldModelMatrix: float4x4,
    projectionMatrix: float4x4
  ) {
    render(
      commandEncoder,
      node: node,
      worldModelMatrix: worldModelMatrix,
      projectionMatrix: projectionMatrix,
      color: vector_float4(1, 1, 1, 1))
  }

  public func render(
    _ commandEncoder: MTLRenderCommandEncoder,
    node: STKDrawableObject,
    worldModelMatrix: float4x4,
    projectionMatrix: float4x4,
    color: vector_float4 = vector_float4(1, 1, 1, 1)
  ) {
    guard node.vertexType is GLKVector3,
      node.indexType is UInt32
    else {
      assertionFailure("Type mismatch")
      return
    }
    guard let vertexBuffer = node.vertices(),
      let indexBuffer = node.indices(),
      let normalsBuffer = node.normals()
    else { return }

    commandEncoder.pushDebugGroup("RenderMeshLightedGrey")

    commandEncoder.setDepthStencilState(depthStencilState)
    commandEncoder.setRenderPipelineState(pipelineState)

    // buffers
    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(STKVertexAttrPosition.rawValue))
    commandEncoder.setVertexBuffer(normalsBuffer, offset: 0, index: Int(STKVertexAttrAddition.rawValue))
    let nodeModelMatrix = worldModelMatrix * node.modelMatrix()
    var uniforms = STKUniformsMesh(modelViewMatrix: nodeModelMatrix, projectionMatrix: projectionMatrix, color: color)
    commandEncoder.setVertexBytes(
      &uniforms, length: MemoryLayout<STKUniformsMesh>.stride, index: Int(STKVertexBufferIndexUniforms.rawValue))

    commandEncoder.drawIndexedPrimitives(
      type: .triangle,
      indexCount: node.triangleCount() * 3,
      indexType: .uint32,
      indexBuffer: indexBuffer,
      indexBufferOffset: 0)
    commandEncoder.popDebugGroup()
  }
}

// Renders mesh edges, uses the mesh normals to calculate light
public class STKMeshRendererWireframe: STKShader {
  private var pipelineState: MTLRenderPipelineState

  public init(colorFormat: MTLPixelFormat, depthFormat: MTLPixelFormat, device: MTLDevice) {
    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0] = MTLVertexAttributeDescriptor(bufferIndex: 0, offset: 0, format: .float3)  // vertices
    vertexDescriptor.attributes[1] = MTLVertexAttributeDescriptor(
      bufferIndex: Int(STKVertexAttrAddition.rawValue), offset: 0, format: .float3)  // normals
    vertexDescriptor.layouts[0].stride = MemoryLayout<GLKVector3>.stride
    vertexDescriptor.layouts[1].stride = MemoryLayout<GLKVector3>.stride

    pipelineState = makePipeline(
      device,
      "vertexWireframe",
      "fragmentWireframe",
      vertexDescriptor,
      colorFormat,
      depthFormat,
      blending: false)
  }

  public convenience init(view: MTKView, device: MTLDevice) {
    self.init(colorFormat: view.colorPixelFormat, depthFormat: view.depthStencilPixelFormat, device: device)
  }

  public func render(
    _ commandEncoder: MTLRenderCommandEncoder,
    node: STKDrawableObject,
    worldModelMatrix: float4x4,
    projectionMatrix: float4x4
  ) {
    render(
      commandEncoder, node: node, worldModelMatrix: worldModelMatrix, projectionMatrix: projectionMatrix, useXray: true)
  }

  public func render(
    _ commandEncoder: MTLRenderCommandEncoder,
    node: STKDrawableObject,
    worldModelMatrix: float4x4,
    projectionMatrix: float4x4,
    useXray: Bool = true,
    color: vector_float4 = vector_float4(1, 1, 1, 1)
  ) {
    guard node.vertexType is GLKVector3,
      node.indexType is UInt32
    else {
      assertionFailure("Type mismatch")
      return
    }

    guard let vertexBuffer = node.vertices(),
      let lineIndexBuffer = node.lines(),
      let normalsBuffer = node.normals()
    else { return }

    commandEncoder.pushDebugGroup("RenderMeshXray")
    commandEncoder.setRenderPipelineState(pipelineState)

    // set buffers
    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(STKVertexAttrPosition.rawValue))
    commandEncoder.setVertexBuffer(normalsBuffer, offset: 0, index: Int(STKVertexAttrAddition.rawValue))
    let nodeModelMatrix = worldModelMatrix * node.modelMatrix()
    var uniforms = STKUniformsMeshWireframe(
      modelViewMatrix: nodeModelMatrix, projectionMatrix: projectionMatrix,
      color: color,
      useXray: useXray)

    commandEncoder.setVertexBytes(
      &uniforms, length: MemoryLayout<STKUniformsMeshWireframe>.stride,
      index: Int(STKVertexBufferIndexUniforms.rawValue))

    commandEncoder.drawIndexedPrimitives(
      type: .line,
      indexCount: node.lineCount() * 2,
      indexType: .uint32,
      indexBuffer: lineIndexBuffer,
      indexBufferOffset: 0)

    commandEncoder.popDebugGroup()
  }
}

// Renders a colored mesh, uses the vertex colors
public class STKMeshRendererColor: STKShader {
  var depthStencilState: MTLDepthStencilState
  private var pipelineState: MTLRenderPipelineState

  public init(colorFormat: MTLPixelFormat, depthFormat: MTLPixelFormat, device: MTLDevice) {
    depthStencilState = makeDepthStencilState(device)

    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0] = MTLVertexAttributeDescriptor(
      bufferIndex: Int(STKVertexAttrPosition.rawValue), offset: 0, format: .float3)  // vertices
    vertexDescriptor.attributes[1] = MTLVertexAttributeDescriptor(
      bufferIndex: Int(STKVertexAttrAddition.rawValue), offset: 0, format: .float3)  // colors
    vertexDescriptor.layouts[0].stride = MemoryLayout<GLKVector3>.stride
    vertexDescriptor.layouts[1].stride = MemoryLayout<GLKVector3>.stride

    pipelineState = makePipeline(
      device,
      "vertexColor",
      "fragmentColor",
      vertexDescriptor,
      colorFormat,
      depthFormat,
      blending: false)
  }

  public convenience init(view: MTKView, device: MTLDevice) {
    self.init(colorFormat: view.colorPixelFormat, depthFormat: view.depthStencilPixelFormat, device: device)
  }

  public func render(
    _ commandEncoder: MTLRenderCommandEncoder,
    node: STKDrawableObject,
    worldModelMatrix: float4x4,
    projectionMatrix: float4x4
  ) {
    guard node.vertexType is GLKVector3,
      node.indexType is UInt32
    else {
      assertionFailure("Type mismatch")
      return
    }

    guard let vertexBuffer = node.vertices(),
      let indexBuffer = node.indices(),
      let colorsBuffer = node.colors(),
      indexBuffer.length > 0
    else { return }

    commandEncoder.pushDebugGroup("RenderMeshColor")
    commandEncoder.setRenderPipelineState(pipelineState)

    commandEncoder.setCullMode(MTLCullMode.front)
    commandEncoder.setDepthStencilState(depthStencilState)
    commandEncoder.setRenderPipelineState(pipelineState)

    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(STKVertexAttrPosition.rawValue))
    commandEncoder.setVertexBuffer(colorsBuffer, offset: 0, index: Int(STKVertexAttrAddition.rawValue))

    // set uniforms
    let nodeModelMatrix = worldModelMatrix * node.modelMatrix()
    var uniforms = STKUniformsMesh(
      modelViewMatrix: nodeModelMatrix, projectionMatrix: projectionMatrix, color: vector_float4(1, 1, 1, 1))
    commandEncoder.setVertexBytes(
      &uniforms, length: MemoryLayout<STKUniformsMesh>.stride, index: Int(STKVertexBufferIndexUniforms.rawValue))

    commandEncoder.drawIndexedPrimitives(
      type: .triangle,
      indexCount: node.triangleCount() * 3,
      indexType: .uint32,
      indexBuffer: indexBuffer,
      indexBufferOffset: 0)

    commandEncoder.popDebugGroup()
  }
}

// Renders a textured mesh
public class STKMeshRendererTexture: STKShader {
  private var depthStencilState: MTLDepthStencilState
  private var samplerState: MTLSamplerState
  private var pipelineState: MTLRenderPipelineState

  public init(colorFormat: MTLPixelFormat, depthFormat: MTLPixelFormat, device: MTLDevice) {
    depthStencilState = makeDepthStencilState(device)
    samplerState = makeDefaultSampler(device)

    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0] = MTLVertexAttributeDescriptor(
      bufferIndex: Int(STKVertexAttrPosition.rawValue), offset: 0, format: .float3)  // vertices
    vertexDescriptor.attributes[1] = MTLVertexAttributeDescriptor(
      bufferIndex: Int(STKVertexAttrAddition.rawValue), offset: 0, format: .float2)  // texture coordinates
    vertexDescriptor.layouts[0].stride = MemoryLayout<GLKVector3>.stride
    vertexDescriptor.layouts[1].stride = MemoryLayout<GLKVector2>.stride

    pipelineState = makePipeline(
      device,
      "vertexTexture",
      "fragmentTexture",
      vertexDescriptor,
      colorFormat,
      depthFormat,
      blending: false)
  }

  public convenience init(view: MTKView, device: MTLDevice) {
    self.init(colorFormat: view.colorPixelFormat, depthFormat: view.depthStencilPixelFormat, device: device)
  }

  public func render(
    _ commandEncoder: MTLRenderCommandEncoder,
    node: STKDrawableObject,
    worldModelMatrix: float4x4,
    projectionMatrix: float4x4
  ) {
    guard node.vertexType is GLKVector3,
      node.indexType is UInt32
    else {
      assertionFailure("Type mismatch")
      return
    }

    guard let vertexBuffer = node.vertices(),
      let indexBuffer = node.indices(),
      let texcoordBuffer = node.texCoords(),
      let textureY = node.textureY(),
      let textureCbCr = node.textureCbCr()
    else { return }

    commandEncoder.pushDebugGroup("RenderMeshTexture")

    commandEncoder.setCullMode(MTLCullMode.front)
    commandEncoder.setDepthStencilState(depthStencilState)
    commandEncoder.setRenderPipelineState(pipelineState)

    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(STKVertexAttrPosition.rawValue))
    commandEncoder.setVertexBuffer(texcoordBuffer, offset: 0, index: Int(STKVertexAttrAddition.rawValue))

    // set uniforms
    let nodeModelMatrix = worldModelMatrix * node.modelMatrix()
    var uniforms = STKUniformsMesh(
      modelViewMatrix: nodeModelMatrix, projectionMatrix: projectionMatrix, color: vector_float4(1, 1, 1, 1))
    commandEncoder.setVertexBytes(
      &uniforms, length: MemoryLayout<STKUniformsMesh>.stride, index: Int(STKVertexBufferIndexUniforms.rawValue))

    commandEncoder.setFragmentTexture(textureY, index: 0)  // [[ texture(0) ]]
    commandEncoder.setFragmentTexture(textureCbCr, index: 1)  // [[ texture(0) ]]
    commandEncoder.setFragmentSamplerState(samplerState, index: 0)  // [[ sampler(0) ]]

    commandEncoder.drawIndexedPrimitives(
      type: .triangle,
      indexCount: node.triangleCount() * 3,
      indexType: .uint32,
      indexBuffer: indexBuffer,
      indexBufferOffset: 0)

    commandEncoder.popDebugGroup()
  }
}

// Renders a mesh in grayscale, uses the mesh normals to calculate light
class STKMeshRendererPoints: STKShader {
  private var depthStencilState: MTLDepthStencilState
  private var pipelineState: MTLRenderPipelineState

  public init(colorFormat: MTLPixelFormat, depthFormat: MTLPixelFormat, device: MTLDevice) {
    depthStencilState = makeDepthStencilState(device)

    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0] = MTLVertexAttributeDescriptor(bufferIndex: 0, offset: 0, format: .float3)  // vertices
    vertexDescriptor.attributes[1] = MTLVertexAttributeDescriptor(
      bufferIndex: Int(STKVertexAttrAddition.rawValue), offset: 0, format: .float3)  // colors
    vertexDescriptor.layouts[0].stride = MemoryLayout<GLKVector3>.stride
    vertexDescriptor.layouts[1].stride = MemoryLayout<GLKVector3>.stride

    pipelineState = makePipeline(
      device,
      "vertexColorPoints",
      "fragmentColorPoints",
      vertexDescriptor,
      colorFormat,
      depthFormat,
      blending: false)
  }

  public convenience init(view: MTKView, device: MTLDevice) {
    self.init(colorFormat: view.colorPixelFormat, depthFormat: view.depthStencilPixelFormat, device: device)
  }

  public func render(
    _ commandEncoder: MTLRenderCommandEncoder,
    node: STKDrawableObject,
    worldModelMatrix: float4x4,
    projectionMatrix: float4x4
  ) {
    render(
      commandEncoder,
      node: node,
      worldModelMatrix: worldModelMatrix,
      projectionMatrix: projectionMatrix,
      alpha: 1.0)
  }

  public func render(
    _ commandEncoder: MTLRenderCommandEncoder,
    node: STKDrawableObject,
    worldModelMatrix: float4x4,
    projectionMatrix: float4x4,
    alpha: Float = 1.0
  ) {
    guard node.vertexType is GLKVector3 else {
      assertionFailure("Type mismatch")
      return
    }

    guard let vertexBuffer = node.vertices(),
      let colorsBuffer = node.colors()
    else { return }

    commandEncoder.pushDebugGroup("RenderPoints")
    commandEncoder.setRenderPipelineState(pipelineState)

    commandEncoder.setCullMode(MTLCullMode.front)
    commandEncoder.setDepthStencilState(depthStencilState)
    commandEncoder.setRenderPipelineState(pipelineState)

    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(STKVertexAttrPosition.rawValue))
    commandEncoder.setVertexBuffer(colorsBuffer, offset: 0, index: Int(STKVertexAttrAddition.rawValue))

    // set uniforms
    let nodeModelMatrix = worldModelMatrix * node.modelMatrix()
    var uniforms = STKUniformsMesh(
      modelViewMatrix: nodeModelMatrix, projectionMatrix: projectionMatrix, color: vector_float4(1, 1, 1, alpha))
    commandEncoder.setVertexBytes(
      &uniforms, length: MemoryLayout<STKUniformsMesh>.stride, index: Int(STKVertexBufferIndexUniforms.rawValue))

    commandEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: node.vertexCount())

    commandEncoder.popDebugGroup()
  }
}

public class STKMeshRendererLines: STKShader {
  private var depthStencilState: MTLDepthStencilState
  private var pipelineState: MTLRenderPipelineState

  public init(colorFormat: MTLPixelFormat, depthFormat: MTLPixelFormat, device: MTLDevice) {
    depthStencilState = makeDepthStencilState(device)

    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0] = MTLVertexAttributeDescriptor(bufferIndex: 0, offset: 0, format: .float3)  // vertices
    vertexDescriptor.attributes[1] = MTLVertexAttributeDescriptor(
      bufferIndex: Int(STKVertexAttrAddition.rawValue), offset: 0, format: .float3)  // colors
    vertexDescriptor.layouts[0].stride = MemoryLayout<vector_float3>.stride
    vertexDescriptor.layouts[1].stride = MemoryLayout<vector_float3>.stride

    pipelineState = makePipeline(
      device,
      "vertexColorPoints",
      "fragmentColorPoints",
      vertexDescriptor,
      colorFormat,
      depthFormat,
      blending: false)
  }

  public convenience init(view: MTKView, device: MTLDevice) {
    self.init(colorFormat: view.colorPixelFormat, depthFormat: view.depthStencilPixelFormat, device: device)
  }

  public func render(
    _ commandEncoder: MTLRenderCommandEncoder,
    node: STKDrawableObject,
    worldModelMatrix: float4x4,
    projectionMatrix: float4x4
  ) {
    render(
      commandEncoder,
      node: node,
      worldModelMatrix: worldModelMatrix,
      projectionMatrix: projectionMatrix,
      alpha: 1.0)
  }

  public func render(
    _ commandEncoder: MTLRenderCommandEncoder,
    node: STKDrawableObject,
    worldModelMatrix: float4x4,
    projectionMatrix: float4x4,
    alpha: Float = 1.0
  ) {
    guard node.vertexType is vector_float3,
      node.indexType is UInt32
    else {
      assertionFailure("Type mismatch")
      return
    }

    guard let vertexBuffer = node.vertices(),
      let colorsBuffer = node.colors(),
      let lineIndexBuffer = node.lines()
    else { return }

    commandEncoder.pushDebugGroup("RenderLines")
    commandEncoder.setRenderPipelineState(pipelineState)

    commandEncoder.setCullMode(MTLCullMode.front)
    commandEncoder.setDepthStencilState(depthStencilState)
    commandEncoder.setRenderPipelineState(pipelineState)

    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(STKVertexAttrPosition.rawValue))
    commandEncoder.setVertexBuffer(colorsBuffer, offset: 0, index: Int(STKVertexAttrAddition.rawValue))

    // set uniforms
    let nodeModelMatrix = worldModelMatrix * node.modelMatrix()
    var uniforms = STKUniformsMesh(
      modelViewMatrix: nodeModelMatrix, projectionMatrix: projectionMatrix, color: vector_float4(1, 1, 1, alpha))
    commandEncoder.setVertexBytes(
      &uniforms, length: MemoryLayout<STKUniformsMesh>.stride, index: Int(STKVertexBufferIndexUniforms.rawValue))

    commandEncoder.drawIndexedPrimitives(
      type: .line,
      indexCount: node.lineCount() * 2,
      indexType: .uint32,
      indexBuffer: lineIndexBuffer,
      indexBufferOffset: 0)

    commandEncoder.popDebugGroup()
  }
}

public class STKScanMeshRenderer {
  private var solid: STKMeshRendererSolid
  private var wireframe: STKMeshRendererWireframe

  public init(view: MTKView, device: MTLDevice) {
    solid = STKShaderManager.solid
    wireframe = STKShaderManager.wireframe
  }

  public func render(
    _ commandEncoder: MTLRenderCommandEncoder,
    node: STKDrawableObject,
    cameraPosition: float4x4,
    projection: float4x4,
    orientation: float4x4,
    color: vector_float4,
    style: STKMeshRenderingStyle
  ) {
    let modelViewMatrix = cameraPosition.inverse
    let projectionMatrix = orientation * projection

    switch style {
    case .solid:
      solid.render(
        commandEncoder,
        node: node,
        worldModelMatrix: modelViewMatrix,
        projectionMatrix: projectionMatrix,
        color: color
      )
    case .wireframe:
      wireframe.render(
        commandEncoder,
        node: node,
        worldModelMatrix: modelViewMatrix,
        projectionMatrix: projectionMatrix,
        useXray: false,
        color: color)
    }
  }

}
