import os, re, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

def remove_inline_comments(code):
    lines = code.split('\n')
    result = []
    for line in lines:
        in_string = False
        string_char = ''
        new_line = []
        i = 0
        while i < len(line):
            c = line[i]
            if in_string:
                new_line.append(c)
                if c == '\\' and i + 1 < len(line):
                    new_line.append(line[i+1])
                    i += 2
                    continue
                if c == string_char:
                    in_string = False
            elif c in ('"', "'"):
                in_string = True
                string_char = c
                new_line.append(c)
            elif line[i:i+2] == '//':
                break
            else:
                new_line.append(c)
            i += 1
        cleaned = ''.join(new_line).rstrip()
        result.append(cleaned)
    return '\n'.join(result)

dart_dir = 'c:/laragon/www/LUNGO/frontend/app/lib'
total = 0

for root, dirs, files in os.walk(dart_dir):
    for fname in files:
        if not fname.endswith('.dart'):
            continue
        fpath = os.path.join(root, fname)
        with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
            original = f.read()
        cleaned = remove_inline_comments(original)
        if cleaned != original:
            with open(fpath, 'w', encoding='utf-8') as f:
                f.write(cleaned)
            total += 1
            print(f'Fixed: {os.path.relpath(fpath, dart_dir)}')

print(f'Total: {total} files fixed')
