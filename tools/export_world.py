"""Convert capture_world.luau JSON to the committed Rojo Edit-mode map snapshot."""
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

def sequence(value):
    if isinstance(value, dict):
        return [value[str(i)] for i in range(1, len(value) + 1)]
    return value

def export(tree, output):
    root = ET.Element('roblox', version='4')
    ET.SubElement(root, 'External').text = 'null'
    ET.SubElement(root, 'External').text = 'nil'
    counter = 0

    def item(node, parent):
        nonlocal counter
        counter += 1
        target = ET.SubElement(parent, 'Item', {'class': node['Class'], 'referent': f'RBX{counter}'})
        props = ET.SubElement(target, 'Properties')
        for name, packed in sorted(node['Properties'].items()):
            kind, value = sequence(packed)
            if name == 'Size' and kind == 'Vector3':
                name = 'size'
            if name == 'Shape':
                name = 'shape'
            if name == 'Color' and node['Class'] in ('Part', 'WedgePart', 'CornerWedgePart', 'SpawnLocation'):
                rgb = sequence(value)
                ET.SubElement(props, 'Color3uint8', name='Color3uint8').text = str(sum(round(c * 255) << shift for c, shift in zip(rgb, (16, 8, 0))))
                continue
            tags = {'boolean': 'bool', 'number': 'float', 'CFrame': 'CoordinateFrame'}
            tag = 'int' if name == 'BorderSizePixel' else tags.get(kind, kind)
            entry = ET.SubElement(props, tag, name=name)
            fields = {
                'Vector3': ('X', 'Y', 'Z'),
                'CFrame': ('X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22'),
                'Color3': ('R', 'G', 'B'),
                'UDim2': ('XS', 'XO', 'YS', 'YO'),
                'UDim': ('S', 'O'),
            }
            if kind in fields:
                for key, number in zip(fields[kind], sequence(value)):
                    ET.SubElement(entry, key).text = str(number)
            else:
                entry.text = str(value).lower() if kind == 'boolean' else str(value)
        for child in sequence(node['Children']):
            item(child, target)
    item(tree, root)
    ET.indent(root, space='  ')
    ET.ElementTree(root).write(output, encoding='utf-8', xml_declaration=False)
    print(f'Exported {counter} instances to {output}')

if __name__ == '__main__':
    data = json.loads(Path(sys.argv[1]).read_text())
    # Accept raw capture JSON or a Studio MCP tool response containing it.
    if isinstance(data, list):
        data = json.loads(''.join(step['result']['result']['content'][0]['text'] for step in data))
    elif 'result' in data:
        data = json.loads(data['result']['content'][0]['text'])
        if isinstance(data, str):
            data = json.loads(data)
    export(data, sys.argv[2])
