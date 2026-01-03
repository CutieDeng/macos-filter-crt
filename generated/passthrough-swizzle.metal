// Test different color channel orders
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
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant Uniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    uint outW = outputTexture.get_width();
    uint outH = outputTexture.get_height();

    if (gid.x >= outW || gid.y >= outH) {
        return;
    }

    float4 color = inputTexture.read(gid);

    // Test different swizzle patterns in horizontal bands
    float4 outColor;

    if (gid.y < outH / 5) {
        // Band 1: Original RGBA order
        outColor = color;
    }
    else if (gid.y < 2 * outH / 5) {
        // Band 2: BGRA -> RGBA (swap R and B)
        outColor = float4(color.b, color.g, color.r, color.a);
    }
    else if (gid.y < 3 * outH / 5) {
        // Band 3: Show only Red channel as gray
        outColor = float4(color.r, color.r, color.r, 1.0);
    }
    else if (gid.y < 4 * outH / 5) {
        // Band 4: Show only Green channel as gray
        outColor = float4(color.g, color.g, color.g, 1.0);
    }
    else {
        // Band 5: Show only Blue channel as gray
        outColor = float4(color.b, color.b, color.b, 1.0);
    }

    outputTexture.write(outColor, gid);
}
