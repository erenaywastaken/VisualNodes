package nodes

import "../clay"
import k2 "../karl2d"
import hm "core:container/handle_map"
import "core:fmt"
import "core:strings"

// Catppuccin Latte

COLOR_BASE :: clay.Color{239, 241, 245, 255}
COLOR_MANTLE :: clay.Color{230, 233, 239, 255}
COLOR_SURFACE :: clay.Color{204, 208, 218, 255}
COLOR_OVERLAY :: clay.Color{156, 160, 176, 255}
COLOR_TEXT :: clay.Color{76, 79, 105, 255}

COLOR_BLUE :: clay.Color{30, 102, 245, 255}
COLOR_MAUVE :: clay.Color{136, 57, 239, 255}
COLOR_MAROON :: clay.Color{230, 69, 83, 255}
COLOR_PEACH :: clay.Color{254, 100, 11, 255}
COLOR_RED :: clay.Color{210, 15, 57, 255}
COLOR_GREEN :: clay.Color{64, 160, 43, 255}
COLOR_TEAL :: clay.Color{23, 146, 153, 255}
COLOR_YELLOW :: clay.Color{223, 142, 29, 255}
COLOR_ROSEWATER :: clay.Color{220, 138, 120, 255}

COLOR_BLACK :: clay.Color{0, 0, 0, 255}
COLOR_WHITE :: clay.Color{255, 255, 255, 255}

clay_mouse_pressed :: proc() -> bool {
	return clay.Hovered() && clay.GetPointerState().state == .PressedThisFrame
}

clay_mouse_released :: proc() -> bool {
	return clay.Hovered() && clay.GetPointerState().state == .ReleasedThisFrame
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
			// top_bar_item("File")
			// top_bar_item("Edit")
			// top_bar_item("View")
			top_bar_item("Examples")
		}

		if clay.UI(clay.ID("TopBarSpacer"))(
		{layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})}}},
		) {}

		run_button()
	}
}

dim :: proc(color: clay.Color, factor: f32 = 0.8) -> clay.Color {
	return {**(color.rgb * factor), color.a}
}

run_button :: proc() {
	if clay.UI(clay.ID("RunButton"))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(90), height = clay.SizingGrow({})},
			padding = {left = 12, right = 12, top = 6, bottom = 6},
			childAlignment = {x = .Center, y = .Center},
		},
		backgroundColor = clay.Hovered() ? dim(COLOR_GREEN) : COLOR_GREEN,
		cornerRadius = clay.CornerRadiusAll(4),
	},
	) {
		clay.Text("Run", {fontSize = 14, textColor = COLOR_WHITE})

		if clay_mouse_pressed() {
			run_graph(&g.graph)
		}
	}
}

UI_State :: struct {
	grabbed_node:       Node_Handle,
	node_grab_consumed: bool,
	grab_offset:        k2.Vec2,
	grabbed_pin:        Maybe(Pin_Handle),
	open_menu:          string,
	text_edit:          Text_Edit_State,
	editing_pin:        Maybe(Pin_Handle),
	dropdown_node:      Maybe(Node_Handle),
	dropdown_position:  Maybe(k2.Vec2),
	connected_inputs:   map[Pin_Handle]struct{}, // hashset
}

top_bar_item :: proc(label: string) {
	active := g.ui.open_menu == label

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
			g.ui.open_menu = active ? "" : label
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
			parentId = clay.ID(g.ui.open_menu).id,
			attachment = {parent = .LeftBottom},
			zIndex = 100,
		},
		backgroundColor = COLOR_MANTLE,
	},
	) {
		pressed := false
		switch g.ui.open_menu {
		// case "File":
		// 	dropdown_item("New")
		// 	dropdown_item("Open")
		// 	dropdown_item("Save")
		// case "Edit":
		// 	dropdown_item("Undo")
		// 	dropdown_item("Redo")
		// case "View":
		// 	dropdown_item("Zoom In")
		// 	dropdown_item("Zoom Out")
		case "Examples":
			pressed ||= dropdown_item("Add and Print")
		}

		if pressed {
			g.ui.open_menu = ""
		}
	}
}

