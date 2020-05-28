
#include <metal_stdlib>
using namespace metal;
#import "../Utility/Common.h"

//структура входных данных вершинного шейдера
struct VertexIn {
  float4 position [[ attribute(0) ]];
  float3 normal [[ attribute(1)]];
};

//структура возвращаемых данных вершинного шейдера
struct VertexOut {
  float4 position [[ position ]];
    //координаты вершин в мировых кооринатах
  float3 worldPosition;
    //вектор нормали в мировых кооринатах
  float3 worldNormal;
  float4 shadowPosition;
};

//вершинный шейдер
vertex VertexOut vertex_main(const VertexIn vertexIn [[ stage_in ]],
                             constant Uniforms &uniforms [[ buffer(1) ]])
{
  VertexOut out;
  matrix_float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;
  out.position = mvp * vertexIn.position;
  out.worldPosition = (uniforms.modelMatrix * vertexIn.position).xyz;
  out.worldNormal = uniforms.normalMatrix * vertexIn.normal, 0;
  out.shadowPosition = uniforms.shadowMatrix * uniforms.modelMatrix * vertexIn.position;
  return out;
}
