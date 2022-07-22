package main

import "core:fmt"
import "core:math/linalg"

Chip_Interface :: struct {
	id:        string,
	pos:       Vector,
	w, h:      f32,
	in_count:  int,
	out_count: int,
	pins:      []Pin_Interface,
}

Pin_Interface :: struct {
	handle: Pin_Handle,
	rect:   Rectangle,
}

Pin_Handle :: struct {
	parent: ^Chip_Interface,
	id:     int,
	kind:   Pin_Kind,
}

Pin_Kind :: enum {
	Builtin_In,
	Builtin_Out,
	In,
	Out,
}

pin_handle_equal :: proc(p1, p2: Pin_Handle) -> bool {
	return p1.parent == p2.parent && p1.id == p2.id
}

pin_compatible :: proc(k1, k2: Pin_Kind) -> bool {
	switch k1 {
	case .Builtin_In:
		return k2 == .In
	case .Builtin_Out:
		return k2 == .Out
	case .In:
		return k2 == .Out || k2 == .Builtin_In
	case .Out:
		return k2 == .In || k2 == .Builtin_Out
	}
	return false
}

PIN_SIZE :: 20
MARGIN :: 10
PADDING :: PIN_SIZE + 10
init_chip_interface :: proc(c: ^Chip_Interface, id: string, p: Vector, i, o: int) {
	m := max(i, o)
	c^ = Chip_Interface {
		id        = id,
		pos       = p,
		w         = 100,
		h         = f32(MARGIN * 2 + PADDING * m),
		in_count  = i,
		out_count = o,
		pins      = make([]Pin_Interface, i + o),
	}
	c.pos -= {c.w / 2, c.h / 2}

	set_pins_position(c)
}

set_pins_position :: proc(c: ^Chip_Interface) {
	in_padding := (c.h - MARGIN * 2) / f32(c.in_count)
	out_padding := (c.h - MARGIN * 2) / f32(c.out_count)
	y := f32(MARGIN)
	for j in 0 ..< c.in_count {

		c.pins[j] = {
			handle = {parent = c, id = j, kind = .In},
			rect = {
				c.pos.x - (PIN_SIZE / 2),
				c.pos.y + f32(y + in_padding / 2) - (PIN_SIZE / 2),
				PIN_SIZE,
				PIN_SIZE,
			},
		}
		y += in_padding
	}

	y = f32(MARGIN)
	for j in 0 ..< c.out_count {
		c.pins[c.in_count + j] = {
			handle = {parent = c, id = c.in_count + j, kind = .Out},
			rect = {
				c.pos.x + c.w - (PIN_SIZE / 2),
				c.pos.y + f32(y + out_padding / 2) - (PIN_SIZE / 2),
				PIN_SIZE,
				PIN_SIZE,
			},
		}
		y += out_padding
	}
}

get_chip_center :: proc(c: ^Chip_Interface) -> Vector {
	return {c.w / 2, c.h / 2}
}

draw_chip_interface :: proc(s: ^State, c: Chip_Interface) {
	draw_rect({c.pos.x, c.pos.y, c.w, c.h}, {255, 255, 255, 255})

	for pin in c.pins {
		draw_rect(pin.rect, {255, 0, 0, 255})
	}
	draw_text(s.font, c.id, c.pos, 16, {0, 0, 0, 255})
}

is_chip_selected :: proc(c: ^Chip_Interface, p: Vector) -> (select: Cursor_Selection) {
	if in_rect_bounds({c.pos.x, c.pos.y, c.w, c.h}, p) {
		select = c
	}
	for _, i in c.pins {
		pin := &c.pins[i]
		if in_rect_bounds(pin.rect, p) {
			select = pin
			return
		}
	}
	return
}

move_chip_interface :: proc(c: ^Chip_Interface, p: Vector) {
	c.pos = p - {c.w / 2, c.h / 2}
	set_pins_position(c)
}

WORKBENCH_MARGIN :: 200

Workbench :: struct {
	outline:       Rectangle,
	inputs:        [dynamic]Pin_Interface,
	input_values:  [dynamic]Value,
	outputs:       [dynamic]Pin_Interface,
	output_values: [dynamic]Value,
	chips:         [dynamic]Chip_Interface,
	circuits:      map[Pin_Handle]Circuit_Simulation,
	state:         enum {
		Planning,
		Simulating,
	},
	// Simulation data
	prototypes:    map[string]Chip,
	tick_rate:     f32,
	timer:         f32,
	commands:      [dynamic]Runtime_Command,
}

Runtime_Command :: struct {
	kind:       enum {
		Load,
		Exe,
	},
	circuit_id: int,
	chip_id:    string,
}