dropdown_item :: proc(label: string) -> bool {
	pressed := false
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

		pressed = clay_mouse_pressed()
		if pressed {
			fmt.println("Pressed dropdown item:", label)
		}

	}
	return pressed
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
		if clay.Hovered() {
			if k2.mouse_button_went_down(.Left) {
				g.ui.grabbed_node = node.handle
				g.ui.grab_offset = clay.GetPointerState().position - node.position
			} else if k2.mouse_button_went_down(.Right) {
				g.ui.dropdown_node = node.handle
				g.ui.dropdown_position = clay.GetPointerState().position
			}
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
			clay.Text(NODE_DEFINITIONS[node.type].name, {fontSize = 18, textColor = COLOR_WHITE})
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

Text_Edit_State :: struct {
	builder: strings.Builder,
}

pin_text_box :: proc(handle: Pin_Handle, i: u32) {
	if clay.UI(clay.ID_LOCAL("PinTextBox", i))(
	{
		layout = {
			sizing = {width = clay.SizingFit({min = 50}), height = clay.SizingFixed(16)},
			childAlignment = {y = .Center},
			padding = {left = 2, right = 2},
		},
		border = {
			width = clay.BorderAll(1),
			color = g.ui.editing_pin == handle ? COLOR_BLUE : COLOR_OVERLAY,
		},
		backgroundColor = COLOR_WHITE,
	},
	) {


		text: string
		if g.ui.editing_pin == handle {
			if clay.Hovered() {
				g.cursor = .Text
			}

			for c in k2.get_typed_runes() {
				strings.write_rune(&g.ui.text_edit.builder, c)
			}

			if (k2.key_went_down(.Backspace)) {
				strings.pop_rune(&g.ui.text_edit.builder)
			}

			clay.Text(
				strings.to_string(g.ui.text_edit.builder),
				{fontSize = 14, textColor = COLOR_BLACK},
			)
		}
	}
}

input_pin_value :: proc(node: ^Node, pin: Pin_Handle, def: Pin_Definition, i: u32) {
	if clay.UI(clay.ID_LOCAL("InputPinText", i))(
	{
		layout = {
			sizing = {width = clay.SizingFit({}), height = clay.SizingGrow({})},
			childAlignment = {y = .Center, x = .Left},
			childGap = 4,
		},
	},
	) {
		_, connected := g.ui.connected_inputs[pin]

		if !connected && clay_mouse_pressed() {
			g.ui.editing_pin = pin
			g.ui.node_grab_consumed = true
			strings.builder_reset(&g.ui.text_edit.builder)
			if node.inputs[pin.index].data != nil {
				fmt.sbprint(&g.ui.text_edit.builder, node.inputs[pin.index].data)
			}
		}

		text := def.name
		if !connected && g.ui.editing_pin != pin && node.inputs[pin.index].data != nil {
			text = fmt.tprintf("%s: %v", def.name, node.inputs[pin.index].data)
		}

		clay.Text(text, {fontSize = 14, textColor = COLOR_TEXT})

		if g.ui.editing_pin == pin {
			pin_text_box(pin, i)
		}
	}
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

		pin_index := is_input ? u8(i) : u8(len(NODE_DEFINITIONS[node.type].inputs)) + u8(i)
		pin_handle := Pin_Handle {
			node  = node.handle,
			index = pin_index,
		}

		if is_input {
			pin_circle(color, pin_handle)
			if pin.type != .Execution {
				input_pin_value(node, pin_handle, pin, i)
			} else {
				clay.Text(pin.name, {fontSize = 14, textColor = COLOR_TEXT})
			}
		} else {
			clay.Text(pin.name, {fontSize = 14, textColor = COLOR_TEXT})
			pin_circle(color, pin_handle)
		}
	}
}

pin_circle :: proc(color: clay.Color, pin_handle: Pin_Handle, radius: f32 = 5) {
	custom_element := new(Clay_Custom_Element, context.temp_allocator)
	custom_element^ = Clay_Custom_Element_Circle {
		radius = radius,
		color  = color,
	}

	if clay.UI(pin_id(pin_handle))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(radius * 2), height = clay.SizingFixed(radius * 2)},
		},
		custom = {customData = custom_element},
	},
	) {
		if clay_mouse_pressed() {
			g.ui.grabbed_pin = pin_handle
			g.ui.node_grab_consumed = true
		} else if clay_mouse_released() && g.ui.grabbed_pin != nil {
			add_link(&g.graph, g.ui.grabbed_pin.?, pin_handle)
		}
	}
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
	to_pos, ok_to := pin_position(link.to)
	if !ok_to do return

	draw_link_draft(link.from, to_pos)
}

draw_link_draft :: proc(handle: Pin_Handle, b: k2.Vec2) {
	pin_pos, pin_ok := pin_position(handle)
	if !pin_ok do return

	node, exists := hm.get(&g.graph.nodes, handle.node)
	if !exists do return

	node_def := NODE_DEFINITIONS[node.type]
	pin: Pin_Definition
	if handle.index < u8(len(node_def.inputs)) {
		pin = node_def.inputs[int(handle.index)]
	} else {
		pin = node_def.outputs[int(handle.index) - len(node_def.inputs)]
	}

	color :=
		pin.type == .Execution ? clay_color_to_k2_color(COLOR_YELLOW) : clay_color_to_k2_color(COLOR_TEAL)
	k2.draw_line(pin_pos, b, 3, color)
}

