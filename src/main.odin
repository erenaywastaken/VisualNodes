package nodes

import k2 "../karl2d"
import hm "core:container/handle_map"

MAX_PINS_PER_NODE :: 5

Node_Definition :: struct {
	name:         string,
	input_count:  int,
	output_count: int,
}

NODE_DEFINITIONS := [?]Node_Definition {
	{name = "Add", input_count = 2, output_count = 1},
	{name = "Print", input_count = 1, output_count = 0},
}

Node_Type :: enum {
	Add,
	Print,
}

Node :: struct {
	handle:   Node_Handle,
	type:     Node_Type,
	position: k2.Vec2,
	inputs:   [MAX_PINS_PER_NODE]Pin_Handle,
	outputs:  [MAX_PINS_PER_NODE]Pin_Handle,
}

Pin :: struct {
	handle:    Pin_Handle,
	node:      Node_Handle,
	direction: Pin_Direction,
	data:      Pin_Data,
}

Pin_Direction :: enum {
	Input,
	Output,
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
Pin_Handle :: distinct hm.Handle32
Link_Handle :: distinct hm.Handle32

Graph :: struct {
	nodes: hm.Dynamic_Handle_Map(Node, Node_Handle),
	pins:  hm.Dynamic_Handle_Map(Pin, Pin_Handle),
	links: hm.Dynamic_Handle_Map(Link, Link_Handle),
}

AppState :: struct {
	graph: Graph,
}
g: AppState

main :: proc() {
	init()
	for step() {}
	shutdown()
}

init :: proc() {
	k2.init(1280, 720, "VisualNodes", {window_mode = .Windowed_Resizable})
}

step :: proc() -> bool {
	if !k2.update() {
		return false
	}

	k2.clear(k2.LIGHT_BLUE)
	k2.draw_text("Hellope!", {50, 50}, 100, k2.DARK_BLUE)
	k2.present()

	return true
}

shutdown :: proc() {
	k2.shutdown()
}
