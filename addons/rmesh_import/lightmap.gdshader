shader_type spatial;

// we are using a lightmap, we don't need realtime lighting
render_mode unshaded;

// these 2 are optional, and although unused in the shader,
// allow us to set materials to emit light in the lightmapping stage
uniform float emission;
uniform vec4 emission_color: source_color;

// our input textures, a material texture, and the lightmap
uniform sampler2D texture_albedo: source_color;
uniform sampler2D texture_lightmap: source_color;

void fragment() {
	// lookup the colors at the uv location of our textures
	vec4 albedo_tex = texture(texture_albedo, UV);
	vec4 lightmap_tex = texture(texture_lightmap, UV2);
  
	// the overall albedo (color) will be the material texture TIMES the lightmap
	// (so it can be darkened).
	// you can optionally use a multiplier to allow lightening areas (the 2.0 here)
	ALBEDO = albedo_tex.rgb * lightmap_tex.rgb * 2.0;
}