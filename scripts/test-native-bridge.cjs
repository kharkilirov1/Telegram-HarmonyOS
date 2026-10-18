// Actual-source lifecycle tests, including native constructor fault injection.
try { require('./native-bridge/run-flow.cjs')({ lifecycle: true }); }
catch (error) { console.error(error); process.exitCode = 1; }
