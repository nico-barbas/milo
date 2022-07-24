package main

// import "core:fmt"

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
	m_left:  bool,
	pm_left: bool,
	state:   ^State,
}
_ctx: ^UI_Context

set_ctx_current :: proc(ctx: ^UI_Context) {
	_ctx = ctx
}

update_ui :: proc(ctx: ^UI_Context, m_pos: Vector, m_left: bool) {
	ctx.pm_left = ctx.m_left
	ctx.m_left = m_left
	ctx.m_pos = m_pos
	for _, i in ctx.layouts {
		layout := &ctx.layouts[i]
		update_layout(layout, ctx.m_pos, ctx.m_left, ctx.pm_left)
	}
}

draw_ui :: proc(ctx: ^UI_Context, s: ^State) {
	for _, i in &ctx.layouts {
		layout := &ctx.layouts[i]
		draw_layout(layout)
	}
}

is_over_ui :: proc(p: Vector) -> bool {
	for _, i in _ctx.layouts {
		layout := &_ctx.layouts[i]
		if is_over_layout(layout, p) {
			return true
		}
	}
	return false
}

Layout :: struct {
	using base: Rect_Layout,
	grow:       bool,
	background: Background,
	shown:      bool,
	widgets:    [dynamic]Widget,
	direction:  Rect_Cut,
	margin:     Vector,
	padding:    f32,
}

init_layout :: proc(l: ^Layout) -> ^Layout {
	cut_rect(l, .Left, l.margin.x)
	cut_rect(l, .Right, l.margin.x)
	cut_rect(l, .Up, l.margin.y)
	cut_rect(l, .Down, l.margin.y)
	return l
}

add_layout :: proc(
	r: Rectangle,
	bg: Background,
	d: Rect_Cut,
	m: Vector,
	p: f32,
) -> ^Layout {
	append(
		&_ctx.layouts,
		Layout{
			base = new_rect_layout(r),
			background = bg,
			shown = true,
			direction = d,
			margin = m,
			padding = p,
		},
	)
	l := &_ctx.layouts[len(_ctx.layouts) - 1]
	init_layout(l)
	return l
}

add_widget :: proc(l: ^Layout, widg: Widget, size: f32) -> ^Widget {
	widget := widg

	// ok := ensure_cut_valid(l, l.direction, size)
	// if !ok {
	// 	switch l.grow {
	// 	case true:
	// 		grow_rect_layout(l, l.direction, size + l.padding)
	// 		switch l.direction {
	// 		case .Left:

	// 		case .Right:
	// 		case .Up:
	// 		case .Down:
	// 		}
	// 	case false:
	// 		// FIXME: return error
	// 		return nil
	// 	}
	// }
	w_rect := cut_rect(l, l.direction, size, l.padding)
	switch w in &widget {
	case Button:
		w.rect = w_rect
	case Dropdown_Panel:
		w.rect = w_rect
		w.layout = Layout {
			base = new_rect_layout(
				{w_rect.x, w.rect.y - w.panel_size.y, w.panel_size.x, w.panel_size.y},
			),
			background = w.background,
			shown = true,
			direction = .Up,
			margin = {0, l.margin.y},
			padding = l.padding,
		}
		w.layout.background.clr = w.clr
		init_layout(&w.layout)
		w.layout.shown = false
	}
	append(&l.widgets, widget)
	return &l.widgets[len(l.widgets) - 1]
}

update_layout :: proc(l: ^Layout, m_pos: Vector, m_left, pm_left: bool) {
	if !l.shown {
		return
	}
	for widget, i in l.widgets {
		switch w in widget {
		case Button:
			b := w
			update_btn(&b, m_pos, m_left, pm_left)
			l.widgets[i] = b

		case Dropdown_Panel:
			d := w
			update_dropdown(&d, m_pos, m_left, pm_left)
			l.widgets[i] = d
		}
	}
}

draw_layout :: proc(l: ^Layout) {
	draw_background :: proc(s: ^State, b: Background, bounds: Rectangle) {
		switch b.kind {
		case .Transparent:
		case .Solid:
			draw_rect(bounds, b.clr)
		case .Slice:
		}
	}

	if !l.shown {
		return
	}
	draw_background(_ctx.state, l.background, l.full)
	for widget in &l.widgets {
		switch w in &widget {
		case Button:
			draw_background(_ctx.state, w.background, w.rect)
			draw_text(
				_ctx.state,
				w.text,
				center_text(_ctx.state.font, w.text, w.rect),
				.Text_Light,
			)

		case Dropdown_Panel:
			draw_background(_ctx.state, w.background, w.rect)
			draw_text(
				_ctx.state,
				w.text,
				center_text(_ctx.state.font, w.text, w.rect),
				.Text_Light,
			)
			draw_layout(&w.layout)
		}
	}
}

is_over_layout :: proc(l: ^Layout, p: Vector) -> bool {
	if !l.shown {
		return false
	}
	#partial switch l.background.kind {
	case .Solid, .Slice:
		if in_rect_bounds(l.full, p) {
			return true
		}
		fallthrough
	case:
		for _, i in l.widgets {
			widget := &l.widgets[i]
			if is_over_widget(widget, p) {
				return true
			}
		}
	}
	return false
}

Widget :: union {
	Button,
	Dropdown_Panel,
}

is_over_widget :: proc(widget: ^Widget, p: Vector) -> bool {
	switch w in widget {
	case Button:
		return in_rect_bounds(w.rect, p)
	case Dropdown_Panel:
		if is_over_layout(&w.layout, p) {
			return true
		}
		return in_rect_bounds(w.rect, p)
	}
	return false
}

Button_ID :: distinct int

Button :: struct {
	rect:       Rectangle,
	background: Background,
	id:         Button_ID,
	state:      enum {
		None,
		Hovered,
		Pressed,
	},
	text:       string,
	clr:        Color,
	press_clr:  Color,
	hover_clr:  Color,
	user_data:  rawptr,
	callback:   proc(data: rawptr, id: Button_ID),
}

update_btn :: proc(b: ^Button, m_pos: Vector, m_left, pm_left: bool) {
	if in_rect_bounds(b.rect, m_pos) {
		if !m_left && pm_left {
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

Dropdown_Panel :: struct {
	layout:     Layout,
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

	// Init data
	panel_size: Vector,
}

update_dropdown :: proc(d: ^Dropdown_Panel, m_pos: Vector, m_left, pm_left: bool) {
	if in_rect_bounds(d.rect, m_pos) {
		if !m_left && pm_left {
			d.state = .Pressed
			d.background.clr = d.hover_clr
			d.layout.shown = !d.layout.shown
		} else {
			d.state = .Hovered
			d.background.clr = d.hover_clr
		}
	} else {
		d.state = .None
		d.background.clr = d.clr
	}

	update_layout(&d.layout, m_pos, m_left, pm_left)
}
