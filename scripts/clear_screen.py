"""
Clear Screen - resets all feedback TOPs found anywhere inside this component.
"""

def onPulse(par):
    if par.name == 'Clearscreen':
        comp = me.parent()
        for fb in comp.findChildren(type=TOP):
            if fb.type == 'feedback':
                fb.par.resetpulse.pulse()

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
