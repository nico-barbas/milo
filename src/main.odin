package main

import rl "vendor:raylib"

main :: proc() {
	g := new_clone(
		Game{
			on_load = on_load,
			on_update = on_update,
			on_draw = on_draw,
			on_exit = on_exit,
		},
	)

	rl.InitWindow(800, 600, "Milo")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)
	g->on_load()
	for !rl.WindowShouldClose() {
		g->on_update()

		rl.BeginDrawing()
		rl.ClearBackground({0, 0, 0, 255})
		{
			g->on_draw()
		}
		rl.EndDrawing()
	}
	g->on_exit()
}