Circuit_Simulation :: struct {
	// Building states
	from:       Pin_Handle,
	to:         Pin_Handle,

	// Runtime states
	runtime_id: int,
	state:      enum {
		Waiting,
		Processing,
		Processed,
	},
	value:      Value,

	// Graphical states
	start, end: Vector,
	particles:  [10]Rectangle,
	count:      int,
	timer:      f32,
}

init_workbench :: proc(w: ^Workbench, s: ^State) {
	cell := s.grid.cell_size
	w.outline = {cell, cell, WIDTH - cell * 2, 600 - cell * 2}
	w.tick_rate = 2.5

	// FIXME: Temp
	add_workbench_pin(w, .Builtin_In)
	add_workbench_pin(w, .Builtin_In)
	add_workbench_pin(w, .Builtin_Out)
}

add_chip_interface :: proc(w: ^Workbench, p: Vector, id: string) {
	append(&w.chips, Chip_Interface{})
	init_chip_interface(&w.chips[len(w.chips) - 1], "nand", p, 2, 1)
}

add_workbench_pin :: proc(w: ^Workbench, kind: Pin_Kind) {
	pins: ^[dynamic]Pin_Interface
	x: f32 = w.outline.x
	y: f32 = WORKBENCH_MARGIN
	#partial switch kind {
	case .Builtin_In:
		pins = &w.inputs
		append(&w.input_values, false)
	case .Builtin_Out:
		pins = &w.outputs
		x += w.outline.width
		append(&w.output_values, false)
	}

	append(pins, Pin_Interface{})
	padding := (w.outline.height - WORKBENCH_MARGIN * 2) / f32(len(pins))
	for _, i in pins {
		pins[i] = {
			handle = {id = i, kind = kind},
			rect = {
				x - (PIN_SIZE / 2),
				y + (padding / 2) - (PIN_SIZE / 2),
				PIN_SIZE,
				PIN_SIZE,
			},
		}
		y += padding
	}
}

remove_workbench_pin :: proc(w: ^Workbench, kind: Pin_Kind) {

}

remove_chip_interface :: proc(w: ^Workbench, c: ^Chip_Interface, id: int) {
	for pin in c.pins {
		for to, circuit in w.circuits {
			if pin_handle_equal(circuit.from, pin.handle) {
				delete_key(&w.circuits, to)
				continue
			} else if pin_handle_equal(circuit.to, pin.handle) {
				delete_key(&w.circuits, to)
				continue
			}
		}
	}
	ordered_remove(&w.chips, id)
}

is_workench_pin_selected :: proc(w: ^Workbench, p: Vector) -> (sel: Cursor_Selection) {
	for _, i in w.inputs {
		pin := &w.inputs[i]
		if in_rect_bounds(pin.rect, p) {
			sel = pin
			return
		}
	}
	for _, i in w.outputs {
		pin := &w.outputs[i]
		if in_rect_bounds(pin.rect, p) {
			sel = pin
			return
		}
	}
	return
}

get_pin :: proc(w: ^Workbench, h: Pin_Handle) -> (pin: Pin_Interface) {
	switch h.kind {
	case .Builtin_In:
		pin = w.inputs[h.id]
	case .Builtin_Out:
		pin = w.outputs[h.id]
	case .In, .Out:
		pin = h.parent.pins[h.id]
	}
	return
}

connect_pins :: proc(w: ^Workbench, start: ^Pin_Interface, end: ^Pin_Interface) {
	if pin_compatible(start.handle.kind, end.handle.kind) {
		insert := true
		if circuit, exist := w.circuits[end.handle]; exist {
			if pin_handle_equal(start.handle, circuit.from) {
				insert = false
			}
		}
		if insert {
			w.circuits[end.handle] = {
				from = start.handle,
				to   = end.handle,
			}
		}
	}
}

start_workbench_simulation :: proc(w: ^Workbench, prototypes: map[string]Chip) {
	w.state = .Simulating
	w.prototypes = prototypes

	// i := 0
	// for _, circuit in w.circuits {
	// 	start := get_pin(w, connection.from)
	// 	end := get_pin(w, connection.to)
	// 	w.circuit_sim[i] = {
	// 		state = .Processing if connection.from.kind == .Builtin_In else .Waiting,
	// 		start = {start.rect.x, start.rect.y},
	// 		end = {end.rect.x, end.rect.y},
	// 	}
	// 	c := connection
	// 	c.runtime_id = i
	// 	if connection.from.kind == .Builtin_In {
	// 		w.circuit_sim[i].value = w.input_values[connection.from.id]
	// 		append(&w.currents, c)
	// 	} else {
	// 		append(&w.remaining, c)
	// 	}
	// 	i += 1
	// }

	batch_loads :: proc(
		w: ^Workbench,
		chips: ^[dynamic]^Chip_Interface,
		cir: ^[dynamic]^Circuit_Simulation,
	) {
		for circuit in cir {
			append(
				&w.commands,
				Runtime_Command{kind = .Load, circuit_id = circuit.runtime_id},
			)
			append(chips, circuit.from.parent)
		}

		clear(&cir)
	}

	batch_loads :: proc(
		w: ^Workbench,
		chips: ^[dynamic]^Chip_Interface,
		cir: ^[dynamic]^Circuit_Simulation,
	) {
		for chip in chips {
			append(
				&w.commands,
				Runtime_Command{kind = .Exe, chip_id = chip.id},
			)
		}
	} 
	chips := make([dynamic]^Chip_Interface, context.temp_allocator)
	circuits := make([dynamic]^Circuit_Simulation, context.temp_allocator)
	for out in w.outputs {
		append(&circuits, &w.circuits[out.handle])
	}
}

