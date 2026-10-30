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
	clay.UpdateScrollContainers(true, {vertical_scroll, horizontal_scroll}, k2.get_frame_time())
}

clay_color_to_k2_color :: proc(color: clay.Color) -> k2.Color {
	return {u8(color.r), u8(color.g), u8(color.b), u8(color.a)}
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

			if config.cornerRadius.topLeft > 0 {
				radius: f32 = (config.cornerRadius.topLeft * 2) / min(bounds.width, bounds.height)
				draw_rect_rounded({bounds.x, bounds.y, bounds.width, bounds.height}, radius, color)
			} else {
				k2.draw_rect({bounds.x, bounds.y, bounds.width, bounds.height}, color)
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
			link := cast(^Link)cmd.renderData.custom.customData
			draw_link(link^)
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
	segments: int = 3,
) {
	// (6 * segments) 6 is the number of verts in a segment.
	k2._prepare_draw(g.k2_state.shape_drawing_texture, 6 * segments)

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

// Draw rectangle with rounded edges
// Segments represents how many triangles the corners will have multiplied by 2
draw_rect_rounded :: proc(
	rec: k2.Rect,
	roundness: f32,
	c: k2.Color,
	origin: k2.Vec2 = 0,
	rot: f32 = 0,
	segments: int = 3,
) {
	roundness := roundness
	segments := segments * 2

	if roundness <= 0 { 	// if not a rounded rectangle will just draw a regular rect
		k2.draw_rect(rec, c, origin, rot)
		return
	}

	// (6*5) 6 is the number of verts in a quad. 5 is the number of quads
	k2._prepare_draw(g.k2_state.shape_drawing_texture, 6 * 5)

	if roundness >= 1 { 	// clamps the roundness value to 1
		roundness = 1
	}

	// Calculate corner radius
	radius: f32
	if rec.w > rec.h {
		radius = (rec.h * roundness) / 2
	} else {
		radius = (rec.w * roundness) / 2
	}

	if radius <= 0 {
		return
	}

	stepLength: f32 = 90 / cast(f32)segments

	// Diagram points and part of the math was adapted from Raylib's "DrawRectangleRounded"
	/*
	Quick sketch to make sense of all of this,
	there are 9 parts to draw, also mark the 12 points we'll use
	      P0____________________P1
	      /|                    |\
	     /1|          2         |3\
	 P7 /__|____________________|__\ P2
	   |   |P8                P9|   |
	   | 8 |          9         | 4 |
	   | __|____________________|__ |
	 P6 \  |P11              P10|  / P3
	     \7|          6         |5/
	      \|____________________|/
	      P5                    P4
	*/
	// Coordinates of the 12 points that define the rounded rect
	// These cords are in locale space {0,0}
	point: [12]k2.Vec2
	point = {
		{radius, 0}, // P0
		{(rec.w) - radius, 0}, // P1
		{rec.w, radius}, // P2
		{rec.w, (rec.h) - radius}, // P3
		{(rec.w) - radius, rec.h}, // P4
		{radius, rec.h}, // P5
		{0, (rec.h) - radius}, // P6
		{0, radius}, // P7
		{radius, radius}, // P8
		{(rec.w) - radius, radius}, // P9
		{(rec.w) - radius, (rec.h) - radius}, // P10
		{radius, (rec.h) - radius}, // P11
	}

	centers: [4]k2.Vec2 = {point[8], point[9], point[10], point[11]} // The center of the 4 rounded corners
	angles: [4]f32 = {180, 270, 0, 90}
	tl, tr, bl, br: k2.Vec2

	// Shifts all of the points "Pos and Origin"
	// If rot != 0 then it will rotate them as well
	if rot == 0 {
		xy: k2.Vec2 = {rec.x, rec.y}
		for &p in point { 	// this shifts all of the points to the correct pos
			p += xy
			p += -origin
		}
	} else {
		sin_rot := math.sin(rot)
		cos_rot := math.cos(rot)
		x := rec.x
		y := rec.y
		dx := -origin.x
		dy := -origin.y
		// this shifts all of the points to the correct pos and rotates it
		for &p in point {
			p = {
				x + (dx + p.x) * cos_rot - (dy + p.y) * sin_rot,
				y + (dx + p.x) * sin_rot + (dy + p.y) * cos_rot,
			}
		}
	}

	// Draw all the 4 corners:
	// [1] Upper Left Corner,
	// [3] Upper Right Corner,
	// [5] Lower Right Corner,
	// [7] Lower Left Corner
	for corner in Corner {
		draw_rounded_corner(rec, corner, radius, c, origin, rot, segments)
	}

	// [2] Upper Rectangle
	tl = point[0]
	tr = point[8]
	bl = point[1]
	br = point[9]
	k2.batch_vertex(tl, {0, 0}, c)
	k2.batch_vertex(tr, {1, 0}, c)
	k2.batch_vertex(br, {1, 1}, c)
	k2.batch_vertex(tl, {0, 0}, c)
	k2.batch_vertex(br, {1, 1}, c)
	k2.batch_vertex(bl, {0, 1}, c)

	// [4] Right Rectangle
	tl = point[2]
	tr = point[9]
	bl = point[3]
	br = point[10]
	k2.batch_vertex(tl, {0, 0}, c)
	k2.batch_vertex(tr, {1, 0}, c)
	k2.batch_vertex(br, {1, 1}, c)
	k2.batch_vertex(tl, {0, 0}, c)
	k2.batch_vertex(br, {1, 1}, c)
	k2.batch_vertex(bl, {0, 1}, c)

	// [6] Bottom Rectangle
	tl = point[11]
	tr = point[5]
	bl = point[10]
	br = point[4]
	k2.batch_vertex(tl, {0, 0}, c)
	k2.batch_vertex(tr, {1, 0}, c)
	k2.batch_vertex(br, {1, 1}, c)
	k2.batch_vertex(tl, {0, 0}, c)
	k2.batch_vertex(br, {1, 1}, c)
	k2.batch_vertex(bl, {0, 1}, c)

	// [8] Left Rectangle
	tl = point[7]
	tr = point[6]
	bl = point[8]
	br = point[11]
	k2.batch_vertex(tl, {0, 0}, c)
	k2.batch_vertex(tr, {1, 0}, c)
	k2.batch_vertex(br, {1, 1}, c)
	k2.batch_vertex(tl, {0, 0}, c)
	k2.batch_vertex(br, {1, 1}, c)
	k2.batch_vertex(bl, {0, 1}, c)

	// [9] Middle Rectangle
	tl = point[8]
	tr = point[11]
	bl = point[9]
	br = point[10]
	k2.batch_vertex(tl, {0, 0}, c)
	k2.batch_vertex(tr, {1, 0}, c)
	k2.batch_vertex(br, {1, 1}, c)
	k2.batch_vertex(tl, {0, 0}, c)
	k2.batch_vertex(br, {1, 1}, c)
	k2.batch_vertex(bl, {0, 1}, c)
}
