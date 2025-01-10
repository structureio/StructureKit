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
import Metal
import MetalKit
import SceneKit
import StructureKitCTypes

extension String: Error {}

extension float4x4 {
  public init(_ m: GLKMatrix4) { self = unsafeBitCast(m, to: float4x4.self) }

  public func toGLK() -> GLKMatrix4 { SCNMatrix4ToGLKMatrix4(SCNMatrix4(self)) }

  public mutating func translate(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
    self = self * float4x4.makeTranslation(x, y, z)
    return self
  }

  public static var identity: float4x4 { unsafeBitCast(GLKMatrix4Identity, to: float4x4.self) }

  public static func makeTranslation(_ vec: vector_float3) -> float4x4 {
    unsafeBitCast(GLKMatrix4MakeTranslation(vec.x, vec.y, vec.z), to: float4x4.self)
  }

  public static func makeTranslation(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
    unsafeBitCast(GLKMatrix4MakeTranslation(x, y, z), to: float4x4.self)
  }

  public static func makeRotationX(_ radians: Float) -> float4x4 {
    unsafeBitCast(GLKMatrix4MakeXRotation(radians), to: float4x4.self)
  }

  public static func makeRotationY(_ radians: Float) -> float4x4 {
    unsafeBitCast(GLKMatrix4MakeYRotation(radians), to: float4x4.self)
  }

  public static func makeRotationZ(_ radians: Float) -> float4x4 {
    unsafeBitCast(GLKMatrix4MakeZRotation(radians), to: float4x4.self)
  }

  public static func makeRotation(_ radians: Float, _ x: Float, _ y: Float, _ z: Float) -> float4x4 {
    unsafeBitCast(GLKMatrix4MakeRotation(radians, x, y, z), to: float4x4.self)
  }

  public static func makeRotation(_ radians: Float, _ vec: vector_float3) -> float4x4 {
    float4x4.makeRotation(radians, vec.x, vec.y, vec.z)
  }

  public static func makeScale(_ s: Float) -> float4x4 {
    unsafeBitCast(GLKMatrix4MakeScale(s, s, s), to: float4x4.self)
  }

  public static func makeScale(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
    unsafeBitCast(GLKMatrix4MakeScale(x, y, z), to: float4x4.self)
  }

  public static func makePerspective(_ fovyRadians: Float, _ aspect: Float, _ nearZ: Float, _ farZ: Float) -> float4x4 {
    unsafeBitCast(GLKMatrix4MakePerspective(fovyRadians, aspect, nearZ, farZ), to: float4x4.self)
  }

  public var translation: vector_float4 { return self.columns.3 }
}

extension float3x3 {
  public static var identity: float3x3 { unsafeBitCast(GLKMatrix3Identity, to: float3x3.self) }

  public static func makeRotationZ(_ radians: Float) -> float3x3 {
    float3x3([
      simd_float3(cos(radians), -sin(radians), 0), simd_float3(sin(radians), cos(radians), 0), simd_float3(0, 0, 1),
    ])
  }

  public static func makeTranslation(x: Float, y: Float) -> float3x3 {
    float3x3([simd_float3(1, 0, 0), simd_float3(0, 1, 0), simd_float3(x, y, 1)])
  }

  public static func makeScale(x: Float, y: Float, z: Float) -> float3x3 { float3x3(diagonal: simd_float3(x, y, z)) }
}

extension float2x2 {
  public static func makeRotation(_ radians: Float) -> float2x2 {
    float2x2([simd_float2(cos(radians), -sin(radians)), simd_float2(sin(radians), cos(radians))])
  }

  public static func makeScale(x: Float, y: Float) -> float2x2 { float2x2(diagonal: simd_float2(x, y)) }
}

extension simd_float4 {
  public func norm2() -> Float { length_squared(self) }

  public func norm() -> Float { length(self) }

  public func toGLK() -> GLKVector4 { GLKVector4Make(x, y, z, w) }

  public var xyz: vector_float3 { vector_float3(self) }
}

extension simd_float3 {
  public init(_ v: GLKVector3) { self = simd_float3(v.x, v.y, v.z) }

  public init(_ v: simd_float4) { self = simd_float3(v.x, v.y, v.z) }

  public func norm2() -> Float { length_squared(self) }

  public func norm() -> Float { length(self) }

  public func toGLK() -> GLKVector3 { GLKVector3Make(x, y, z) }
}

extension simd_float2 {
  public init(_ v: GLKVector2) { self = simd_float2(v.x, v.y) }

  public func norm2() -> Float { length_squared(self) }

  public func norm() -> Float { length(self) }

  public func toGLK() -> GLKVector2 { GLKVector2Make(x, y) }
}

public func makeRectangularVertices(z: Float = 0.0) -> [STKVertexTex] {
  let vertexData: [STKVertexTex] = [
    // a b
    // c d
    // -1.0,  1.0, 0.0,   0.0, 0.0, // a
    //  1.0,  1.0, 0.0,   1.0, 0.0, // b
    //  1.0, -1.0, 0.0,   1.0, 1.0, // d
    //
    // -1.0,  1.0, 0.0,   0.0, 0.0, // a
    //  1.0, -1.0, 0.0,   1.0, 1.0, // d
    // -1.0, -1.0, 0.0,   0.0, 1.0  // c
    STKVertexTex(position: vector_float3(x: -1.0, y: 1.0, z: z), texCoord: vector_float2(0.0, 0.0)),  // a
    STKVertexTex(position: vector_float3(x: 1.0, y: 1.0, z: z), texCoord: vector_float2(1.0, 0.0)),  // b
    STKVertexTex(position: vector_float3(x: 1.0, y: -1.0, z: z), texCoord: vector_float2(1.0, 1.0)),  // d

    STKVertexTex(position: vector_float3(x: -1.0, y: 1.0, z: z), texCoord: vector_float2(0.0, 0.0)),  // a
    STKVertexTex(position: vector_float3(x: 1.0, y: -1.0, z: z), texCoord: vector_float2(1.0, 1.0)),  // d
    STKVertexTex(position: vector_float3(x: -1.0, y: -1.0, z: z), texCoord: vector_float2(0.0, 1.0)),  // c
  ]
  return vertexData
}

