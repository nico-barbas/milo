package main

import "core:strings"
import "core:math/linalg"
import rl "vendor:raylib"

to_grid :: proc(s: ^State, p: Vector) -> (x, y: int) {
	return int(p.x / s.cell_size), int(p.y / s.cell_size)
}

to_screen :: proc(s: ^State, x, y: int) -> Vector {
	return {s.cell_size * f32(x), s.cell_size * f32(y)}
}


Font :: struct {
	using data: rl.Font,
	size:       f32,
	ascend:     f32,
}
load_font :: proc(path: string, size: int) -> Font {
	cpath := strings.clone_to_cstring(path, context.temp_allocator)
	return Font{
		data = rl.LoadFontEx(cpath, i32(size), nil, 128),
		size = f32(size),
		ascend = f32(size),
	}
}

measure_text :: proc(f: Font, text: string) -> Vector {
	return rl.MeasureTextEx(f, cstring(raw_data(text)), f.size, 0)
}

center_text :: proc(f: Font, text: string, bounds: Rectangle) -> Vector {
	text_size := measure_text(f, text)
	return {
		bounds.x + (bounds.width - text_size.x) / 2,
		bounds.y + (bounds.height - text_size.y) / 2,
	}
}

Rectangle :: rl.Rectangle
in_rect_bounds :: proc(r: Rectangle, p: Vector) -> bool {
	if p.x < r.x || p.x > r.x + r.width {
		return false
	}
	if p.y < r.y || p.y > r.y + r.height {
		return false
	}
	return true
}


Vector :: rl.Vector2
Edge :: [2]Vector

edge_slice_length :: proc(e: []Edge) -> f32 {
	length: f32
	for edge in e {
		length += linalg.length(edge[0] - edge[1])
	}
	return length
}

Color :: rl.Color

highlight :: proc(c: Color, s: f32) -> Color {
	return {u8(f32(c.r) * s), u8(f32(c.g) * s), u8(f32(c.b) * s), c.a}
}

Image :: struct {
	data:   rl.Texture,
	bounds: Rectangle,
}

Image_Filter :: enum {
	Point     = int(rl.TextureFilter.POINT),
	Bilinear  = int(rl.TextureFilter.BILINEAR),
	Trilinear = int(rl.TextureFilter.TRILINEAR),
}

load_image :: proc(path: string, filter: Image_Filter) -> Image {
	cpath := strings.clone_to_cstring(path, context.temp_allocator)
	img := Image {
		data = rl.LoadTexture(cpath),
	}
	img.bounds = {0, 0, f32(img.data.width), f32(img.data.height)}
	rl.SetTextureFilter(img.data, rl.TextureFilter(filter))
	return img
}


// Input
elapsed_time :: rl.GetFrameTime
mouse_position :: rl.GetMousePosition
is_mouse_pressed :: rl.IsMouseButtonDown
is_mouse_just_pressed :: rl.IsMouseButtonPressed
is_mouse_released :: rl.IsMouseButtonReleased
is_key_pressed :: rl.IsKeyPressed

// Draw
draw_line :: rl.DrawLineEx
draw_rect :: rl.DrawRectangleRec
draw_rect_line :: rl.DrawRectangleLinesEx
draw_text :: proc(s: ^State, text: string, p: Vector, k: Theme_Palette) {
	rl.DrawTextEx(s.font, cstring(raw_data(text)), p, s.font.size, 0, s.theme[k])
}
draw_sub_image :: proc(
	i: Image,
	src,
	dst: Rectangle,
	clr: Color,
	o := Vector{0, 0},
	r: f32 = 0,
) {
	rl.DrawTexturePro(i.data, src, dst, o, r, clr)
}


Timer :: struct {
	tick_rate:   f32,
	accumulator: f32,
	reset:       bool,
}

advance_timer :: proc(t: ^Timer, dt: f32) -> (finished: bool) {
	t.accumulator += dt
	if t.accumulator >= t.tick_rate {
		finished = true
		if t.reset do t.accumulator = 0
	}
	return
}
