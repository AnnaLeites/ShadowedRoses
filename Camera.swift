

import Foundation

class Camera: Node {
  
  var fovDegrees: Float = 50
  var fovRadians: Float {
    return radians(fromDegrees: fovDegrees)
  }
  var aspect: Float = 1
    //самый близкий видимый объект
  var near: Float = 0.01
    //самый далёкий видимый объект
  var far: Float = 100
  
    //матрица перспективной проекции (объекты, которые ближе к камере кажутся больше)
  var projectionMatrix: float4x4 {
    return float4x4(projectionFov: fovRadians,
                    near: near,
                    far: far,
                    aspect: aspect)
  }
  
    //матрица вида
  var viewMatrix: float4x4 {
    let translateMatrix = float4x4(translation: position).inverse
    let rotateMatrix = float4x4(rotation: rotation)
    let scaleMatrix = float4x4(scaling: scale)
    return translateMatrix * scaleMatrix * rotateMatrix
  }
}
