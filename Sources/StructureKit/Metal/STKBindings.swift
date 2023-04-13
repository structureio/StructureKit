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
import CoreVideo
import GLKit

public protocol STKColorFrame {
  var sampleBuffer: CMSampleBuffer! { get }
  func glProjectionMatrix() -> GLKMatrix4
}

public protocol STKDepthFrame {
  var width: Int32 { get }
  var height: Int32 { get }
  var depthInMillimeters: UnsafeMutablePointer<Float>! { get }
  func intrinsics() -> STKIntrinsics
  func glProjectionMatrix() -> GLKMatrix4
}

/// Bridged minimal STMesh prototol from Structure SDK.
///   extension STIntrinsics : STKIntrinsics {
///   }
public protocol STKIntrinsics {
  var width: Int32 { get set }
  var height: Int32 { get set }
  var fx: Float { get set }
  var fy: Float { get set }
  var cx: Float { get set }
  var cy: Float { get set }
  var k1: Float { get set }
  var k2: Float { get set }
}

/// Bridged minimal STMesh prototol from Structure SDK.
///   extension STMesh : STKMesh {
///   }
public protocol STKMesh {
  func numberOfMeshes() -> Int32
  func number(ofMeshFaces meshIndex: Int32) -> Int32
  func number(ofMeshVertices meshIndex: Int32) -> Int32
  func number(ofMeshLines meshIndex: Int32) -> Int32
  func meshVertices(_ meshIndex: Int32) -> UnsafeMutablePointer<GLKVector3>!
  func hasPerVertexNormals() -> Bool
  func meshPerVertexNormals(_ meshIndex: Int32) -> UnsafeMutablePointer<GLKVector3>!
  func hasPerVertexColors() -> Bool
  func meshPerVertexColors(_ meshIndex: Int32) -> UnsafeMutablePointer<GLKVector3>!
  func hasPerVertexUVTextureCoords() -> Bool
  func meshPerVertexUVTextureCoords(_ meshIndex: Int32) -> UnsafeMutablePointer<GLKVector2>!
  func meshLines(_ meshIndex: Int32) -> UnsafeMutablePointer<UInt32>!
  func meshFaces(_ meshIndex: Int32) -> UnsafeMutablePointer<UInt32>!
  func meshYCbCrTexture() -> Unmanaged<CVPixelBuffer>!
}
