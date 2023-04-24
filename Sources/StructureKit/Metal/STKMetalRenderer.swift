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
import Accelerate
import CoreVideo
import MetalKit

public enum STKMeshRenderingStyle {
  case solid
  case wireframe
}

// MARK: Metal rendering API
protocol STKRenderer: AnyObject {
  // MARK: update functions
  /** A depth frame for visualization
  @param depthFrame The depth frame.
  */
  func setDepthFrame(_ depthFrame: STKDepthFrame)

  /** A color frame for visualization
  @param colorFrame The color frame.
  */
  func setColorFrame(_ colorFrame: STKColorFrame)

  /** A mesh for visualization of current scanning progress
  @param mesh The mesh.
  */
  func setScanningMesh(_ mesh: STKMesh)

  /** An ARKit face mesh for visualization
  @param mesh The mesh.
  */
  func setARKitMesh(_ mesh: ARFaceGeometry)

  /** Transformation matrices describing coordinate systems for visualization
  @param anchors Set of transformation matrices.
  */
  func setARKitAnchors(_ anchors: [simd_float4x4])

  /** Specify the cube size.
  @param sizeInMeters The current volume size in meters.
  */
  func adjustCubeSize(_ sizeInMeters: simd_float3)

  /**
  Set custom colors used for depth rendering.
  @param baseColors Array of base colors for gradient.
     Colors are specified in RGB space using float values in range [0, 1]. Outlier will be clamped to that range.
     These colors will be spaced evenly and the final color will be lineary interpolated between nearest neighbours.
  */
  func setDepthRenderingColors(_ baseColors: [simd_float4])

  // MARK: rendering functions
  /**
  Initialized metal rendering pipeline. Must be called before other rendering functions.
  */
  func startRendering()

  /** Highlight the depth frame area which fits inside the cube.
  @param cameraPose the viewpoint to use for rendering.
  @param alpha transparency factor between 0 (fully transparent) and 1 (fully opaque).
  @param textureOrientation orientation of the depth texture relatively to the metal view.
  */
  func renderHighlightedDepth(cameraPose: simd_float4x4, alpha: Float, textureOrientation: simd_float4x4)

  /**
  Render the cube wireframe outline at the given pose.
  @param cameraPose the viewpoint to use for rendering.
  @param occlusionTestEnabled whether to use the current depth frame to do occlusion testing. You can turn this off for
  better performance.
  @param orientation orientation of the cube relatively to the metal view.
  @param drawTriad whether to draw the origin of the coordinate system.
  */
  func renderCubeOutline(cameraPose: simd_float4x4, occlusionTest: Bool, orientation: simd_float4x4, drawTriad: Bool)

  /**
  Render the color frame in the view.
  @param orientation orientation of the color texture relatively to the metal view.
  */
  func renderColorFrame(orientation textureOrientation: simd_float4x4)

  /**
  Render the depth frame in the view.
  @param orientation orientation of the depth texture relatively to the metal view.
  @param range minimum and maximum depth in mm for colorization.
  */
  func renderDepthFrame(orientation textureOrientation: simd_float4x4, range: simd_float2)

  /**
  Render the current mesh in the view.
  @param cameraPose the viewpoint to use for rendering.
  @param meshOrientation orientation of the mesh relatively to the metal view.
  */
  func renderScanningMesh(
    cameraPose: simd_float4x4, meshOrientation: simd_float4x4, color: vector_float4, style: STKMeshRenderingStyle)

  /**
  Render the ARKit face mesh in the view.
  @param cameraPose the viewpoint to use for rendering.
  @param orientation orientation of the mesh relatively to the metal view.
  */
  func renderARKitMesh(cameraPose: simd_float4x4, orientation: simd_float4x4)

  /**
  Render the triads in the view.
  @param cameraPose the viewpoint to use for rendering.
  @param orientation orientation of the triads relatively to the metal view.
  */
  func renderARKitAnchors(cameraPose: simd_float4x4, orientation: simd_float4x4)

  /**
  Finalizes the rendering pipeline and presents the resulting texture in the metal view.
  */
  func presentDrawable()

  /**
  Access to the Command Encoder of the current pipeline. Available between calls to startRendering() and presentDrawable()
  */
  var commandEncoder: MTLRenderCommandEncoder? { get }
}

