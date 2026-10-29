package nodes

import k2 "../karl2d"
import hm "core:container/handle_map"
import "core:fmt"
import "core:strings"

MAX_PINS_PER_NODE :: 5

Pin_Type :: enum {
	Execution,
	Integer,
	String,
}

Pin_Definition :: struct {
	name: string,
	type: Pin_Type,
}

Node_Definition :: struct {
	name:    string,
	inputs:  []Pin_Definition,
	outputs: []Pin_Definition,
}

NODE_DEFINITIONS := [Node_Type]Node_Definition {
	.Begin = {name = "Begin", inputs = {}, outputs = {{"Exec", .Execution}}},
	.Add = {
		name = "Add",
		inputs = {{"A", .Integer}, {"B", .Integer}},
		outputs = {{"Out", .Integer}},
	},
	.Print = {name = "Print", inputs = {{"Exec", .Execution}, {"Number", .Integer}}, outputs = {}},
}

Node_Type :: enum {
	Begin,
	Add,
	Print,
}

Base_Node :: struct {
	handle:   Node_Handle,
	type:     Node_Type,
	position: k2.Vec2,
	inputs:   [MAX_PINS_PER_NODE]Pin,
	outputs:  [MAX_PINS_PER_NODE]Pin,
}

Pin :: struct {
	data: Pin_Data,
}

Pin_Data :: union {
	int,
	string,
}

Link :: struct {
	handle:   Link_Handle,
	from, to: Pin_Handle,
}

Node_Handle :: distinct hm.Handle32
Link_Handle :: distinct hm.Handle32

Pin_Handle :: struct {
	node:  Node_Handle,
	// For inputs: indexof(Pin, node.inputs)
	// For outputs: len(node.inputs) + indexof(Pin, node.outputs)
	// Saves us from an extra is_output bool lol
	index: u8,
}

Graph :: struct {
	nodes: hm.Dynamic_Handle_Map(Base_Node, Node_Handle),
	links: hm.Dynamic_Handle_Map(Link, Link_Handle),
}

AppState :: struct {
	graph:              Graph,
	mouse_grabbed_node: Node_Handle,
	mouse_grab_offset:  k2.Vec2,
	output:             string,
}
g: AppState

main :: proc() {
	init()
	for step() {}
	shutdown()
}

add_node :: proc(graph: ^Graph, node_type: Node_Type, position: k2.Vec2) -> Node_Handle {
	return hm.add(&graph.nodes, Base_Node{type = node_type, position = position})
}

add_link :: proc(graph: ^Graph, from, to: Pin_Handle) -> Link_Handle {
	return hm.add(&graph.links, Link{from = from, to = to})
}

create_test_graph :: proc(graph: ^Graph) {
	begin := add_node(graph, .Begin, {100, 50})
	add := add_node(graph, .Add, {200, 200})
	print := add_node(graph, .Print, {500, 50})

	add_node := hm.get(&graph.nodes, add)
	add_node.inputs[0].data = 1
	add_node.inputs[1].data = 2

	add_link(graph, {begin, 0}, {print, 0})
	add_link(graph, {add, 2}, {print, 1})
}

print_graph :: proc(graph: ^Graph) {
	fmt.println("--- Nodes ---")

	for it := hm.iterator_make(&graph.nodes); node, handle in hm.iterate(&it) {
		definition := NODE_DEFINITIONS[node.type]

		fmt.printf(
			"Node %v: %s at (%.1f, %.1f)\n",
			handle,
			definition.name,
			node.position.x,
			node.position.y,
		)

		for pin, i in definition.inputs {
			fmt.printf("  Input  [%d] %s (%v) : %v\n", i, pin.name, pin.type, node.inputs[i].data)
		}

		for pin, i in definition.outputs {
			fmt.printf("  Output [%d] %s (%v)\n", len(definition.inputs) + i, pin.name, pin.type)
		}
	}

	fmt.println("--- Links ---")

	for it := hm.iterator_make(&graph.links); link, handle in hm.iterate(&it) {
		from_node := hm.get(&graph.nodes, link.from.node)
		to_node := hm.get(&graph.nodes, link.to.node)

		from_def := NODE_DEFINITIONS[from_node.type]
		to_def := NODE_DEFINITIONS[to_node.type]

		from_pin_index := int(link.from.index) - len(from_def.inputs)
		from_pin := from_def.outputs[from_pin_index]

		to_pin := to_def.inputs[link.to.index]

		fmt.printf(
			"Link %v: %s.%s -> %s.%s\n",
			handle,
			from_def.name,
			from_pin.name,
			to_def.name,
			to_pin.name,
		)
	}
}

find_incoming_link :: proc(graph: ^Graph, pin_handle: Pin_Handle) -> (Link, bool) {
	for it := hm.iterator_make(&graph.links); link, _ in hm.iterate(&it) {
		if link.to == pin_handle {
			return link^, true
		}
	}
	return {}, false
}

evaluate_data_node :: proc(
	graph: ^Graph,
	node_handle: Node_Handle,
	output_index: int,
) -> Pin_Data {
	node := hm.get(&graph.nodes, node_handle)
	switch node.type {
	case .Add:
		a_val := evaluate_pin_value(graph, node_handle, 0)
		b_val := evaluate_pin_value(graph, node_handle, 1)

		a, a_ok := a_val.(int)
		b, b_ok := b_val.(int)
		if a_ok && b_ok {
			return a + b
		}
	case .Begin, .Print:
		panic("Tried to evaluate action node!")
	}
	return nil
}

