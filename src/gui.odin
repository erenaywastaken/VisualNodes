package nodes

import "../clay"
import k2 "../karl2d"
import hm "core:container/handle_map"
import "core:fmt"

// Catppuccin Latte

COLOR_BASE :: clay.Color{239, 241, 245, 255}
COLOR_MANTLE :: clay.Color{230, 233, 239, 255}
COLOR_SURFACE :: clay.Color{204, 208, 218, 255}
COLOR_OVERLAY :: clay.Color{156, 160, 176, 255}
COLOR_TEXT :: clay.Color{76, 79, 105, 255}

COLOR_BLUE :: clay.Color{30, 102, 245, 255}
COLOR_MAUVE :: clay.Color{136, 57, 239, 255}
COLOR_PEACH :: clay.Color{254, 100, 11, 255}
COLOR_RED :: clay.Color{210, 15, 57, 255}
COLOR_GREEN :: clay.Color{64, 160, 43, 255}
COLOR_TEAL :: clay.Color{23, 146, 153, 255}
COLOR_YELLOW :: clay.Color{223, 142, 29, 255}
COLOR_ROSEWATER :: clay.Color{220, 138, 120, 255}

clay_mouse_pressed :: proc() -> bool {
	return clay.Hovered() && clay.GetPointerState().state == .PressedThisFrame
}

clay_mouse_down :: proc() -> bool {
	return clay.Hovered() && clay.GetPointerState().state == .Pressed
}

top_bar :: proc() {
	if clay.UI(clay.ID("TopBar"))(
	{
		layout = {
			layoutDirection = .LeftToRight,
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(40)},
			padding = clay.PaddingAll(4),
		},
		backgroundColor = COLOR_MANTLE,
	},
	) {
		if clay.UI(clay.ID("TopBarItems"))(
		{
			layout = {
				layoutDirection = .LeftToRight,
				sizing = {width = clay.SizingFit({}), height = clay.SizingGrow({})},
			},
		},
		) {
			top_bar_item("File")
			top_bar_item("Edit")
			top_bar_item("View")
			top_bar_item("Examples")
		}
	}
}

open_menu: string

top_bar_item :: proc(label: string) {
	active := open_menu == label

	if clay.UI(clay.ID(label))(
	{
		layout = {
			sizing = {width = clay.SizingFit({}), height = clay.SizingGrow({})},
			padding = clay.PaddingAll(8),
		},
		backgroundColor = active || clay.Hovered() ? COLOR_SURFACE : {},
	},
	) {
		clay.Text(label, {fontSize = 14, textColor = COLOR_TEXT})

		if clay_mouse_pressed() {
			open_menu = active ? "" : label
		}
	}
}

top_bar_dropdown :: proc() {
	if clay.UI(clay.ID("TopBarDropdown"))(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {width = clay.SizingFit({}), height = clay.SizingFit({})},
		},
		floating = {
			attachTo = .ElementWithId,
			parentId = clay.ID(open_menu).id,
			attachment = {parent = .LeftBottom},
		},
		backgroundColor = COLOR_MANTLE,
	},
	) {
		switch open_menu {
		case "File":
			dropdown_item("New")
			dropdown_item("Open")
			dropdown_item("Save")
		case "Edit":
			dropdown_item("Undo")
			dropdown_item("Redo")
		case "View":
			dropdown_item("Zoom In")
			dropdown_item("Zoom Out")
		case "Examples":
			dropdown_item("Example 1")
			dropdown_item("Example 2")
			dropdown_item("Example 3")
		}
	}
}

dropdown_item :: proc(label: string) {
	if clay.UI(clay.ID_LOCAL(label))(
	{
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFit({})},
			padding = clay.Padding{top = 8, bottom = 8, left = 10, right = 10},
		},
		backgroundColor = clay.Hovered() ? COLOR_SURFACE : {},
	},
	) {
		clay.Text(label, {fontSize = 14, textColor = COLOR_TEXT})

		if clay_mouse_pressed() {
			fmt.printf("Clicked: %s\n", label)
			open_menu = ""
		}
	}
}

node_element :: proc(node: ^Node, i: int) {
	if clay.UI(clay.ID("Node", u32(i)))(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {width = clay.SizingFixed(200), height = clay.SizingFit({min = 75})},
		},
		floating = {offset = node.position, attachTo = .Parent},
	},
	) {
		if clay_mouse_pressed() {
			g.mouse_grabbed_node = node.handle
			g.mouse_grab_offset = clay.GetPointerState().position - node.position
		}

		if clay.UI(clay.ID("NodeHeader", u32(i)))(
		{
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(30)},
				padding = clay.PaddingAll(8),
			},
			backgroundColor = NODE_DEFINITIONS[node.type].color,
			cornerRadius = {topLeft = 16, topRight = 16, bottomLeft = 0, bottomRight = 0},
		},
		) {
			clay.Text(NODE_DEFINITIONS[node.type].name, {fontSize = 18, textColor = 255})
		}

		if clay.UI(clay.ID("NodeBody", u32(i)))(
		{
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
				padding = {bottom = 10, left = 4, right = 4},
			},
			backgroundColor = COLOR_SURFACE,
			cornerRadius = {topLeft = 0, topRight = 0, bottomLeft = 16, bottomRight = 16},
		},
		) {
			if clay.UI(clay.ID("NodePins", u32(i)))(
			{
				layout = {
					layoutDirection = .LeftToRight,
					sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
				},
			},
			) {
				if clay.UI(clay.ID("InputPins", u32(i)))(
				{
					layout = {
						layoutDirection = .TopToBottom,
						sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
					},
				},
				) {
					for pin, j in NODE_DEFINITIONS[node.type].inputs {
						pin_element(node, pin, u32(j), true)
					}
				}

				if clay.UI(clay.ID("OutputPins", u32(i)))(
				{
					layout = {
						layoutDirection = .TopToBottom,
						sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
					},
				},
				) {
					for pin, j in NODE_DEFINITIONS[node.type].outputs {
						pin_element(node, pin, u32(j), false)
					}
				}
			}
		}
	}
}

