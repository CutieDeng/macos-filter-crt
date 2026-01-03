// CRT 2.0 Effect Shader - Enhanced with noise, interlacing, NO flicker
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float scanlineWeight;   // Also used as time (updated each frame)
    float scanlineGap;      // Noise intensity
    float maskBrightness;   // Unused
    int maskType;           // Effect mode
    float bloomFactor;      // Bloom intensity
    float inputGamma;
    float outputGamma;
    float _padding;
};

// Pseudo-random noise function
float rand(float2 co) {
    return fract(sin(dot(co, float2(12.9898, 78.233))) * 43758.5453);
}

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

    // Get time from uniform (scanlineWeight is repurposed as time)
    float time = uniforms.scanlineWeight;

    // Normalized coordinates
    float2 uv = float2(gid) / float2(outW, outH);
    int lineNum = int(gid.y);

    // === Enhanced Scanlines (240 lines, more visible) ===
    float virtualLines = 240.0;
    float scanlineY = uv.y * virtualLines;
    float scanlinePhase = fract(scanlineY);
    float scanlineDist = abs(scanlinePhase - 0.5) * 2.0;
    float scanline = mix(0.85, 1.0, scanlineDist);  // 15% darker at gaps
    rgb *= scanline;

    // === Enhanced Interlace Effect ===
    // Simulate interlaced display - alternate lines dimmer based on "field"
    float field = fract(time * 30.0);  // Alternates at ~30Hz
    bool evenLine = (lineNum % 2) == 0;
    float interlace = evenLine ? mix(0.94, 1.0, field) : mix(1.0, 0.94, field);
    rgb *= interlace;

    // === NO FLICKER (removed - too uncomfortable) ===

    // === Enhanced Analog Noise/Grain ===
    float noise = rand(uv + fract(time)) * 0.04 - 0.02;  // +/- 2% noise
    rgb += noise;

    // === Horizontal Sync Jitter (visible) ===
    // Slight horizontal shift per scanline that varies with time
    float hJitter = rand(float2(float(lineNum), floor(time * 10.0))) * 2.0 - 1.0;  // -1 to 1
    int jitterPixels = int(hJitter * 1.5);  // up to 1.5 pixel jitter
    uint2 jitteredPos = uint2(clamp(int(gid.x) + jitterPixels, 0, int(outW) - 1), gid.y);
    float3 jitteredColor = inputTexture.read(jitteredPos).rgb;
    rgb = mix(rgb, jitteredColor, 0.3);  // 30% jitter blend

    // === Enhanced Color Bleeding / Chromatic Aberration ===
    // RGB channels slightly offset
    float2 redOffset = float2(1.5, 0.0);   // 1.5 pixel offset for red
    float2 blueOffset = float2(-1.5, 0.0); // -1.5 pixel offset for blue
    uint2 redPos = uint2(clamp(float2(gid) + redOffset, float2(0), float2(outW-1, outH-1)));
    uint2 bluePos = uint2(clamp(float2(gid) + blueOffset, float2(0), float2(outW-1, outH-1)));
    float redSample = inputTexture.read(redPos).r;
    float blueSample = inputTexture.read(bluePos).b;
    rgb.r = mix(rgb.r, redSample, 0.2);   // 20% blend
    rgb.b = mix(rgb.b, blueSample, 0.2);  // 20% blend

    // === Enhanced Phosphor Glow ===
    float lum = dot(rgb, float3(0.299, 0.587, 0.114));
    float glow = max(0.0, lum - 0.5) * 0.1;  // More glow
    rgb += glow;

    // === RGB Phosphor Mask (subtle) ===
    int subpixel = int(gid.x) % 3;
    float3 mask = float3(1.0);
    if (subpixel == 0) mask = float3(1.1, 0.95, 0.95);
    else if (subpixel == 1) mask = float3(0.95, 1.1, 0.95);
    else mask = float3(0.95, 0.95, 1.1);
    rgb *= mask;

    // === Vignette (slightly stronger) ===
    float2 center = uv - 0.5;
    float dist = length(center);
    float vignette = 1.0 - dist * dist * 0.2;
    rgb *= vignette;

    // === Warm CRT Tint ===
    rgb.r *= 1.03;
    rgb.b *= 0.97;

    // Clamp
    rgb = clamp(rgb, 0.0, 1.0);

    outputTexture.write(float4(rgb, color.a), gid);
}
