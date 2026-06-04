const fs = require('fs');
const path = require('path');

function getAllDartFiles(dir) {
  let files = [];
  const items = fs.readdirSync(dir);
  for (const item of items) {
    const fullPath = path.join(dir, item);
    if (fs.statSync(fullPath).isDirectory()) {
      files = files.concat(getAllDartFiles(fullPath));
    } else if (item.endsWith('.dart')) {
      files.push(fullPath);
    }
  }
  return files;
}

const dartDir = 'c:/laragon/www/LUNGO/frontend/app/lib';
const files = getAllDartFiles(dartDir);
let totalFixed = 0;

for (const file of files) {
  const content = fs.readFileSync(file, 'utf8');
  const lines = content.split('\n');
  let changed = false;

  const newLines = lines.map(line => {
    if (!line.includes('//')) return line;
    if (line.includes('http://') || line.includes('https://') || line.includes('dana://')) return line;

    let inString = false;
    let stringChar = '';
    let commentIdx = -1;

    for (let i = 0; i < line.length - 1; i++) {
      const c = line[i];
      if (inString) {
        if (c === '\\') { i++; continue; }
        if (c === stringChar) inString = false;
      } else if (c === '"' || c === "'") {
        inString = true;
        stringChar = c;
      } else if (line[i] === '/' && line[i+1] === '/') {
        commentIdx = i;
        break;
      }
    }

    if (commentIdx >= 0) {
      const newLine = line.substring(0, commentIdx).trimEnd();
      changed = true;
      return newLine;
    }
    return line;
  }).filter((line, idx, arr) => {
    if (line.trim() === '' && idx > 0 && arr[idx-1].trim() === '') return false;
    return true;
  });

  if (changed) {
    fs.writeFileSync(file, newLines.join('\n'), 'utf8');
    totalFixed++;
    console.log('Fixed: ' + path.relative(dartDir, file));
  }
}
console.log('Total fixed: ' + totalFixed + ' files');
