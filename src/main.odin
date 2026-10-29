package nodes

import k2 "../karl2d"
import hm "core:container/handle_map"
import "core:fmt"

MAX_PINS_PER_NODE :: 5

Pin_Type :: enum {
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
	.Add = {
		name = "Add",
		inputs = {{"A", .Integer}, {"B", .Integer}},
		outputs = {{"Out", .Integer}},
	},
	.Print = {name = "Print", inputs = {{"Number", .Integer}}},
}

Node_Type :: enum {
	Add,
	Print,
}

Node :: struct {
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
	nodes: hm.Dynamic_Handle_Map(Node, Node_Handle),
	links: hm.Dynamic_Handle_Map(Link, Link_Handle),
}

AppState :: struct {
	graph:              Graph,
	mouse_grabbed_node: Node_Handle,
	mouse_grab_offset:  k2.Vec2,
}
g: AppState

main :: proc() {
	init()
	for step() {}
	shutdown()
}

add_node :: proc(graph: ^Graph, node_type: Node_Type, position: k2.Vec2) -> Node_Handle {
	return hm.add(&graph.nodes, Node{type = node_type, position = position})
}

add_link :: proc(graph: ^Graph, from, to: Pin_Handle) -> Link_Handle {
	return hm.add(&graph.links, Link{from = from, to = to})
}

create_test_graph :: proc(graph: ^Graph) {
	add := add_node(graph, .Add, {100, 100})
	print := add_node(graph, .Print, {400, 100})

	add_node := hm.get(&graph.nodes, add)
	add_node.inputs[0].data = 1
	add_node.inputs[1].data = 2

	add_link(graph, {add, 2}, {print, 0})
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
			fmt.printf("  Output [%d] %s (%v)\n", i, pin.name, pin.type)
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

init :: proc() {
	k2.init(1280, 720, "VisualNodes", {window_mode = .Windowed_Resizable})

	create_test_graph(&g.graph)
	print_graph(&g.graph)
}

draw_node :: proc(node: Node) {
	definition := NODE_DEFINITIONS[node.type]

	k2.draw_rect_vec(node.position, {200, 100}, k2.DARK_GRAY)
	k2.draw_text(definition.name, node.position, 20, k2.WHITE)

	for pin, i in definition.inputs {
		pin_pos := node.position + {0, f32(30 + i * 20)}
		k2.draw_circle(pin_pos, 5, k2.BLUE)
		pin_text :=
			node.inputs[i].data != nil ? fmt.tprintf("%s: %v", pin.name, node.inputs[i].data) : pin.name
		k2.draw_text(pin_text, pin_pos + {10, -8}, 16, k2.WHITE)
	}

	for pin, i in definition.outputs {
		pin_pos := node.position + {200, f32(30 + i * 20)}
		k2.draw_circle(pin_pos, 5, k2.GREEN)
		k2.draw_text(pin.name, pin_pos + {-50, -8}, 16, k2.WHITE)
	}
}

draw_link :: proc(link: Link) {
	from_node := hm.get(&g.graph.nodes, link.from.node)
	to_node := hm.get(&g.graph.nodes, link.to.node)

	from_def := NODE_DEFINITIONS[from_node.type]
	to_def := NODE_DEFINITIONS[to_node.type]

	from_pin_index := int(link.from.index) - len(from_def.inputs)
	from_pin_pos := from_node.position + {200, f32(30 + from_pin_index * 20)}

	to_pin_pos := to_node.position + {0, f32(30 + link.to.index * 20)}

	k2.draw_line(from_pin_pos, to_pin_pos, 3, k2.YELLOW)
}

step :: proc() -> bool {
	if !k2.update() {
		return false
	}

	defer free_all(context.temp_allocator)

	// Update

	for it := hm.iterator_make(&g.graph.nodes); node, handle in hm.iterate(&it) {
		if k2.mouse_button_went_down(.Left) {
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

	k2.present()

	return true
}

shutdown :: proc() {
	k2.shutdown()
}
