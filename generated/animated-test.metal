// Simple animated test - color changes over time based on frame count
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float scanlineWeight;  // We'll use this as frame counter
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

    // Read input
    float4 inputColor = inputTexture.read(gid);

    // Use position to create a pattern
    float2 uv = float2(gid) / float2(outW, outH);

    // Animated color based on position (creates a gradient that should be visible)
    float r = uv.x;  // Red increases left to right
    float g = uv.y;  // Green increases top to bottom
    float b = 0.5;   // Constant blue

    // Mix with input color (50% screen, 50% gradient)
    float4 outColor = float4(
        inputColor.r * 0.5 + r * 0.5,
        inputColor.g * 0.5 + g * 0.5,
        inputColor.b * 0.5 + b * 0.5,
        1.0
    );

    // Draw a moving bar to show animation is working
    // The bar position comes from scanlineWeight (will be updated each frame)
    float barPos = fmod(uniforms.scanlineWeight * 100.0, float(outH));
    if (abs(float(gid.y) - barPos) < 10.0) {
        outColor = float4(1.0, 0.0, 0.0, 1.0);  // Red bar
    }

    outputTexture.write(outColor, gid);
}
