package nodes

import hm "core:container/handle_map"
import "core:fmt"
import "core:strings"

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
