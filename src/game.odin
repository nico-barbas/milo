package main

// import "core:fmt"
import "core:mem"

GAME_WIDTH :: 1280
GAME_HEIGHT :: 720
FONT_SIZE :: 16

WORKBENCH_MARGIN :: 200
WORKBENCH_MIN_PINS :: 1
WORKBENCH_MAX_PINS :: 6
WORKBENCH_TOGGLE_SIZE :: 32
WORKBENCH_TOGGLE_WIDTH :: 10
WORKBENCH_TOGGLE_HEIGHT :: 6
WORKBENCH_BTN_SIZE :: WORKBENCH_TOGGLE_SIZE * 0.75
WORKBENCH_BTN_PADDING :: 5

WORKBENCH_TICK_RATE :: 2

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
	prototype_id:   string,
	// cmd_panel
}

State :: struct {
	active_rect:    Rectangle,
	bottom_rect:    Rectangle,
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
	Bit_On,
	Bit_Off,
	Chip,
	Pin,
	Circuit_Wait,
	Circuit_Process,
	Circuit_Loaded,
	Process_Anim,
	Nand_Chip,
	And_Chip,
	Or_Chip,
	Not_Chip,
}

Game_Button_ID :: enum Button_ID {
	Input_Add,
	Input_Sub,
	Output_Add,
	Output_Sub,

	//
	Nand,
	And,
	Or,
	Not,
}

Action :: enum {
	Idle,
	Drag_Chip,
	Connect_Pins,
}

Cursor :: struct {
	hover:          Cursor_Selection,
	selection:      Cursor_Selection,
	chip_id:        int,
	offset:         Vector,
	start_point:    Vector,
	current_point:  Vector,
	circuit_schema: [10]Edge,
	schema_count:   int,
}

Cursor_Selection :: union {
	^Chip_Interface,
	^Workbench_Pin,
	^Pin_Interface,
}

on_load :: proc(g: ^Game) {
	game_layout := new_rect_layout({0, 0, GAME_WIDTH, GAME_HEIGHT})

	g.s = {
		active_rect = game_layout.current,
		bottom_rect = cut_rect(&game_layout, .Down, 40),
		font = load_font("assets/FiraSans-Regular.ttf", 24),
		theme = map[Theme_Palette]Color{
			.Background = {29, 31, 33, 255},
			.Background_Light = {43, 46, 49, 255},
			.Panel_Background = {23, 25, 26, 255},
			.Text_Dark = {44, 38, 44, 255},
			.Text_Light = {235, 219, 178, 255},
			.Separator = {60, 54, 60, 255},
			.Bit_Off = {9, 11, 13, 255},
			.Bit_On = {251, 70, 48, 255},
			.Chip = {},
			.Pin = {9, 11, 13, 255},
			.Circuit_Wait = {111, 107, 91, 255},
			.Circuit_Process = {255, 189, 47, 255},
			.Circuit_Loaded = {251, 70, 48, 255},
			.Process_Anim = {251, 70, 48, 255},
			.Nand_Chip = {211, 134, 147, 255},
			.And_Chip = {131, 165, 152, 255},
			.Or_Chip = {184, 187, 38, 255},
			.Not_Chip = {184, 187, 38, 255},
		},
		outline_weight = 2,
		line_weight = 1,
		pin_sprite = load_image("assets/circle.png", .Trilinear),
		cell_size = 16,
	}


	g.prototypes = map[string]Chip {
		"nand" = Chip{
			input_pins = make([]Value, 2),
			output_pins = make([]Value, 1),
			bytecode = NAND_BYTECODE[:],
		},
		"and" = Chip{
			input_pins = make([]Value, 2),
			output_pins = make([]Value, 1),
			bytecode = AND_BYTECODE[:],
		},
		"or" = Chip{
			input_pins = make([]Value, 2),
			output_pins = make([]Value, 1),
			bytecode = OR_BYTECODE[:],
		},
		"not" = Chip{
			input_pins = make([]Value, 1),
			output_pins = make([]Value, 1),
			bytecode = NOT_BYTECODE[:],
		},
	}
	g.prototype_id = "nand"
	init_workbench(&g.bench, &g.s)
	init_game_ui(g)
}

