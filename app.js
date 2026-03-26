const express = require('express');
const app = express();

const PORT = 3000;

// Middleware (for JSON handling)
app.use(express.json());

// Health Check Endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'UP',
    message: 'Server is healthy'
  });
});

// Real Endpoint (Users)
app.get('/users', (req, res) => {
  const users = [
    { id: 1, name: 'Alice' },
    { id: 2, name: 'Bob' }
  ];

  res.status(200).json(users);
});

// Start Server
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
