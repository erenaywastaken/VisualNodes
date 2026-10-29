package nodes

import k2 "../karl2d"
import hm "core:container/handle_map"

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
	node: Node_Handle,
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
