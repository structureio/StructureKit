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

#include <metal_stdlib>

using namespace metal;

float4 calcDepthColor(float depth, float2 range, texture2d<float> colors)
{
    const float minDepth = range.x;
    const float maxDepth = range.y;
    const float normalized = clamp((depth - minDepth) / (maxDepth - minDepth), 0.f, 0.999f); // [0, 1)

    const uint colorCoord = colors.get_width() * normalized;
    const uint colorCoordNext = colorCoord < (colors.get_width() - 1) ? colorCoord + 1 : colorCoord;
    const float fraction = float(colors.get_width()) * normalized - colorCoord;

    const float4 color1 = colors.read(uint2(colorCoord, 0));
    const float4 color2 = colors.read(uint2(colorCoordNext, 0));
    float4 finalColor = color1 * (1 - fraction) + color2 * fraction;
    return finalColor;
}

float4 calcYCbCrColor(float y, float2 cbcr)
{
    const float3x3 yuv2rgb(1, 1, 1, 0, -.18732, 1.8556, 1.57481, -.46813, 0);
    const float3 rgb = yuv2rgb * float3(y, cbcr);
    return float4(rgb, 1.0);
}
