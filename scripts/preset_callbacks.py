# Parameter Execute callbacks for Side_LED_ALL preset system

PRESET_MAP = {'Intro': 0, 'Build': 1, 'Climax': 2, 'Resolve': 3}

def _apply_table(comp):
	table = comp.op('switch_preset')
	for row in range(1, table.numRows):
		pname = table[row, 'param'].val
		pval = table[row, 'value'].val
		try:
			setattr(comp.par, pname, float(pval))
		except:
			pass

def _save_to_table(comp):
	idx = PRESET_MAP.get(comp.par.Preset.eval())
	if idx is None:
		return
	table = comp.op('preset_' + str(idx))
	for row in range(1, table.numRows):
		pname = table[row, 'param'].val
		try:
			val = getattr(comp.par, pname).eval()
			table[row, 'value'] = str(val)
		except:
			pass

def onValueChange(par, prev, val):
	if par.name == 'Preset':
		comp = par.owner
		idx = PRESET_MAP.get(par.eval())
		if idx is not None:
			comp.op('switch_preset').par.index = idx
			_apply_table(comp)
	return

def onPulse(par):
	comp = par.owner
	if par.name == 'Applypreset':
		idx = PRESET_MAP.get(comp.par.Preset.eval())
		if idx is not None:
			comp.op('switch_preset').par.index = idx
		_apply_table(comp)
	elif par.name == 'Savepreset':
		_save_to_table(comp)
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
