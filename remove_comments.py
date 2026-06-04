import os, re, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

def remove_comments(code):
    result = []
    i = 0
    n = len(code)
    in_string = False
    string_char = ''

    while i < n:
        c = code[i]

        if in_string:
            result.append(c)
            if c == '\\' and i + 1 < n:
                result.append(code[i+1])
                i += 2
                continue
            if c == string_char:
                in_string = False
            i += 1
            continue

        if c in ('"', "'"):
            in_string = True
            string_char = c
            result.append(c)
            i += 1
            continue

        if code[i:i+2] == '//':
            while i < n and code[i] != '\n':
                i += 1
            continue

        if code[i:i+2] == '/*':
            i += 2
            while i < n - 1:
                if code[i:i+2] == '*/':
                    i += 2
                    break
                i += 1
            continue

        result.append(c)
        i += 1

    cleaned = ''.join(result)
    cleaned = re.sub(r'\n[ \t]*\n[ \t]*\n', '\n\n', cleaned)
    return cleaned

dart_dir = 'c:/laragon/www/LUNGO/frontend/app/lib'
total = 0
errors = []

for root, dirs, files in os.walk(dart_dir):
    for fname in files:
        if not fname.endswith('.dart'):
            continue
        fpath = os.path.join(root, fname)
        try:
            with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                original = f.read()
            cleaned = remove_comments(original)
            if cleaned != original:
                with open(fpath, 'w', encoding='utf-8') as f:
                    f.write(cleaned)
                total += 1
                rel = os.path.relpath(fpath, dart_dir)
                print(f'Cleaned: {rel}')
        except Exception as e:
            errors.append(f'{fname}: {e}')

print(f'\nTotal files cleaned: {total}')
if errors:
    print(f'Errors: {errors}')