// Implementation of STKRenderer protocol. Calculates viewport and projection matrix and stores the metal buffers to render meshes.
// Starts and finalizes the rendering pipeline.
public class STKMetalRenderer: NSObject, STKRenderer {
  // data to visualize
  private var _scanMesh: STKMeshBuffers
  private var _arkitMesh: STKMeshBuffers
  private var _anchors: [simd_float4x4] = []
  private var _volumeSize = simd_float3(1, 1, 1)
  private var colorCameraGLProjectionMatrix = float4x4.identity
  private var depthCameraGLProjectionMatrix = float4x4.identity

  // metal general
  private var _mtkView: MTKView
  private var _device: MTLDevice
  private var _commandQueue: MTLCommandQueue

  // specific renderers
  private var _colorFrameRenderer: STKColorFrameRenderer
  private var _arkitRenderer: STKARKitOverlayRenderer
  private var _anchorRenderer: STKLineRenderer
  private var _depthOverlayRenderer: STKDepthRenderer
  private var _meshRenderer: STKScanMeshRenderer

  // rendering state
  private var _commandEncoder: MTLRenderCommandEncoder?
  private var _commandBuffer: MTLCommandBuffer?
  private var _currentDrawable: CAMetalDrawable?

  // projection
  private var projection: float4x4 { colorCameraGLProjectionMatrix }
  private var frameRatio: Float {
    abs(colorCameraGLProjectionMatrix.columns.0[0] / colorCameraGLProjectionMatrix.columns.1[1])
  }
  private var viewport: MTLViewport {
    let z = (near: 0.0, far: 1.0)
    let frame = _mtkView.bounds.size
    let sc: CGFloat = UIScreen.main.scale
    let screen = simd_float2(x: Float(frame.width * sc), y: Float(frame.height * sc))

    let isPortraitOrientation = frame.height > frame.width
    if isPortraitOrientation {
      let width = screen.y * frameRatio
      let overflow = Double(width) - Double(screen.x)
      let viewport = MTLViewport.init(
        originX: -overflow / 2, originY: 0, width: Double(width), height: Double(screen.y), znear: z.near, zfar: z.far)
      return viewport
    } else {
      let height = screen.x * frameRatio
      let overflow = Double(height) - Double(screen.y)
      let viewport = MTLViewport.init(
        originX: 0, originY: -overflow / 2, width: Double(screen.x), height: Double(height), znear: z.near, zfar: z.far)
      return viewport
    }
  }

  var commandEncoder: MTLRenderCommandEncoder? { _commandEncoder }

  public init(view: MTKView, device: MTLDevice, mesh: STKMesh) {
    _mtkView = view
    _device = device
    _commandQueue = device.makeCommandQueue()!

    _colorFrameRenderer = STKColorFrameRenderer(view: view, device: device)
    _arkitRenderer = STKARKitOverlayRenderer(view: view, device: device)
    _anchorRenderer = STKLineRenderer(view: view, device: device)
    _depthOverlayRenderer = STKDepthRenderer(view: view, device: device)
    _meshRenderer = STKScanMeshRenderer(view: view, device: device)

    _scanMesh = STKMeshBuffers(_device)
    _scanMesh.mesh = mesh
    _arkitMesh = STKMeshBuffers(_device)
    super.init()
  }

  public func setDepthFrame(_ depthFrame: STKDepthFrame) {
    _depthOverlayRenderer.uploadColorTextureFromDepth(depthFrame)
    depthCameraGLProjectionMatrix = float4x4(depthFrame.glProjectionMatrix())
  }

  public func setColorFrame(_ colorFrame: STKColorFrame) {
    _colorFrameRenderer.uploadColorTexture(colorFrame)
    colorCameraGLProjectionMatrix = float4x4(colorFrame.glProjectionMatrix())
  }

  public func setScanningMesh(_ mesh: STKMesh) { _scanMesh.updateMesh(mesh) }

  public func setARKitMesh(_ mesh: ARFaceGeometry) { _arkitMesh.updateMesh(arkitFace: mesh) }

  public func setARKitAnchors(_ anchors: [simd_float4x4]) { _anchors = anchors }

