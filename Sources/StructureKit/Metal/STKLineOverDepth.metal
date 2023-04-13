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

struct VertexIn
{
    packed_float3 position;
    packed_float3 color;
};

struct VertexOut
{
    float4 position [[position]];
    float4 cameraPosition;
    float4 color;
};

vertex VertexOut vertexLineOverDepth(
    const device VertexIn* vertex_array [[buffer(0)]],
    const device STKUniformsCube& uniforms [[buffer(1)]],
    unsigned int vid [[vertex_id]])
{
    VertexIn in = vertex_array[vid];
    VertexOut out;

    out.position = uniforms.projection * uniforms.view * uniforms.model * float4(in.position, 1.0);
    if (uniforms.useOcclusion)
        out.cameraPosition = uniforms.view * uniforms.model * float4(in.position, 1.0);
    out.color = float4(in.color, 1);
    return out;
}

fragment float4 fragmentLineOverDepth(
    VertexOut in [[stage_in]],
    const device STKUniformsCube& uniforms [[buffer(0)]],
    texture2d<float> texDepth [[texture(0)]],
    sampler sampler2D [[sampler(0)]])
{
    if (uniforms.useOcclusion)
    {
        // project cube point to depth image
        const float4 point = in.cameraPosition; // screen
        const float2 proj(
            uniforms.cameraIntrinsics.cx + (point.x * uniforms.cameraIntrinsics.fx) / point.z,
            uniforms.cameraIntrinsics.cy + (point.y * uniforms.cameraIntrinsics.fy) / point.z);

        // const float depth = texDepth.read(uint2(texDepth.get_width() - proj.x, texDepth.get_height() - proj.y)).r;
        const float depth = texDepth.read(uint2(proj.x, proj.y)).r;
        if (in.cameraPosition.z * 1000 > depth)
            return float4(0);
    }
    return in.color;
}
