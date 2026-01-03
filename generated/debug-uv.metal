// Debug shader - shows UV coordinates and raw pixel samples
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

    // Calculate normalized UV for output position
    float2 uv = float2(gid) / float2(outW, outH);

    // Sample input texture
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float4 inputColor = inputTexture.sample(s, uv);

    float4 outColor = inputColor;

    // Top strip: show UV.x as red gradient (should go 0->1 left to right)
    if (gid.y < 50) {
        outColor = float4(uv.x, 0.0, 0.0, 1.0);
    }
    // Left strip: show UV.y as green gradient (should go 0->1 top to bottom)
    else if (gid.x < 50) {
        outColor = float4(0.0, uv.y, 0.0, 1.0);
    }
    // Top-left corner: show input texture size info
    else if (gid.x < 200 && gid.y < 100) {
        // Red if input width != output width
        if (inW != outW) {
            outColor = float4(1.0, 0.0, 0.0, 1.0);
        }
        // Green if input height != output height
        else if (inH != outH) {
            outColor = float4(0.0, 1.0, 0.0, 1.0);
        }
        // Blue if sizes match
        else {
            outColor = float4(0.0, 0.0, 1.0, 1.0);
        }
    }
    // Bottom-right 100x100: show raw sampled color components
    else if (gid.x >= outW - 300 && gid.y >= outH - 100) {
        // Show R, G, B channels separately
        float xPos = float(gid.x - (outW - 300)) / 100.0;
        if (xPos < 1.0) {
            outColor = float4(inputColor.r, 0.0, 0.0, 1.0);  // Red channel only
        } else if (xPos < 2.0) {
            outColor = float4(0.0, inputColor.g, 0.0, 1.0);  // Green channel only
        } else {
            outColor = float4(0.0, 0.0, inputColor.b, 1.0);  // Blue channel only
        }
    }

    outputTexture.write(outColor, gid);
}
