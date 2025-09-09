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

import ARKit
import Metal
import MetalKit

// Implementation of the STKDrawableObject protocol for STKMesh and ARFaceGeometry
public class STKMeshBuffers: STKDrawableObject {
  public var mesh: STKMesh?
  public var arkitMesh: ARFaceGeometry?

  public var vertexType: Any = GLKVector3()
  public var indexType: Any = UInt32()

  fileprivate var device: MTLDevice
  fileprivate var textureCache: CVMetalTextureCache!
  fileprivate var vertexBuffer: MTLBuffer?
  fileprivate var indexBuffer: MTLBuffer?
  fileprivate var lineBuffer: MTLBuffer?
  fileprivate var normalBuffer: MTLBuffer?
  fileprivate var colorBuffer: MTLBuffer?
  fileprivate var texcoordBuffer: MTLBuffer?
  fileprivate var textureYinternal: MTLTexture?
  fileprivate var textureCbCrinternal: MTLTexture?
  fileprivate var nTriangle: Int = 0
  fileprivate var nVertex: Int = 0
  fileprivate var nLine: Int = 0

  public init(_ device: MTLDevice) {
    self.device = device
    CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
  }

  fileprivate func clear() {
    vertexBuffer = nil
    indexBuffer = nil
    lineBuffer = nil
    normalBuffer = nil
    colorBuffer = nil
    texcoordBuffer = nil
    textureYinternal = nil
    textureCbCrinternal = nil
    nTriangle = 0
    nVertex = 0
    nLine = 0
    self.mesh = nil
    arkitMesh = nil
  }

  public func updateMesh(_ mesh: STKMesh) {
    self.mesh = mesh
    updateBuffers()
  }

  public func updateMesh(arkitFace mesh: ARFaceGeometry) {
    clear()
    vertexType = vector_float3()
    indexType = UInt16()

    guard mesh.vertices.count > 0 else { return }

    nTriangle = mesh.triangleCount
    nVertex = mesh.vertices.count

    vertexBuffer = device.makeBuffer(
      bytes: mesh.vertices, length: mesh.vertices.count * MemoryLayout<vector_float3>.stride, options: [])

    // convert Int16 to UInt16
    var indices = [UInt16](repeating: 0, count: mesh.triangleIndices.count)
    for i in 0..<mesh.triangleIndices.count {
      indices[i] = UInt16(mesh.triangleIndices[i])
    }

    let indexSize = mesh.triangleIndices.count * MemoryLayout<UInt16>.stride
    indexBuffer = device.makeBuffer(bytes: indices, length: indexSize, options: [])
  }

  public func vertexArray() -> [simd_float3]? {
    if let mesh = mesh {
      let numVertices: Int = Int(mesh.number(ofMeshVertices: Int32(0)))
      let buff = UnsafeMutableBufferPointer<GLKVector3>(start: mesh.meshVertices(0), count: numVertices)
      let glk: [GLKVector3] = [GLKVector3](buff)
      let simd: [simd_float3] = glk.map { simd_float3($0) }
      return simd
    } else if let mesh = arkitMesh {
      return mesh.vertices
    }
    return nil
  }

  public func boundingBox() -> (min: simd_float3, max: simd_float3)? {
    var min = simd_float3(repeating: Float.greatestFiniteMagnitude)
    var max = simd_float3(repeating: -Float.greatestFiniteMagnitude)

    if let mesh = mesh {
      for i in 0..<mesh.number(ofMeshVertices: 0) {
        let v = mesh.meshVertices(0)![Int(i)]
        min.x = Float.minimum(min.x, v.x)
        min.y = Float.minimum(min.y, v.y)
        min.z = Float.minimum(min.z, v.z)
        max.x = Float.maximum(max.x, v.x)
        max.y = Float.maximum(max.y, v.y)
        max.z = Float.maximum(max.z, v.z)
      }
      return (min, max)
    } else if let mesh = arkitMesh {
      for v in mesh.vertices {
        min.x = Float.minimum(min.x, v.x)
        min.y = Float.minimum(min.y, v.y)
        min.z = Float.minimum(min.z, v.z)
        max.x = Float.maximum(max.x, v.x)
        max.y = Float.maximum(max.y, v.y)
        max.z = Float.maximum(max.z, v.z)
      }
      return (min, max)
    }
    return nil
  }

