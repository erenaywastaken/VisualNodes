package nodes

import hm "core:container/handle_map"

clear_graph :: proc(graph: ^Graph) {
	hm.clear(&graph.nodes)
	hm.clear(&graph.links)
}

load_example1 :: proc() {
	clear_graph(&g.graph)

	begin := add_node(&g.graph, .Begin, {100, 50})
	add := add_node(&g.graph, .Arithmetic, {200, 200})
	print := add_node(&g.graph, .Print, {500, 50})

	add_node := hm.get(&g.graph.nodes, add)
	add_node.inputs[0].data = 1
	add_node.inputs[1].data = 2
	add_node.inputs[2].data = "+"

	add_link(&g.graph, {begin, 0}, {print, 0})
	add_link(&g.graph, {add, 3}, {print, 1})
}

load_example2 :: proc() {
	clear_graph(&g.graph)

	begin := add_node(&g.graph, .Begin, {100, 50})
	add1 := add_node(&g.graph, .Arithmetic, {400, 200})
	add2 := add_node(&g.graph, .Arithmetic, {150, 150})
	print := add_node(&g.graph, .Print, {500, 50})

	add1_node := hm.get(&g.graph.nodes, add1)
	add1_node.inputs[0].data = 1
	add1_node.inputs[2].data = "+"

	add2_node := hm.get(&g.graph.nodes, add2)
	add2_node.inputs[0].data = 3
	add2_node.inputs[1].data = 4
	add2_node.inputs[2].data = "*"

	add_link(&g.graph, {begin, 0}, {print, 0})
	add_link(&g.graph, {add1, 3}, {print, 1})
	add_link(&g.graph, {add2, 3}, {add1, 1})
}

load_example3 :: proc() {
	clear_graph(&g.graph)

	begin := add_node(&g.graph, .Begin, {80, 115})
	compare := add_node(&g.graph, .Compare, {250, 300})
	branch := add_node(&g.graph, .Branch, {470, 200})
	print_true := add_node(&g.graph, .Print, {700, 120})
	print_false := add_node(&g.graph, .Print, {700, 280})

	compare_node := hm.get(&g.graph.nodes, compare)
	compare_node.inputs[0].data = 5
	compare_node.inputs[1].data = 3
	compare_node.inputs[2].data = ">"

	print_true_node := hm.get(&g.graph.nodes, print_true)
	print_true_node.inputs[1].data = 1

	print_false_node := hm.get(&g.graph.nodes, print_false)
	print_false_node.inputs[1].data = 0

	add_link(&g.graph, {begin, 0}, {branch, 0})
	add_link(&g.graph, {compare, 3}, {branch, 1})
	add_link(&g.graph, {branch, 2}, {print_true, 0})
	add_link(&g.graph, {branch, 3}, {print_false, 0})
}
