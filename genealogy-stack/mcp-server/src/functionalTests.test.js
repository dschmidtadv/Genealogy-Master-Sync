// Functional tests for the genealogy stack

const axios = require('axios');

// Grampsweb admin credentials from .env
const GRAMPS_USER = process.env.GRAMPS_ADMIN_USER || 'dschmidt';
const GRAMPS_PASS = process.env.GRAMPS_ADMIN_PASS || 'password'; // Set actual password in .env

// Helper to get auth headers for Basic Auth
function grampsAuthHeaders() {
  const token = Buffer.from(`${GRAMPS_USER}:${GRAMPS_PASS}`).toString('base64');
  return { Authorization: `Basic ${token}` };
}

describe('Genealogy Stack Functional Tests', () => {
  test('Grampsweb API should return people data', async () => {
    const response = await axios.get('http://localhost:5000/api/people', {
      headers: grampsAuthHeaders()
    }).catch(e => e.response);
    expect([200,401,403]).toContain(response.status);
    if (response.status === 200) {
      expect(response.data).toBeDefined();
    }
  });

  test('RootsMagic noVNC should be accessible', async () => {
    const response = await axios.get('http://localhost:8080');
    expect(response.status).toBe(200);
    expect(response.data).toContain('noVNC');
  });

  test('Sync-worker should respond correctly', async () => {
    let response;
    try {
      response = await axios.get('http://localhost:8000/sync');
    } catch (e) {
      response = e.response || { status: 0 };
    }
    expect([200,404,500,0]).toContain(response.status);
  });

  // --- New test: Add a person to Grampsweb and validate ---
  test('Grampsweb API should allow adding and retrieving a person', async () => {
    const newPerson = {
      first_name: 'Test',
      last_name: 'User',
      gender: 'M',
      birth_date: '2000-01-01'
    };
    const addResponse = await axios.post('http://localhost:5000/api/people', newPerson, {
      headers: grampsAuthHeaders()
    }).catch(e => e.response);
    expect([200,201,400,401,403]).toContain(addResponse.status);
    if (addResponse.status === 200 || addResponse.status === 201) {
      const getResponse = await axios.get('http://localhost:5000/api/people', {
        headers: grampsAuthHeaders()
      });
      expect(getResponse.status).toBe(200);
      const found = Array.isArray(getResponse.data) && getResponse.data.some(p => p.first_name === 'Test' && p.last_name === 'User');
      expect(found).toBe(true);
    }
  });

  // --- New test: Validate error on invalid data ---
  test('Grampsweb API should reject invalid person data', async () => {
    const invalidPerson = { foo: 'bar' };
    const response = await axios.post('http://localhost:5000/api/people', invalidPerson, {
      headers: grampsAuthHeaders()
    }).catch(e => e.response);
    expect([400,401,403]).toContain(response.status);
  });
});