  public func updateBuffers() {
    vertexBuffer = nil
    indexBuffer = nil
    lineBuffer = nil
    normalBuffer = nil
    colorBuffer = nil
    texcoordBuffer = nil
    textureYinternal = nil
    textureCbCrinternal = nil
    nTriangle = 0
    nVertex = 0
    nLine = 0

    if let mesh = mesh {
      vertexType = GLKVector3()
      indexType = UInt32()

      guard mesh.number(ofMeshVertices: 0) > 0 else { return }
      let numVertices: Int = Int(mesh.number(ofMeshVertices: Int32(0)))
      vertexBuffer = device.makeBuffer(
        bytes: mesh.meshVertices(0)!, length: numVertices * MemoryLayout<GLKVector3>.stride, options: [])

      if mesh.hasPerVertexNormals(), let bytes = mesh.meshPerVertexNormals(0) {
        normalBuffer = device.makeBuffer(
          bytes: bytes, length: numVertices * MemoryLayout<GLKVector3>.stride, options: [])
      }
      if mesh.hasPerVertexColors(), let bytes = mesh.meshPerVertexColors(0) {
        colorBuffer = device.makeBuffer(
          bytes: bytes, length: numVertices * MemoryLayout<GLKVector3>.stride, options: [])
      }
      if mesh.hasPerVertexUVTextureCoords(), let bytes = mesh.meshPerVertexUVTextureCoords(0) {
        texcoordBuffer = device.makeBuffer(
          bytes: bytes, length: numVertices * MemoryLayout<GLKVector2>.stride, options: [])
      }

      nLine = Int(mesh.number(ofMeshLines: 0))
      if nLine > 0, let bytes = mesh.meshLines(0) {
        lineBuffer = device.makeBuffer(bytes: bytes, length: nLine * MemoryLayout<UInt32>.stride * 2, options: [])
      }

      let indexSize = Int(mesh.number(ofMeshFaces: Int32(0))) * MemoryLayout<UInt32>.stride * 3
      if indexSize > 0, let bytes = mesh.meshFaces(0) {
        indexBuffer = device.makeBuffer(bytes: bytes, length: indexSize, options: [])
      }

      nTriangle = Int(mesh.number(ofMeshFaces: 0))
      nVertex = Int(mesh.number(ofMeshVertices: 0))

      // texture
      if let pixelBuffer: CVPixelBuffer = mesh.meshYCbCrTexture()?.takeUnretainedValue() {
        textureYinternal = try! makeTexture(
          pixelBuffer: pixelBuffer, textureCache: textureCache, planeIndex: 0, pixelFormat: .r8Unorm)
        textureCbCrinternal = try! makeTexture(
          pixelBuffer: pixelBuffer, textureCache: textureCache, planeIndex: 1, pixelFormat: .rg8Unorm)
      }
    }
  }

  public func vertices() -> MTLBuffer? { vertexBuffer }

  public func indices() -> MTLBuffer? { indexBuffer }

  public func lines() -> MTLBuffer? { lineBuffer }

  public func normals() -> MTLBuffer? { normalBuffer }

  public func colors() -> MTLBuffer? { colorBuffer }

  public func texCoords() -> MTLBuffer? { texcoordBuffer }

  public func textureY() -> MTLTexture? { textureYinternal }

  public func textureCbCr() -> MTLTexture? { textureCbCrinternal }

  public func modelMatrix() -> float4x4 { float4x4.identity }

  public func vertexCount() -> Int { nVertex }

  public func triangleCount() -> Int { nTriangle }

  public func lineCount() -> Int { nLine }
}

