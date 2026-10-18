// Actual-source delivery, credit and heap matrix. Old drop/retry expectations
// are replaced by the frozen lossless-or-terminal receive contract.
try { require('./native-bridge/run-flow.cjs')(); }
catch (error) { console.error(error); process.exitCode = 1; }
