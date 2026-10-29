package nodes

import hm "core:container/handle_map"

MAX_PINS_PER_NODE :: 5

Base_Node :: struct {
	handle:   Node_Handle,
	type:     Node_Type,
	position: [2]f32,
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

add_node :: proc(graph: ^Graph, node_type: Node_Type, position: [2]f32) -> Node_Handle {
	return hm.add(&graph.nodes, Base_Node{type = node_type, position = position})
}

add_link :: proc(graph: ^Graph, from, to: Pin_Handle) -> Link_Handle {
	return hm.add(&graph.links, Link{from = from, to = to})
}