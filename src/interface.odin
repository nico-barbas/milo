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
		draw_sub_image(s.pin_sprite, s.pin_sprite.bounds, pin.rect, s.theme[.Pin])
	}
	draw_text(s, c.id, c.pos, .Text_Dark)
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

Circuit_Interface :: struct {
	// Building states
	from:       Pin_Handle,
	to:         Pin_Handle,

	// Runtime states
	runtime_id: int,
	state:      Circuit_State,
	value:      Value,

	// Graphical states
	start, end: Vector,
	particles:  [10]Rectangle,
	count:      int,
	timer:      f32,
}

Circuit_State :: enum {
	Waiting,
	Processing,
	Loaded,
}

Workbench :: struct {
	outline:    Rectangle,
	inputs:     [dynamic]Workbench_Pin,
	outputs:    [dynamic]Workbench_Pin,
	chips:      [dynamic]Chip_Interface,
	circuits:   map[Pin_Handle]Circuit_Interface,
	state:      enum {
		Planning,
		Simulating,
	},
	// Simulation data
	prototypes: map[string]Chip,
	tick_rate:  f32,
	timer:      f32,
	open:       [dynamic]^Circuit_Interface,
	currents:   [dynamic]^Circuit_Interface,
}

Workbench_Pin :: struct {
	using base:    Pin_Interface,
	toggle:        Rectangle,
	inner_circuit: Rectangle,
	on:            bool,
}

init_workbench :: proc(w: ^Workbench, s: ^State) {
	cell := s.cell_size
	w.outline = {
		x      = s.active_rect.x + cell,
		y      = s.active_rect.y + cell,
		width  = s.active_rect.width - cell * 2,
		height = s.active_rect.height - cell * 2,
	}
	w.tick_rate = 2

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
	pins: ^[dynamic]Workbench_Pin
	x: f32 = w.outline.x
	offset: f32 = WORKBENCH_TOGGLE_SIZE / 2 + PIN_SIZE / 2 + WORKBENCH_TOGGLE_WIDTH
	#partial switch kind {
	case .Builtin_In:
		pins = &w.inputs
	case .Builtin_Out:
		pins = &w.outputs
		x += w.outline.width
		offset *= -1
	}

	append(pins, Workbench_Pin{})
	set_workbench_pins_position(w, kind)
}

remove_workbench_pin :: proc(w: ^Workbench, kind: Pin_Kind) {
	handle: Pin_Handle

	#partial switch kind {
	case .Builtin_In:
		handle = w.inputs[len(w.inputs) - 1].handle
		ordered_remove(&w.inputs, len(w.inputs) - 1)
	case .Builtin_Out:
		handle = w.outputs[len(w.outputs) - 1].handle
		ordered_remove(&w.outputs, len(w.outputs) - 1)
	}
	for to, circuit in w.circuits {
		#partial switch kind {
		case .Builtin_In:
			if pin_handle_equal(handle, circuit.from) {
				delete_key(&w.circuits, to)
			}
		case .Builtin_Out:
			if pin_handle_equal(handle, to) {
				delete_key(&w.circuits, to)
			}
		}
	}

	set_workbench_pins_position(w, kind)
}

