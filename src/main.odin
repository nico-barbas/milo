package main

import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(600, 800, "Milo")
	rl.SetTargetFPS(60)
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground({255, 255, 255, 255})
		{
			rl.DrawRectangleRec({100, 100, 100, 100}, {195, 55, 0, 255})
		}
		rl.EndDrawing()
	}
}
