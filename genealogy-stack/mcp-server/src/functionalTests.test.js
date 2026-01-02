// Functional tests for the genealogy stack

const axios = require('axios');

describe('Genealogy Stack Functional Tests', () => {
  test('Grampsweb API should return people data', async () => {
    const response = await axios.get('http://localhost:5000/api/people');
    expect(response.status).toBe(200);
    expect(response.data).toBeDefined();
  });

  test('RootsMagic noVNC should be accessible', async () => {
    const response = await axios.get('http://localhost:8080');
    expect(response.status).toBe(200);
    expect(response.data).toContain('noVNC');
  });

  test('Sync-worker should respond correctly', async () => {
    const response = await axios.get('http://localhost:8000/sync'); // Adjust the endpoint as needed
    expect(response.status).toBe(200);
    expect(response.data).toContain('Sync completed'); // Adjust based on expected response
  });
});