set_workbench_pins_position :: proc(w: ^Workbench, kind: Pin_Kind) {
	pins: ^[dynamic]Workbench_Pin
	x: f32 = w.outline.x
	y: f32 = WORKBENCH_MARGIN
	offset: f32 = WORKBENCH_TOGGLE_SIZE / 2 + PIN_SIZE / 2 + WORKBENCH_TOGGLE_WIDTH

	#partial switch kind {
	case .Builtin_In:
		pins = &w.inputs
	case .Builtin_Out:
		pins = &w.outputs
		x += w.outline.width
		offset *= -1
	}

	padding := (w.outline.height - WORKBENCH_MARGIN * 2) / f32(len(pins))
	for _, i in pins {
		pins[i] = {
			base = {
				handle = {id = i, kind = kind},
				rect = {
					x - (PIN_SIZE / 2),
					y + (padding / 2) - (PIN_SIZE / 2),
					PIN_SIZE,
					PIN_SIZE,
				},
			},
			toggle = {
				x - (WORKBENCH_TOGGLE_SIZE / 2),
				y + (padding / 2) - (WORKBENCH_TOGGLE_SIZE / 2),
				WORKBENCH_TOGGLE_SIZE,
				WORKBENCH_TOGGLE_SIZE,
			},
			on = false,
		}
		pins[i].rect.x += offset
		pins[i].inner_circuit = {
			x if kind == .Builtin_In else x + offset,
			pins[i].toggle.y + (pins[i].toggle.height / 2) - WORKBENCH_TOGGLE_HEIGHT / 2,
			abs(offset),
			WORKBENCH_TOGGLE_HEIGHT,
		}
		y += padding
	}
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
			sel = &pin.base
			return
		} else if in_rect_bounds(pin.toggle, p) {
			sel = pin
		}
	}
	for _, i in w.outputs {
		pin := &w.outputs[i]
		if in_rect_bounds(pin.rect, p) {
			sel = &pin.base
			return
		} else if in_rect_bounds(pin.toggle, p) {
			sel = pin
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

	for k, _ in w.circuits {
		circuit := &w.circuits[k]
		start := get_pin(w, circuit.from).rect
		end := get_pin(w, circuit.to).rect
		circuit.start = {start.x, start.y}
		circuit.end = {end.x, end.y}
		if circuit.from.kind == .Builtin_In {
			circuit.value = w.inputs[circuit.from.id].on
			circuit.state = .Processing
			append(&w.currents, &w.circuits[k])
		} else {
			circuit.value = nil
			circuit.state = .Waiting
			append(&w.open, &w.circuits[k])
		}

		if circuit.to.kind == .Builtin_Out {
			w.outputs[circuit.to.id].on = false
		}
	}

	if len(w.currents) == 0 {
		fmt.println("No pins connected to Workbench Input Pins, stopping simulation")
		clear(&w.currents)
		clear(&w.open)
		end_workbench_simulation(w)
	}
}

end_workbench_simulation :: proc(w: ^Workbench) {
	w.state = .Planning
	fmt.println(w.outputs)

	for handle in w.circuits {
		circuit := &w.circuits[handle]
		circuit.state = .Waiting
	}
}

update_workbench :: proc(w: ^Workbench, dt: f32) {
	if w.state != .Simulating {
		return
	}

	if len(w.open) == 0 && len(w.currents) == 0 {
		end_workbench_simulation(w)
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
		for circuit in w.currents {
			#partial switch circuit.to.kind {
			case .Builtin_Out:
				w.outputs[circuit.to.id].on = circuit.value.(bool)
			case .In:
				interface := circuit.to.parent
				if _, exist := chips[interface]; !exist {
					chips[interface] = w.prototypes[interface.id]
				}

			case:
				assert(false)
			}
			circuit.state = .Loaded
		}

		clear(&w.currents)

		for interface in chips {
			chip := clone_chip(&chips[interface], context.temp_allocator)
			ready := true
			check_inputs: for pin_id in 0 ..< interface.in_count {
				handle := Pin_Handle {
					parent = interface,
					kind   = .In,
					id     = pin_id,
				}
				if w.circuits[handle].state == .Loaded {
					chip.input_pins[pin_id] = w.circuits[handle].value
				} else {
					ready = false
					break check_inputs
				}
			}

			if !ready {
				continue
			}

			execute(chip)

			left := make([dynamic]^Circuit_Interface, context.temp_allocator)
			next: for circuit in w.open {
				from := circuit.from
				if from.parent == interface {
					for j in interface.in_count ..< len(interface.pins) {
						if from.id == j {
							output_id := from.id - interface.in_count
							circuit.value = chip.output_pins[output_id]
							circuit.state = .Processing

							append(&w.currents, circuit)
							continue next
						}
					}
				} else {
					append(&left, circuit)
				}
			}
			clear(&w.open)
			for circuit in left {
				append(&w.open, circuit)
			}
		}
	}

	CIRCUIT_TICK_RATE :: 0.5
	for handle in w.circuits {
		circuit := &w.circuits[handle]
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
			for j in 0 ..< circuit.count {
				part := &circuit.particles[j]
				part.x += norm.x * dt * 250
				part.y += norm.y * dt * 250

				l := linalg.length2(Vector{part.x, part.y} - circuit.start)
				if l >= linalg.length2(dir) {
					circuit.particles[j] = circuit.particles[circuit.count]
					circuit.count -= 1
				}
			}
		}
	}
}

