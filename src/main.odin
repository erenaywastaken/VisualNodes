package nodes

import k2 "../karl2d"
import hm "core:container/handle_map"
import "core:fmt"

AppState :: struct {
	k2_state:           ^k2.State,
	graph:              Graph,
	mouse_grabbed_node: Node_Handle,
	mouse_grab_offset:  k2.Vec2,
	output:             string,

	// ui: UI_State,
}
g: AppState

main :: proc() {
	init()
	for step() {}
	shutdown()
}

init :: proc() {
	g.k2_state = k2.init(
		1280,
		720,
		"VisualNodes",
		{window_mode = .Windowed_Resizable, anti_alias = true},
	)
	setup_clay()

	create_test_graph(&g.graph)
	print_graph(&g.graph)
	run_graph(&g.graph)
	// Try again to make sure there's no state bug
	delete(g.output)
	run_graph(&g.graph)
}

step :: proc() -> bool {
	if !k2.update() {
		return false
	}

	defer free_all(context.temp_allocator)

	// Update
	clay_update_state()

	if k2.mouse_button_went_up(.Left) {
		g.mouse_grabbed_node = {}
	}

	if g.mouse_grabbed_node != {} && k2.mouse_button_is_held(.Left) {
		node := hm.get(&g.graph.nodes, g.mouse_grabbed_node)
		node.position = k2.get_mouse_position() - g.mouse_grab_offset
	}

	// Draw
	k2.clear(k2.BLACK)

	ui_cmds := do_ui()
	clay_render(&ui_cmds)

	// for it := hm.iterator_make(&g.graph.nodes); node, handle in hm.iterate(&it) {
	// 	draw_node(node^)
	// }

	// for it := hm.iterator_make(&g.graph.links); link, handle in hm.iterate(&it) {
	// 	draw_link(link^)
	// }

	// k2.draw_text(fmt.tprintf("Output:\n%s", g.output), {10, 10}, 20, k2.BLACK)

	// stats_text := fmt.tprintf("%d nodes, %d links", hm.len(g.graph.nodes), hm.len(g.graph.links))
	// text_size := k2.measure_text(stats_text, 20)
	// k2.draw_text(stats_text, k2.get_screen_size() - {text_size.x + 25, 45}, 20, k2.BLACK)

	k2.present()

	return true
}

shutdown :: proc() {
	hm.dynamic_destroy(&g.graph.nodes)
	hm.dynamic_destroy(&g.graph.links)
	k2.shutdown()
}
