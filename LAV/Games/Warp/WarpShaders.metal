#include <metal_stdlib>
using namespace metal;

// Borderlands-style Sobel edge detection post-process for Warp
// Purple-tinted edge color matching space aesthetic

struct WarpEdgeVertexIn {
    float4 position [[attribute(0)]];
    float2 texcoord [[attribute(7)]];
};

struct WarpEdgeVertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex WarpEdgeVertexOut warp_edge_vertex(WarpEdgeVertexIn in [[stage_in]]) {
    WarpEdgeVertexOut out;
    out.position = in.position;
    out.uv = float2((in.position.x + 1.0) * 0.5, 1.0 - (in.position.y + 1.0) * 0.5);
    return out;
}

fragment half4 warp_edge_fragment(WarpEdgeVertexOut in [[stage_in]],
                                  texture2d<half> colorSampler [[texture(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 uv = in.uv;
    float2 texSize = float2(colorSampler.get_width(), colorSampler.get_height());
    float2 texel = 1.5 / texSize;

    // Sobel edge detection
    float tl = dot(float3(colorSampler.sample(s, uv + texel * float2(-1,  1)).rgb), float3(0.299, 0.587, 0.114));
    float t  = dot(float3(colorSampler.sample(s, uv + texel * float2( 0,  1)).rgb), float3(0.299, 0.587, 0.114));
    float tr = dot(float3(colorSampler.sample(s, uv + texel * float2( 1,  1)).rgb), float3(0.299, 0.587, 0.114));
    float l  = dot(float3(colorSampler.sample(s, uv + texel * float2(-1,  0)).rgb), float3(0.299, 0.587, 0.114));
    float r  = dot(float3(colorSampler.sample(s, uv + texel * float2( 1,  0)).rgb), float3(0.299, 0.587, 0.114));
    float bl = dot(float3(colorSampler.sample(s, uv + texel * float2(-1, -1)).rgb), float3(0.299, 0.587, 0.114));
    float b  = dot(float3(colorSampler.sample(s, uv + texel * float2( 0, -1)).rgb), float3(0.299, 0.587, 0.114));
    float br = dot(float3(colorSampler.sample(s, uv + texel * float2( 1, -1)).rgb), float3(0.299, 0.587, 0.114));

    float gx = tl + 2.0 * l + bl - tr - 2.0 * r - br;
    float gy = tl + 2.0 * t + tr - bl - 2.0 * b - br;
    float edge = sqrt(gx * gx + gy * gy);

    half4 color = colorSampler.sample(s, uv);

    // Edge outline — purple-tinted dark ink lines for space aesthetic
    float outline = smoothstep(0.06, 0.2, edge * 1.6);
    color.rgb = mix(color.rgb, half3(0.06, 0.02, 0.08), half(outline * 0.7));

    return color;
}