update_workbench :: proc(w: ^Workbench, dt: f32) {
	if w.state != .Simulating {
		return
	}

	if len(w.remaining) == 0 && len(w.currents) == 0 {
		w.state = .Planning
		clear(&w.currents)
		delete(w.circuit_sim)
		fmt.println(w.output_values)
		return
	}

	advance := false
	w.timer += dt
	if w.timer >= w.tick_rate {
		w.timer = 0
		advance = true
	}


	if advance {
		chips := make(map[^Chip_Interface]Chip, 10, context.temp_allocator)
		for connection in w.currents {
			id := connection.runtime_id
			#partial switch connection.to.kind {
			case .Builtin_Out:
				w.output_values[connection.to.id] = w.circuit_sim[id].value
			case .In:
				interface := connection.to.parent
				if _, exist := chips[interface]; !exist {
					chips[interface] = w.prototypes[interface.id]
				}
				chips[interface].input_pins[connection.to.id] = w.circuit_sim[id].value
				fmt.println(chips[interface].input_pins[connection.to.id])
			case:
				assert(false)
			}
			w.circuit_sim[id].state = .Processed
		}
		clear(&w.currents)
		for i in chips {
			chip := &chips[i]
			execute(chip)

			to_remove := make([dynamic]int, context.temp_allocator)
			next: for connection, j in w.remaining {
				from := connection.from
				if from.parent == i {
					for k in i.in_count ..< len(i.pins) {
						if from.id == k {
							append(&to_remove, j)
							c := connection
							append(&w.currents, c)

							cid := c.runtime_id
							w.circuit_sim[cid].value =
								chip.output_pins[from.id - i.in_count]
							w.circuit_sim[cid].state = .Processing
							continue next
						}
					}
				}
			}
			for rid in to_remove {
				ordered_remove(&w.remaining, rid)
			}
		}
	}

	CIRCUIT_TICK_RATE :: 0.5
	for _, i in w.circuit_sim {
		circuit := &w.circuit_sim[i]
		if circuit.state == .Processing {
			circuit.timer += dt
			if circuit.timer >= CIRCUIT_TICK_RATE {
				circuit.timer = 0
				circuit.particles[circuit.count] = {
					circuit.start.x,
					circuit.start.y,
					10,
					10,
				}
				circuit.count += 1
			}

			dir := circuit.end - circuit.start
			norm := linalg.normalize(dir)
			to_remove := make([dynamic]int, context.temp_allocator)
			for j in 0 ..< circuit.count {
				part := &circuit.particles[j]
				part.x += norm.x * dt * 250
				part.y += norm.y * dt * 250

				l := linalg.length2(Vector{part.x, part.y} - circuit.start)
				if l >= linalg.length2(dir) {
					append(&to_remove, j)
				}
			}
			for j in to_remove {
				circuit.particles[j] = circuit.particles[circuit.count]
				circuit.count -= 1
			}
		}
	}
}

draw_workbench :: proc(s: ^State, w: ^Workbench) {

	draw_rect_line(w.outline, 1, {255, 255, 255, 255})

	for pin in w.inputs {
		draw_rect(pin.rect, {255, 0, 0, 255})
	}

	for pin in w.outputs {
		draw_rect(pin.rect, {255, 0, 0, 255})
	}

	for chip in w.chips {
		draw_chip_interface(s, chip)
	}
	for to, connection in w.connections {
		start := get_pin(w, connection.from)
		end := get_pin(w, to)
		draw_line(
			{start.rect.x + PIN_SIZE / 2, start.rect.y + PIN_SIZE / 2},
			{end.rect.x + PIN_SIZE / 2, end.rect.y + PIN_SIZE / 2},
			1,
			{255, 255, 255, 255},
		)
	}


	FALSE_CLR :: Color{23, 95, 176, 255}
	TRUE_CLR :: Color{155, 45, 155, 255}
	if w.state == .Simulating {
		for circuit in &w.circuit_sim {
			// b := circuit.value.(bool)
			if circuit.state != .Processing do continue
			for particle in circuit.particles[:circuit.count] {
				draw_rect(particle, TRUE_CLR) //if b else FALSE_CLR
			}
		}
	}
}
