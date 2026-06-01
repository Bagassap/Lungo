import os
import sys


def strip_dart_comments(content: str) -> str:
    result: list[str] = []
    i = 0
    n = len(content)

    while i < n:
        if i + 2 < n and content[i:i+3] in ('"""', "'''"):
            quote3 = content[i:i+3]
            result.append(quote3)
            i += 3
            while i < n:
                if content[i:i+3] == quote3:
                    result.append(quote3)
                    i += 3
                    break
                if content[i] == '\\' and i + 1 < n:
                    result.append(content[i:i+2])
                    i += 2
                else:
                    result.append(content[i])
                    i += 1

        elif (i + 3 < n and content[i] == 'r'
              and content[i+1:i+4] in ('"""', "'''")):
            quote3 = content[i+1:i+4]
            result.append(content[i:i+4])
            i += 4
            while i < n:
                if content[i:i+3] == quote3:
                    result.append(quote3)
                    i += 3
                    break
                result.append(content[i])
                i += 1

        elif (i + 1 < n and content[i] == 'r'
              and content[i+1] in ('"', "'")):
            quote = content[i+1]
            result.append(content[i:i+2])
            i += 2
            while i < n and content[i] != quote:
                result.append(content[i])
                i += 1
            if i < n:
                result.append(content[i])
                i += 1

        elif content[i] in ('"', "'"):
            quote = content[i]
            result.append(content[i])
            i += 1
            while i < n:
                if content[i] == '\\' and i + 1 < n:
                    result.append(content[i:i+2])
                    i += 2
                elif content[i] == quote:
                    result.append(content[i])
                    i += 1
                    break
                else:
                    result.append(content[i])
                    i += 1

        elif content[i:i+2] == '//':
            while i < n and content[i] != '\n':
                i += 1

        elif content[i:i+2] == '/*':
            i += 2
            while i < n:
                if content[i:i+2] == '*/':
                    i += 2
                    break
                if content[i] == '\n':
                    result.append('\n')
                i += 1

        else:
            result.append(content[i])
            i += 1

    return ''.join(result)


def _ts_scan_string(content: str, i: int, n: int, quote: str,
                    result: list[str]) -> int:
    result.append(quote)
    i += 1
    while i < n:
        if content[i] == '\\' and i + 1 < n:
            result.append(content[i:i+2])
            i += 2
        elif content[i] == quote:
            result.append(content[i])
            i += 1
            break
        else:
            result.append(content[i])
            i += 1
    return i


def _ts_scan_template(content: str, i: int, n: int, result: list[str]) -> int:
    result.append('`')
    i += 1
    while i < n:
        if content[i] == '\\' and i + 1 < n:
            result.append(content[i:i+2])
            i += 2
        elif content[i] == '`':
            result.append('`')
            i += 1
            return i
        elif content[i] == '$' and i + 1 < n and content[i+1] == '{':
            result.append('${')
            i += 2
            depth = 1
            while i < n and depth > 0:
                if content[i] == '`':
                    i = _ts_scan_template(content, i, n, result)
                elif content[i] in ('"', "'"):
                    i = _ts_scan_string(content, i, n, content[i], result)
                elif content[i:i+2] == '//':
                    while i < n and content[i] != '\n':
                        i += 1
                elif content[i:i+2] == '/*':
                    i += 2
                    while i < n:
                        if content[i:i+2] == '*/':
                            i += 2
                            break
                        if content[i] == '\n':
                            result.append('\n')
                        i += 1
                elif content[i] == '{':
                    depth += 1
                    result.append(content[i])
                    i += 1
                elif content[i] == '}':
                    depth -= 1
                    result.append(content[i])
                    i += 1
                else:
                    result.append(content[i])
                    i += 1
        else:
            result.append(content[i])
            i += 1
    return i


def strip_ts_comments(content: str) -> str:
    result: list[str] = []
    i = 0
    n = len(content)

    while i < n:
        if content[i] == '`':
            i = _ts_scan_template(content, i, n, result)

        elif content[i] in ('"', "'"):
            i = _ts_scan_string(content, i, n, content[i], result)

        elif content[i:i+2] == '//':
            while i < n and content[i] != '\n':
                i += 1

        elif content[i:i+2] == '/*':
            i += 2
            while i < n:
                if content[i:i+2] == '*/':
                    i += 2
                    break
                if content[i] == '\n':
                    result.append('\n')
                i += 1

        else:
            result.append(content[i])
            i += 1

    return ''.join(result)


def clean_blank_lines(content: str) -> str:
    lines = [line.rstrip() for line in content.split('\n')]

    cleaned: list[str] = []
    blank_count = 0
    for line in lines:
        if line == '':
            blank_count += 1
            if blank_count <= 1:
                cleaned.append('')
        else:
            blank_count = 0
            cleaned.append(line)

    while cleaned and cleaned[0] == '':
        cleaned.pop(0)

    result = '\n'.join(cleaned)
    return result.rstrip('\n') + '\n'


def process_file(path: str, strip_fn) -> bool:
    with open(path, encoding='utf-8') as f:
        original = f.read()

    stripped = strip_fn(original)
    final    = clean_blank_lines(stripped)

    if final == original:
        return False

    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(final)
    return True


def walk_and_strip(root_dir: str, ext: str, strip_fn) -> tuple[int, int]:
    changed = 0
    total   = 0
    for root, _, files in os.walk(root_dir):
        for fname in files:
            if not fname.endswith(ext):
                continue
            fpath = os.path.join(root, fname)
            total += 1
            try:
                if process_file(fpath, strip_fn):
                    rel = os.path.relpath(fpath, root_dir)
                    print(f'  stripped: {rel}')
                    changed += 1
            except Exception as e:
                print(f'  ERROR {fpath}: {e}', file=sys.stderr)
    return changed, total


def main():
    base = r'c:\laragon\www\LUNGO'

    targets = [
        (r'frontend\app\lib',  '.dart', strip_dart_comments),
        (r'backend\src',       '.ts',   strip_ts_comments),
    ]

    total_changed = 0
    total_all     = 0

    for rel_dir, ext, strip_fn in targets:
        full_dir = os.path.join(base, rel_dir)
        print(f'\n[{ext}] {full_dir}')
        c, t = walk_and_strip(full_dir, ext, strip_fn)
        total_changed += c
        total_all     += t

    print(f'\nDone. {total_changed}/{total_all} files modified.')


if __name__ == '__main__':
    main()
