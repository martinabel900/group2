module.exports = {
  env: {
    node: true, // Enable Node.js globals
    es6: true,  // Enable ECMAScript 6 features
  },
  parserOptions: {
    ecmaVersion: 2018,  // Allow ECMAScript 2018 features
  },
  extends: [
    'eslint:recommended',
    'google',
  ],
  rules: {
    'no-redeclare': 'error',
    'no-undef': 'error',
    'no-unused-vars': 'warn',
  },
};