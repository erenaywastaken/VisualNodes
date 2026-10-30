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
		layout = {sizing = {width = clay.SizingFixed(200), height = clay.SizingFixed(100)}},
		floating = {offset = node.position, attachTo = .Parent},
		cornerRadius = clay.CornerRadiusAll(16),
		backgroundColor = COLOR_SURFACE,
	},
	) {
		if clay_mouse_pressed() {
			g.mouse_grabbed_node = node.handle
			g.mouse_grab_offset = clay.GetPointerState().position - node.position
		}
	}
}

link_element :: proc(link: ^Link, i: int) {
	// Handled in clay_backend.odin
	clay.UI(clay.ID("Link", u32(i)))(
	{floating = {attachTo = .Parent}, custom = {customData = link}},
	)
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
			link_element(link, i)
			i += 1
		}

		for it, i := hm.iterator_make(&g.graph.nodes), 0; node, handle in hm.iterate(&it) {
			node_element(node, i)
			i += 1
		}
	}

	return clay.EndLayout(k2.get_frame_time())
}
