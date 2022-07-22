package main

Background :: struct {
	kind: enum {
		Solid,
		Slice,
	},
	img:  Image,
	clr:  Color,
}

Rect_Layout :: struct {
	full:    Rectangle,
	current: Rectangle,
}

Rect_Cut :: enum {
	Left,
	Right,
	Up,
	Down,
}

new_rect_layout :: proc(r: Rectangle) -> Rect_Layout {
	return {full = r, current = r}
}

is_rect_valid :: proc()

ensure_cut_valid :: proc(rl: Rect_Layout, cut: Rect_Cut, size: f32) -> (ok: bool) {
	switch cut {
	case .Left, .Right:
		ok = rl.current.width >= size
	case .Up, .Down:
		ok = rl.current.height >= size
	}
	return
}

cut_rect :: proc(rl: ^Rect_Layout, cut: Rect_Cut, size: f32) -> (result: Rectangle) {
	r := rl.current
	switch cut {
	case .Left:
		result = {r.x, r.y, size, r.height}
		rl.current.x += size
		rl.current.width -= size
	case .Right:
		result = {r.x + r.width - size, r.y, size, r.height}
		rl.current.width -= size
	case .Up:
		result = {r.x, r.y, r.width, size}
		rl.current.y += size
		rl.current.height -= size
	case .Down:
		result = {r.x, r.y + r.height - size, r.width, size}
		rl.current.height -= size
	}
	return
}

UI_Context :: struct {
	layouts: [dynamic]Layout,
	m_pos:   Vector,
}
_ctx: ^UI_Context

set_ctx_current :: proc(ctx: ^UI_Context) {
	_ctx = ctx
}

update_ui :: proc(ctx: ^UI_Context) {
	for layout in &ctx.layouts {
		for widget, i in layout.widgets {
			switch w in widget {
			case Button:
				b := w
				update_btn(&b, ctx.m_pos)
				layout.widgets[i] = b
			}
		}
	}
}

draw_ui :: proc(ctx: ^UI_Context, s: ^State) {
	draw_background :: proc(s: ^State, b: Background, bounds: Rectangle) {
		switch b.kind {
		case .Solid:
			draw_rect(bounds, b.clr)
		case .Slice:
		}
	}

	for layout in &ctx.layouts {
		draw_background(s, layout.background, layout.full)
		for widget in &layout.widgets {
			switch w in widget {
			case Button:
				draw_background(s, w.background, w.rect)
				draw_text(s, w.text, {w.rect.x, w.rect.y}, .Text_Light)
			}
		}
	}
}

Layout :: struct {
	using base: Rect_Layout,
	background: Background,
	widgets:    [dynamic]Widget,
	direction:  Rect_Cut,
	padding:    f32,
}

add_layout :: proc(
	r: Rectangle,
	bg: Background,
	d: Rect_Cut,
	h_m,
	v_m,
	p: f32,
) -> ^Layout {
	append(
		&_ctx.layouts,
		Layout{base = new_rect_layout(r), background = bg, direction = d, padding = p},
	)
	l := &_ctx.layouts[len(_ctx.layouts) - 1]
	cut_rect(l, .Left, h_m)
	cut_rect(l, .Right, h_m)
	cut_rect(l, .Up, v_m)
	cut_rect(l, .Down, v_m)
	return l
}

add_widget :: proc(l: ^Layout, widg: Widget, size: f32) {
	widget := widg
	w_rect := cut_rect(l, l.direction, size)
	switch w in &widget {
	case Button:
		w.rect = w_rect
	}
	append(&l.widgets, widget)
}

Widget :: union {
	Button,
}

Button :: struct {
	rect:       Rectangle,
	background: Background,
	state:      enum {
		None,
		Hovered,
		Pressed,
	},
	text:       string,
	clr:        Color,
	press_clr:  Color,
	hover_clr:  Color,
}

update_btn :: proc(b: ^Button, m_pos: Vector) {
	if in_rect_bounds(b.rect, m_pos) {
		b.state = .Hovered
		b.background.clr = b.hover_clr
	} else {
		b.state = .None
		b.background.clr = b.clr
	}
}