on_update :: proc(g: ^Game) {
	m_pos := mouse_position()
	m_left := is_mouse_pressed(.LEFT)

	if !is_over_ui(m_pos) {
		handle_gameplay_input(g, m_pos)
	}

	g.ui.state = &g.s
	update_ui(&g.ui, m_pos, m_left)
}

on_draw :: proc(g: ^Game) {
	draw_rect(g.s.active_rect, g.s.theme[.Background])
	draw_workbench(&g.s, &g.bench)

	if g.action == .Connect_Pins {
		// start := g.cursor.selection.(^Pin_Interface)
		draw_line(
			g.cursor.start_point,
			g.cursor.current_point,
			1,
			g.s.theme[.Circuit_Wait],
		)
		for i in 0 ..< g.cursor.schema_count {
			edge := g.cursor.circuit_schema[i]
			draw_line(edge[0], edge[1], 1, g.s.theme[.Circuit_Wait])
		}
	}

	draw_ui(&g.ui, &g.s)
}

on_exit :: proc(g: ^Game) {

}

handle_gameplay_input :: proc(g: ^Game, m_pos: Vector) {
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

	switch g.action {
	case .Idle:
		switch h in g.cursor.hover {
		case ^Chip_Interface:
			switch {
			case is_mouse_just_pressed(.LEFT):
				g.action = .Drag_Chip
				g.cursor.selection = g.cursor.hover
				g.cursor.offset = m_pos - (h.pos + get_chip_center(h))

			case is_mouse_just_pressed(.RIGHT):
				remove_chip_interface(&g.bench, h, g.cursor.chip_id)
			}

		case ^Workbench_Pin:
			if is_mouse_just_pressed(.LEFT) && h.handle.kind == .Builtin_In {
				h.on = !h.on
			}

		case ^Pin_Interface:
			if is_mouse_just_pressed(.LEFT) {
				g.action = .Connect_Pins
				g.cursor.selection = g.cursor.hover
				g.cursor.start_point = {h.rect.x + PIN_SIZE / 2, h.rect.y + PIN_SIZE / 2}
				g.cursor.current_point = g.cursor.start_point
				g.cursor.schema_count = 0
			}

		case:
			if is_mouse_just_pressed(.LEFT) {
				gx, gy := to_grid(&g.s, m_pos)
				fixed_pos := to_screen(&g.s, gx, gy)
				chip := g.prototypes[g.prototype_id]
				add_chip_interface(
					&g.bench,
					&g.s,
					fixed_pos,
					g.prototype_id,
					len(chip.input_pins),
					len(chip.output_pins),
				)
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
		direct_line := m_pos - g.cursor.start_point
		x_dir := abs(direct_line.x) > abs(direct_line.y)
		straight_line := Vector{
			direct_line.x if x_dir else 0,
			direct_line.y if !x_dir else 0,
		}
		fixed_line := to_screen(&g.s, to_grid(&g.s, straight_line))
		g.cursor.current_point = g.cursor.start_point + fixed_line

		switch {
		case is_mouse_just_pressed(.LEFT):
			switch h in g.cursor.hover {
			case ^Chip_Interface, ^Workbench_Pin:
			case ^Pin_Interface:
				add_edge_to_circuit_schema(&g.cursor)
				connect_pins(
					&g.bench,
					g.cursor.selection.(^Pin_Interface),
					h,
					g.cursor.circuit_schema,
					g.cursor.schema_count,
				)
				deselect(g)
			case:
				add_edge_to_circuit_schema(&g.cursor)
			}

		case is_mouse_just_pressed(.RIGHT):
			deselect(g)
		}
	}

	update_workbench(&g.bench, elapsed_time())
}

add_edge_to_circuit_schema :: proc(c: ^Cursor) {
	c.circuit_schema[c.schema_count] = {c.start_point, c.current_point}
	c.schema_count += 1
	c.start_point = c.current_point
}

deselect :: proc(g: ^Game) {
	g.action = .Idle
	g.cursor.selection = nil
	g.cursor.offset = {}
	g.cursor.schema_count = 0
}
