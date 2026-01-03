// Subtle CRT Effect - gentle scanlines, minimal bloom, light vignette
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float scanlineWeight;   // Scanline intensity (default ~0.15)
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

    // Read input pixel
    float4 color = inputTexture.read(gid);
    float3 rgb = color.rgb;

    // === Subtle Scanlines ===
    // Use fewer virtual lines (240 like classic CRT) for less dense effect
    float virtualLines = 240.0;
    float scanlineY = (float(gid.y) / float(outH)) * virtualLines;
    float scanlinePhase = fract(scanlineY);

    // Very subtle scanline - only slight darkening between lines
    // Using smooth step for softer transition
    float scanlineDist = abs(scanlinePhase - 0.5) * 2.0;  // 0 at edges, 1 at center
    float scanline = mix(0.92, 1.0, scanlineDist);  // 8% darker at line gaps

    rgb *= scanline;

    // === Very Subtle Vignette ===
    float2 uv = float2(gid) / float2(outW, outH);
    float2 center = uv - 0.5;
    float dist = length(center);
    float vignette = 1.0 - dist * dist * 0.15;  // Very gentle edge darkening
    rgb *= vignette;

    // === Subtle Warmth (CRT phosphor tint) ===
    // Slight warm color shift typical of CRT monitors
    rgb.r *= 1.02;  // Slight red boost
    rgb.b *= 0.98;  // Slight blue reduction

    // Clamp
    rgb = clamp(rgb, 0.0, 1.0);

    outputTexture.write(float4(rgb, color.a), gid);
}
