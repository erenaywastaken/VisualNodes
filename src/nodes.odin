package nodes

Node_Definition :: struct {
	name:    string,
	color:   [4]f32, // 0-255
	inputs:  []Pin_Definition,
	outputs: []Pin_Definition,
}

Pin_Definition :: struct {
	name: string,
	type: Pin_Type,
}

Pin_Type :: enum {
	Execution,
	Integer,
	String,
}

Node_Type :: enum {
	Begin,
	Add,
	Print,
}

NODE_DEFINITIONS := [Node_Type]Node_Definition {
	.Begin = {
		name = "Begin",
		color = COLOR_TEAL,
		inputs = {},
		outputs = {{"Prg Out", .Execution}},
	},
	.Add = {
		name = "Add",
		color = COLOR_ROSEWATER,
		inputs = {{"A", .Integer}, {"B", .Integer}},
		outputs = {{"Out", .Integer}},
	},
	.Print = {
		name = "Print",
		color = COLOR_MAUVE,
		inputs = {{"Prg In", .Execution}, {"Number", .Integer}},
		outputs = {{"Prg Out", .Execution}},
	},
}
