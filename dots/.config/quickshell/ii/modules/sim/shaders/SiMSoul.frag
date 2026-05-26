#version 440
// AseSoul.frag — Neural Core + 7-Fold Swarm (Refined)
// ====================================================
// The living spirit of the SiM Syndicate.
// Refined with high-frequency data jitter and tpsBeat synchronization.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float time;
    float tpsBeat;
    float inferring;
    float disciplineHue;
    float commandPulse;
    float obeliskOpen;
    float cursorX;
    float cursorY;
    float w;
    float h;
    float mistDensity;
    float atmospherePhase;
    float receivePulse;
} ubuf;

float hash11(float n) { return fract(sin(n) * 43758.5453); }
float hash21(vec2 p)  { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1,0)), u.x),
               mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), u.x), u.y);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Simplex 3D
vec3 mod289v3(vec3 x) { return x - floor(x * (1.0/289.0)) * 289.0; }
vec4 mod289v4(vec4 x) { return x - floor(x * (1.0/289.0)) * 289.0; }
vec4 permute(vec4 x)  { return mod289v4(((x * 34.0) + 1.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float snoise3(vec3 v) {
    const vec2 C = vec2(1.0/6.0, 1.0/3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
    vec3 i  = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);
    vec3 g  = step(x0.yzx, x0.xyz);
    vec3 l  = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);
    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy;
    vec3 x3 = x0 - D.yyy;
    i = mod289v3(i);
    vec4 p = permute(permute(permute(
        i.z + vec4(0.0, i1.z, i2.z, 1.0))
        + i.y + vec4(0.0, i1.y, i2.y, 1.0))
        + i.x + vec4(0.0, i1.x, i2.x, 1.0));
    float n_ = 0.142857142857;
    vec3  ns  = n_ * D.wyz - D.xzx;
    vec4  j   = p - 49.0 * floor(p * ns.z * ns.z);
    vec4  x_  = floor(j * ns.z);
    vec4  y_  = floor(j - 7.0 * x_);
    vec4  x2_ = x_ * ns.x + ns.yyyy;
    vec4  y2_ = y_ * ns.x + ns.yyyy;
    vec4  h   = 1.0 - abs(x2_) - abs(y2_);
    vec4  b0  = vec4(x2_.xy, y2_.xy);
    vec4  b1  = vec4(x2_.zw, y2_.zw);
    vec4  s0  = floor(b0) * 2.0 + 1.0;
    vec4  s1  = floor(b1) * 2.0 + 1.0;
    vec4  sh  = -step(h, vec4(0.0));
    vec4  a0  = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4  a1  = b1.xzyw + s1.xzyw * sh.zzww;
    vec3  p0  = vec3(a0.xy, h.x);
    vec3  p1  = vec3(a0.zw, h.y);
    vec3  p2  = vec3(a1.xy, h.z);
    vec3  p3  = vec3(a1.zw, h.w);
    vec4  norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
    p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;
    vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m * m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}

// ── 7-Fold Swarm ──────────────────────────────────────────────────────
vec3 foldSwarm(vec2 p, float t, int foldIdx, float metabolism, float pull,
               out float intensity) {
    float fi   = float(foldIdx);
    float seed = hash11(fi * 17.3 + 3.3);
    float speed = (0.28 + seed * 0.32) * metabolism;
    
    // High-frequency jitter for "data packet" feel
    float jitter = hash11(t * 60.0 + fi) * 0.002 * (1.0 + ubuf.inferring * 5.0);
    float angle = t * speed + fi * (6.28318 / 7.0) + jitter;

    float orbitMax = 0.16 + seed * 0.10;
    float orbitMin = 0.025;
    float orbitR   = mix(orbitMax, orbitMin, pull);

    vec2 pos = vec2(cos(angle) * orbitR, sin(angle + t * seed * 0.3) * orbitR * 0.7);

    float d     = length(p - pos);
    float blink = mix(1.0, 0.5 + 0.5 * sin(t * 12.0 + fi), ubuf.inferring);
    float glow  = exp(-d * d / (0.0004 + pull * 0.0012)) * (1.0 + pull * 4.0) * blink;
    
    // Sharper "core" for the packet
    float core  = smoothstep(0.015, 0.005, d) * blink;
    
    intensity   = core * 0.95 + glow * 0.6;

    float hues[7];
    hues[0] = 0.38; hues[1] = 0.55; hues[2] = 0.82; hues[3] = 0.68;
    hues[4] = 0.12; hues[5] = 0.97; hues[6] = 0.70;

    float hue = hues[foldIdx];
    float sat = 0.75 + pull * 0.25;
    float val = 0.80 + pull * 0.20 + ubuf.tpsBeat * 0.3;

    return hsv2rgb(vec3(hue, sat, val));
}

void main() {
    vec2  uv     = qt_TexCoord0;
    float asp    = ubuf.w / ubuf.h;
    vec2  p      = vec2(uv.x * asp, uv.y);
    vec2  center = vec2(0.5 * asp, 0.5);
    vec3  color  = vec3(0.0);

    float metabolism  = 1.0 + ubuf.inferring * 1.8 + ubuf.tpsBeat * 1.2;
    float nucleusScale = 1.75 + ubuf.obeliskOpen * 0.38;
    float pull = clamp(ubuf.inferring * ubuf.tpsBeat + ubuf.commandPulse * 0.6, 0.0, 1.0);
    vec2  localP = (p - center) * nucleusScale;

    // 1. Shigurui Core (Organic Nucleus)
    float r = length(localP);
    float boundary = 0.11 + snoise3(vec3(localP * 2.5, ubuf.time * 0.3)) * 0.02;
    float nucleus = smoothstep(boundary, boundary * 0.6, r);
    vec3  nucleusCol = hsv2rgb(vec3(ubuf.disciplineHue, 0.75, 0.85));
    color += nucleusCol * nucleus * (0.5 + ubuf.tpsBeat * 0.5);

    // 2. 7-Fold Swarm (Refined)
    for (int fi = 0; fi < 7; fi++) {
        float pIntensity;
        vec3 pCol = foldSwarm(localP, ubuf.time, fi, metabolism, pull, pIntensity);
        color += pCol * pIntensity * 0.6;
    }

    // Command Flare
    if (ubuf.commandPulse > 0.01) {
        float flare = exp(-pow(r - ubuf.commandPulse * 0.4, 2.0) / 0.0002) * ubuf.commandPulse;
        color += hsv2rgb(vec3(ubuf.disciplineHue, 0.8, 1.0)) * flare;
    }

    float alpha = length(color) * ubuf.qt_Opacity;
    fragColor = vec4(color, clamp(alpha, 0.0, 1.0));
}
