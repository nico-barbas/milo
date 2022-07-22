package main

import "core:mem"
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

	buf := make([]byte, 500 * mem.Megabyte)
	mem.init_arena(&g.arena, buf)
	g.allocator = mem.arena_allocator(&g.arena)
	temp_buf := make([]byte, 500 * mem.Megabyte)
	mem.init_arena(&g.temp_arena, temp_buf)
	g.temp_allocator = mem.arena_allocator(&g.temp_arena)

	context.allocator = g.allocator
	context.temp_allocator = g.temp_allocator
	defer delete(buf)
	defer delete(temp_buf)

	rl.InitWindow(GAME_WIDTH, GAME_HEIGHT, "Milo")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)
	g->on_load()
	for !rl.WindowShouldClose() {
		g.temp_arena.offset = 0
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
