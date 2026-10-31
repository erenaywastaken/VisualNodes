package nodes

import "core:math"
import "core:math/linalg"

// Taken from https://victorlecomte.com/cp-geo.pdf
// Handbook of geometry for competitive programmers

Vec2 :: [2]f32

orient :: proc(a, b, c: Vec2) -> f32 {
	return linalg.cross(b - a, c - a)
}

segment_segment_intersects :: proc(a, b, c, d: Vec2) -> bool {
	oa := orient(c, d, a)
	ob := orient(c, d, b)
	oc := orient(a, b, c)
	od := orient(a, b, d)
    
	// Proper intersection exists iff opposite signs
	return oa * ob < 0 && oc * od < 0
}
