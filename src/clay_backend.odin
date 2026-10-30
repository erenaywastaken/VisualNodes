package nodes

// Some parts from https://gist.github.com/brunodeangelis/8289db5012c687ee953b60ba96e71518

import "../clay"
import k2 "../karl2d"
import "base:runtime"
import "core:fmt"
import "core:math"
import "core:unicode/utf8"

setup_clay :: proc() {
	error_handler :: proc "c" (errorData: clay.ErrorData) {
		context = runtime.default_context()
		panic(
			fmt.tprintf(
				"Clay Error: %s",
				string(errorData.errorText.chars[:errorData.errorText.length]),
			),
		)
	}

	min_memory_size := clay.MinMemorySize()
	memory := make([^]u8, min_memory_size)
	arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), memory)
	clay.Initialize(arena, {1280, 720}, {handler = error_handler})

	measure_text :: proc "c" (
		text: clay.StringSlice,
		config: ^clay.TextElementConfig,
		userData: rawptr,
	) -> clay.Dimensions {
		context = runtime.default_context()

		text_str := string(text.chars[:text.length])

		size := k2.measure_text(text_str, f32(config.fontSize))

		if config.letterSpacing != 0 {
			grapheme_count, _, _ := utf8.grapheme_count(text_str)
			size.x += f32(grapheme_count) * f32(config.letterSpacing)
		}

		return {width = size.x, height = f32(config.fontSize)}
	}


	clay.SetMeasureTextFunction(measure_text, nil)
}

clay_update_state :: proc() {
	screen_size := k2.get_screen_size()
	clay.SetLayoutDimensions({screen_size.x, screen_size.y})
	clay.SetPointerState(k2.get_mouse_position(), k2.mouse_button_is_held(.Left))
	vertical_scroll := k2.get_mouse_wheel_delta()
	horizontal_scroll := k2.get_mouse_wheel_delta_horizontal()
	if k2.key_is_held(.Left_Shift) {
		vertical_scroll = 0
		horizontal_scroll += k2.get_mouse_wheel_delta()
	}
	clay.UpdateScrollContainers(
		true,
		{horizontal_scroll, vertical_scroll} * 4,
		k2.get_frame_time(),
	)

	if k2.key_went_down(.F12) {
		clay.SetDebugModeEnabled(!clay.IsDebugModeEnabled())
	}
}

clay_color_to_k2_color :: proc(color: clay.Color) -> k2.Color {
	return {u8(color.r), u8(color.g), u8(color.b), u8(color.a)}
}

Clay_Custom_Element :: union {
	Link,
	Clay_Custom_Element_Circle,
}

Clay_Custom_Element_Circle :: struct {
	radius: f32,
	color:  clay.Color,
}

