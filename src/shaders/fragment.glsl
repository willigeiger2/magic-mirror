precision mediump float;
varying vec2 v_texCoord;
uniform sampler2D u_texture;
uniform float u_time;
uniform float u_effectStrength;
uniform float u_effectSpeed;
uniform float u_effectId;

#define PI 3.141593
#define FRACTAL_OCTAVES 5.0
#define BLUR_SAMPLES 9.0


float rand(float co) { return fract(sin(co*(91.3458)) * 47453.5453); }
float rand(vec2 co){ return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453); }
float rand(vec3 co){ return rand(co.xy+rand(co.z)); }


float quantize(float x, float q) { return floor(x / q + 0.5) * q; }


float noise(vec3 xyz, float period) {
  xyz /= period;
  float x0 = floor(xyz.x);
  float y0 = floor(xyz.y);
  float z0 = floor(xyz.z);
  float x1 = x0 + 1.0;
  float y1 = y0 + 1.0;
  float z1 = z0 + 1.0;
  float tx = smoothstep(0.0, 1.0, xyz.x - x0);
  float ty = smoothstep(0.0, 1.0, xyz.y - y0);
  float tz = smoothstep(0.0, 1.0, xyz.z - z0);
  
  // Wrap to avoid inaccuracy
  const float wrap = 1024.0;
  x0 = mod(x0, wrap);
  y0 = mod(y0, wrap);
  z0 = mod(z0, wrap);
  x1 = mod(x1, wrap);
  y1 = mod(y1, wrap);
  z1 = mod(z1, wrap);
  return mix(mix(mix(rand(vec3(x0, y0, z0)), rand(vec3(x1, y0, z0)), tx),
                 mix(rand(vec3(x0, y1, z0)), rand(vec3(x1, y1, z0)), tx), ty),
             mix(mix(rand(vec3(x0, y0, z1)), rand(vec3(x1, y0, z1)), tx),
                 mix(rand(vec3(x0, y1, z1)), rand(vec3(x1, y1, z1)), tx), ty), tz);
}

float fractal(vec3 xyz, float period, float gain, float lac) {
    float result = 0.0;
    float mag = 1.0;
    for (float oct = 0.0; oct < FRACTAL_OCTAVES; oct += 1.0) {
        result += mag * (noise(xyz, period) - 0.5);
        mag *= gain;
        period /= lac;
    }
    return result + 0.5;
}


vec2 rotate(vec2 xy, float angle, vec2 pivot) {
  xy -= pivot;
  float x =  cos(angle) * xy.x + sin(angle) * xy.y;
  float y = -sin(angle) * xy.x + cos(angle) * xy.y;
  return vec2(x, y) + pivot;
}

vec4 lookup(sampler2D tex, vec2 xy) {
    return texture2D(tex, xy);
}

vec4 cosblur(vec2 xy, vec2 radius) {
    vec4 result = vec4(0.0, 0.0, 0.0, 0.0);
    float weight = 0.0;
    for (float i = 0.0; i < BLUR_SAMPLES; i += 1.0) {
        for (float j = 0.0; j < BLUR_SAMPLES; j += 1.0) {
            float dx = rand(xy + 3.3 * i + 7.7 * j);
            float dy = rand(xy + 7.3 * i + 3.7 * j);
            float tx = (i + dx) / BLUR_SAMPLES;
            float ty = (j + dy) / BLUR_SAMPLES;
            float x = mod(xy.x + 2.0 * radius.x * (tx - 0.5), 1.0);
            float y = mod(xy.y + 2.0 * radius.y * (ty - 0.5), 1.0);
            float w = cos(PI * length(vec2(tx - 0.5, ty - 0.5)));
            result  += w * texture2D(u_texture, vec2(x, y));
            weight += w;
        }
    }
    return result / weight;
}

