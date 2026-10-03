// REFERENCE COPY (round 16): the shader as it was before render R3/R4, for within-run A/B layers (RenderLayers *_r15). Not used in play.
// The arena floor, tier high, lit in the shader instead of by the renderer (render X5, round 5): the floor is flat and,
// since X3, nothing casts a dynamic shadow on it, so its moon and ambient light are constants. Skipping the engine's lit
// pass on the biggest surface on screen is the saving; pooled lights no longer touch the floor (the effects' own ground
// glows stand in for them).
shader_type spatial;
render_mode unshaded, cull_back;

#define GROUND_HIGH
#define GROUND_UNLIT
#include "res://game/theme/fx/shaders/reference/arena_ground_r15.gdshaderinc"
