// CRT Effect Shader - scanlines, phosphor mask, bloom (no curvature)
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float scanlineWeight;   // Scanline darkness (0-1, higher = darker lines)
    float scanlineGap;      // Not used currently
    float maskBrightness;   // RGB mask strength (0-1)
    int maskType;           // 0=off, 1=RGB, 2=aperture grille
    float bloomFactor;      // Bloom intensity
    float inputGamma;       // Input gamma correction
    float outputGamma;      // Output gamma correction
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

    // Apply input gamma (linearize)
    float3 linearColor = pow(color.rgb, float3(uniforms.inputGamma));

    // === Scanlines ===
    // Create virtual scanlines (480 lines like old CRT)
    float virtualLines = 480.0;
    float scanlineY = (float(gid.y) / float(outH)) * virtualLines;
    float scanlinePhase = fract(scanlineY);

    // Smooth scanline with sine wave
    float scanline = 0.5 + 0.5 * cos(scanlinePhase * 3.14159 * 2.0);
    scanline = mix(1.0, scanline, uniforms.scanlineWeight * 0.3);

    linearColor *= scanline;

    // === Phosphor Mask (RGB subpixels) ===
    if (uniforms.maskType > 0) {
        int subpixel = int(gid.x) % 3;
        float3 mask = float3(1.0);

        if (uniforms.maskType == 1) {
            // RGB stripe mask
            if (subpixel == 0) mask = float3(1.0, 0.7, 0.7);
            else if (subpixel == 1) mask = float3(0.7, 1.0, 0.7);
            else mask = float3(0.7, 0.7, 1.0);
        } else {
            // Aperture grille (vertical lines)
            float grille = 0.8 + 0.2 * sin(float(gid.x) * 3.14159);
            mask = float3(grille);
        }

        linearColor *= mix(float3(1.0), mask, uniforms.maskBrightness * 0.3);
    }

    // === Subtle Bloom ===
    // Simple bloom approximation - brighten based on luminance
    float lum = dot(linearColor, float3(0.299, 0.587, 0.114));
    float bloom = max(0.0, lum - 0.5) * uniforms.bloomFactor * 0.1;
    linearColor += bloom;

    // === Vignette (subtle darkening at edges) ===
    float2 uv = float2(gid) / float2(outW, outH);
    float2 vignetteUV = uv * 2.0 - 1.0;
    float vignette = 1.0 - dot(vignetteUV, vignetteUV) * 0.1;
    linearColor *= vignette;

    // Apply output gamma
    float3 finalColor = pow(linearColor, float3(1.0 / uniforms.outputGamma));

    // Clamp to valid range
    finalColor = clamp(finalColor, 0.0, 1.0);

    outputTexture.write(float4(finalColor, color.a), gid);
}
