package nodes

Node_Definition :: struct {
	name:    string,
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
	.Begin = {name = "Begin", inputs = {}, outputs = {{"Exec", .Execution}}},
	.Add = {
		name = "Add",
		inputs = {{"A", .Integer}, {"B", .Integer}},
		outputs = {{"Out", .Integer}},
	},
	.Print = {name = "Print", inputs = {{"Exec", .Execution}, {"Number", .Integer}}, outputs = {}},
}
