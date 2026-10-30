package nodes

import k2 "../karl2d"
import hm "core:container/handle_map"
import "core:fmt"

AppState :: struct {
	k2_state:              ^k2.State,
	graph:                 Graph,
	mouse_grabbed_node:    Node_Handle,
	mouse_grab_offset:     k2.Vec2,
	output:                string,
	last_frame_times:      [60]f32,
	last_frame_time_index: int,
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

get_average_frame_time :: proc() -> f32 {
	sum: f32 = 0.0
	for time in g.last_frame_times {
		sum += time
	}
	return sum / len(g.last_frame_times)
}

step :: proc() -> bool {
	if !k2.update() {
		return false
	}

	defer free_all(context.temp_allocator)

	// Update
	g.last_frame_times[g.last_frame_time_index] = k2.get_frame_time()
	g.last_frame_time_index = (g.last_frame_time_index + 1) % len(g.last_frame_times)

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

	k2.present()

	return true
}

shutdown :: proc() {
	hm.dynamic_destroy(&g.graph.nodes)
	hm.dynamic_destroy(&g.graph.links)
	k2.shutdown()
}