draw_workbench :: proc(s: ^State, w: ^Workbench) {
	circuit_state_to_clr :: proc(s: ^State, c_s: Circuit_State) -> Color {
		switch c_s {
		case .Waiting:
			return s.theme[.Circuit_Wait]
		case .Processing:
			return s.theme[.Circuit_Process]
		case .Loaded:
			return s.theme[.Circuit_Loaded]
		}
		return {255, 0, 255, 255}
	}

	draw_rect_line(w.outline, s.outline_weight, s.theme[.Separator])

	for to, circuit in w.circuits {
		start := get_pin(w, circuit.from)
		end := get_pin(w, to)
		draw_line(
			{start.rect.x + PIN_SIZE / 2, start.rect.y + PIN_SIZE / 2},
			{end.rect.x + PIN_SIZE / 2, end.rect.y + PIN_SIZE / 2},
			s.line_weight,
			circuit_state_to_clr(s, circuit.state),
		)

		if w.state == .Simulating {
			if circuit.state != .Processing do continue
			for i in 0 ..< circuit.count {
				draw_rect(circuit.particles[i], s.theme[.Process_Anim])
			}
		}
	}

	for pin in w.inputs {
		draw_rect(pin.inner_circuit, s.theme[.Pin])
		draw_sub_image(s.pin_sprite, s.pin_sprite.bounds, pin.rect, s.theme[.Pin])
		palette := Theme_Palette.Bit_On if pin.on else .Bit_Off
		draw_sub_image(s.pin_sprite, s.pin_sprite.bounds, pin.toggle, s.theme[palette])
	}

	for pin in w.outputs {
		draw_rect(pin.inner_circuit, s.theme[.Pin])
		draw_sub_image(s.pin_sprite, s.pin_sprite.bounds, pin.rect, s.theme[.Pin])
		palette := Theme_Palette.Bit_On if pin.on else .Bit_Off
		draw_sub_image(s.pin_sprite, s.pin_sprite.bounds, pin.toggle, s.theme[palette])
	}

	for chip in w.chips {
		draw_chip_interface(s, chip)
	}

	y: f32 = 10
	ascend: f32 = 18
	if w.state == .Simulating {
		draw_text(s, "Remaining: ", {5, y}, .Text_Light)
		y += ascend
		for circuit in w.open {
			details := fmt.tprintf(
				"from: (%p, %s, %d) -> to: (%p, %s, %d)",
				circuit.from.parent,
				circuit.from.kind,
				circuit.from.id,
				circuit.to.parent,
				circuit.to.kind,
				circuit.to.id,
			)
			draw_text(s, details, {5, y}, .Text_Light)
			y += ascend
		}
	}


	// if w.state == .Simulating {
	// 	for circuit in &w.circuit_sim {
	// 		// b := circuit.value.(bool)
	// 		if circuit.state != .Processing do continue
	// 		for particle in circuit.particles[:circuit.count] {
	// 			draw_rect(particle, TRUE_CLR) //if b else FALSE_CLR
	// 		}
	// 	}
	// }
}
