"""
Clear Screen callback for Side_LED_Effect TOX.
Resets all feedback TOPs (morse_fb, morse_fb1, ca_feedback).
Attach to a parameterexecuteDAT watching '..' for 'Clearscreen' pulse.
"""

FEEDBACK_NODES = ['morse_fb', 'morse_fb1', 'ca_feedback']

def onPulse(par):
	if par.name == 'Clearscreen':
		comp = par.owner
		for name in FEEDBACK_NODES:
			node = comp.op(name)
			if node:
				node.par.resetpulse.pulse()

def onValueChange(par, prev, val):
	return

def onValuesChanged(changes):
	return

def onExpressionChange(par, val, prev):
	return

def onExportChange(par, val, prev):
	return

def onEnableChange(par, val, prev):
	return

def onModeChange(par, val, prev):
	return
