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

#include "STKMetalData.h"

#include <metal_stdlib>

using namespace metal;

struct VertexOut
{
  float4 position [[position]];
  float2 texCoords;
  float4 color;
};

constant float2 quadVertices[4] = {
  float2(-1.0, -1.0),
  float2(1.0, -1.0),
  float2(-1.0, 1.0),
  float2(1.0, 1.0)
};

constant float2 quadTexCoords[4] = {
  float2(0.0, 1.0),
  float2(1.0, 1.0),
  float2(0.0, 0.0),
  float2(1.0, 0.0)
};

vertex VertexOut vertexColorPoints(
    const device vector_float3* positions [[buffer(STKVertexAttrPosition)]],
    const device vector_float3* colors [[buffer(STKVertexAttrAddition)]],
    const device STKUniformsMeshPoints& uniforms [[buffer(STKVertexBufferIndexUniforms)]],
    unsigned int vertex_id [[vertex_id]],
    unsigned int instance_id [[instance_id]])
{
  VertexOut out;
  
  float3 current_position = positions[instance_id];
  float3 current_color = colors[instance_id];
  
  float aspectRatio = uniforms.projectionMatrix[1][1] / uniforms.projectionMatrix[0][0];
  float4 posCenter = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(current_position, 1.0);
  
  float2 vertexOffset = quadVertices[vertex_id] * uniforms.pointSize;
  vertexOffset.y *= aspectRatio;

  out.position.xy = posCenter.xy + vertexOffset;
  out.position.z = posCenter.z;
  out.position.w = posCenter.w;
  
  out.texCoords = quadTexCoords[vertex_id];
  out.color = float4(current_color * 255, 1.0);

  return out;
}


fragment float4 fragmentColorPoints(
    VertexOut in [[stage_in]],
    texture2d<float> textureColor [[texture(0)]],
    sampler textureSampler [[sampler(0)]])
{
  float4 textureColorSample = textureColor.sample(textureSampler, in.texCoords);
  return in.color * textureColorSample;
}