output_box :: proc() {
	if clay.UI(clay.ID("OutputBox"))(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {width = clay.SizingFit({min = 400}), height = clay.SizingFit({})},
			padding = clay.PaddingAll(10),
		},
		floating = {
			attachTo = .Parent,
			attachment = {parent = .LeftBottom, element = .LeftBottom},
		},
		backgroundColor = COLOR_MANTLE,
		cornerRadius = {topRight = 16},
	},
	) {
		if clay.UI(clay.ID("OutputBoxHeader"))(
		{
			layout = {
				layoutDirection = .LeftToRight,
				sizing = {width = clay.SizingFit({}), height = clay.SizingFit({})},
				childGap = 10,
				childAlignment = {x = .Left, y = .Center},
			},
		},
		) {
			clay.Text("Output", {fontSize = 18, textColor = COLOR_TEXT})
			if g.executed {
				clay.Text(
					fmt.tprintf(
						"Executed at %v in %v",
						g.last_execution_date,
						g.last_execution_time,
					),
					{fontSize = 14, textColor = COLOR_TEXT},
				)
			}
		}
		clay.Text(g.output, {fontSize = 18, textColor = COLOR_TEXT})
	}
}

stats_box :: proc() {
	if clay.UI(clay.ID("StatsBox"))(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {width = clay.SizingFit({}), height = clay.SizingFit({})},
			padding = clay.PaddingAll(10),
			childAlignment = {x = .Right, y = .Top},
		},
		floating = {
			attachTo = .Parent,
			attachment = {parent = .RightBottom, element = .RightBottom},
			pointerCaptureMode = .Passthrough,
		},
	},
	) {
		stats_text := fmt.tprintf(
			"%d nodes, %d links",
			hm.len(g.graph.nodes),
			hm.len(g.graph.links),
		)
		clay.Text(stats_text, {fontSize = 14, textColor = COLOR_TEXT})

		avg_dt := get_average_frame_time()
		fps_text := fmt.tprintf("FPS: %.2f / %.2f ms", 1.0 / avg_dt, avg_dt * 1000.0)
		clay.Text(fps_text, {fontSize = 14, textColor = COLOR_TEXT})
	}
}

canvas_dropdown :: proc() {
	if clay.UI(clay.ID("CanvasDropdown"))(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {width = clay.SizingFit({}), height = clay.SizingFit({})},
		},
		floating = {attachTo = .Root, offset = g.ui.dropdown_position.?, zIndex = 100},
		backgroundColor = COLOR_MANTLE,
	},
	) {
		if g.ui.dropdown_node != nil {
			if dropdown_item("Delete Node") {
				hm.remove(&g.graph.nodes, g.ui.dropdown_node.?)
				g.ui.dropdown_node = nil
				g.ui.dropdown_position = nil
			}
		} else {
			for def, type in NODE_DEFINITIONS {
				if dropdown_item(fmt.tprintf("Add %s Node", def.name)) {
					add_node(&g.graph, type, g.ui.dropdown_position.?)
					g.ui.dropdown_position = nil
				}
			}
		}

		if k2.mouse_button_went_down(.Left) && !clay.Hovered() {
			g.ui.dropdown_position = nil
			g.ui.dropdown_node = nil
		}
	}
}

do_ui :: proc() -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()

	if clay.UI(clay.ID("OuterContainer"))(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
		},
		backgroundColor = COLOR_BASE,
	},
	) {
		top_bar()
		if g.ui.open_menu != "" {
			if clay.GetPointerState().state == .PressedThisFrame &&
			   !clay.PointerOver(clay.ID("TopBarItems")) &&
			   !clay.PointerOver(clay.ID("TopBarDropdown")) {
				g.ui.open_menu = ""
			} else {
				top_bar_dropdown()
			}
		}

		if clay.UI(clay.ID("Canvas"))(
		{
			layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})}},
			// floating = {attachTo = .Parent},
		},
		) {

			clear(&g.ui.connected_inputs)
			for it, i := hm.iterator_make(&g.graph.links), 0; link, handle in hm.iterate(&it) {
				link_element(link^, i)
				g.ui.connected_inputs[link.to] = {}
				i += 1
			}

			for it, i := hm.iterator_make(&g.graph.nodes), 0; node, handle in hm.iterate(&it) {
				node_element(node, i)
				i += 1
			}

			if k2.mouse_button_went_down(.Right) && clay.Hovered() {
				g.ui.dropdown_position = k2.get_mouse_position()
			}

			if g.ui.dropdown_position != nil {
				canvas_dropdown()
			}
		}

		output_box()
		stats_box()
	}

	return clay.EndLayout(k2.get_frame_time())
}
