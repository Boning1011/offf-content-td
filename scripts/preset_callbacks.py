# Parameter Execute callbacks for Side_LED_ALL preset system

def onValueChange(par, prev, val):
	if par.name == 'Preset':
		comp = par.owner
		mgr = mod(comp.op('preset_manager'))
		mgr.apply_preset(comp, par.eval())
	return

def onPulse(par):
	comp = par.owner
	mgr = mod(comp.op('preset_manager'))
	if par.name == 'Applypreset':
		mgr.apply_preset(comp)
	elif par.name == 'Savepreset':
		mgr.save_current(comp)
	elif par.name == 'Clearscreen':
		for child in ['Side_LED_Effect_1', 'Side_LED_Effect_2']:
			comp.op(child).par.Clearscreen.pulse()
	return

# Standard stubs (required by TD)
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
