#version 440
// SiMSanctum.frag — The live background shader space
// ====================================================
// Highly optimized breathing style HSL auroras and click ripple shockwaves.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float time;
    float breathingStyle; // 0.0=moon, 1.0=sun, 2.0=prismatic
    float breathRhythm;   // 0.0 - 1.0
    float cursorX;        // 0.0 - 1.0 (normalized mouse coordinate)
    float cursorY;        // 0.0 - 1.0
    float clickRipple;    // 0.0 - 1.0 (active ripple intensity)
    float w;
    float h;
} ubuf;

// Noise utilities
float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = ubuf.w / ubuf.h;
    vec2 p = vec2(uv.x * aspect, uv.y);
    
    vec3 color = vec3(0.0);
    float alpha = 0.0;

    // ── Mouse Click Ripple Shockwave ──
    vec2 mousePos = vec2(ubuf.cursorX * aspect, ubuf.cursorY);
    float distToMouse = length(p - mousePos);
    
    // Shockwave distortion factor
    float waveOffset = 0.0;
    float rippleIntensity = 0.0;
    
    if (ubuf.clickRipple > 0.01) {
        float rippleRadius = ubuf.clickRipple * 0.6; // expand over time
        float thickness = 0.04;
        // Shockwave ring intensity
        rippleIntensity = smoothstep(thickness, 0.0, abs(distToMouse - rippleRadius)) * (1.0 - ubuf.clickRipple);
        // Distortion vector
        waveOffset = sin(distToMouse * 40.0 - ubuf.time * 20.0) * 0.03 * rippleIntensity;
    }

    // Apply distortion to texture coordinate for background wallpaper
    vec2 distortedUv = uv + vec2(waveOffset) * normalize(p - mousePos + 0.0001);
    distortedUv = clamp(distortedUv, 0.0, 1.0);

    // ── Breathing Styles Shaders ──
    if (ubuf.breathingStyle < 0.5) {
        // ── STEALTH MOON: Cerulean Night Auroras & Particles ──
        // Ambient breathing night light
        float baseBreath = mix(0.05, 0.15, ubuf.breathRhythm);
        
        // Dynamic cerulean auroras
        vec2 noiseUv1 = p * 1.5 + vec2(ubuf.time * 0.05, ubuf.time * 0.02);
        vec2 noiseUv2 = p * 2.0 - vec2(ubuf.time * 0.03, -ubuf.time * 0.04);
        float aurora = fbm(noiseUv1 + fbm(noiseUv2));
        
        vec3 auroraCol = hsv2rgb(vec3(0.55 + 0.05 * sin(ubuf.time * 0.1), 0.85, 0.7));
        color += auroraCol * aurora * (0.15 + baseBreath * 0.5);
        
        // Float particles
        float particleNoise = noise(p * 20.0 + vec2(0.0, ubuf.time * 0.1));
        if (particleNoise > 0.82) {
            float pSize = smoothstep(0.82, 1.0, particleNoise);
            color += vec3(0.0, 0.7, 1.0) * pSize * 0.4 * ubuf.breathRhythm;
        }
        
        alpha = 0.2 + 0.1 * aurora;

    } else if (ubuf.breathingStyle < 1.5) {
        // ── SUN STYLE: Radiant Strike-Rose Border Flame Waves ──
        float baseBreath = mix(0.1, 0.25, ubuf.breathRhythm);
        
        // Edge calculation (vibrant borders)
        float borderDistX = min(uv.x, 1.0 - uv.x);
        float borderDistY = min(uv.y, 1.0 - uv.y);
        float edge = 1.0 - smoothstep(0.0, 0.08 + 0.02 * sin(ubuf.time), min(borderDistX, borderDistY));
        
        // Flame noise
        vec2 flameUv = p * 2.5 + vec2(0.0, ubuf.time * 0.2);
        float flame = fbm(flameUv + fbm(flameUv * 1.5));
        
        // Strike-Rose Red/Amber HSL gradient
        vec3 flameCol = hsv2rgb(vec3(0.97 + 0.03 * sin(ubuf.time * 0.2), 0.9, 0.9));
        vec3 borderColor = flameCol * (flame * 0.6 + 0.4) * edge * (0.8 + 0.4 * ubuf.breathRhythm);
        
        color += borderColor;
        
        // Center radiant ambient glow
        float centerGlow = exp(-length(p - vec2(0.5 * aspect, 0.5)) * 1.2) * 0.12 * ubuf.breathRhythm;
        color += vec3(0.95, 0.25, 0.35) * centerGlow;
        
        alpha = 0.15 + 0.35 * edge;

    } else {
        // ── PRISMATIC STYLE: Shifting Rainbow Gradients ──
        float baseBreath = mix(0.08, 0.2, ubuf.breathRhythm);
        
        // Fluid noise shifting coordinates
        vec2 shiftUv1 = p * 1.2 + vec2(sin(ubuf.time * 0.1), cos(ubuf.time * 0.15));
        vec2 shiftUv2 = p * 1.8 + vec2(cos(ubuf.time * 0.08), sin(ubuf.time * 0.12));
        float fluid = fbm(shiftUv1 + fbm(shiftUv2));
        
        // Cycle the base hue over time
        float baseHue = fract(ubuf.time * 0.02 + fluid * 0.35);
        vec3 prismaticCol = hsv2rgb(vec3(baseHue, 0.7, 0.65));
        
        color += prismaticCol * (0.25 + 0.15 * sin(ubuf.time * 0.5)) * (0.7 + 0.3 * ubuf.breathRhythm);
        
        // Dynamic soft accents
        float accentNoise = noise(p * 3.0 - vec2(ubuf.time * 0.05));
        if (accentNoise > 0.6) {
            color += hsv2rgb(vec3(fract(baseHue + 0.5), 0.8, 0.8)) * (accentNoise - 0.6) * 0.25;
        }
        
        alpha = 0.22;
    }

    // Overlay click ripple highlights
    if (rippleIntensity > 0.01) {
        vec3 rippleColor = vec3(0.0);
        if (ubuf.breathingStyle < 0.5) {
            rippleColor = vec3(0.0, 0.7, 1.0); // Moon cerulean
        } else if (ubuf.breathingStyle < 1.5) {
            rippleColor = vec3(1.0, 0.25, 0.35); // Sun strike-rose
        } else {
            rippleColor = hsv2rgb(vec3(fract(ubuf.time * 0.2), 0.9, 1.0)); // Prismatic rainbow cycle
        }
        color += rippleColor * rippleIntensity * 0.85;
        alpha = max(alpha, rippleIntensity * 0.4);
    }

    fragColor = vec4(color, alpha * ubuf.qt_Opacity);
}