clay_render :: proc(cmds: ^clay.ClayArray(clay.RenderCommand)) {
	overlay_colors := make([dynamic]clay.Color, context.temp_allocator)
	for i in 0 ..< cmds.length {
		cmd := clay.RenderCommandArray_Get(cmds, i)
		bounds := cmd.boundingBox

		switch cmd.commandType {
		case .Text:
			config := cmd.renderData.text

			text := string(config.stringContents.chars[:config.stringContents.length])

			k2.draw_text(
				text,
				{bounds.x, bounds.y},
				f32(config.fontSize),
				clay_color_to_k2_color(config.textColor),
			)
		case .Image:
			config := cmd.renderData.image
			tint := config.backgroundColor
			if tint == {} {
				tint = {255, 255, 255, 255}
			}
			texture := (^k2.Texture)(config.imageData)
			src := k2.Rect{0, 0, f32(texture.width), f32(texture.height)}
			dst := k2.Rect{bounds.x, bounds.y, bounds.width, bounds.height}
			k2.draw_texture_fit(texture^, src, dst, {0, 0}, 0, clay_color_to_k2_color(tint))
		case .ScissorStart:
			k2.set_scissor_rect(k2.Rect{bounds.x, bounds.y, bounds.width, bounds.height})

		case .ScissorEnd:
			k2.set_scissor_rect(nil)

		case .Rectangle:
			config := cmd.renderData.rectangle
			color := clay_color_to_k2_color(config.backgroundColor)

			cr := config.cornerRadius
			rounded := cr.topLeft > 0 || cr.topRight > 0 || cr.bottomRight > 0 || cr.bottomLeft > 0

			if !rounded {
				k2.draw_rect({bounds.x, bounds.y, bounds.width, bounds.height}, color)
			} else {
				// These are the rectangles we draw, seperated:
				//       XXXX
				//    XX XXXX X
				//       XXXX
				tl_r := f32(cr.topLeft)
				tr_r := f32(cr.topRight)
				br_r := f32(cr.bottomRight)
				bl_r := f32(cr.bottomLeft)

				// Top
				if bounds.width - tl_r - tr_r > 0 {
					k2.draw_rect(
						{bounds.x + tl_r, bounds.y, bounds.width - tl_r - tr_r, max(tl_r, tr_r)},
						color,
					)
				}
				// Bottom
				if bounds.width - bl_r - br_r > 0 {
					k2.draw_rect(
						{
							bounds.x + bl_r,
							bounds.y + bounds.height - max(bl_r, br_r),
							bounds.width - bl_r - br_r,
							max(bl_r, br_r),
						},
						color,
					)
				}
				// Left
				if bounds.height - tl_r - bl_r > 0 {
					k2.draw_rect(
						{bounds.x, bounds.y + tl_r, max(tl_r, bl_r), bounds.height - tl_r - bl_r},
						color,
					)
				}
				// Right
				if bounds.height - tr_r - br_r > 0 {
					k2.draw_rect(
						{
							bounds.x + bounds.width - max(tr_r, br_r),
							bounds.y + tr_r,
							max(tr_r, br_r),
							bounds.height - tr_r - br_r,
						},
						color,
					)
				}
				// Center
				cx := bounds.x + max(tl_r, bl_r)
				cy := bounds.y + max(tl_r, tr_r)
				cw := bounds.width - max(tl_r, bl_r) - max(tr_r, br_r)
				ch := bounds.height - max(tl_r, tr_r) - max(bl_r, br_r)
				if cw > 0 && ch > 0 {
					k2.draw_rect({cx, cy, cw, ch}, color)
				}

				// Corners
				if tl_r > 0 {
					draw_rounded_corner(
						{bounds.x, bounds.y, bounds.width, bounds.height},
						.Top_Left,
						tl_r,
						color,
					)
				}
				if tr_r > 0 {
					draw_rounded_corner(
						{bounds.x, bounds.y, bounds.width, bounds.height},
						.Top_Right,
						tr_r,
						color,
					)
				}
				if br_r > 0 {
					draw_rounded_corner(
						{bounds.x, bounds.y, bounds.width, bounds.height},
						.Bottom_Right,
						br_r,
						color,
					)
				}
				if bl_r > 0 {
					draw_rounded_corner(
						{bounds.x, bounds.y, bounds.width, bounds.height},
						.Bottom_Left,
						bl_r,
						color,
					)
				}
			}

		case .Border:
			config := cmd.renderData.border
			color := clay_color_to_k2_color(config.color)

			if config.width.left > 0 {
				k2.draw_rect({bounds.x, bounds.y, f32(config.width.left), bounds.height}, color)
			}
			if config.width.right > 0 {
				k2.draw_rect(
					{
						bounds.x + bounds.width - f32(config.width.right),
						bounds.y,
						f32(config.width.right),
						bounds.height,
					},
					color,
				)
			}
			if config.width.top > 0 {
				k2.draw_rect({bounds.x, bounds.y, bounds.width, f32(config.width.top)}, color)
			}
			if config.width.bottom > 0 {
				k2.draw_rect(
					{
						bounds.x,
						bounds.y + bounds.height - f32(config.width.bottom),
						bounds.width,
						f32(config.width.bottom),
					},
					color,
				)
			}

			if config.cornerRadius.topLeft > 0 {
				draw_rounded_corner(
					{bounds.x, bounds.y, bounds.width, bounds.height},
					.Top_Left,
					f32(config.cornerRadius.topLeft),
					color,
				)
			}

			if config.cornerRadius.topRight > 0 {
				draw_rounded_corner(
					{bounds.x, bounds.y, bounds.width, bounds.height},
					.Top_Right,
					f32(config.cornerRadius.topRight),
					color,
				)
			}

			if config.cornerRadius.bottomRight > 0 {
				draw_rounded_corner(
					{bounds.x, bounds.y, bounds.width, bounds.height},
					.Bottom_Right,
					f32(config.cornerRadius.bottomRight),
					color,
				)
			}

			if config.cornerRadius.bottomLeft > 0 {
				draw_rounded_corner(
					{bounds.x, bounds.y, bounds.width, bounds.height},
					.Bottom_Left,
					f32(config.cornerRadius.bottomLeft),
					color,
				)
			}
		case .OverlayColorStart:
			config := cmd.renderData.overlayColor
			append(&overlay_colors, config.color)
		case .OverlayColorEnd:
			pop(&overlay_colors)
		case .Custom:
			switch v in (cast(^Clay_Custom_Element)cmd.renderData.custom.customData)^ {
			case Link:
				draw_link(v)
			case Clay_Custom_Element_Circle:
				k2.draw_circle(
					{bounds.x, bounds.y} + v.radius,
					v.radius,
					clay_color_to_k2_color(v.color),
				)
			}
		case .None:
		}
	}
}

