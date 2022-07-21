package main

import rl "vendor:raylib"

Font :: rl.Font
load_font :: rl.LoadFontEx

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
Color :: rl.Color

// Input
elapsed_time :: rl.GetFrameTime
mouse_position :: rl.GetMousePosition
is_mouse_pressed :: rl.IsMouseButtonPressed
is_mouse_released :: rl.IsMouseButtonReleased
is_key_pressed :: rl.IsKeyPressed

// Draw
draw_line :: rl.DrawLineEx
draw_rect :: rl.DrawRectangleRec
draw_rect_line :: rl.DrawRectangleLinesEx
draw_text :: proc(f: Font, s: string, p: Vector, size: int, clr: Color) {
	rl.DrawTextEx(f, cstring(raw_data(s)), p, f32(size), 0, clr)
}
