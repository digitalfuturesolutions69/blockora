class_name SfxLibrary
extends RefCounted

# Original procedural compositions. See docs/audio/gameplay-sfx.md for provenance.
const RATE := 22050
const RECIPES := {
	"piece_placed": {"seconds": 0.12, "notes": [1046.5], "noise": 0.0},
	"line_clear_1": {"seconds": 0.28, "notes": [1046.5, 1568.0], "noise": 0.08},
	"line_clear_2": {"seconds": 0.38, "notes": [1174.7, 1568.0, 2093.0], "noise": 0.08},
	"line_clear_3_plus": {"seconds": 0.52, "notes": [1046.5, 1318.5, 1568.0, 2093.0], "noise": 0.06},
	"combo": {"seconds": 0.18, "notes": [1318.5, 1568.0], "noise": 0.0},
	"invalid_placement": {"seconds": 0.09, "notes": [293.7], "noise": 0.0},
	"game_over": {"seconds": 0.55, "notes": [784.0, 659.3, 523.3], "noise": 0.0},
	"daily_completed": {"seconds": 0.50, "notes": [1046.5, 1318.5, 1568.0, 2093.0], "noise": 0.0}
}

static func create() -> Dictionary:
	var streams := {}
	for event: String in RECIPES:
		streams[event] = _synthesize(RECIPES[event], event == "invalid_placement")
	return streams

static func _synthesize(recipe: Dictionary, soft: bool) -> AudioStreamWAV:
	var count := int(float(recipe.seconds) * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var noise_state := 23
	var filtered_noise := 0.0
	var notes: Array = recipe.notes
	for index in count:
		var t := float(index) / RATE
		var progress := float(index) / (count - 1)
		var note_progress := progress * notes.size()
		var note_index := mini(int(note_progress), notes.size() - 1)
		var local := note_progress - note_index
		# Smooth attack/release per note and at stream boundaries prevent clicks.
		var envelope := sin(PI * local) * exp(-2.0 * local)
		var frequency := float(notes[note_index])
		var tone := sin(TAU * frequency * t) + 0.16 * sin(TAU * frequency * 2.0 * t)
		noise_state = (noise_state * 48271) % 2147483647
		filtered_noise = lerpf(filtered_noise, float(noise_state) / 1073741823.5 - 1.0, 0.15)
		var whoosh := filtered_noise * float(recipe.noise) * sin(PI * progress)
		var sample := (tone * envelope * (0.12 if soft else 0.38) + whoosh) * sin(PI * progress)
		data.encode_s16(index * 2, int(clampf(sample, -0.45, 0.45) * 32767))
	var stream := AudioStreamWAV.new()
	stream.mix_rate = RATE
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = data
	return stream