// Heavily based on github.com/karl-zylinski/karl2d/pull/42

Corner :: enum {
	Top_Left = 0,
	Top_Right,
	Bottom_Right,
	Bottom_Left,
}

draw_rounded_corner :: proc(
	rec: k2.Rect,
	corner: Corner,
	radius: f32,
	c: k2.Color,
	origin: k2.Vec2 = 0,
	rot: f32 = 0,
	segments: int = 6,
) {
	k2._prepare_draw(g.k2_state.shape_drawing_texture, 6 * segments / 2)

	point: [12]k2.Vec2
	centers := [4]k2.Vec2 {
		{radius, radius}, // P8
		{(rec.w) - radius, radius}, // P9
		{(rec.w) - radius, (rec.h) - radius}, // P10
		{radius, (rec.h) - radius}, // P11
	}
	angles: [4]f32 = {180, 270, 0, 90}

	stepLength: f32 = 90 / cast(f32)segments

	tl, tr, bl, br: k2.Vec2
	angle: f32 = angles[corner]
	center: k2.Vec2 = centers[corner]
	// NOTE: Every QUAD actually represents two segments
	for i := 0; i < segments / 2; i += 1 {
		// Shifts all of the points "Pos and Origin"
		// if rot != 0 then it will rotate them as well
		// It will then draw the corners
		if rot == 0 {
			x := center.x + rec.x - origin.x
			y := center.y + rec.y - origin.y
			tl = {x, y}
			tr = {
				x + math.cos_f32((math.PI / 180) * (angle + stepLength * 2)) * radius,
				y + math.sin_f32((math.PI / 180) * (angle + stepLength * 2)) * radius,
			}
			bl = {
				x + math.cos_f32((math.PI / 180) * (angle + stepLength)) * radius,
				y + math.sin_f32((math.PI / 180) * (angle + stepLength)) * radius,
			}
			br = {
				x + math.cos_f32((math.PI / 180) * angle) * radius,
				y + math.sin_f32((math.PI / 180) * angle) * radius,
			}
		} else {
			sin_rot := math.sin(rot)
			cos_rot := math.cos(rot)
			x := rec.x
			y := rec.y
			dx := center.x - origin.x
			dy := center.y - origin.y

			tl = {x + (dx) * cos_rot - (dy) * sin_rot, y + (dx) * sin_rot + (dy) * cos_rot}

			tr_cos_rot := math.cos_f32((math.PI / 180) * (angle + stepLength * 2)) * radius
			tr_sin_rot := math.sin_f32((math.PI / 180) * (angle + stepLength * 2)) * radius
			tr = {
				x + (dx + tr_cos_rot) * cos_rot - (dy + tr_sin_rot) * sin_rot,
				y + (dx + tr_cos_rot) * sin_rot + (dy + tr_sin_rot) * cos_rot,
			}

			bl_cos_rot := math.cos_f32((math.PI / 180) * (angle + stepLength)) * radius
			bl_sin_rot := math.sin_f32((math.PI / 180) * (angle + stepLength)) * radius
			bl = {
				x + (dx + bl_cos_rot) * cos_rot - (dy + bl_sin_rot) * sin_rot,
				y + (dx + bl_cos_rot) * sin_rot + (dy + bl_sin_rot) * cos_rot,
			}

			br_cos_rot := math.cos_f32((math.PI / 180) * angle) * radius
			br_sin_rot := math.sin_f32((math.PI / 180) * angle) * radius
			br = {
				x + (dx + br_cos_rot) * cos_rot - (dy + br_sin_rot) * sin_rot,
				y + (dx + br_cos_rot) * sin_rot + (dy + br_sin_rot) * cos_rot,
			}
		}
		k2.batch_vertex(tl, {0, 0}, c)
		k2.batch_vertex(br, {1, 0}, c)
		k2.batch_vertex(bl, {1, 1}, c)

		k2.batch_vertex(tl, {0, 0}, c)
		k2.batch_vertex(tr, {1, 1}, c)
		k2.batch_vertex(bl, {0, 1}, c)

		angle += (stepLength * 2)
	}
}
