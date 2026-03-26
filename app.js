const express = require('express');
const app = express();

const PORT = 3000;

app.use(express.json());

// Routes
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'UP',
    message: 'Server is healthy'
  });
});

app.get('/users', (req, res) => {
  const users = [
    { id: 1, name: 'Alice' },
    { id: 2, name: 'Bob' }
  ];

  res.status(200).json(users);
});

// Export app for testing
module.exports = app;

// Start server only if run directly
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}
