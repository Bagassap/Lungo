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
let total = 0;
const found = [];

for (const file of files) {
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  lines.forEach((line, idx) => {
    if (line.includes('//') &&
        !line.includes('http://') &&
        !line.includes('https://') &&
        !line.includes('dana://')) {
      total++;
      found.push(path.relative(dartDir, file) + ':' + (idx+1) + ' -> ' + line.trim());
    }
  });
}

console.log('Komentar non-URL tersisa: ' + total);
found.slice(0, 30).forEach(f => console.log(f));
if (total === 0) console.log('BERSIH SEMPURNA!');