extension STKMeshBuffers {
  public func update(polyline: [vector_float3], colors: [vector_float3], closed: Bool = false) {
    clear()

    vertexType = vector_float3()
    indexType = UInt32()

    guard polyline.count > 1 else { return }

    // TODO(GD): important
    // MemoryLayout<vector_float3>.stride means there should be
    // vertexDescriptor.layouts[0].stride = MemoryLayout<vector_float3>.stride in the vertex descriptor!!!
    // make type fixed in the drawable ?

    nVertex = polyline.count
    vertexBuffer = device.makeBuffer(
      bytes: polyline, length: polyline.count * MemoryLayout<vector_float3>.stride, options: [])

    if colors.count == polyline.count {
      colorBuffer = device.makeBuffer(
        bytes: colors, length: colors.count * MemoryLayout<vector_float3>.stride, options: [])
    }

    nLine = polyline.count - 1
    if nLine > 0 {
      var segmentIndices: [vector_uint2] = []
      for i in stride(from: 0, through: polyline.count - 1, by: 1) {
        segmentIndices.append(vector_uint2(x: UInt32(i), y: UInt32(i + 1)))
      }
      if closed {
        nLine += 1
        segmentIndices.append(vector_uint2(x: UInt32(polyline.count - 1), y: 0))
      }
      lineBuffer = device.makeBuffer(
        bytes: segmentIndices, length: nLine * MemoryLayout<UInt32>.stride * 2, options: [])
    }
  }

  public func update(thickLine: [vector_float3], colors: [vector_float3]) {
    clear()

    vertexType = vector_float3()
    indexType = UInt32()

    guard thickLine.count > 1 else { return }

    // vertices: for every point (.) generate 4 vertices with offset for the previous and the next line segments,
    // see the diagram below:
    //   /
    // --\--|  /
    //    \ . /
    // ----\|/
    let vertices: [vector_float3] = thickLine.flatMap { p in [p, p, p, p] }
    nVertex = vertices.count
    vertexBuffer = device.makeBuffer(
      bytes: vertices, length: vertices.count * MemoryLayout<vector_float3>.stride, options: [])

    // use normals buffers for line directions..
    var lineDir: [vector_float3] = []
    for i in 0..<thickLine.count - 1 {
      lineDir.append(thickLine[i + 1] - thickLine[i])
    }
    lineDir.append(thickLine[thickLine.count - 1] - thickLine[thickLine.count - 2])
    lineDir = lineDir.flatMap { p in [p, p, p, p] }

    for i in 1..<thickLine.count - 1 {
      lineDir[i * 4 + 0] = lineDir[(i - 1) * 4 + 2]
      lineDir[i * 4 + 1] = lineDir[(i - 1) * 4 + 3]
    }

    normalBuffer = device.makeBuffer(
      bytes: lineDir, length: lineDir.count * MemoryLayout<vector_float3>.stride, options: [])

    // colors
    if colors.count == thickLine.count {
      let _colors: [vector_float3] = colors.flatMap { p in [p, p, p, p] }
      colorBuffer = device.makeBuffer(
        bytes: _colors, length: _colors.count * MemoryLayout<vector_float3>.stride, options: [])
    }

    // indices
    let indices = Array((0..<UInt32(vertices.count)))

    nTriangle = indices.count
    indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt32>.stride, options: [])
  }
  
  public func updateMesh(vertices: [vector_float3], colors: [vector_float3] = [], indices:[UInt32] = []) {
    clear()
    
    vertexType = GLKVector3()
    indexType = UInt32()
    
    guard vertices.count > 0 else { return }
    
    // The shader excpects GLK types
    var verticesGLK: [GLKVector3] = []
    for v in vertices {
      verticesGLK.append(GLKVector3Make(Float(v.x), Float(v.y), Float(v.z)))
    }
    
    nVertex = verticesGLK.count
    vertexBuffer = device.makeBuffer(
      bytes: verticesGLK, length: verticesGLK.count * MemoryLayout<GLKVector3>.stride, options: [])
    
    if colors.count == vertices.count {
      var colorsGLK: [GLKVector3] = []
      for v in colors {
        colorsGLK.append(GLKVector3Make(Float(v.x), Float(v.y), Float(v.z)))
      }
      
      colorBuffer = device.makeBuffer(
        bytes: colorsGLK, length: colorsGLK.count * MemoryLayout<GLKVector3>.stride, options: [])
    }
    
    if !indices.isEmpty && indices.count % 3 == 0 {
      nTriangle = indices.count / 3
      indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt32>.stride, options: [])
    }
    
  }
  
  public func update(cloud: [vector_float3], colors: [vector_float3]) {
    updateMesh(vertices: cloud, colors: colors)
  }
  
}
