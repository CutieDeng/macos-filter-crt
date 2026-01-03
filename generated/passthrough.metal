// Pure passthrough shader using sampler for proper texture reading
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float scanlineWeight;
    float scanlineGap;
    float maskBrightness;
    int maskType;
    float bloomFactor;
    float inputGamma;
    float outputGamma;
    float _padding;
};

kernel void processCRT(
    texture2d<float, access::sample> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant Uniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    uint outputWidth = outputTexture.get_width();
    uint outputHeight = outputTexture.get_height();

    if (gid.x >= outputWidth || gid.y >= outputHeight) {
        return;
    }

    // Use sampler to read texture - handles stride/alignment properly
    constexpr sampler textureSampler(coord::normalized,
                                      address::clamp_to_edge,
                                      filter::linear);

    // Calculate normalized coordinates
    float2 uv = (float2(gid) + 0.5) / float2(outputWidth, outputHeight);

    // Sample the input texture
    float4 color = inputTexture.sample(textureSampler, uv);

    outputTexture.write(color, gid);
}
