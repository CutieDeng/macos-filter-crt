// CRT Filter Shader - Subtle vintage CRT effect
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
    uint outputWidth = outputTexture.get_width();
    uint outputHeight = outputTexture.get_height();

    if (gid.x >= outputWidth || gid.y >= outputHeight) {
        return;
    }

    // Read input pixel - use gid directly since sizes match
    // Clamp to valid range just in case
    uint inputWidth = inputTexture.get_width();
    uint inputHeight = inputTexture.get_height();
    uint2 readCoord = uint2(
        min(gid.x, inputWidth - 1),
        min(gid.y, inputHeight - 1)
    );

    float4 inputColor = inputTexture.read(readCoord);
    float3 color = inputColor.rgb;

    // Normalized UV for effects
    float2 uv = float2(gid) / float2(outputWidth, outputHeight);

    // === SUBTLE SCANLINES ===
    float virtualLines = 480.0;
    float scanlineY = uv.y * virtualLines;
    float scanlinePos = fract(scanlineY);
    float scanlineDist = abs(scanlinePos - 0.5) * 2.0;
    float scanlineIntensity = mix(1.0, 0.88, pow(scanlineDist, 2.0));
    color *= scanlineIntensity;

    // === SUBTLE RGB PHOSPHOR MASK ===
    if (uniforms.maskType > 0) {
        int xMod = gid.x % 3;
        float3 maskColor = float3(1.0);
        if (xMod == 0) maskColor = float3(1.0, 0.97, 0.97);
        else if (xMod == 1) maskColor = float3(0.97, 1.0, 0.97);
        else maskColor = float3(0.97, 0.97, 1.0);
        color *= maskColor;
    }

    // === VERY SUBTLE VIGNETTE ===
    float2 vignetteUV = uv * 2.0 - 1.0;
    float vignetteDist = dot(vignetteUV, vignetteUV);
    float vignette = 1.0 - vignetteDist * 0.08;  // Only 8% at extreme corners
    color *= max(vignette, 0.7);  // Never darker than 70%

    color = saturate(color);
    outputTexture.write(float4(color, 1.0), gid);
}
