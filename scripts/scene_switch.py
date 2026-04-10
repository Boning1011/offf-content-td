"""
CHOP Execute - switch Side_LED_ALL preset based on null_mapped (preset_idx 0..2).
Sets the Preset menu, which triggers preset_exec to apply the table values.
"""

def onValueChange(channel, sampleIndex, val, prev):
	idx = int(round(val))
	if 0 <= idx <= 2:
		me.parent().par.Preset.menuIndex = idx
	return

def onOffToOn(channel, sampleIndex, val, prev):
	return

def whileOn(channel, sampleIndex, val, prev):
	return

def onOnToOff(channel, sampleIndex, val, prev):
	return

def whileOff(channel, sampleIndex, val, prev):
	return
