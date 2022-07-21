package main

// import "core:fmt"

WIDTH :: 800

Game :: struct {
	on_load:    proc(g: ^Game),
	on_update:  proc(g: ^Game),
	on_draw:    proc(g: ^Game),
	on_exit:    proc(g: ^Game),

	// 
	s:          State,
	prototypes: map[string]Chip,
	bench:      Workbench,
	action:     Action,
	cursor:     Cursor,
}

State :: struct {
	font: Font,
	grid: Grid,
}

Action :: enum {
	Idle,
	Drag_Chip,
	Connect_Pins,
}

Cursor :: struct {
	hover:     Cursor_Selection,
	selection: Cursor_Selection,
	chip_id:   int,
	offset:    Vector,
}

Cursor_Selection :: union {
	^Chip_Interface,
	^Pin_Interface,
}

on_load :: proc(g: ^Game) {
	g.s = {
		font = load_font("assets/FiraSans-Regular.ttf", 16, nil, 128),
		grid = {cell_size = 16},
	}
    //odinfmt: disable
    g.prototypes["nand"] = Chip {
		input_pins  = {true, true},
		output_pins = make([]Value, 1),
		bytecode = NAND_BYTECODE[:],
	}
    //odinfmt: enable
	init_workbench(&g.bench, &g.s)
}

on_update :: proc(g: ^Game) {
	m_pos := mouse_position()


	g.cursor.hover = nil
	for _, i in g.bench.chips {
		chip := &g.bench.chips[i]
		if s := is_chip_selected(chip, m_pos); s != nil {
			g.cursor.hover = s
			g.cursor.chip_id = i
			break
		}
	}
	if g.cursor.hover == nil {
		if s := is_workench_pin_selected(&g.bench, m_pos); s != nil {
			g.cursor.hover = s
		}
	}

	// fmt.println(g.cursor.hover)

	switch g.action {
	case .Idle:
		switch h in g.cursor.hover {
		case ^Chip_Interface:
			switch {
			case is_mouse_pressed(.LEFT):
				g.action = .Drag_Chip
				g.cursor.selection = g.cursor.hover
				g.cursor.offset = m_pos - (h.pos + get_chip_center(h))

			case is_mouse_pressed(.RIGHT):
				remove_chip_interface(&g.bench, h, g.cursor.chip_id)
			}

		case ^Pin_Interface:
			if is_mouse_pressed(.LEFT) {
				g.action = .Connect_Pins
				g.cursor.selection = g.cursor.hover
			}

		case:
			if is_mouse_pressed(.LEFT) {
				gx, gy := to_grid(&g.s.grid, m_pos)
				fixed_pos := to_screen(&g.s.grid, gx, gy)
				add_chip_interface(&g.bench, fixed_pos, "nand")
			} else if is_key_pressed(.SPACE) {
				start_workbench_simulation(&g.bench, g.prototypes)
			}
		}

	case .Drag_Chip:
		if is_mouse_released(.LEFT) {
			deselect(g)
			return
		} else {
			gx, gy := to_grid(&g.s.grid, m_pos - g.cursor.offset)
			fixed_pos := to_screen(&g.s.grid, gx, gy)
			drag := g.cursor.selection.(^Chip_Interface)
			move_chip_interface(drag, fixed_pos)
		}

	case .Connect_Pins:
		if is_mouse_pressed(.LEFT) {
			switch h in g.cursor.hover {
			case ^Chip_Interface:
			case ^Pin_Interface:
				connect_pins(&g.bench, g.cursor.selection.(^Pin_Interface), h)
			case:
			}
			deselect(g)
		}
	}

	update_workbench(&g.bench, elapsed_time())
}

on_draw :: proc(g: ^Game) {
	draw_workbench(&g.s, &g.bench)

	if g.action == .Connect_Pins {
		start := g.cursor.selection.(^Pin_Interface)
		draw_line(
			{start.rect.x + PIN_SIZE / 2, start.rect.y + PIN_SIZE / 2},
			mouse_position(),
			1,
			{255, 255, 255, 255},
		)
	}
}

on_exit :: proc(g: ^Game) {

}

deselect :: proc(g: ^Game) {
	g.action = .Idle
	g.cursor.selection = nil
	g.cursor.offset = {}
}
