#version 460 core

precision highp float;

#include <flutter/runtime_effect.glsl>

// Uniforms passed from Flutter
uniform vec2 u_resolution;
uniform float u_time;
uniform float u_audioLevel;
uniform vec2 u_center;

// Input/Output
out vec4 fragColor;

// Texture sampler for the input image
uniform sampler2D u_texture;

void main() {
    // Normalize coordinates
    vec2 uv = FlutterFragCoord().xy / u_resolution.xy;
    
    // Calculate distance from center
    vec2 center = u_center / u_resolution.xy;
    float dist = distance(uv, center);
    
    // Create ripple effect based on audio level and time
    float rippleStrength = u_audioLevel * 0.1; // Adjust intensity
    float rippleFreq = 8.0; // Number of ripples
    float rippleSpeed = 2.0; // Speed of ripple propagation
    
    // Generate multiple ripples with different phases
    float ripple1 = sin(dist * rippleFreq - u_time * rippleSpeed) * rippleStrength;
    float ripple2 = sin(dist * rippleFreq * 1.5 - u_time * rippleSpeed * 0.8) * rippleStrength * 0.6;
    float ripple3 = sin(dist * rippleFreq * 0.7 - u_time * rippleSpeed * 1.2) * rippleStrength * 0.4;
    
    // Combine ripples with falloff based on distance
    float falloff = exp(-dist * 2.0); // Exponential falloff
    float totalRipple = (ripple1 + ripple2 + ripple3) * falloff;
    
    // Create displacement vector
    vec2 displacement = normalize(uv - center) * totalRipple;
    
    // Sample the texture with displacement
    vec2 distortedUV = uv + displacement;
    
    // Ensure UV coordinates stay within bounds
    distortedUV = clamp(distortedUV, 0.0, 1.0);
    
    // Sample the texture
    vec4 texColor = texture(u_texture, distortedUV);
    
    // Apply subtle color shift for enhanced effect
    float colorShift = totalRipple * 0.1;
    texColor.rgb += vec3(colorShift * 0.2, colorShift * 0.1, colorShift * 0.3);
    
    fragColor = texColor;
}