package main

Chip :: struct {
    input_pins: []Value,
    output_pins: []Value,
    inner_pins: [dynamic]Value,
    bytecode: []byte,
}

Value :: union {
    bool,
}

Vm :: struct {
    ip: int,
    stack: [10]Value,
    count: int,
}

push_value :: proc(vm: ^Vm, v: Value) {
    vm.stack[vm.count] = v
    vm.count += 1
}