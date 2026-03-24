"""
CHOP Execute - switch Side_LED_ALL preset based on scene index.
Watches null_scene_index channel (integer 0..2).
Reads parameter values from switch_preset DAT and applies them.
"""

PRESET_NAMES = {0: 'Mid Speed, Mid Density', 1: 'Fast Speed, High Density', 2: 'Slow Speed, Mid Density'}

def _apply_from_table(comp):
	table = comp.op('switch_preset')
	for row in range(1, table.numRows):
		pname = table[row, 'param'].val
		pval = table[row, 'value'].val
		try:
			setattr(comp.par, pname, float(pval))
		except:
			pass

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
	comp = me.parent()
	preset = PRESET_NAMES.get(idx)
	if preset:
		comp.par.Preset.val = preset
		_apply_from_table(comp)
	return