pin_id :: proc(h: Pin_Handle) -> clay.ElementId {
	// Pack the node handle and pin index into a single unique u32
	return clay.ID("PinCircle", u32(h.node.idx) << 8 | u32(h.index))
}

pin_element :: proc(node: ^Node, pin: Pin_Definition, i: u32, is_input: bool) {
	if clay.UI(clay.ID_LOCAL("Pin", i))(
	{
		layout = {
			layoutDirection = .LeftToRight,
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(20)},
			childGap = 2,
			childAlignment = {y = .Center, x = is_input ? .Left : .Right},
		},
	},
	) {
		color := pin.type == .Execution ? COLOR_YELLOW : (is_input ? COLOR_BLUE : COLOR_GREEN)


		pin_text: string
		if is_input {
			pin_text =
				node.inputs[i].data != nil ? fmt.tprintf("%s: %v", pin.name, node.inputs[i].data) : pin.name
		} else {
			pin_text = pin.name
		}

		pin_index := is_input ? u8(i) : u8(len(NODE_DEFINITIONS[node.type].inputs)) + u8(i)
		id := pin_id(Pin_Handle{node = node.handle, index = pin_index})

		if is_input {
			circle_element(color, id)
			clay.Text(pin_text, {fontSize = 14, textColor = COLOR_TEXT})
		} else {
			clay.Text(pin_text, {fontSize = 14, textColor = COLOR_TEXT})
			circle_element(color, id)
		}
	}
}

circle_element :: proc(color: clay.Color, id: clay.ElementId, radius: f32 = 5) {
	custom_element := new(Clay_Custom_Element, context.temp_allocator)
	custom_element^ = Clay_Custom_Element_Circle {
		radius = radius,
		color  = color,
	}

	if clay.UI(id)(
	{
		layout = {
			sizing = {width = clay.SizingFixed(radius * 2), height = clay.SizingFixed(radius * 2)},
		},
		custom = {customData = custom_element},
	},
	) {}
}

link_element :: proc(link: Link, i: int) {
	// Pointer has to be valid until it reaches the render stage
	// This is the best way I could think of to do it
	custom_element := new(Clay_Custom_Element, context.temp_allocator)
	custom_element^ = link
	if clay.UI(clay.ID("Link", u32(i)))(
	{floating = {attachTo = .Parent}, custom = {customData = custom_element}},
	) {}
}

pin_position :: proc(h: Pin_Handle) -> (pos: k2.Vec2, ok: bool) {
	data := clay.GetElementData(pin_id(h))
	if !data.found {
		return {}, false
	}
	bb := data.boundingBox
	return {bb.x + bb.width / 2, bb.y + bb.height / 2}, true
}

draw_link :: proc(link: Link) {
	from_pos, ok_from := pin_position(link.from)
	to_pos, ok_to := pin_position(link.to)
	if !ok_from || !ok_to do return

	from_node := hm.get(&g.graph.nodes, link.from.node)
	from_def := NODE_DEFINITIONS[from_node.type]
	from_pin := from_def.outputs[int(link.from.index) - len(from_def.inputs)]

	color :=
		from_pin.type == .Execution ? clay_color_to_k2_color(COLOR_YELLOW) : clay_color_to_k2_color(COLOR_TEAL)
	k2.draw_line(from_pos, to_pos, 3, color)
}

do_ui :: proc() -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()

	if clay.UI(clay.ID("OuterContainer"))(
	{
		layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})}},
		backgroundColor = COLOR_BASE,
	},
	) {
		top_bar()
		if open_menu != "" {
			if clay.GetPointerState().state == .PressedThisFrame &&
			   !clay.PointerOver(clay.ID("TopBarItems")) &&
			   !clay.PointerOver(clay.ID("TopBarDropdown")) {
				open_menu = ""
			} else {
				top_bar_dropdown()
			}
		}

		for it, i := hm.iterator_make(&g.graph.links), 0; link, handle in hm.iterate(&it) {
			link_element(link^, i)
			i += 1
		}

		for it, i := hm.iterator_make(&g.graph.nodes), 0; node, handle in hm.iterate(&it) {
			node_element(node, i)
			i += 1
		}
	}

	return clay.EndLayout(k2.get_frame_time())
}
