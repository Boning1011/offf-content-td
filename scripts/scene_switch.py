"""
CHOP Execute — switch Side_LED_ALL preset based on scene index.
Watches null_scene_index channel (integer 0..3).
"""

SCENE_TO_PRESET = {
	0: 'Intro',
	1: 'Build',
	2: 'Climax',
	3: 'Resolve',
}

def onOffToOn(channel, sampleIndex, val, prev):
	return

def whileOn(channel, sampleIndex, val, prev):
	return

def onOnToOff(channel, sampleIndex, val, prev):
	return

def whileOff(channel, sampleIndex, val, prev):
	return

def onValueChange(channel, sampleIndex, val, prev):
	idx = int(round(val))
	preset = SCENE_TO_PRESET.get(idx)
	if preset:
		comp = me.parent()
		comp.par.Preset.val = preset
		mgr = mod(comp.op('preset_manager'))
		mgr.apply_preset(comp, preset)
	return
