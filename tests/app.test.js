const request = require('supertest');
const app = require('../app');

describe('DevOps App API Tests', () => {

  // ============================================
  // GET /health endpoint tests
  // ============================================
  it('GET /health → should return status UP', async () => {
    const res = await request(app).get('/health');

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('status', 'UP');
    expect(res.body).toHaveProperty('message');
  });

  it('GET /health → should return correct message', async () => {
    const res = await request(app).get('/health');

    expect(res.body.message).toBe('Server is healthy');
  });

  it('GET /health → should return JSON content-type', async () => {
    const res = await request(app).get('/health');

    expect(res.headers['content-type']).toMatch(/json/);
  });

  // ============================================
  // GET /users endpoint tests
  // ============================================
  it('GET /users → should return list of users', async () => {
    const res = await request(app).get('/users');

    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);

    expect(res.body[0]).toHaveProperty('id');
    expect(res.body[0]).toHaveProperty('name');
  });

  it('GET /users → should return correct user data structure', async () => {
    const res = await request(app).get('/users');

    expect(res.body).toEqual([
      { id: 1, name: 'Alice' },
      { id: 2, name: 'Bob' }
    ]);
  });

  it('GET /users → should return JSON content-type', async () => {
    const res = await request(app).get('/users');

    expect(res.headers['content-type']).toMatch(/json/);
  });

  // ============================================
  // Edge case tests for existing endpoints
  // ============================================
  it('GET /health with trailing slash → should still work', async () => {
    const res = await request(app).get('/health/');

    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('UP');
  });

  it('GET /users with trailing slash → should still work', async () => {
    const res = await request(app).get('/users/');

    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  // ============================================
  // Different HTTP methods on existing routes
  // ============================================
  it('POST /health → should return 404 (method not allowed)', async () => {
    const res = await request(app).post('/health');

    expect(res.statusCode).toBe(404);
  });

  it('PUT /health → should return 404 (method not allowed)', async () => {
    const res = await request(app).put('/health');

    expect(res.statusCode).toBe(404);
  });

  it('DELETE /health → should return 404 (method not allowed)', async () => {
    const res = await request(app).delete('/health');

    expect(res.statusCode).toBe(404);
  });

  it('POST /users → should return 404 (method not allowed)', async () => {
    const res = await request(app).post('/users');

    expect(res.statusCode).toBe(404);
  });

  it('PUT /users → should return 404 (method not allowed)', async () => {
    const res = await request(app).put('/users');

    expect(res.statusCode).toBe(404);
  });

  it('DELETE /users → should return 404 (method not allowed)', async () => {
    const res = await request(app).delete('/users');

    expect(res.statusCode).toBe(404);
  });

  // ============================================
  // 404 error handling tests (non-existent routes)
  // ============================================
  it('GET /invalid → should return 404', async () => {
    const res = await request(app).get('/invalid');

    expect(res.statusCode).toBe(404);
  });

  it('GET /undefined → should return 404', async () => {
    const res = await request(app).get('/undefined');

    expect(res.statusCode).toBe(404);
  });

  it('GET / → should return 404', async () => {
    const res = await request(app).get('/');

    expect(res.statusCode).toBe(404);
  });

  it('GET /api → should return 404', async () => {
    const res = await request(app).get('/api');

    expect(res.statusCode).toBe(404);
  });

  it('GET /users/123 → should return 404', async () => {
    const res = await request(app).get('/users/123');

    expect(res.statusCode).toBe(404);
  });

  it('GET /health/check → should return 404', async () => {
    const res = await request(app).get('/health/check');

    expect(res.statusCode).toBe(404);
  });

  // ============================================
  // Edge cases - PATCH method tests
  // ============================================
  it('PATCH /health → should return 404', async () => {
    const res = await request(app).patch('/health');

    expect(res.statusCode).toBe(404);
  });

  it('PATCH /users → should return 404', async () => {
    const res = await request(app).patch('/users');

    expect(res.statusCode).toBe(404);
  });

  // ============================================
  // Edge cases - empty path and special characters
  // ============================================
  it('GET /%00 → should return 404 (null byte)', async () => {
    const res = await request(app).get('/%00');

    expect(res.statusCode).toBe(404);
  });

  it('GET /.. → should return 404 (path traversal attempt)', async () => {
    const res = await request(app).get('/..');

    expect(res.statusCode).toBe(404);
  });

  // ============================================
  // Response headers and content-type validation
  // ============================================
  it('should include charset in content-type for /health', async () => {
    const res = await request(app).get('/health');

    expect(res.headers['content-type']).toMatch(/charset/);
  });

  it('should include charset in content-type for /users', async () => {
    const res = await request(app).get('/users');

    expect(res.headers['content-type']).toMatch(/charset/);
  });

});
