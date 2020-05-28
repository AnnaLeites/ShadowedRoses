
import MetalKit

class Renderer: NSObject {
  
  //связь с графическим процессором
  static var device: MTLDevice!
  // командная очередь
  static var commandQueue: MTLCommandQueue!
    
  static var colorPixelFormat: MTLPixelFormat!
    //библиотека для использования функций, написанных на MSL
  static var library: MTLLibrary!
  
  var renderPipelineState: MTLRenderPipelineState!
  var depthStencilState: MTLDepthStencilState!
  
  var shadowTexture: MTLTexture!
  let shadowRenderPassDescriptor = MTLRenderPassDescriptor()
  var shadowPipelineState: MTLRenderPipelineState!
  
  //переменные 4х текстур для G-буфера
  var albedoTexture: MTLTexture!  //цвет
  var normalTexture: MTLTexture! //нормали
  var positionTexture: MTLTexture! //позиция
  var depthTexture: MTLTexture!  //глубина
  
  var gBufferPipelineState: MTLRenderPipelineState!
  var gBufferRenderPassDescriptor: MTLRenderPassDescriptor!
  
  var compositionPipelineState: MTLRenderPipelineState!
  
  var quadVerticesBuffer: MTLBuffer!
  var quadTexCoordsBuffer: MTLBuffer!
  
    //буфер для хранения вершин
  let quadVertices: [Float] = [
    -1.0,  1.0,
    1.0, -1.0,
    -1.0, -1.0,
    -1.0,  1.0,
    1.0,  1.0,
    1.0, -1.0,
  ]
  
    //буфер для хранения текстур
  let quadTexCoords: [Float] = [
    0.0, 0.0,
    1.0, 1.0,
    0.0, 1.0,
    0.0, 0.0,
    1.0, 0.0,
    1.0, 1.0
  ]
  
  var uniforms = Uniforms()
  var fragmentUniforms = FragmentUniforms()
  
    //объект-камера
  lazy var camera: Camera = {
    let camera = Camera()
    camera.position = [0, 0, -5]
    camera.rotation = [-0.5, -0.5, 0]
    return camera
  }()
  
    //источник освещения - солнце
  lazy var sunlight: Light = {
    var light = buildDefaultLight()
    light.position = [1, 2, -2]
    light.intensity = 0.8
    return light
  }()
    
  //массив для хранения источников освещения
  var lights = [Light]()
  //массив для хранения моделей на сцене
  var models: [Model] = []
    
  var lightsBuffer: MTLBuffer!
  
