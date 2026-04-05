/* Avvio da Run and Debug: esegue firmware/build_and_flash.sh (niente CMake kit / LLDB). */
const { execSync } = require('child_process');
const path = require('path');

const firmware = path.join(__dirname, '..', 'firmware');
try {
  execSync('./build_and_flash.sh', {
    cwd: firmware,
    stdio: 'inherit',
    env: process.env,
    shell: '/bin/bash',
  });
  process.exit(0);
} catch (e) {
  process.exit(typeof e.status === 'number' ? e.status : 1);
}
