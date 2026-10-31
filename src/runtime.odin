package nodes

import hm "core:container/handle_map"
import "core:fmt"
import "core:math"
import "core:strings"
import "core:time"

find_incoming_link :: proc(graph: ^Graph, pin_handle: Pin_Handle) -> (Link, bool) {
	for it := hm.iterator_make(&graph.links); link, _ in hm.iterate(&it) {
		if link.to == pin_handle {
			return link^, true
		}
	}
	return {}, false
}

evaluate_data_node :: proc(
	ctx: ^Execution_Context,
	node_handle: Node_Handle,
	output_index: int,
) -> Pin_Data {
	node := hm.get(&ctx.graph.nodes, node_handle)
	switch node.type {
	case .Arithmetic:
		a_val := evaluate_pin_value(ctx, node_handle, 0)
		b_val := evaluate_pin_value(ctx, node_handle, 1)

		a, a_ok := a_val.(f64)
		b, b_ok := b_val.(f64)
		if a_ok && b_ok {
			switch node.inputs[2].data.(string) {
			case "+":
				return a + b
			case "-":
				return a - b
			case "*":
				return a * b
			case "/":
				return a / b
			case "%":
				return math.mod(a, b)
			}
		}
	case .Compare:
		a_val := evaluate_pin_value(ctx, node_handle, 0)
		b_val := evaluate_pin_value(ctx, node_handle, 1)

		a, a_ok := a_val.(f64)
		b, b_ok := b_val.(f64)
		if a_ok && b_ok {
			switch node.inputs[2].data.(string) {
			case "==":
				return a == b
			case "!=":
				return a != b
			case "<":
				return a < b
			case ">":
				return a > b
			case "<=":
				return a <= b
			case ">=":
				return a >= b
			}
		}
	case .Begin, .Branch, .Print:
		fmt.printf(
			"Error: Attempted to evaluate a non-data node type (Hint: Have you connected Program Flow to a data pin?): %s\n",
			NODE_DEFINITIONS[node.type].name,
		)
	}
	return nil
}

evaluate_pin_value :: proc(
	ctx: ^Execution_Context,
	node_handle: Node_Handle,
	pin_index: int,
) -> Pin_Data {
	node := hm.get(&ctx.graph.nodes, node_handle)
	pin_handle := Pin_Handle {
		node  = node_handle,
		index = u8(pin_index),
	}

	if link, found := find_incoming_link(ctx.graph, pin_handle); found {
		from_def := NODE_DEFINITIONS[hm.get(&ctx.graph.nodes, link.from.node).type]
		from_output_index := int(link.from.index) - len(from_def.inputs)
		return evaluate_data_node(ctx, link.from.node, from_output_index)
	}

	return node.inputs[pin_index].data
}

follow_and_run_execution :: proc(ctx: ^Execution_Context, out_handle: Pin_Handle) {
	node := hm.get(&ctx.graph.nodes, out_handle.node)

	for it := hm.iterator_make(&ctx.graph.links); link, _ in hm.iterate(&it) {
		if link.from == out_handle {
			execute_from_node(ctx, link.to.node)
		}
	}
}

execute_from_node :: proc(ctx: ^Execution_Context, node_handle: Node_Handle) {
	node := hm.get(&ctx.graph.nodes, node_handle)
	definition := NODE_DEFINITIONS[node.type]

	switch node.type {
	case .Print:
		val := evaluate_pin_value(ctx, node_handle, 1)
		if num, ok := val.(f64); ok {
			fmt.sbprintf(&ctx.output, "%v\n", num)
		} else {
			fmt.sbprintf(&ctx.output, "<nil>\n")
		}
		follow_and_run_execution(ctx, Pin_Handle{node = node_handle, index = 2})

	case .Branch:
		condition := evaluate_pin_value(ctx, node_handle, 1)
		if cond, ok := condition.(bool); ok && cond {
			follow_and_run_execution(ctx, Pin_Handle{node = node_handle, index = 2})
		} else {
			follow_and_run_execution(ctx, Pin_Handle{node = node_handle, index = 3})
		}
	case .Begin:
		follow_and_run_execution(ctx, Pin_Handle{node = node_handle, index = 0})
	case .Arithmetic, .Compare:
	}
}

Execution_Context :: struct {
	graph:  ^Graph,
	output: strings.Builder,
}

run_graph :: proc(graph: ^Graph) {
	start := time.now()

	ctx: Execution_Context
	ctx.graph = graph
	strings.builder_init(&ctx.output)

	for it := hm.iterator_make(&graph.nodes); node, handle in hm.iterate(&it) {
		if node.type == .Begin {
			execute_from_node(&ctx, handle)
			break
		}
	}

	g.output = strings.to_string(ctx.output)

	now := time.now()
	g.executed = true
	g.last_execution_time = time.diff(start, now)
	g.last_execution_date = now
}