  public func adjustCubeSize(_ sizeInMeters: simd_float3) { _volumeSize = sizeInMeters }

  public func setARKitTransformation(_ transformation: simd_float4x4) { _arkitRenderer.arkitToWorld = transformation }

  public func setDepthRenderingColors(_ baseColors: [simd_float4]) {
    _depthOverlayRenderer.depthRenderingColors = baseColors
  }

  public func startRendering() {
    guard let commandBuffer = _commandQueue.makeCommandBuffer(),
      let currentRenderPassDescriptor = _mtkView.currentRenderPassDescriptor,
      let currentDrawable = _mtkView.currentDrawable,
      let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
    else {
      return
    }
    _commandBuffer = commandBuffer
    _currentDrawable = currentDrawable
    _commandEncoder = commandEncoder

    commandEncoder.setViewport(viewport)
  }

  public func presentDrawable() {
    guard let commandBuffer = _commandBuffer,
      let currentDrawable = _currentDrawable,
      let commandEncoder = _commandEncoder
    else {
      return
    }

    commandEncoder.endEncoding()
    commandBuffer.present(currentDrawable)
    commandBuffer.commit()

    _commandBuffer = nil
    _commandBuffer = nil
    _commandEncoder = nil
  }

  public func renderColorFrame(orientation textureOrientation: simd_float4x4) {
    guard let commandEncoder = _commandEncoder else { return }
    _colorFrameRenderer.renderCameraImage(commandEncoder, orientation: textureOrientation)
  }

  public func renderCubeOutline(
    cameraPose: simd_float4x4, occlusionTest: Bool, orientation: simd_float4x4, drawTriad: Bool
  ) {
    guard let commandEncoder = _commandEncoder else { return }
    _depthOverlayRenderer.renderCubeOutline(
      commandEncoder,
      volumeSizeInMeters: _volumeSize,
      cameraPosition: cameraPose,
      projection: projection,
      orientation: orientation,
      useOcclusion: occlusionTest
    )

    if drawTriad {
      _anchorRenderer.renderAnchors(
        commandEncoder,
        anchors: [simd_float4x4.identity],
        cameraPosition: cameraPose,
        projection: projection,
        orientation: orientation,
        triadSize: _volumeSize.x)
    }
  }

  public func renderHighlightedDepth(cameraPose: simd_float4x4, alpha: Float, textureOrientation: simd_float4x4) {
    guard let commandEncoder = _commandEncoder else { return }
    _depthOverlayRenderer.renderDepthOverlay(
      commandEncoder,
      volumeSizeInMeters: _volumeSize,
      cameraPosition: cameraPose,
      textureOrientation: textureOrientation,
      alpha: alpha)
  }

  public func renderDepthFrame(orientation textureOrientation: simd_float4x4, range: simd_float2) {
    guard let commandEncoder = _commandEncoder else { return }
    _depthOverlayRenderer.renderDepthFrame(
      commandEncoder, orientation: textureOrientation, minDepth: range.x, maxDepth: range.y, alpha: 0.5)
  }

  public func renderScanningMesh(
    cameraPose: simd_float4x4, meshOrientation: simd_float4x4, color: vector_float4, style: STKMeshRenderingStyle
  ) {
    guard let commandEncoder = _commandEncoder else { return }
    _meshRenderer.render(
      commandEncoder,
      node: _scanMesh,
      cameraPosition: cameraPose,
      projection: projection,
      orientation: meshOrientation,
      color: color,
      style: style)
  }

  public func renderARKitMesh(cameraPose: simd_float4x4, orientation: simd_float4x4) {
    guard let commandEncoder = _commandEncoder else { return }
    _arkitRenderer.renderARkitGeom(
      commandEncoder,
      mesh: _arkitMesh,
      cameraPosition: cameraPose,
      projection: projection,
      orientation: orientation)
  }

  public func renderARKitAnchors(cameraPose: simd_float4x4, orientation: simd_float4x4) {
    guard let commandEncoder = _commandEncoder else { return }
    _anchorRenderer.renderAnchors(
      commandEncoder,
      anchors: _anchors,
      cameraPosition: cameraPose,
      projection: projection,
      orientation: orientation)
  }

}
