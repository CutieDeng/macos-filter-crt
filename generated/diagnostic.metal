// Diagnostic shader - shows corners in different colors to verify coordinate mapping
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
    uint outW = outputTexture.get_width();
    uint outH = outputTexture.get_height();

    if (gid.x >= outW || gid.y >= outH) {
        return;
    }

    uint inW = inputTexture.get_width();
    uint inH = inputTexture.get_height();

    // Calculate normalized UV
    float2 uv = float2(gid) / float2(outW, outH);

    // Sample input
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float4 inputColor = inputTexture.sample(s, uv);

    float4 outColor = inputColor;

    // Draw colored corners to verify coordinate mapping (50 pixel squares)
    float cornerSize = 100.0;

    // Top-left: RED
    if (gid.x < cornerSize && gid.y < cornerSize) {
        outColor = float4(1.0, 0.0, 0.0, 1.0);
    }
    // Top-right: GREEN
    else if (gid.x >= outW - cornerSize && gid.y < cornerSize) {
        outColor = float4(0.0, 1.0, 0.0, 1.0);
    }
    // Bottom-left: BLUE
    else if (gid.x < cornerSize && gid.y >= outH - cornerSize) {
        outColor = float4(0.0, 0.0, 1.0, 1.0);
    }
    // Bottom-right: YELLOW
    else if (gid.x >= outW - cornerSize && gid.y >= outH - cornerSize) {
        outColor = float4(1.0, 1.0, 0.0, 1.0);
    }

    // Draw a white border around the whole screen (5 pixels)
    if (gid.x < 5 || gid.x >= outW - 5 || gid.y < 5 || gid.y >= outH - 5) {
        outColor = float4(1.0, 1.0, 1.0, 1.0);
    }

    // Show input/output size mismatch - draw cyan center if sizes differ
    if (inW != outW || inH != outH) {
        if (gid.x > outW/2 - 50 && gid.x < outW/2 + 50 &&
            gid.y > outH/2 - 50 && gid.y < outH/2 + 50) {
            outColor = float4(0.0, 1.0, 1.0, 1.0); // Cyan = size mismatch!
        }
    }

    outputTexture.write(outColor, gid);
}
