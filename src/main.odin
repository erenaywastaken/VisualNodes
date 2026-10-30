package nodes

import k2 "../karl2d"
import hm "core:container/handle_map"
import "core:strings"
import "core:strconv"
import "core:time"

AppState :: struct {
	k2_state:              ^k2.State,
	cursor:                k2.Cursor,
	previous_cursor:       k2.Cursor,
	graph:                 Graph,
	output:                string,
	last_execution_date:   time.Time,
	last_execution_time:   time.Duration,
	last_frame_times:      [60]f32,
	last_frame_time_index: int,
	ui:                    UI_State,
}
g: AppState

main :: proc() {
	init()
	for step() {}
	shutdown()
}

init :: proc() {
	g.k2_state = k2.init(
		960,
		540,
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
		g.ui.grabbed_node = {}
		g.ui.node_grab_consumed = false
	} else if g.ui.grabbed_node != {} &&
	   !g.ui.node_grab_consumed &&
	   k2.mouse_button_is_held(.Left) {
		node := hm.get(&g.graph.nodes, g.ui.grabbed_node)
		node.position = k2.get_mouse_position() - g.ui.grab_offset
	}

	if k2.mouse_button_went_down(.Left) {
		if g.ui.editing_pin != nil {
			text := strings.to_string(g.ui.text_edit.builder)
			node := hm.get(&g.graph.nodes, g.ui.editing_pin.?.node)
			switch v in node.inputs[g.ui.editing_pin.?.index].data {
			case string:
				node.inputs[g.ui.editing_pin.?.index].data = text
			case int:
				if num, ok := strconv.parse_int(text); ok {
					node.inputs[g.ui.editing_pin.?.index].data = num
				}
			}
		}
		g.ui.editing_pin = nil
	}

	g.cursor = .Default

	ui_cmds := do_ui()

	// This has to run after UI logic,
	// so we don't forget the grabbed pin when the mouse is released over a pin
	if k2.mouse_button_went_up(.Left) {
		g.ui.grabbed_pin = nil
	}

	// set_cursor() directly calls the OS API,
	// so I thought it would be better to cache the states
	if g.cursor != g.previous_cursor {
		k2.set_cursor(g.cursor)
		g.previous_cursor = g.cursor
	}

	// Draw
	k2.clear(k2.BLACK)
	clay_render(&ui_cmds)

	if g.ui.grabbed_pin != nil {
		draw_link_draft(g.ui.grabbed_pin.?, k2.get_mouse_position())
	}

	k2.present()

	return true
}

shutdown :: proc() {
	hm.dynamic_destroy(&g.graph.nodes)
	hm.dynamic_destroy(&g.graph.links)
	k2.shutdown()
}
