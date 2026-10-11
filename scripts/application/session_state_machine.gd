class_name SessionStateMachine
extends RefCounted

enum State { BOOT, HOME, PLAYING, PAUSED, GAME_OVER }
const LEGAL := {
	State.BOOT: [State.HOME],
	State.HOME: [State.PLAYING, State.GAME_OVER],
	State.PLAYING: [State.PAUSED, State.GAME_OVER, State.HOME],
	State.PAUSED: [State.PLAYING, State.HOME],
	State.GAME_OVER: [State.PLAYING, State.HOME],
}
var _state := State.BOOT

func state() -> int:
	return _state

func transition(target: int) -> bool:
	if not LEGAL[_state].has(target):
		return false
	_state = target
	return true
