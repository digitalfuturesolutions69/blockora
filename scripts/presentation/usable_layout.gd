class_name UsableLayout
extends RefCounted

# Android supplies screen pixels; Godot Controls use expanded canvas coordinates.
static func safe_canvas_rect(screen_safe: Rect2, window_pixels: Rect2, canvas_to_window: Transform2D, canvas: Rect2) -> Rect2:
	if screen_safe.size.x <= 0 or screen_safe.size.y <= 0:
		return canvas
	var physical := screen_safe.intersection(window_pixels)
	if physical.size.x <= 0 or physical.size.y <= 0:
		return canvas
	var inverse := canvas_to_window.affine_inverse()
	var start := inverse * (physical.position - window_pixels.position)
	var finish := inverse * (physical.end - window_pixels.position)
	return Rect2(start, finish - start).intersection(canvas)

static func touch_target(dpi: float, canvas_to_window: Transform2D) -> float:
	var scale := maxf(0.01, canvas_to_window.x.length())
	return maxf(96.0, 48.0 * maxf(160.0, dpi) / 160.0 / scale)

static func content_rect(safe: Rect2) -> Rect2:
	return Rect2(safe.position + Vector2(24,28), (safe.size - Vector2(48,56)).max(Vector2.ZERO))
