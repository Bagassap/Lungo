import os, re, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

COMMENT_LINE = re.compile(r'^\s*//')
COMMENT_INLINE = re.compile(r'\)\s*//|\]\s*//|\}\s*//|,\s*//')

dart_dir = 'c:/laragon/www/LUNGO/frontend/app/lib'
total_comments = 0
files_with_comments = []

for root, dirs, files in os.walk(dart_dir):
    for fname in files:
        if not fname.endswith('.dart'):
            continue
        fpath = os.path.join(root, fname)
        file_count = 0
        with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
            for i, line in enumerate(f, 1):
                if COMMENT_LINE.search(line) or COMMENT_INLINE.search(line):
                    total_comments += 1
                    file_count += 1
        if file_count > 0:
            rel = os.path.relpath(fpath, dart_dir)
            files_with_comments.append(f'{rel}: {file_count} komentar')

print(f'Total komentar tersisa: {total_comments}')
if files_with_comments:
    print('File dengan komentar:')
    for f in files_with_comments:
        print(f'  {f}')
else:
    print('BERSIH SEMPURNA - 0 komentar!')
