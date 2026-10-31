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
	data: Pin_Type_Data,
}

Pin_Type :: enum {
	Execution,
	Number,
	Boolean,
	String,
	Enum,
}

Pin_Type_Data :: union {
	[]string,
}

Node_Type :: enum {
	Begin,
	Arithmetic,
	Compare,
	Branch,
	Print,
}

NODE_DEFINITIONS := [Node_Type]Node_Definition {
	.Begin = {
		name = "Begin",
		color = COLOR_TEAL,
		inputs = {},
		outputs = {{"Prg Out", .Execution, {}}},
	},
	.Arithmetic = {
		name = "Arithmetic",
		color = COLOR_ROSEWATER,
		inputs = {
			{"A", .Number, {}},
			{"B", .Number, {}},
			{"Op", .Enum, {"+", "-", "*", "/", "%"}},
		},
		outputs = {{"Out", .Number, {}}},
	},
	.Compare = {
		name = "Compare",
		color = COLOR_YELLOW,
		inputs = {
			{"A", .Number, {}},
			{"B", .Number, {}},
			{"Op", .Enum, {"==", "!=", "<", ">", "<=", ">="}},
		},
		outputs = {{"Out", .Number, {}}},
	},
	.Branch = {
		name = "Branch",
		color = COLOR_BLUE,
		inputs = {{"Prg In", .Execution, {}}, {"Condition", .Boolean, {}}},
		outputs = {{"True", .Execution, {}}, {"False", .Execution, {}}},
	},
	.Print = {
		name = "Print",
		color = COLOR_MAUVE,
		inputs = {{"Prg In", .Execution, {}}, {"Value", .Number, {}}},
		outputs = {{"Prg Out", .Execution, {}}},
	},
}
