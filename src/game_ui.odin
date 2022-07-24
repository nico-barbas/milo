package main

// import "core:fmt"

init_game_ui :: proc(g: ^Game) {
	set_ctx_current(&g.ui)
	l := add_layout(
		g.s.bottom_rect,
		Background{kind = .Solid, clr = g.s.theme[.Panel_Background]},
		.Left,
		Vector{6, 4},
		2,
	)
	b_w := add_widget(
		l,
		Dropdown_Panel{
			text = "Builtin",
			background = {kind = .Solid},
			clr = g.s.theme[.Background_Light],
			hover_clr = highlight(g.s.theme[.Background_Light], 1.3),
			panel_size = {100, 200},
		},
		60,
	)
	builtin_menu := b_w.(Dropdown_Panel)
	add_widget(
		&builtin_menu.layout,
		Button{
			text = "NAND",
			background = {kind = .Solid},
			clr = g.s.theme[.Background_Light],
			hover_clr = highlight(g.s.theme[.Background_Light], 1.3),
			id = Button_ID(Game_Button_ID.Nand),
			user_data = g,
			callback = on_btn_pressed,
		},
		30,
	)
	add_widget(
		&builtin_menu.layout,
		Button{
			text = "AND",
			background = {kind = .Solid},
			clr = g.s.theme[.Background_Light],
			hover_clr = highlight(g.s.theme[.Background_Light], 1.3),
			id = Button_ID(Game_Button_ID.And),
			user_data = g,
			callback = on_btn_pressed,
		},
		30,
	)
	add_widget(
		&builtin_menu.layout,
		Button{
			text = "OR",
			background = {kind = .Solid},
			clr = g.s.theme[.Background_Light],
			hover_clr = highlight(g.s.theme[.Background_Light], 1.3),
			id = Button_ID(Game_Button_ID.Or),
			user_data = g,
			callback = on_btn_pressed,
		},
		30,
	)
	add_widget(
		&builtin_menu.layout,
		Button{
			text = "NOT",
			background = {kind = .Solid},
			clr = g.s.theme[.Background_Light],
			hover_clr = highlight(g.s.theme[.Background_Light], 1.3),
			id = Button_ID(Game_Button_ID.Not),
			user_data = g,
			callback = on_btn_pressed,
		},
		30,
	)
	b_w^ = builtin_menu


	in_panel := add_layout(
		{
			g.bench.outline.x - (WORKBENCH_BTN_SIZE / 2) + g.s.outline_weight / 2,
			g.bench.outline.y + (WORKBENCH_MARGIN / 4),
			WORKBENCH_BTN_SIZE,
			WORKBENCH_BTN_SIZE * 2 + WORKBENCH_BTN_PADDING,
		},
		Background{kind = .Transparent},
		.Up,
		Vector{},
		WORKBENCH_BTN_PADDING,
	)
	add_widget(
		in_panel,
		Button{
			text = "-",
			background = {kind = .Solid},
			clr = g.s.theme[.Background_Light],
			hover_clr = highlight(g.s.theme[.Background_Light], 1.3),
			id = Button_ID(Game_Button_ID.Input_Sub),
			user_data = g,
			callback = on_btn_pressed,
		},
		WORKBENCH_BTN_SIZE,
	)
	add_widget(
		in_panel,
		Button{
			text = "+",
			background = {kind = .Solid},
			clr = g.s.theme[.Background_Light],
			hover_clr = highlight(g.s.theme[.Background_Light], 1.3),
			id = Button_ID(Game_Button_ID.Input_Add),
			user_data = g,
			callback = on_btn_pressed,
		},
		WORKBENCH_BTN_SIZE,
	)

	out_panel := add_layout(
		{
			in_panel.full.x + g.bench.outline.width - g.s.outline_weight,
			in_panel.full.y,
			in_panel.full.width,
			in_panel.full.height,
		},
		Background{kind = .Transparent},
		.Up,
		Vector{},
		WORKBENCH_BTN_PADDING,
	)
	add_widget(
		out_panel,
		Button{
			text = "-",
			background = {kind = .Solid},
			clr = g.s.theme[.Background_Light],
			hover_clr = highlight(g.s.theme[.Background_Light], 1.3),
			id = Button_ID(Game_Button_ID.Output_Sub),
			user_data = g,
			callback = on_btn_pressed,
		},
		WORKBENCH_BTN_SIZE,
	)
	add_widget(
		out_panel,
		Button{
			text = "+",
			background = {kind = .Solid},
			clr = g.s.theme[.Background_Light],
			hover_clr = highlight(g.s.theme[.Background_Light], 1.3),
			id = Button_ID(Game_Button_ID.Output_Add),
			user_data = g,
			callback = on_btn_pressed,
		},
		WORKBENCH_BTN_SIZE,
	)
}


on_btn_pressed :: proc(data: rawptr, btn_id: Button_ID) {
	g := cast(^Game)data
	game_btn_id := Game_Button_ID(btn_id)

	switch game_btn_id {
	case .Input_Sub:
		remove_workbench_pin(&g.bench, .Builtin_In)

	case .Input_Add:
		add_workbench_pin(&g.bench, .Builtin_In)

	case .Output_Sub:
		remove_workbench_pin(&g.bench, .Builtin_Out)

	case .Output_Add:
		add_workbench_pin(&g.bench, .Builtin_Out)

	case .Nand:
		g.prototype_id = "nand"

	case .And:
		g.prototype_id = "and"

	case .Or:
		g.prototype_id = "or"

	case .Not:
		g.prototype_id = "not"
	}
}
