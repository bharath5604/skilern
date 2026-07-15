// hash-admin.js
const bcrypt = require('bcryptjs');

async function run() {
  const plain = 'Raghavarao@9000';
  const hash = await bcrypt.hash(plain, 10); // same salt rounds as your app
  console.log(hash);
}

run();