vec4 dirblur(sampler2D tex, vec2 xy, vec2 dir, float ditherAmount, float center) {
    vec4 result = vec4(0.0, 0.0, 0.0, 1.0);
    for (float i = 0.0; i < BLUR_SAMPLES; i += 1.0) {
        float dither = mix(0.5, rand(xy), ditherAmount);
        float t = (i + dither) / BLUR_SAMPLES - center;
        result += texture2D(tex, mod(xy + t * dir, 1.0));
    }
    return result / BLUR_SAMPLES;
}

vec4 circgradient(vec4 centerColor, vec4 edgeColor, vec2 center, vec2 radius, vec2 P) {
  float t = length((P - center) / radius);
  return mix(centerColor, edgeColor, t);
}

float smoke(vec2 uv, float t) {
    const float warpScale = 0.66;
    const float warpGain = 0.17 * warpScale;
    vec2 uv_warp = uv;
    uv_warp.y += 0.57 * t;
    float dx = fractal(vec3(uv_warp, 0.0 * 0.02 * t + 0.0), warpScale, 0.52, 2.0) - 0.5;
    float dy = fractal(vec3(uv_warp, 0.0 * 0.02 * t + 7.7), warpScale, 0.52, 2.0) - 0.5;
    uv += vec2(warpGain * dx, warpGain * dy);
    uv.y +=  0.07 * t;
    float v = 0.7 * fractal(vec3(uv, 0.03 * t), 0.5, 0.55, 2.0);
    return v;
}

