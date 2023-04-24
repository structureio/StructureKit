# StructureKit

A collection of helper tools for [Structure SDK](https://structure.io/developers)

## Installation
You can consume it as a Swift Package:
[Adding package dependencies to your app](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)

## Usage
Import into your Swift source code:
```swift
import StructureKit
```

### Integration with Structure SDK
StructureKit based on Structure SDK - compatible interfaces.

Current version is compatible with Structure SDK `2.*`

To seamlessly use Structure SDK types together with StructureKit, add the following code in your project:

```swift
import StructureKit

extension STMesh : STKMesh {
}

extension STColorFrame : STKColorFrame {
}

extension STIntrinsics : STKIntrinsics {
}

extension STDepthFrame : STKDepthFrame {
  public func intrinsics() -> STKIntrinsics {
    let i : STIntrinsics = self.intrinsics()
    return i;
  }
}
```
