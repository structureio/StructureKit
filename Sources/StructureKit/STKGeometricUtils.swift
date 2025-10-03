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

import simd

public func generateSphereMesh(center:vector_float3, radius: Float, uResolution: Int = 32, vResolution: Int = 32) -> (vertices: [simd_float3], indices: [UInt32]) {
  var vertices: [simd_float3] = []
  var indices: [UInt32] = []
  
  // Ensure minimum resolution
  let uSegments = max(3, uResolution)
  let vSegments = max(3, vResolution)
  
  let uStep = 2.0 * .pi / Float(uSegments)
  let vStep = .pi / Float(vSegments)
  
  // Generate vertices for the sphere
  for v in 0...vSegments {
    let vAngle = Float(v) * vStep
    let y = radius * cos(vAngle)
    let zRadius = radius * sin(vAngle) // Radius of the current latitude circle
    
    for u in 0...uSegments {
      let uAngle = Float(u) * uStep
      let x = zRadius * cos(uAngle)
      let z = zRadius * sin(uAngle)
      
      vertices.append(center + vector_float3(x, y, z))
    }
  }
  
  // Generate indices for the triangles
  // This is done by creating two triangles for each quad segment of the sphere.
  let uVertices = uSegments + 1
  for v in 0..<vSegments {
    for u in 0..<uSegments {
      let p0 = u + v * uVertices
      let p1 = u + (v + 1) * uVertices
      let p2 = (u + 1) + v * uVertices
      let p3 = (u + 1) + (v + 1) * uVertices
      
      // Add the two triangles that form the quad
      if v != 0 { // Skip top pole triangles
        indices.append(UInt32(p0))
        indices.append(UInt32(p1))
        indices.append(UInt32(p2))
      }
      
      if v != vSegments - 1 { // Skip bottom pole triangles
        indices.append(UInt32(p1))
        indices.append(UInt32(p3))
        indices.append(UInt32(p2))
      }
    }
  }
  
  return (vertices, indices)
}