    //конструктор класса
  init(metalView: MTKView) {
    //подключаемся к графическому процессору
    guard let device = MTLCreateSystemDefaultDevice() else {
      fatalError("GPU not available")
    }
    metalView.device = device
    Renderer.device = device
    Renderer.commandQueue = device.makeCommandQueue()!
    Renderer.colorPixelFormat = metalView.colorPixelFormat
    Renderer.library = device.makeDefaultLibrary()
    
    //вызов конструктора суперкласса
    super.init()
    //устанавливаем цвет фона
    metalView.clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 0.8, alpha: 1)
    metalView.depthStencilPixelFormat = .depth32Float
    metalView.delegate = self
    metalView.framebufferOnly = false
    mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)
    //добававляем солнце первым источником света
    lights.append(sunlight)
    //создаём 300 точечных источников раскрашенных случайным образом
    createPointLights(count: 300, min: [-10, 0.3, -10], max: [10, 2, 20])
    fragmentUniforms.lightCount = UInt32(lights.count)
    
    //загружаем модель вазы с розами
    let rose = Model(name: "white_roses")
    //устанавливаем позицию модели
    rose.position = [-0.5, 0, 0]
    //увеличиваем размер модели в 3 раза
    rose.scale = [3,3,3]
    //rose.rotation = [0, radians(fromDegrees: 45), 0]
    models.append(rose)
    
    //добавляем модель плоскости на сцену
    let plane = Model(name: "plane")
    //увеличиваем её в 8 раз
    plane.scale = [8, 8, 8]
    plane.position = [0, 0, 0]
    models.append(plane)
    
 
    //функция, вызывающая объект дескриптора шаблона глубины
    buildDepthStencilState()
    //строим текстуру для теней (текстуру глубины)
    buildShadowTexture(size: metalView.drawableSize)
    buildShadowPipelineState()
    
    //второй проход рендеринга
    buildGbufferPipelineState()
    
    //буфер для хранения координат
    quadVerticesBuffer = Renderer.device.makeBuffer(bytes: quadVertices, length: MemoryLayout<Float>.size * quadVertices.count, options: [])
    quadVerticesBuffer.label = "Quad vertices"
    //буфер для хранения текстур
    quadTexCoordsBuffer = Renderer.device.makeBuffer(bytes: quadTexCoords, length: MemoryLayout<Float>.size * quadTexCoords.count, options: [])
    quadTexCoordsBuffer.label = "Quad texCoords"
    //буфер для хранения большого числа источников света
    lightsBuffer = Renderer.device.makeBuffer(bytes: lights, length: MemoryLayout<Light>.stride * lights.count, options: [])
    
    //финальный проход рендеринга
    buildCompositionPipelineState()
  }
  
    //конвейер по обработке теней
  func buildShadowPipelineState() {
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = Renderer.library.makeFunction(
      name: "vertex_depth")
    pipelineDescriptor.fragmentFunction = nil
    pipelineDescriptor.colorAttachments[0].pixelFormat = .invalid
    pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(Model.defaultVertexDescriptor)
    pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
    do {
      shadowPipelineState = try Renderer.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch let error {
      fatalError(error.localizedDescription)
    }
  }
    
  func buildDepthStencilState() {
    //дескриптор шаблона глубины
    let descriptor = MTLDepthStencilDescriptor()
    descriptor.depthCompareFunction = .less
    descriptor.isDepthWriteEnabled = true
    depthStencilState = Renderer.device.makeDepthStencilState(descriptor: descriptor)
  }
  
    //создание источника света по умолчанию (солнца с белым освещением в центре сцены)
  func buildDefaultLight() -> Light {
    var light = Light()
    //позиция источника света
    light.position = [0, 0, 0]
    //цвет освещения источника света
    light.color = [1, 1, 1]
    //интенсивность свечения источника света
    light.intensity = 1
    //затухание источника света
    light.attenuation = float3(1, 0, 0)
    //тип источника света
    light.type = Sunlight
    return light
  }
  
    //создание текстуры
  func buildTexture(pixelFormat: MTLPixelFormat, size: CGSize, label: String) -> MTLTexture {
    //дескриптор текстуры
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: false)
    descriptor.usage = [.shaderRead, .renderTarget]
    descriptor.storageMode = .private
    
    //создание текстуры
    guard let texture = Renderer.device.makeTexture(descriptor: descriptor) else {
      fatalError()
    }
    //присвоение имени текстуре
    texture.label = "\(label) texture"
    return texture
  }
  
  //создаём текстуру глубины
  func buildShadowTexture(size: CGSize) {
    //создаём текстуру
    shadowTexture = buildTexture(pixelFormat: .depth32Float, size: size, label: "Shadow")
    shadowRenderPassDescriptor.setUpDepthAttachment(texture: shadowTexture)
  }
  
    //проход рендеринга со стороны источника света для создания карты теней
  func renderShadowPass(renderEncoder: MTLRenderCommandEncoder) {
    renderEncoder.pushDebugGroup("Shadow pass")
    renderEncoder.label = "Shadow encoder"
    renderEncoder.setCullMode(.none)
    renderEncoder.setDepthStencilState(depthStencilState)
    //корректируем значение глубины
    renderEncoder.setDepthBias(0.01, slopeScale: 1.0, clamp: 0.01)
    //создаём проекционную матрицу
    uniforms.projectionMatrix = float4x4(orthoLeft: -8, right: 8, bottom: -8, top: 8, near: 0.1, far: 16)
    
    let position: float3 = [-sunlight.position.x,
                            -sunlight.position.y,
                            -sunlight.position.z]
    let center: float3 = [0, 0, 0]
    
    //смотрим с позиции источника света (солнца)
    let lookAt = float4x4(eye: position, center: center, up: [0,1,0])
    //сдвигаем на позицию солнца
    uniforms.viewMatrix = float4x4(translation: [0, 0, 7]) * lookAt
    //вычисляем проекцию
    uniforms.shadowMatrix = uniforms.projectionMatrix * uniforms.viewMatrix
    renderEncoder.setRenderPipelineState(shadowPipelineState)
    for model in models {
      draw(renderEncoder: renderEncoder, model: model)
    }
    //сообщаем энкодеру о завершении последовательности вызовов для отрисовки
    renderEncoder.endEncoding()
  }
  
    //создаём 4 текстуры для G-буфера
  func buildGbufferTextures(size: CGSize) {
    //создаём текстуру цвета
    albedoTexture = buildTexture(pixelFormat: .bgra8Unorm, size: size, label: "Albedo texture")
    //создаём текстуру нормалей
    normalTexture = buildTexture(pixelFormat: .rgba16Float, size: size, label: "Normal texture")
    //создаём текстуру позиций моделей
    positionTexture = buildTexture(pixelFormat: .rgba16Float, size: size, label: "Position texture")
    //создаём текстуру глубины
    depthTexture = buildTexture(pixelFormat: .depth32Float, size: size, label: "Depth texture")
  }
  
    //создаём 4 текстуры к проходу рендеринга
  func buildGBufferRenderPassDescriptor(size: CGSize) {
    gBufferRenderPassDescriptor = MTLRenderPassDescriptor()
    //создаём 4 текстуры для G-буфера
    buildGbufferTextures(size: size)
    let textures: [MTLTexture] = [albedoTexture, normalTexture, positionTexture]
    
    //для 3х текстур цвета
    for (position, texture) in textures.enumerated() {
        //устанавливаем цвет фона - голубой цвет неба
      gBufferRenderPassDescriptor.setUpColorAttachment(position: position, texture: texture)
    }
    gBufferRenderPassDescriptor.setUpDepthAttachment(texture: depthTexture)
    gBufferRenderPassDescriptor.setUpDepthAttachment(texture: depthTexture)
  }
  
  func buildGbufferPipelineState() {
    let descriptor = MTLRenderPipelineDescriptor()
    //текстура цвета
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    //текстура нормалей
    descriptor.colorAttachments[1].pixelFormat = .rgba16Float
    //текстура позиций
    descriptor.colorAttachments[2].pixelFormat = .rgba16Float
    //текстура глубины
    descriptor.depthAttachmentPixelFormat = .depth32Float
    descriptor.label = "GBuffer state"
    //выполняем шейдеры
    descriptor.vertexFunction = Renderer.library.makeFunction(name: "vertex_main")
    descriptor.fragmentFunction = Renderer.library.makeFunction(name: "gBufferFragment")
    
    //получаем вершины модели
    descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(Model.defaultVertexDescriptor)
    
    //проводим рендеринг
    do {
      gBufferPipelineState = try Renderer.device.makeRenderPipelineState(descriptor: descriptor)
    } catch let error {
      fatalError(error.localizedDescription)
    }
  }
  
  func renderGbufferPass(renderEncoder: MTLRenderCommandEncoder) {
    renderEncoder.pushDebugGroup("Gbuffer pass")
    renderEncoder.label = "Gbuffer encoder"
    renderEncoder.setRenderPipelineState(gBufferPipelineState)
    renderEncoder.setDepthStencilState(depthStencilState)
    uniforms.viewMatrix = camera.viewMatrix
    uniforms.projectionMatrix = camera.projectionMatrix
    fragmentUniforms.cameraPosition = camera.position
    renderEncoder.setFragmentTexture(shadowTexture, index: 0)
    renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.stride, index: 3)
    for model in models {
      draw(renderEncoder: renderEncoder, model: model)
    }
    renderEncoder.endEncoding()
    renderEncoder.popDebugGroup()
  }
  
  func renderCompositionPass(renderEncoder: MTLRenderCommandEncoder) {
    renderEncoder.pushDebugGroup("Composition pass")
    renderEncoder.label = "Composition encoder"
    renderEncoder.setRenderPipelineState(compositionPipelineState)
    renderEncoder.setDepthStencilState(depthStencilState)
    renderEncoder.setVertexBuffer(quadVerticesBuffer, offset: 0, index: 0)
    renderEncoder.setVertexBuffer(quadTexCoordsBuffer, offset: 0, index: 1)
    renderEncoder.setFragmentTexture(albedoTexture, index: 0)
    renderEncoder.setFragmentTexture(normalTexture, index: 1)
    renderEncoder.setFragmentTexture(positionTexture, index: 2)
    renderEncoder.setFragmentBuffer(lightsBuffer, offset: 0, index: 2)
    renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.stride, index: 3)
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quadVertices.count)
    renderEncoder.endEncoding()
    renderEncoder.popDebugGroup()
  }
  
  func buildCompositionPipelineState() {
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
    descriptor.depthAttachmentPixelFormat = .depth32Float
    descriptor.label = "Composition state"
    //вызов шейдерных функций
    descriptor.vertexFunction = Renderer.library.makeFunction(name: "compositionVert")
    descriptor.fragmentFunction = Renderer.library.makeFunction(name: "compositionFrag")
    do {
        //проводим рендеринг
      compositionPipelineState = try Renderer.device.makeRenderPipelineState(descriptor: descriptor)
    } catch let error {
      fatalError(error.localizedDescription)
    }
  }
}

