package main

Grid :: struct {
	cell_size: f32,
}

to_grid :: proc(g: ^Grid, p: Vector) -> (x, y: int) {
	return int(p.x / g.cell_size), int(p.y / g.cell_size)
}

to_screen :: proc(g: ^Grid, x, y: int) -> Vector {
	return {g.cell_size * f32(x), g.cell_size * f32(y)}
}
