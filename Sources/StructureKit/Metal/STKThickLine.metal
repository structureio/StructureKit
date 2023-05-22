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

#include "STKMetalCommon.h"
#include "STKMetalData.h"

#include <metal_stdlib>
using namespace metal;

struct VertexOut
{
  float4 position [[position]];
  float4 color;
};


vertex VertexOut vertexThickLine(constant float3* vertices                   [[buffer(0)]],
                                 constant float3* color                      [[buffer(STKVertexAttrAddition)]],
                                 const device STKUniformsThickLine& uniforms [[buffer(STKVertexBufferIndexUniforms)]],
                                 constant float3* dirLine                    [[buffer(3)]],
                                 uint v_id [[vertex_id]])
{
  float sign = v_id % 2 ? -1 : 1; // should point be up or down in line
  
  VertexOut vert;
  vert.color = float4(color[v_id], 1); //pass the color data to fragment shader
  vert.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(vertices[v_id], 1); //position of the point
  
  float3 pointCurrent = vertices[v_id];
  float3 pointNext = pointCurrent + normalize(dirLine[v_id]);
  
  //calculate MVP transform for both points
  float4 currentProjection = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(pointCurrent, 1.0);
  float4 nextProjection = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(pointNext, 1.0);

  float2 aspect = float2(uniforms.projectionMatrix[1][1] / uniforms.projectionMatrix[0][0], 1); //aspect ratio

  //get 2d position in screen space
  float2 currentScreen = currentProjection.xy / currentProjection.w * aspect;
  float2 nextScreen = nextProjection.xy / nextProjection.w * aspect;

  float2 dirScreen = normalize(nextScreen - currentScreen); // line direction in screen space
  float2 normal = float2(-dirScreen.y, dirScreen.x);   // vector of direction of thickness
  normal /= aspect;
  
  //get thickness in pixels in screen space
  float thickness = uniforms.width / 500;
  
  //move current point up or down, by thickness, with the same distance independent on depth
  vert.position += float4(sign*normal*thickness*vert.position.w, 0, 0 );
  
  return vert;
}

fragment float4 fragmentThickLine(VertexOut in [[stage_in]])
{
  return in.color;
}