extension Renderer: MTKViewDelegate {
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    camera.aspect = Float(view.bounds.width)/Float(view.bounds.height)
    uniforms.projectionMatrix = camera.projectionMatrix
    
    buildShadowTexture(size: size)
    
    buildGBufferRenderPassDescriptor(size: size)
  }
  
  func draw(in view: MTKView) {
    guard let descriptor = view.currentRenderPassDescriptor,
      let commandBuffer = Renderer.commandQueue.makeCommandBuffer(),
      let drawable = view.currentDrawable else {
        return
    }
    
    //вращение модели
    models[0].rotation.y += 0.01
    
    // shadow pass
    guard let shadowEncoder = commandBuffer.makeRenderCommandEncoder(
      descriptor: shadowRenderPassDescriptor) else {
        return
    }
    renderShadowPass(renderEncoder: shadowEncoder)
    
    // g-buffer pass
    guard let gBufferEncoder = commandBuffer.makeRenderCommandEncoder(
      descriptor: gBufferRenderPassDescriptor) else {
        return
    }
    renderGbufferPass(renderEncoder: gBufferEncoder)
   
    
    // composition pass
    guard let compositionEncoder = commandBuffer.makeRenderCommandEncoder(
      descriptor: descriptor) else {
        return
    }
    renderCompositionPass(renderEncoder: compositionEncoder)
    
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
  
    //рисование модели на экране
  func draw(renderEncoder: MTLRenderCommandEncoder, model: Model) {
    uniforms.modelMatrix = model.modelMatrix
    uniforms.normalMatrix = float3x3(normalFrom4x4: model.modelMatrix)
    renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
    renderEncoder.setVertexBuffer(model.vertexBuffer, offset: 0, index: 0)
    //нанесение материалов на каждый сегмент модели
    for modelSubmesh in model.submeshes {
      let submesh = modelSubmesh.submesh
      renderEncoder.setFragmentBytes(&modelSubmesh.material, length: MemoryLayout<Material>.stride, index: 1)
      renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
    }
  }
}

//очищаем текстуру глубины
private extension MTLRenderPassDescriptor {
  func setUpDepthAttachment(texture: MTLTexture) {
    depthAttachment.texture = texture
    //очищение текстуры в начале рендеринга
    depthAttachment.loadAction = .clear
    //сохранение текстуры в конце рендеринга
    depthAttachment.storeAction = .store
    //ставим значение по умолчанию
    depthAttachment.clearDepth = 1
  }
  
    //устанавливаем голубой цвет неба
  func setUpColorAttachment(position: Int, texture: MTLTexture) {
    let attachment: MTLRenderPassColorAttachmentDescriptor = colorAttachments[position]
    attachment.texture = texture
      //очищение текстуры в начале рендеринга
    attachment.loadAction = .clear
    //сохранение текстуры в конце рендеринга
    attachment.storeAction = .store
    //устанавливаем голубой цвет
    attachment.clearColor = MTLClearColorMake(0.73, 0.92, 1, 1)
  }
}
