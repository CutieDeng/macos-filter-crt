// Simple test shader - adds red tint to verify rendering works
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
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    // Read original color
    float4 inputColor = inputTexture.read(gid);

    // Add strong red tint - this should be VERY obvious
    float3 color = inputColor.rgb;
    color.r = min(1.0, color.r + 0.3);  // Boost red
    color.g *= 0.7;  // Reduce green
    color.b *= 0.7;  // Reduce blue

    // Also add scanlines that are VERY visible
    int scanline = int(gid.y) % 4;
    if (scanline == 0) {
        color *= 0.5;  // Dark line every 4 pixels
    }

    outputTexture.write(float4(color, 1.0), gid);
}
