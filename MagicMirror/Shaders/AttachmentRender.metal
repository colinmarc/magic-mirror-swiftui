#include <metal_stdlib>
#include <simd/simd.h>
#include "Types.h"

using namespace metal;

constexpr sampler videoSampler (mag_filter::linear,
                                min_filter::linear);

// Vertex shader outputs and fragmentShader inputs.
typedef struct
{
    float4 coords [[position]];
    float2 uv;

} RasterizerData;

// Vertex Function
vertex RasterizerData
vertexShader(uint vertexID [[vertex_id]])
{
    RasterizerData out;
    
    out.uv = float2((vertexID << 1) & 2, vertexID & 2);
    out.coords = vector_float4((out.uv.x * 2.0) - 1.0, (out.uv.y * -2.0) + 1.0, 0.0, 1.0);
    return out;
}

// Fragment function
fragment half4 fragmentShader(RasterizerData in [[stage_in]],
                              texture2d<half> videoTexture [[texture(0)]])
{
//    half2 rg = half2(clamp(in.uv, 0.0, 1.0));
//    return half4(rg, 0.0, 1.0);
    return videoTexture.sample(videoSampler, float2(clamp(in.uv, 0.0, 1.0)));
}
