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
  var depthStencilState: MTLDepthStencilState
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
    color: vector_float4 = vector_float4(1, 1, 1, 1),
    hideBackFaces: Bool = true
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

    // Setting the depth stencil state to prevent rendering the back faces, otherwise it renders the backfaces and mesh apprears transparent
    if hideBackFaces {
      commandEncoder.setDepthStencilState(depthStencilState)
    }
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
    color: vector_float4 = vector_float4(1, 1, 1, 1),
    hideBackFaces: Bool = false
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

    let solid = STKShaderManager.solid
    if hideBackFaces {
      // use solid shader to fill the depth buffer where necessary
      commandEncoder.setDepthBias(0.01, slopeScale: 1.0, clamp: 0.01)
      solid.render(
        commandEncoder, node: node, worldModelMatrix: worldModelMatrix, projectionMatrix: projectionMatrix,
        color: vector_float4(0, 0, 0, 0))
      commandEncoder.setDepthBias(0, slopeScale: 0, clamp: 0)
    }

    commandEncoder.pushDebugGroup("RenderMeshXray")
    if hideBackFaces {
      commandEncoder.setDepthStencilState(solid.depthStencilState)
    }
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
public class STKMeshRendererPoints: STKShader {
  private var depthStencilState: MTLDepthStencilState
  private var pipelineState: MTLRenderPipelineState
  private var pointTexture: MTLTexture
  private var textureSamplerState: MTLSamplerState
  
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
      blending: true)
    
    pointTexture = STKMeshRendererPoints.generateCircleTexture(device: device)
    
    let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.minFilter = .linear
    samplerDescriptor.magFilter = .linear
    samplerDescriptor.sAddressMode = .clampToEdge
    samplerDescriptor.tAddressMode = .clampToEdge
    textureSamplerState = device.makeSamplerState(descriptor: samplerDescriptor)!
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

    commandEncoder.setCullMode(MTLCullMode.none)
    commandEncoder.setDepthStencilState(depthStencilState)
    commandEncoder.setRenderPipelineState(pipelineState)

    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(STKVertexAttrPosition.rawValue))
    commandEncoder.setVertexBuffer(colorsBuffer, offset: 0, index: Int(STKVertexAttrAddition.rawValue))

    // set uniforms
    let nodeModelMatrix = worldModelMatrix * node.modelMatrix()
    var uniforms = STKUniformsMeshPoints(
      modelViewMatrix: nodeModelMatrix, projectionMatrix: projectionMatrix, pointSize: 0.05)
    commandEncoder.setVertexBytes(
      &uniforms, length: MemoryLayout<STKUniformsMesh>.stride, index: Int(STKVertexBufferIndexUniforms.rawValue))
    
    // Set the texture and sampler for the fragment shader
    commandEncoder.setFragmentTexture(pointTexture, index: 0)
    commandEncoder.setFragmentSamplerState(textureSamplerState, index: 0)
    
    commandEncoder.drawPrimitives(
      type: .triangleStrip,
      vertexStart: 0,
      vertexCount: 4,
      instanceCount: node.vertexCount()
    )

    commandEncoder.popDebugGroup()
  }
  
  private static func generateCircleTexture(device: MTLDevice, size:Int = 16) -> MTLTexture {
    let radius = Float(size) / 2.0
    var textureData = [UInt8](repeating: 0, count: size * size * 4) // RGBA
    
    for y in 0..<size {
      for x in 0..<size {
        let dx = Float(x) - radius
        let dy = Float(y) - radius
        let dist = sqrt(dx * dx + dy * dy)
        
        // Set alpha based on distance from center
        let alpha: UInt8
        if dist < radius - 2 {
          alpha = 255
        }
        else if dist < radius {
          // Simple linear falloff
          let ratio = (1.0 - dist / radius)
          alpha = UInt8(sqrt(ratio) * 255.0)
        } else {
          alpha = 0
        }
        
        let index = (y * size + x) * 4
        textureData[index + 0] = 255 // R
        textureData[index + 1] = 255 // G
        textureData[index + 2] = 255 // B
        textureData[index + 3] = alpha // A
      }
    }
    
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba8Unorm,
      width: size,
      height: size,
      mipmapped: false)
    
    guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
      fatalError("Failed to create texture.")
    }
    
    let region = MTLRegionMake2D(0, 0, size, size)
    texture.replace(region: region, mipmapLevel: 0, withBytes: &textureData, bytesPerRow: size * 4)
    
    return texture
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
    case .transparentSolid:
      solid.render(
        commandEncoder,
        node: node,
        worldModelMatrix: modelViewMatrix,
        projectionMatrix: projectionMatrix,
        color: color,
        hideBackFaces: false
      )
    }
  }

}

