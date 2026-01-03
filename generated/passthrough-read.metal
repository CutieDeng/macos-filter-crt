// Pure passthrough using direct read instead of sampler
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

    uint inW = inputTexture.get_width();
    uint inH = inputTexture.get_height();

    // Calculate corresponding input pixel
    uint2 inPos = gid;

    // Handle size mismatch by scaling
    if (inW != outW || inH != outH) {
        inPos.x = uint(float(gid.x) * float(inW) / float(outW));
        inPos.y = uint(float(gid.y) * float(inH) / float(outH));
    }

    // Clamp to valid range
    inPos.x = min(inPos.x, inW - 1);
    inPos.y = min(inPos.y, inH - 1);

    // Direct pixel read
    float4 color = inputTexture.read(inPos);

    // Debug: show size mismatch in top-left corner
    if (gid.x < 100 && gid.y < 100) {
        if (inW != outW) {
            color = float4(1.0, 0.0, 0.0, 1.0);  // Red = width mismatch
        } else if (inH != outH) {
            color = float4(0.0, 1.0, 0.0, 1.0);  // Green = height mismatch
        }
    }

    outputTexture.write(color, gid);
}
