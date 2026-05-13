import Foundation
import Metal
import simd

/// Identification for shaders in the STKScene
public enum STKShaderID: Equatable {
  case solid
  case wireframe
  case vertexColor
  case texture
  case pointCloud
  case lines
  case thickLine
  case custom(STKShader)

  public static func == (lhs: STKShaderID, rhs: STKShaderID) -> Bool {
    switch (lhs, rhs) {
    case (.solid, .solid),
      (.wireframe, .wireframe),
      (.vertexColor, .vertexColor),
      (.texture, .texture),
      (.pointCloud, .pointCloud),
      (.lines, .lines),
      (.thickLine, .thickLine):
      return true
    case (.custom(let l), .custom(let r)):
      return l === r
    default:
      return false
    }
  }

  /// Retrieve the shader (non-optional)
  public func getShader() -> STKShader {
    switch self {
    case .solid: return STKShaderManager.solid
    case .wireframe: return STKShaderManager.wireframe
    case .vertexColor: return STKShaderManager.vertexColor
    case .texture: return STKShaderManager.textureShader
    case .pointCloud: return STKShaderManager.pointCloud
    case .lines: return STKShaderManager.lines
    case .thickLine: return STKShaderManager.thickLine
    case .custom(let shader): return shader
    }
  }
}

public struct STKShaderProperties {
  /// Flat tint color for untextured meshes
  public var baseColor: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1)
  
  /// Size for point primitives and line width.
  public var pointSize: Float = 5.0

  /// Cull backfaces during rendering.
  public var hideBackFaces: Bool = true

  /// Render wireframe with x-ray effect.
  public var useXray: Bool = true

  public init(baseColor: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1), pointSize: Float = 5.0, hideBackFaces: Bool = true, useXray: Bool = true) {
    self.baseColor = baseColor
    self.pointSize = pointSize
    self.hideBackFaces = hideBackFaces
    self.useXray = useXray
  }
}

public struct STKMaterial {
  // MARK: - Pipeline State
  public var shaderID: STKShaderID
  public var properties: STKShaderProperties

  public init(shaderID: STKShaderID, properties: STKShaderProperties = STKShaderProperties()) {
    self.shaderID = shaderID
    self.properties = properties
  }
}

public class STKSceneNode: Identifiable {
  public let id: String
  public var name: String
  public var isVisible: Bool = true
  
  // Spatial data
  public var localTransform: float4x4 = float4x4.identity
  
  // Renderable data (Composition)
  public var buffer: STKMeshBuffers
  public var material: STKMaterial
  
  public init(name: String, device: MTLDevice, id: String? = nil) {
    self.name = name
    self.id = id ?? UUID().uuidString
    self.buffer = STKMeshBuffers(device)
    self.material = STKMaterial(shaderID: .wireframe)
  }

  public convenience init(name: String, device: MTLDevice, id: String? = nil, buffer: STKMeshBuffers? = nil, material: STKMaterial? = nil) {
    self.init(name: name, device: device, id: id)
    if let buffer = buffer { self.buffer = buffer }
    if let material = material { self.material = material }
  }

  public weak var parent: STKSceneNode?
  private(set) public var children: [STKSceneNode] = []
  
  public func addChild(_ node: STKSceneNode) {
    node.parent = self
    children.append(node)
  }


  public func removeChild(_ node: STKSceneNode) {
    if let index = children.firstIndex(where: { $0 === node }) {
      node.parent = nil
      children.remove(at: index)
    }
  }

  public func removeAllChildren() {
    for child in children {
      child.parent = nil
    }
    children.removeAll()
  }

  public func findNode(named name: String) -> STKSceneNode? {
    if self.name == name { return self }
    for child in children {
      if let found = child.findNode(named: name) { return found }
    }
    return nil
  }

  public func findNode(id: String) -> STKSceneNode? {
    if self.id == id { return self }
    for child in children {
      if let found = child.findNode(id: id) { return found }
    }
    return nil
  }
}

public class STKScene {
  public let rootNode: STKSceneNode
  private var allNodes: [String: STKSceneNode] = [:]
  
  public init(device: MTLDevice) {
    let root = STKSceneNode(name: "Root", device: device, id: "Root")
    self.rootNode = root
    allNodes[root.id] = root
  }

  @discardableResult
  public func addNode(_ node: STKSceneNode, to parent: STKSceneNode? = nil) -> Bool {
    if allNodes[node.id] != nil {
      print("Error: Node with ID \(node.id) already exists in scene.")
      return false
    }
    
    // Register node and its children recursively
    return registerRecursive(node, to: parent ?? rootNode)
  }
  
  private func registerRecursive(_ node: STKSceneNode, to parent: STKSceneNode) -> Bool {
    if allNodes[node.id] != nil { return false }
    
    allNodes[node.id] = node
    parent.addChild(node)
    
    for child in node.children {
       _ = registerRecursive(child, to: node)
    }
    return true
  }

  public func removeNode(_ node: STKSceneNode) {
    unregisterRecursive(node)
    node.parent?.removeChild(node)
  }

  private func unregisterRecursive(_ node: STKSceneNode) {
    allNodes.removeValue(forKey: node.id)
    for child in node.children {
      unregisterRecursive(child)
    }
  }

  public func findNode(id: String) -> STKSceneNode? {
    return allNodes[id]
  }
  
  public func findNode(named name: String) -> STKSceneNode? {
    return rootNode.findNode(named: name)
  }
}
