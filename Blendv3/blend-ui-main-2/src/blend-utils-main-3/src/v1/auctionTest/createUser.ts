import { createUser } from './user.js';

const user = await createUser();
console.log(user.secret(), '\n', user.publicKey());
