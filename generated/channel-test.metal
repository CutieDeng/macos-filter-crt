// Show individual color channels to diagnose the black/white issue
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
    float4 outColor;

    // Divide screen into 4 quadrants
    bool left = gid.x < outW / 2;
    bool top = gid.y < outH / 2;

    if (left && top) {
        // Top-left: RED channel only (should show red tones if R varies)
        outColor = float4(color.r, 0.0, 0.0, 1.0);
    }
    else if (!left && top) {
        // Top-right: GREEN channel only (should show green tones if G varies)
        outColor = float4(0.0, color.g, 0.0, 1.0);
    }
    else if (left && !top) {
        // Bottom-left: BLUE channel only (should show blue tones if B varies)
        outColor = float4(0.0, 0.0, color.b, 1.0);
    }
    else {
        // Bottom-right: Original color as-is
        outColor = color;
    }

    // Draw white cross to divide quadrants
    if (abs(int(gid.x) - int(outW/2)) < 3 || abs(int(gid.y) - int(outH/2)) < 3) {
        outColor = float4(1.0, 1.0, 1.0, 1.0);
    }

    outputTexture.write(outColor, gid);
}
