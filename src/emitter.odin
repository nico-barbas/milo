package main

import "core:math/linalg"

Emitter :: struct {
	particles: [10]Particle,
	edges:     []Edge,
	cap:       int,
	count:     int,
	timer:     Timer,
	velocity:  f32,
}

PARTICLE_SIZE :: 20

Particle :: struct {
	pos:      Vector,
	step:     int,
	finished: bool,
}

init_emitter :: proc(e: ^Emitter, count: int, edges: []Edge, t: f32) {
	time := t / f32(count)
	e.edges = edges
	e.cap = count
	e.count = 0
	distance := edge_slice_length(edges)
	e.velocity = distance / time
	e.timer = Timer {
		tick_rate   = time,
		accumulator = time,
		reset       = true,
	}

	for i in 0 ..< count {
		e.particles[i] = {
			pos      = edges[0][0] - (PARTICLE_SIZE / 2),
			finished = false,
		}
	}
}

update_emitter :: proc(e: ^Emitter, dt: f32) {
	if finished := advance_timer(&e.timer, dt); finished {
		e.count += 1
	}

	for i in 0 ..< e.count {
		p := &e.particles[i]
		if p.finished do continue
		edge := e.edges[p.step]
		v := edge[1] - edge[0]

		dir := linalg.normalize(v)
		p.pos += dir * e.velocity * dt
		d := linalg.length2(p.pos - edge[0])
		max_d := linalg.length2(v)
		if d >= max_d {
			p.pos = edge[1] - (PARTICLE_SIZE / 2)
			p.step += 1
			if p.step >= len(e.edges) {
				p.finished = true
			}
		}
	}
}

draw_particles :: proc(s: ^State, e: Emitter) {
	for i in 0 ..< e.count {
		p := e.particles[i]
		if p.finished do continue

		draw_sub_image(
			s.pin_sprite,
			s.pin_sprite.bounds,
			{p.pos.x, p.pos.y, 20, 20},
			s.theme[.Process_Anim],
		)
	}
}
