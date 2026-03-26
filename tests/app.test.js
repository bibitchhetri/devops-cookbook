const request = require('supertest');
const app = require('../app');

describe('DevOps App API Tests', () => {

  // Health endpoint test
  it('GET /health → should return status UP', async () => {
    const res = await request(app).get('/health');

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('status', 'UP');
    expect(res.body).toHaveProperty('message');
  });

  // Users endpoint test
  it('GET /users → should return list of users', async () => {
    const res = await request(app).get('/users');

    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);

    expect(res.body[0]).toHaveProperty('id');
    expect(res.body[0]).toHaveProperty('name');
  });

  // Edge case test
  it('GET /invalid → should return 404', async () => {
    const res = await request(app).get('/invalid');

    expect(res.statusCode).toBe(404);
  });

});
