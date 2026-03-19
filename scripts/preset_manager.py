"""
Preset Manager for Side_LED_ALL
- Loads/saves presets from JSON file
- Drop this into a Text DAT with sync, then reference from parameterexecute callbacks
"""
import json
import os

PRESET_FILE = 'presets/side_led_presets.json'
PARAM_NAMES = [
    'Dotspeedscale', 'Dotminspeed', 'Inputprobability', 'Colorfaderate',
    'Usecolor', 'Backupmode', 'Pixelprobability', 'Cakillrate', 'Caupdatebynframes'
]

def _preset_path():
    return os.path.join(project.folder, PRESET_FILE)

def _load_presets():
    path = _preset_path()
    if not os.path.exists(path):
        return {"presets": {}, "order": []}
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def _save_presets(data):
    path = _preset_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def refresh_menu(comp):
    """Update the Preset menu parameter from the JSON file."""
    data = _load_presets()
    order = data.get('order', list(data.get('presets', {}).keys()))
    presets = data.get('presets', {})
    names = [n for n in order if n in presets]
    labels = []
    for n in names:
        desc = presets[n].get('description', n)
        labels.append(desc if desc else n)
    comp.par.Preset.menuNames = names
    comp.par.Preset.menuLabels = labels

def apply_preset(comp, preset_name=None):
    """Apply a preset to the component's custom parameters."""
    if preset_name is None:
        preset_name = comp.par.Preset.eval()
    data = _load_presets()
    preset = data.get('presets', {}).get(preset_name)
    if not preset:
        debug(f'Preset "{preset_name}" not found')
        return
    for p in PARAM_NAMES:
        if p in preset:
            setattr(comp.par, p, preset[p])

def save_current(comp, name=None):
    """Save current parameter values as a preset."""
    if name is None:
        name = comp.par.Preset.eval()
    data = _load_presets()
    existing = data.get('presets', {}).get(name, {})
    preset = {'description': existing.get('description', name)}
    for p in PARAM_NAMES:
        val = getattr(comp.par, p).eval()
        preset[p] = val
    data.setdefault('presets', {})[name] = preset
    if name not in data.get('order', []):
        data.setdefault('order', []).append(name)
    _save_presets(data)
    refresh_menu(comp)
    debug(f'Preset "{name}" saved')
