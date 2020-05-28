

import MetalKit

class Node {
    //имя модеои
  var name: String = "untitled"
    //координаты положения модели
  var position: float3 = [0, 0, 0]
    //угол поворота модели
  var rotation: float3 = [0, 0, 0]
    //масштаб модели
  var scale: float3 = [1, 1, 1]

  var modelMatrix: float4x4 {
    //вызываем преобразования
    let translateMatrix = float4x4(translation: position)
    let rotateMatrix = float4x4(rotation: rotation)
    let scaleMatrix = float4x4(scaling: scale)
    //возвращаем произведение матриц сдвига, поворота и масштабирования
    return translateMatrix * rotateMatrix * scaleMatrix
  }
}
