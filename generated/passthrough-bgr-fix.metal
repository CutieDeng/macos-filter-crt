// Try different channel interpretations
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

    float4 c = inputTexture.read(gid);
    float4 outColor;

    // Divide into 6 horizontal bands to test different channel orders
    uint band = gid.y * 6 / outH;

    switch (band) {
        case 0:
            // Band 0: Original RGBA
            outColor = c;
            break;
        case 1:
            // Band 1: Swap R and B (BGRA interpretation)
            outColor = float4(c.b, c.g, c.r, c.a);
            break;
        case 2:
            // Band 2: ARGB interpretation
            outColor = float4(c.g, c.b, c.a, c.r);
            break;
        case 3:
            // Band 3: Only use first channel for all RGB
            outColor = float4(c.r, c.r, c.r, 1.0);
            break;
        case 4:
            // Band 4: Use g channel for all RGB
            outColor = float4(c.g, c.g, c.g, 1.0);
            break;
        default:
            // Band 5: Use b channel for all RGB
            outColor = float4(c.b, c.b, c.b, 1.0);
            break;
    }

    // Draw band separators
    if (gid.y % (outH / 6) < 3) {
        outColor = float4(1.0, 1.0, 0.0, 1.0); // Yellow separator
    }

    outputTexture.write(outColor, gid);
}