evaluate_pin_value :: proc(graph: ^Graph, node_handle: Node_Handle, pin_index: int) -> Pin_Data {
	node := hm.get(&graph.nodes, node_handle)
	pin_handle := Pin_Handle {
		node  = node_handle,
		index = u8(pin_index),
	}

	if link, found := find_incoming_link(graph, pin_handle); found {
		from_def := NODE_DEFINITIONS[hm.get(&graph.nodes, link.from.node).type]
		from_output_index := int(link.from.index) - len(from_def.inputs)
		return evaluate_data_node(graph, link.from.node, from_output_index)
	}

	return node.inputs[pin_index].data
}

execute_from_node :: proc(graph: ^Graph, node_handle: Node_Handle, builder: ^strings.Builder) {
	node := hm.get(&graph.nodes, node_handle)
	definition := NODE_DEFINITIONS[node.type]

	switch node.type {
	case .Print:
		val := evaluate_pin_value(graph, node_handle, 1)
		if num, ok := val.(int); ok {
			fmt.sbprintf(builder, "%d\n", num)
		} else {
			fmt.sbprintf(builder, "<nil>\n")
		}

	case .Begin, .Add:
	}

	for pin, i in definition.outputs {
		if pin.type == .Execution {
			out_pin_index := len(definition.inputs) + i
			out_pin_handle := Pin_Handle {
				node  = node_handle,
				index = u8(out_pin_index),
			}

			for it := hm.iterator_make(&graph.links); link, _ in hm.iterate(&it) {
				if link.from == out_pin_handle {
					execute_from_node(graph, link.to.node, builder)
				}
			}
		}
	}
}

run_graph :: proc(graph: ^Graph) {
	builder: strings.Builder
	strings.builder_init(&builder)

	for it := hm.iterator_make(&graph.nodes); node, handle in hm.iterate(&it) {
		if node.type == .Begin {
			execute_from_node(graph, handle, &builder)
			break
		}
	}

	g.output = strings.to_string(builder)
}

init :: proc() {
	k2.init(1280, 720, "VisualNodes", {window_mode = .Windowed_Resizable})

	create_test_graph(&g.graph)
	print_graph(&g.graph)
	run_graph(&g.graph)
	// Try again to make sure there's no state bug
	delete(g.output)
	run_graph(&g.graph)
}

draw_node :: proc(node: Base_Node) {
	definition := NODE_DEFINITIONS[node.type]

	k2.draw_rect_vec(node.position, {200, 100}, k2.DARK_GRAY)
	k2.draw_text(definition.name, node.position, 20, k2.WHITE)

	for pin, i in definition.inputs {
		pin_pos := node.position + {0, f32(30 + i * 20)}
		color := pin.type == .Execution ? k2.YELLOW : k2.BLUE
		k2.draw_circle(pin_pos, 5, color)
		pin_text :=
			node.inputs[i].data != nil ? fmt.tprintf("%s: %v", pin.name, node.inputs[i].data) : pin.name
		k2.draw_text(pin_text, pin_pos + {10, -8}, 16, k2.WHITE)
	}

	for pin, i in definition.outputs {
		pin_pos := node.position + {200, f32(30 + i * 20)}
		color := pin.type == .Execution ? k2.YELLOW : k2.GREEN
		k2.draw_circle(pin_pos, 5, color)
		k2.draw_text(pin.name, pin_pos + {-50, -8}, 16, k2.WHITE)
	}
}

draw_link :: proc(link: Link) {
	from_node := hm.get(&g.graph.nodes, link.from.node)
	to_node := hm.get(&g.graph.nodes, link.to.node)

	from_def := NODE_DEFINITIONS[from_node.type]
	to_def := NODE_DEFINITIONS[to_node.type]

	from_pin_index := int(link.from.index) - len(from_def.inputs)
	from_pin := from_def.outputs[from_pin_index]

	from_pin_pos := from_node.position + {200, f32(30 + from_pin_index * 20)}
	to_pin_pos := to_node.position + {0, f32(30 + link.to.index * 20)}

	color := from_pin.type == .Execution ? k2.YELLOW : k2.WHITE
	k2.draw_line(from_pin_pos, to_pin_pos, 3, color)
}

step :: proc() -> bool {
	if !k2.update() {
		return false
	}

	defer free_all(context.temp_allocator)

	// Update

	for it := hm.iterator_make(&g.graph.nodes); node, handle in hm.iterate(&it) {
		if k2.mouse_button_went_up(.Left) {
			g.mouse_grabbed_node = {}
		} else if k2.mouse_button_went_down(.Left) {
			mouse_pos := k2.get_mouse_position()
			node_rect := k2.rect_from_pos_size(node.position, {200, 100})

			if k2.point_in_rect(mouse_pos, node_rect) {
				g.mouse_grabbed_node = handle
				g.mouse_grab_offset = mouse_pos - node.position
				break
			}
		}
	}

	if g.mouse_grabbed_node != {} && k2.mouse_button_is_held(.Left) {
		node := hm.get(&g.graph.nodes, g.mouse_grabbed_node)
		node.position = k2.get_mouse_position() - g.mouse_grab_offset
	}

	k2.clear(k2.LIGHT_BLUE)

	// Draw

	for it := hm.iterator_make(&g.graph.nodes); node, handle in hm.iterate(&it) {
		draw_node(node^)
	}

	for it := hm.iterator_make(&g.graph.links); link, handle in hm.iterate(&it) {
		draw_link(link^)
	}

	k2.draw_text(fmt.tprintf("Output:\n%s", g.output), {10, 10}, 20, k2.BLACK)

	stats_text := fmt.tprintf("%d nodes, %d links", hm.len(g.graph.nodes), hm.len(g.graph.links))
	text_size := k2.measure_text(stats_text, 20)
	k2.draw_text(stats_text, k2.get_screen_size() - {text_size.x + 25, 45}, 20, k2.BLACK)

	k2.present()

	return true
}

shutdown :: proc() {
	k2.shutdown()
}