public func makeDefaultSampler(_ device: MTLDevice) -> MTLSamplerState {
  let sampler = MTLSamplerDescriptor()
  sampler.minFilter = MTLSamplerMinMagFilter.nearest
  sampler.magFilter = MTLSamplerMinMagFilter.nearest
  sampler.mipFilter = MTLSamplerMipFilter.notMipmapped
  sampler.maxAnisotropy = 1
  sampler.sAddressMode = MTLSamplerAddressMode.clampToEdge
  sampler.tAddressMode = MTLSamplerAddressMode.clampToEdge
  sampler.rAddressMode = MTLSamplerAddressMode.clampToEdge
  sampler.normalizedCoordinates = true
  sampler.lodMinClamp = 0
  sampler.lodMaxClamp = Float.greatestFiniteMagnitude
  return device.makeSamplerState(descriptor: sampler)!
}

extension MTLVertexAttributeDescriptor {
  public convenience init(bufferIndex: Int, offset: Int, format: MTLVertexFormat) {
    self.init()
    self.format = format
    self.offset = offset
    self.bufferIndex = bufferIndex
  }
}

extension MTLRenderPipelineDescriptor {
  public convenience init(
    _ view: MTKView,
    _ device: MTLDevice,
    _ vertex: String,
    _ fragment: String,
    _ vertexDescriptor: MTLVertexDescriptor
  ) {
    self.init()

    let library = STKMetalLibLoader.load(device: device)
    self.vertexFunction = library.makeFunction(name: vertex)
    self.fragmentFunction = library.makeFunction(name: fragment)
    self.colorAttachments[0].pixelFormat = view.colorPixelFormat
    self.depthAttachmentPixelFormat = view.depthStencilPixelFormat
    self.vertexDescriptor = vertexDescriptor
  }

}

public func makeDepthStencilState(_ device: MTLDevice, isDepthWriteEnabled: Bool = true) -> MTLDepthStencilState {
  let depthStencilDescriptor = MTLDepthStencilDescriptor()
  depthStencilDescriptor.depthCompareFunction = .less
  depthStencilDescriptor.isDepthWriteEnabled = isDepthWriteEnabled
  return device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
}

public func makePipeline(
  _ device: MTLDevice,
  _ vertex: String,
  _ fragment: String,
  _ vertexDescriptor: MTLVertexDescriptor,
  _ pixelFormat: MTLPixelFormat,
  _ depthFormat: MTLPixelFormat,
  blending: Bool
) -> MTLRenderPipelineState {
  let pipelineDescriptor = MTLRenderPipelineDescriptor()
  let library = STKMetalLibLoader.load(device: device)
  pipelineDescriptor.vertexFunction = library.makeFunction(name: vertex)
  pipelineDescriptor.fragmentFunction = library.makeFunction(name: fragment)
  pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
  pipelineDescriptor.depthAttachmentPixelFormat = depthFormat
  pipelineDescriptor.vertexDescriptor = vertexDescriptor

  if blending {
    pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
    pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
    pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
  }

  return try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
}

public func makePipeline(
  _ view: MTKView,
  _ device: MTLDevice,
  _ vertex: String,
  _ fragment: String,
  _ vertexDescriptor: MTLVertexDescriptor,
  blending: Bool
) -> MTLRenderPipelineState {
  makePipeline(
    device, vertex, fragment, vertexDescriptor, view.colorPixelFormat, view.depthStencilPixelFormat, blending: blending)
}

public func makeTexture(
  pixelBuffer: CVPixelBuffer, textureCache: CVMetalTextureCache, planeIndex: Int, pixelFormat: MTLPixelFormat
) throws -> MTLTexture {
  var imageTexture: CVMetalTexture?
  let isPlanar = CVPixelBufferIsPlanar(pixelBuffer)
  let width = isPlanar ? CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex) : CVPixelBufferGetWidth(pixelBuffer)
  let height = isPlanar ? CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex) : CVPixelBufferGetHeight(pixelBuffer)
  let result = CVMetalTextureCacheCreateTextureFromImage(
    kCFAllocatorDefault, textureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &imageTexture)
  guard
    let unwrappedImageTexture = imageTexture,
    let texture = CVMetalTextureGetTexture(unwrappedImageTexture),
    result == kCVReturnSuccess
  else { throw "cannot create texture" }
  return texture
}

public func calcVisualizationDistance(cameraPoint: vector_float3, cubeSize: vector_float3) -> (min: Float, max: Float) {
  // we need to evenly distribute the colormap across the whole depth range inside the cube. lets approximate it with a sphere
  let cubeCenter = cubeSize / 2
  let maxDiagonal = cubeSize.max()
  let maxDistMM = ((cubeCenter - cameraPoint).norm() + maxDiagonal / 2)
  let minDistMM = max((cubeCenter - cameraPoint).norm() - maxDiagonal / 2, 0)
  return (minDistMM, maxDistMM)
}
