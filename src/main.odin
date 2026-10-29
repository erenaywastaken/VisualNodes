package nodes

import k2 "../karl2d"
import hm "core:container/handle_map"
import "core:fmt"


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
	if k2.mouse_button_went_up(.Left) {
		g.mouse_grabbed_node = {}
	} else if k2.mouse_button_went_down(.Left) {
		for it := hm.iterator_make(&g.graph.nodes); node, handle in hm.iterate(&it) {
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
