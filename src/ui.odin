package main

Background :: struct {
	kind: enum {
		Transparent,
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

cut_rect :: proc(
	rl: ^Rect_Layout,
	cut: Rect_Cut,
	size: f32,
	p: f32 = 0,
) -> (
	result: Rectangle,
) {
	r := rl.current
	switch cut {
	case .Left:
		result = {r.x, r.y, size, r.height}
		rl.current.x += size + p
		rl.current.width -= size + p
	case .Right:
		result = {r.x + r.width - size, r.y, size, r.height}
		rl.current.width -= size + p
	case .Up:
		result = {r.x, r.y, r.width, size}
		rl.current.y += size + p
		rl.current.height -= size + p
	case .Down:
		result = {r.x, r.y + r.height - size, r.width, size}
		rl.current.height -= size + p
	}
	return
}

UI_Context :: struct {
	layouts: [dynamic]Layout,
	m_pos:   Vector,
	m_left: bool,
	pm_left: bool,
}
_ctx: ^UI_Context

set_ctx_current :: proc(ctx: ^UI_Context) {
	_ctx = ctx
}

update_ui :: proc(ctx: ^UI_Context,m_pos: Vector,  m_left: bool) {
	ctx.pm_left = ctx.m_left
	ctx.m_left = m_left
	ctx.m_pos = m_pos
	for layout in &ctx.layouts {
		for widget, i in layout.widgets {
			switch w in widget {
			case Button:
				b := w
				update_btn(&b, ctx.m_pos, ctx.m_left)
				layout.widgets[i] = b
			}
		}
	}
}

draw_ui :: proc(ctx: ^UI_Context, s: ^State) {
	draw_background :: proc(s: ^State, b: Background, bounds: Rectangle) {
		switch b.kind {
		case .Transparent:
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
	w_rect := cut_rect(l, l.direction, size, l.padding)
	switch w in &widget {
	case Button:
		w.rect = w_rect
	}
	append(&l.widgets, widget)
}

Widget :: union {
	Button,
}

Button_ID :: distinct int

Button :: struct {
	rect:       Rectangle,
	background: Background,
	id: Button_ID,
	state:      enum {
		None,
		Hovered,
		Pressed,
	},
	text:       string,
	clr:        Color,
	press_clr:  Color,
	hover_clr:  Color,
	user_data: rawptr,
	callback: proc(data: rawptr, id: Button_ID),
}

update_btn :: proc(b: ^Button, m_pos: Vector, m_left, pm_left: bool) {
	if in_rect_bounds(b.rect, m_pos) {
		if m_left {
			b.state = .Pressed
			b.background.clr = b.hover_clr
			if b.callback != nil {
				b.callback(b.user_data, b.id)
			}
		} else {
			b.state = .Hovered
			b.background.clr = b.hover_clr
		}
	} else {
		b.state = .None
		b.background.clr = b.clr
	}
}
