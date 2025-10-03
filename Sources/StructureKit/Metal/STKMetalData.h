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

#pragma once

#import <simd/simd.h>

#ifdef __METAL_VERSION__
    #define ST_IS_METAL 1
    #define ST_IF_METAL(x) x
#else
    #define ST_IS_METAL 0
    #define ST_IF_METAL(x)
    #include <stdbool.h>
#endif

struct STKIntrinsicsMetal
{
    float cx;
    float cy;
    float fx;
    float fy;
    uint32_t width;
    uint32_t height;
};

struct STKUniformsColorTexture
{
    matrix_float4x4 projection;
};

struct STKUniformsDepthTexture
{
    matrix_float4x4 projection;
    float depthMin;
    float depthMax;
    float alpha;
};

struct STKUniformsDepthOverlay
{
    matrix_float4x4 projection;
    matrix_float4x4 cameraPose;
    struct STKIntrinsicsMetal cameraIntrinsics;
    matrix_float4x4 cubeModelInv;
    float depthMin;
    float depthMax;
    float alpha;
};

struct STKUniformsDepthBandOverlay
{
    matrix_float4x4 projection;
    matrix_float4x4 cameraPose;
    struct STKIntrinsicsMetal cameraIntrinsics;
    matrix_float4x4 cubeModelInv;
    float alpha;
    float validRangeMinMM;
    float validRangeMaxMM;
    vector_float4 validRangeColor;
    vector_float4 outOfRangeColor;
    float feather;
};

struct STKUniformsLine
{
    matrix_float4x4 model;
    matrix_float4x4 view;
    matrix_float4x4 projection;
};

struct STKUniformsCube
{
    matrix_float4x4 model;
    matrix_float4x4 view;
    matrix_float4x4 projection;
    struct STKIntrinsicsMetal cameraIntrinsics;
    bool useOcclusion;
};

struct STKUniformsMesh
{
    matrix_float4x4 modelViewMatrix;
    matrix_float4x4 projectionMatrix;
    vector_float4 color;
};

struct STKUniformsMeshPoints
{
  matrix_float4x4 modelViewMatrix;
  matrix_float4x4 projectionMatrix;
  float pointSize;
};

struct STKUniformsMeshWireframe
{
    matrix_float4x4 modelViewMatrix;
    matrix_float4x4 projectionMatrix;
    vector_float4 color;
    bool useXray;
};

struct STKUniformsThickLine {
  matrix_float4x4 modelViewMatrix;
  matrix_float4x4 projectionMatrix;
  vector_float4 color;
  float width;
};

struct STKVertexTex
{
    vector_float3 position;
    vector_float2 texCoord;
};

// The following enums are added to keep in order indexes of the buffers for mesh rendering shaders.
enum STKVertexAttr
{
    STKVertexAttrPosition = 0,
    STKVertexAttrAddition = 1
};

// STKVertexBufferIndex is an addition to STKVertexAttr, so it starts from 2
enum STKVertexBufferIndex
{
    STKVertexBufferIndexUniforms = 2
};

struct STKVertexNormal
{
    vector_float3 position ST_IF_METAL([[attribute(STKVertexAttrPosition)]]);
    vector_float3 normal ST_IF_METAL([[attribute(STKVertexAttrAddition)]]);
};

struct STKVertexColor
{
    vector_float3 position ST_IF_METAL([[attribute(STKVertexAttrPosition)]]);
    vector_float3 color ST_IF_METAL([[attribute(STKVertexAttrAddition)]]);
};

struct STKVertexTexModel
{
    vector_float3 position ST_IF_METAL([[attribute(STKVertexAttrPosition)]]);
    vector_float2 texCoord ST_IF_METAL([[attribute(STKVertexAttrAddition)]]);
};

#if ST_IS_METAL

struct STKVertexTexOut
{
    float4 position [[position]];
    float2 texCoord;
};

#endif
