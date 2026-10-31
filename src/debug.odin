package nodes

import hm "core:container/handle_map"
import "core:fmt"

create_test_graph :: proc(graph: ^Graph) {
	begin := add_node(graph, .Begin, {100, 50})
	add := add_node(graph, .Arithmetic, {200, 200})
	print := add_node(graph, .Print, {500, 50})

	add_node := hm.get(&graph.nodes, add)
	add_node.inputs[0].data = 1
	add_node.inputs[1].data = 2
	add_node.inputs[2].data = "+"

	// add_link(graph, {begin, 0}, {print, 0})
	// add_link(graph, {add, 2}, {print, 1})
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
