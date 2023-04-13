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

using VertexOut = STKVertexTexOut;
vertex VertexOut vertexTex(
    const device STKVertexTex* vertex_array [[buffer(0)]],
    const device STKUniformsColorTexture& uniforms [[buffer(1)]],
    unsigned int vid [[vertex_id]])
{
    const STKVertexTex vertexIn = vertex_array[vid];
    const float4x4 orientation = uniforms.projection;

    VertexOut VertexOut;
    VertexOut.position = float4(vertexIn.position, 1);
    float4 texTrans = orientation * float4(vertexIn.texCoord, 0, 1);
    VertexOut.texCoord = float2(texTrans.x, texTrans.y);
    return VertexOut;
}

fragment float4 fragmentTex(
    VertexOut interpolated [[stage_in]],
    texture2d<float> tex2dY [[texture(0)]],
    texture2d<float> tex2dCbCr [[texture(1)]],
    sampler sampler2D [[sampler(0)]])
{
    const float x = tex2dY.sample(sampler2D, interpolated.texCoord).r;
    const float2 yz = tex2dCbCr.sample(sampler2D, interpolated.texCoord).rg - float2(0.5, 0.5);
    return calcYCbCrColor(x, yz);
}
