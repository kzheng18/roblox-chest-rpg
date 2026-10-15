"""Reject executable scripts in packaged models; allow only sword JSON modules.

This is a packaging gate for these models, not a general Lua security audit.
"""
from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
data_model = ROOT / 'src/assets/SwordGeometry.rbxmx'
scripts = 0


def validate_source(code):
    match = re.fullmatch(r'\s*return\s*\[==\[(.*)\]==\]\s*', code, flags=re.S)
    assert match, 'Unexpected executable geometry module'
    payload = match.group(1)
    # A delimiter inside JSON text would terminate the Lua string early, even
    # if the greedy match and JSON parser otherwise accepted the whole source.
    assert ']==]' not in payload, 'Embedded Lua string delimiter'
    return json.loads(payload)


for malicious in (
    'return [==[{"x":"]==]..require(1)..[==["}]==]',
    'return [==[{}]==]; require(1)',
    'require(1); return [==[{}]==]',
):
    try:
        validate_source(malicious)
    except (AssertionError, ValueError):
        continue
    raise AssertionError('Model audit accepted executable source')

for path in sorted((ROOT / 'src').rglob('*.rbxmx')):
    for item in ET.parse(path).getroot().iter('Item'):
        if item.attrib.get('class') not in ('Script', 'LocalScript', 'ModuleScript'):
            continue
        assert path == data_model and item.attrib['class'] == 'ModuleScript', f'Executable model script in {path}'
        props = item.find('Properties')
        source = props.find("ProtectedString[@name='Source']")
        if source is None:
            source = props.find("string[@name='Source']")
        code = source.text or '' if source is not None else ''
        validate_source(code)
        scripts += 1
print(f'PASS packaged model audit: {scripts} JSON-only modules; no executable model scripts')
