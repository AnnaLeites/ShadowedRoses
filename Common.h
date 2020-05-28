

#ifndef Common_h
#define Common_h

#import <simd/simd.h>

typedef struct {
  matrix_float4x4 modelMatrix;
  matrix_float4x4 viewMatrix;
  matrix_float4x4 projectionMatrix;
  matrix_float3x3 normalMatrix;
  matrix_float4x4 shadowMatrix;
} Uniforms;

typedef struct {
    //количество источников света на сцене
  uint lightCount;
    //координаты положения камеры
  vector_float3 cameraPosition;
} FragmentUniforms;

//перечисление видов источников света
typedef enum {
  unused = 0,
    //направленный источник - солнце
  Sunlight = 1,
    //прожектор
  Spotlight = 2,
    //точечный источник
  Pointlight = 3,
} LightType;


//структура со свойствами источника света
typedef struct {
  vector_float3 position;
  vector_float3 color;
  //vector_float3 specularColor;
  float intensity;
  vector_float3 attenuation;
  LightType type;
  float coneAngle;
  vector_float3 coneDirection;
  float coneAttenuation;
} Light;

//структура со свойствами материала
typedef struct {
  vector_float3 emissionColor;
  vector_float3 baseColor;
  vector_float3 specularColor;
  float shininess;
} Material;

#endif /* Common_h */
