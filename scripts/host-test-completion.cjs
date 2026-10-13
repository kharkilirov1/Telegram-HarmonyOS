// Observe only the suite's top-level Promise. Fixture promises may remain pending
// after a completed suite, but an unfinished suite must never exit successfully.
function guardSuite(promise) {
  const incomplete = () => {
    console.error('HARNESS_ERROR incomplete async suite');
    process.exitCode = process.exitCode || 2;
  };
  process.on('beforeExit', incomplete);
  return Promise.resolve(promise).then(value => {
    process.removeListener('beforeExit', incomplete);
    return value;
  }, error => {
    process.removeListener('beforeExit', incomplete);
    throw error;
  });
}

module.exports = { guardSuite };
