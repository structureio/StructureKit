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

vertex STKVertexTexOut vertexDepthBandOverlay(
    const device STKVertexTex* vertex_array [[buffer(0)]],
    const device STKUniformsDepthOverlay& uniforms [[buffer(1)]],
    unsigned int vid [[vertex_id]])
{
    const STKVertexTex VertexIn = vertex_array[vid];
    const float4 texTrans = uniforms.projection * float4(VertexIn.texCoord, 0, 1);

    STKVertexTexOut VertexOut;
    VertexOut.position = float4(VertexIn.position, 1);
    VertexOut.texCoord = float2(texTrans.x, texTrans.y);
    return VertexOut;
}

fragment float4 fragmentDepthBandOverlay(
    STKVertexTexOut interpolated [[stage_in]],
    const device STKUniformsDepthBandOverlay& uniforms [[buffer(0)]],
    texture2d<float> texDepth [[texture(0)]],
    sampler sampler2D [[sampler(0)]])
{
    // depth udefined
    const float depth = texDepth.sample(sampler2D, interpolated.texCoord).r;
    if (isnan(depth))
        return float4(0);

    // calculate position of the depth pixel in the world CS using intrinsics
    const auto intrinsics = uniforms.cameraIntrinsics;
    const float u = interpolated.texCoord.x * intrinsics.width;
    const float v = interpolated.texCoord.y * intrinsics.height;
    const float depthM = depth / 1000;
    const float4 cameraPoint(
        depthM * (u - intrinsics.cx) / intrinsics.fx,
        depthM * (v - intrinsics.cy) / intrinsics.fy,
        depthM,
        1);
    const float4 worldPoint = uniforms.cameraPose * cameraPoint;
    const float4 cubePoint = uniforms.cubeModelInv * worldPoint;

    // outside the box
    if (cubePoint.x < 0 || cubePoint.x > 1 || cubePoint.y < 0 || cubePoint.y > 1 || cubePoint.z < 0 || cubePoint.z > 1)
        return float4(0);

    // Use validRangeColor in ideal range, outOfRangeColor elsewhere.
    float inAtMin  = smoothstep(uniforms.validRangeMinMM - uniforms.feather, uniforms.validRangeMinMM + uniforms.feather, depth);
    float inAtMax  = 1.0 - smoothstep(uniforms.validRangeMaxMM - uniforms.feather, uniforms.validRangeMaxMM + uniforms.feather, depth);
    float t        = clamp(inAtMin * inAtMax, 0.0, 1.0);

    float4 color   = mix(uniforms.outOfRangeColor, uniforms.validRangeColor, t);
    color.a        = uniforms.alpha;
    return color;
}
