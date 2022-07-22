package main

// import "core:fmt"
import "core:mem"

GAME_WIDTH :: 1280
GAME_HEIGHT :: 720
FONT_SIZE :: 16

Game :: struct {
	arena:          mem.Arena,
	allocator:      mem.Allocator,
	temp_arena:     mem.Arena,
	temp_allocator: mem.Allocator,
	on_load:        proc(g: ^Game),
	on_update:      proc(g: ^Game),
	on_draw:        proc(g: ^Game),
	on_exit:        proc(g: ^Game),

	// 
	s:              State,
	ui:             UI_Context,
	prototypes:     map[string]Chip,
	bench:          Workbench,
	action:         Action,
	cursor:         Cursor,
	// cmd_panel
}

State :: struct {
	active_rect:    Rectangle,
	font:           Font,
	theme:          map[Theme_Palette]Color,
	outline_weight: f32,
	line_weight:    f32,
	pin_sprite:     Image,
	cell_size:      f32,
}

Theme_Palette :: enum {
	// UI Elements
	Background,
	Background_Light,
	Panel_Background,
	Text_Light,
	Text_Dark,
	Separator,

	// Gameplay elements
	Chip,
	Pin,
	Circuit_Wait,
	Circuit_Process,
	Circuit_Loaded,
	Process_Anim,
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
	game_layout := new_rect_layout({0, 0, GAME_WIDTH, GAME_HEIGHT})
	bottom_panel := cut_rect(&game_layout, .Down, 40)

	g.s = {
		active_rect = game_layout.current,
		font = load_font("assets/FiraSans-Regular.ttf", 24),
		theme = map[Theme_Palette]Color{
			.Background = {29, 31, 33, 255},
			.Background_Light = {43, 46, 49, 255},
			.Panel_Background = {23, 25, 26, 255},
			.Text_Dark = {44, 38, 44, 255},
			.Text_Light = {235, 219, 178, 255},
			.Separator = {60, 54, 60, 255},
			.Chip = {},
			.Pin = {9, 11, 13, 255},
			.Circuit_Wait = {111, 107, 91, 255},
			.Circuit_Process = {255, 189, 47, 255},
			.Circuit_Loaded = {251, 70, 48, 255},
			.Process_Anim = {251, 70, 48, 255},
		},
		outline_weight = 2,
		line_weight = 1,
		pin_sprite = load_image("assets/circle.png", .Trilinear),
		cell_size = 16,
	}

	// UI setup
	set_ctx_current(&g.ui)
	l := add_layout(
		bottom_panel,
		Background{kind = .Solid, clr = g.s.theme[.Panel_Background]},
		.Left,
		6,
		4,
		2,
	)
	add_widget(
		l,
		Button{
			text = "hello",
			background = {kind = .Solid},
			clr = g.s.theme[.Background_Light],
			hover_clr = highlight(g.s.theme[.Background_Light], 1.3),
		},
		50,
	)

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
				gx, gy := to_grid(&g.s, m_pos)
				fixed_pos := to_screen(&g.s, gx, gy)
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
			gx, gy := to_grid(&g.s, m_pos - g.cursor.offset)
			fixed_pos := to_screen(&g.s, gx, gy)
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

	g.ui.m_pos = m_pos
	update_ui(&g.ui)
}

on_draw :: proc(g: ^Game) {
	draw_rect(g.s.active_rect, g.s.theme[.Background])
	draw_workbench(&g.s, &g.bench)

	if g.action == .Connect_Pins {
		start := g.cursor.selection.(^Pin_Interface)
		draw_line(
			{start.rect.x + PIN_SIZE / 2, start.rect.y + PIN_SIZE / 2},
			mouse_position(),
			1,
			g.s.theme[.Circuit_Wait],
		)
	}

	draw_ui(&g.ui, &g.s)
}

on_exit :: proc(g: ^Game) {

}

deselect :: proc(g: ^Game) {
	g.action = .Idle
	g.cursor.selection = nil
	g.cursor.offset = {}
}