void main() {
	// Map the effect speed parameter to get a larger, logarithmic range and generate a scaled time value.
	float effectSpeed = u_effectSpeed / 100.0;
	const float logSpeedScale = 5.0;
	effectSpeed = 0.5 * exp(logSpeedScale * effectSpeed) / exp(logSpeedScale * 0.5);
	float effectTime = u_time * effectSpeed;
    
    // Normalized (0..1 effect strength)
	float effectAmount = u_effectStrength / 100.0;
    
    // Effect selection: use u_effectId from uniform
    // If u_effectId is -1.0, cycle through all effects
    float effectId = u_effectId;
    if (u_effectId < 0.0) {
        effectId = mod(floor(0.5 * u_time * effectSpeed + 0.5), 12.0);
    }
   
    // Normalized pixel coordinates (from 0 to 1).
	vec2 uv = v_texCoord;
	vec4 fragColor = texture2D(u_texture, uv);
    
    // For some effects, modulate time with noise for extra glitchiness.
    if (effectId == 0.0 || effectId == 3.0) {
        effectTime += 0.2 * (rand(quantize(effectTime, 0.157)) - 0.5);
	}
    
    if (effectId == 0.0) {
		// Glitch.
		float scalineDistortion = 1.0 * 0.008;
		float scanError = 1.0 * 0.5;
		float verticalShake = 1.0 * 0.5;
		float negative = 1.0;
		float scanlines = 2.0;
        uv.x += effectAmount * scalineDistortion * cos(400.0 * uv.y + 10.0 * effectTime);
		uv.x += effectAmount * scanError * (mod(uv.y + effectTime, 0.2) - 0.1);
        uv.y += effectAmount * verticalShake * (rand(floor(10.0 * effectTime)) - 0.5);
        fragColor = lookup(u_texture, uv);
		fragColor = (effectAmount * negative > rand(floor(10.0 * effectTime)))
			? vec4(vec3(1.0) - fragColor.rgb, 1.0) : fragColor;
        fragColor += effectAmount * scanlines * rand(uv) *
                     cos(77347.87 * uv.y + 20.0 * effectTime + 2.0 *
                     (rand(quantize(uv.x, 0.007)) - 0.5));
    }
    
    else if (effectId == 1.0) {
		// Smear. Sinusoisal distortion with directional blur.
		vec2 streak;
		streak.x = 0.1 * effectAmount * cos(7.0 * uv.y + 1.7 * effectTime);
        streak.y = 0.1 * effectAmount * cos(7.0 * uv.x + 2.9 * effectTime);
		uv += streak;
        fragColor = dirblur(u_texture, uv, streak, 1.0, 0.5);
    }
    
    else if (effectId == 2.0) {
		// Projector: Varying directional blur.
        vec2 streak = uv - vec2(0.5, 0.5);
        streak += vec2(cos(3.8 * effectTime), cos(2.3 * effectTime));
        float ditherAmount = rand(quantize(effectTime, 0.44));
        streak *= effectAmount * 0.1;
        fragColor = dirblur(u_texture, uv, streak, ditherAmount, 0.5);
    }

    else if (effectId == 3.0) {
		// Unlock. Scanline break-up and occasional monochrome.
        float y = uv.y + rand(quantize(effectTime, 75.0/(effectAmount + 0.1)));
        y += 0.2 * rand(quantize(y, 0.077));
        float dx = rand(quantize(y + effectTime, 0.22));
        float dy = 3.0 * effectTime * effectAmount;
        uv.x += 1.0 * effectAmount * (dx - 0.5);
        uv.y = mod(uv.y + dy, 1.0);
        fragColor = lookup(u_texture, uv);
		fragColor.rgb = (effectAmount * 1.0 > rand(floor(10.0 * effectTime)))
			? vec3(0.3 * fragColor.r + 0.59 * fragColor.g + 0.11 * fragColor.b)
			: fragColor.rgb;
    }
    
    else if (effectId == 4.0) {
		// Wobble. Sinusoidal distortion.
 		uv.x += 0.15 * effectAmount * cos(3.7 * uv.y + 0.7 * effectTime);
        uv.y += 0.15 * effectAmount * cos(3.7 * uv.x + 1.9 * effectTime);
		uv.x += 0.05 * effectAmount * cos(13.0 * uv.y + 2.1 * effectTime);
        uv.y += 0.05 * effectAmount * cos(13.0 * uv.x + 2.7 * effectTime);
		uv.x += 0.02 * effectAmount * cos(33.0 * uv.y + 3.3 * effectTime);
        uv.y += 0.02 * effectAmount * cos(33.0 * uv.x + 2.8 * effectTime);
        fragColor = lookup(u_texture, uv);
    }
    
    else if (effectId == 5.0) {
        // Posterize.
		if (effectAmount > 0.0) {
			float q = mix(0.004, 1.0, pow(effectAmount, 1.7));
			float dr = fractal(vec3(uv, 0.257 * effectTime + 0.0), 0.25, 0.5, 2.0) - 0.5;
			float dg = fractal(vec3(uv, 0.242 * effectTime + 7.7), 0.25, 0.5, 2.0) - 0.5;
			float db = fractal(vec3(uv, 0.247 * effectTime + 5.3), 0.25, 0.5, 2.0) - 0.5;
			float r = quantize(fragColor.r + 1.0 * q * dr, q);
			float g = quantize(fragColor.g + 1.0 * q * dg, q);
			float b = quantize(fragColor.b + 1.0 * q * db, q);
			fragColor.rgb = vec3(r, g, b);
		}
   }
    
    else if (effectId == 6.0) {
        // Quicksilver. Fractal displacement.
        vec2 uv_noise = uv;
        float dx = fractal(vec3(uv_noise, 0.057 * effectTime + 0.0), 0.3, 0.5, 2.0) - 0.5;
        float dy = fractal(vec3(uv_noise, 0.042 * effectTime + 7.7), 0.3, 0.5, 2.0) - 0.5;
        uv += 0.3 * effectAmount * vec2(dx, dy);
        fragColor = lookup(u_texture, uv);
    }
    
    else if (effectId == 7.0) {
        // Twist.
        float ar = 1.0;//iResolution.x / iResolution.y;
        float inner = 2.0 * effectAmount * sin(2.0 * effectTime);
        float outer = 2.0 * effectAmount * sin(0.0 * effectTime);
        float r = length(uv - 0.5);
        uv.y = (uv.y - 0.5) / ar + 0.5;
        uv = rotate(uv, 2.0 * PI * mix(inner, outer, r), vec2(0.5, 0.5));
        uv.y = (uv.y - 0.5) * ar + 0.5;
        vec2 streak = 0.5 * (uv - v_texCoord);
        fragColor = dirblur(u_texture, uv, streak, 1.0, 0.5);
    }
    
    else if (effectId == 8.0) {
        // Smolder. Fractal variation.
        float frac = 0.7 * (fractal(vec3(uv, 0.1 * effectTime + 0.0), 0.35, 0.5, 2.0) - 0.5) + 0.5;
        float edge = effectAmount;
        float edgeWidth = 0.03;
		float invGamma = mix(3.0, 1.0, smoothstep(edge - edgeWidth, edge + edgeWidth, frac));
		fragColor.r = pow(fragColor.r, invGamma);
		fragColor.g = pow(fragColor.g, invGamma);
		fragColor.b = pow(fragColor.b, invGamma);
        fragColor.rgb += smoothstep(edge - edgeWidth, edge, frac) *
                         smoothstep(edge + edgeWidth, edge, frac) * vec3(1.0, 0.7, 0.5) * 0.85;
    }
    
    else if (effectId == 9.0) {
		// Wet. Fractal-varying blur with downward motion.
		vec3 fractalCoord = vec3(uv.x, 0.5 * uv.y - 0.2 * effectTime, 0.257 * effectTime + 0.0);
		float blurAmount = 2.0 * (fractal(fractalCoord, 0.35, 0.5, 2.0) - 0.5);
        fragColor = cosblur(uv, vec2(0.2 * effectAmount * blurAmount));
    }
    
    else if (effectId == 10.0) {
		// Rainbow. Adds fractal colors, additive and subtractive.
        float amount = 2.0 * effectAmount;
        float dr = fractal(vec3(uv, 0.257 * effectTime + 0.0), 0.35, 0.5, 2.0) - 0.5;
        float dg = fractal(vec3(uv, 0.242 * effectTime + 7.7), 0.35, 0.5, 2.0) - 0.5;
        float db = fractal(vec3(uv, 0.247 * effectTime + 5.3), 0.35, 0.5, 2.0) - 0.5;
		fragColor.rgb += amount * vec3(dr, dg, db);
   }
    
    else if (effectId == 11.0) {
		// Smoke.
        const float loopLength = 30.0;
        float t0 = mod(2.0 * effectTime, loopLength);
        float t1 = mod(2.0 * effectTime + 0.5 * loopLength, loopLength);
        float w0 = 0.5 * (1.0 - cos(2.0 * PI * t0 / loopLength));
        float w1 = 0.5 * (1.0 - cos(2.0 * PI * t1 / loopLength));
        
        const float colorSmear = 0.30;
        float gain = 1.5 * pow(effectAmount, 0.35) * pow(uv.y, 0.5);
		vec3 smokeColor;
        smokeColor.g = gain * (w0 * smoke(uv, t0) + w1 * smoke(uv, t1 + 137.1));
        smokeColor.r = gain * (w0 * smoke(uv, t0 + colorSmear) + w1 * smoke(uv, t1 + 137.1 + colorSmear));
        smokeColor.b = gain * (w0 * smoke(uv, t0 - colorSmear) + w1 * smoke(uv, t1 + 137.1 - colorSmear));

		fragColor.rgb += smokeColor - 2.5 * smokeColor * fragColor.rgb;
    }
    
    else if (effectId == -1.0) {
        //fragColor.rgb = vec3(noise(vec3(uv, 0.1 * iTime), 0.1));
        fragColor.rgb = 0.7 * vec3(fractal(vec3(uv, 0.1 * effectTime), 0.1, 0.5, 2.0));
    }

	gl_FragColor = fragColor;
}
