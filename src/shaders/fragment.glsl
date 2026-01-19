precision mediump float;
varying vec2 v_texCoord;
uniform sampler2D u_texture;
uniform float u_time;
uniform float u_distortionAmount;
uniform float u_distortionSpeed;
uniform float u_colorShift;

void main() {
	vec2 uv = v_texCoord;
	
	// Apply wave distortion
	float distortion = u_distortionAmount * 0.01;
	float speed = u_distortionSpeed * 0.01;
	uv.x += sin(uv.y * 10.0 + u_time * speed) * distortion * 0.05;
	uv.y += cos(uv.x * 10.0 + u_time * speed) * distortion * 0.05;
	
	// Sample the texture
	vec4 color = texture2D(u_texture, uv);
	
	// Apply color shift effect
	float shift = u_colorShift * 0.01;
	if (shift > 0.0) {
		vec2 offset = vec2(0.005 * shift, 0.0);
		float r = texture2D(u_texture, uv + offset).r;
		float g = texture2D(u_texture, uv).g;
		float b = texture2D(u_texture, uv - offset).b;
		color = vec4(r, g, b, 1.0);
	}
	
	gl_FragColor = color;
}
