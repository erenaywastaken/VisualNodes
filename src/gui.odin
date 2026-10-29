package nodes

import "../clay"
import k2 "../karl2d"

do_ui :: proc() -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()

	return clay.EndLayout(k2.get_frame_time())
}
