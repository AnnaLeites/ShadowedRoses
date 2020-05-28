

import MetalKit

extension Renderer {
    //увеличение
  func zoomUsing(delta: CGFloat, sensitivity: Float) {
    //перемещение камеры вдоль оси z 
    camera.position.z += Float(delta) * sensitivity
  }
  
  func rotateUsing(translation: float2) {
    let sensitivity: Float = 0.01
    camera.rotation.x += Float(translation.y) * sensitivity
    camera.rotation.y -= Float(translation.x) * sensitivity
  }
  
  func random(range: CountableClosedRange<Int>) -> Int {
    var offset = 0
    if range.lowerBound < 0 {
      offset = abs(range.lowerBound)
    }
    let min = UInt32(range.lowerBound + offset)
    let max = UInt32(range.upperBound + offset)
    return Int(min + arc4random_uniform(max-min)) - offset
  }
  
    
    //создаём точечные источники света
  func createPointLights(count: Int, min: float3, max: float3) {
    //массив цветов для источника точечного освещения
    let colors: [float3] = [
      //красный
      float3(1, 0, 0),
      //жёлтый
      float3(1, 1, 0),
      //белый
      float3(1, 1, 1),
      //зелёный
      float3(0, 1, 0),
      //голубой
      float3(0, 1, 1),
      //синий
      float3(0, 0, 1),
      //розовый
      float3(1, 0, 1) ]
    //увеличиваем координаты в 100 раз для дальнейших вычислений
    let newMin: float3 = [min.x*100, min.y*100, min.z*100]
    let newMax: float3 = [max.x*100, max.y*100, max.z*100]
    //создаём заданное число точечных источников
    for _ in 0..<count {
      var light = buildDefaultLight()
      light.type = Pointlight
        //позиция задаётся случайным образом в диапазоне
      let x = Float(random(range: Int(newMin.x)...Int(newMax.x))) * 0.01
      let y = Float(random(range: Int(newMin.y)...Int(newMax.y))) * 0.01
      let z = Float(random(range: Int(newMin.z)...Int(newMax.z))) * 0.01
      light.position = [x, y, z]
        //цвет задаётся случайным образом из вышеперечисленного массива цветов
      light.color = colors[random(range: 0...colors.count)]
      light.intensity = 0.6
      light.attenuation = float3(1.5, 1, 1)
      lights.append(light)
    }
  }  
}