public class STKMeshRendererThickLines: STKShader {
  private var depthStencilState: MTLDepthStencilState
  private var pipelineState: MTLRenderPipelineState

  init(colorFormat: MTLPixelFormat, depthFormat: MTLPixelFormat, device: MTLDevice) {
    depthStencilState = makeDepthStencilState(device)

    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0] = MTLVertexAttributeDescriptor(bufferIndex: 0, offset: 0, format: .float3)  // vertices
    vertexDescriptor.attributes[1] = MTLVertexAttributeDescriptor(
      bufferIndex: Int(STKVertexAttrAddition.rawValue), offset: 0, format: .float3)  // colors
    vertexDescriptor.layouts[0].stride = MemoryLayout<vector_float3>.stride
    vertexDescriptor.layouts[1].stride = MemoryLayout<vector_float3>.stride

    pipelineState = makePipeline(
      device,
      "vertexThickLine",
      "fragmentThickLine",
      vertexDescriptor,
      colorFormat,
      depthFormat,
      blending: false)
  }

  convenience init(view: MTKView, device: MTLDevice) {
    self.init(colorFormat: view.colorPixelFormat, depthFormat: view.depthStencilPixelFormat, device: device)
  }

  public func render(
    _ commandEncoder: MTLRenderCommandEncoder,
    node: STKDrawableObject,
    worldModelMatrix: float4x4,
    projectionMatrix: float4x4
  ) {
    render(
      commandEncoder, node: node, worldModelMatrix: worldModelMatrix, projectionMatrix: projectionMatrix, width: 3.0)
  }

  public func render(
    _ commandEncoder: MTLRenderCommandEncoder,
    node: STKDrawableObject,
    worldModelMatrix: float4x4,
    projectionMatrix: float4x4,
    width: Float
  ) {
    guard node.vertexType is vector_float3,
      node.indexType is UInt32
    else {
      assertionFailure("Type mismatch")
      return
    }

    guard let vertexBuffer = node.vertices(),
      let colorsBuffer = node.colors(),
      let indexBuffer = node.indices(),
      let lineDir = node.normals(),
      node.triangleCount() > 0
    else { return }

    commandEncoder.pushDebugGroup("RenderThickLines")
    commandEncoder.setRenderPipelineState(pipelineState)
    commandEncoder.setDepthStencilState(depthStencilState)
    commandEncoder.setCullMode(MTLCullMode.none)

    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(STKVertexAttrPosition.rawValue))
    commandEncoder.setVertexBuffer(colorsBuffer, offset: 0, index: Int(STKVertexAttrAddition.rawValue))
    commandEncoder.setVertexBuffer(lineDir, offset: 0, index: 3)

    // set uniforms
    let indexCount = node.triangleCount()
    let nodeModelMatrix = worldModelMatrix * node.modelMatrix()
    var uniforms = STKUniformsThickLine(
      modelViewMatrix: nodeModelMatrix, projectionMatrix: projectionMatrix, color: vector_float4(1, 1, 1, 1),
      width: width)
    commandEncoder.setVertexBytes(
      &uniforms, length: MemoryLayout<STKUniformsThickLine>.stride, index: Int(STKVertexBufferIndexUniforms.rawValue))

    // commandEncoder.setDepthBias(-1, slopeScale: 0, clamp: 0)
    commandEncoder.drawIndexedPrimitives(
      type: .triangleStrip,
      indexCount: indexCount,
      indexType: .uint32,
      indexBuffer: indexBuffer,
      indexBufferOffset: 0)
    // commandEncoder.setDepthBias(0, slopeScale: 0, clamp: 0)

    commandEncoder.popDebugGroup()
  }
}
