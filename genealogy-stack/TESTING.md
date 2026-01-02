# Testing Guide

This document provides comprehensive information about testing the Genealogy Master-Sync Stack.

## Overview

The project includes a robust test suite that validates:
- Individual service functionality
- API authentication and authorization
- Data creation and validation
- Inter-service communication
- End-to-end integration workflows

## Test Structure

### Location
All tests are located in [`genealogy-stack/mcp-server/src/functionalTests.test.js`](genealogy-stack/mcp-server/src/functionalTests.test.js)

### Test Categories

#### 1. Service Accessibility Tests
- **Grampsweb API**: Validates API endpoint availability and authentication
- **RootsMagic noVNC**: Confirms web-based VNC interface accessibility
- **Sync-worker**: Tests sync service endpoint responsiveness

#### 2. Data Management Tests
- **Person Creation**: Tests adding new persons to Grampsweb
- **Data Validation**: Ensures proper data structure validation
- **Error Handling**: Validates rejection of invalid data

#### 3. Integration Tests
- **Cross-service Data Flow**: Tests data creation in Grampsweb and sync to RootsMagic
- **Authentication Flow**: Validates authentication across service boundaries
- **Sync Workflow**: Tests the complete sync process

## Running Tests

### Prerequisites
1. Ensure all services are running via Docker Compose:
   ```bash
   cd genealogy-stack
   docker-compose up -d
   ```

2. Configure authentication in your `.env` file:
   ```bash
   GRAMPS_ADMIN_USER=dschmidt
   GRAMPS_ADMIN_PASS=your_secure_password
   ```

### Execute Tests
```bash
cd genealogy-stack/mcp-server
npm test
```

### Expected Output
```
PASS src/functionalTests.test.js
  Genealogy Stack Functional Tests
    ✓ Grampsweb API should return people data
    ✓ RootsMagic noVNC should be accessible
    ✓ Sync-worker should respond correctly
    ✓ Grampsweb API should allow adding and retrieving a person
    ✓ Grampsweb API should reject invalid person data
    ✓ Create person in Grampsweb, trigger sync, validate in RootsMagic

Test Suites: 1 passed, 1 total
Tests: 6 passed, 6 total
```

## Test Details

### Authentication Testing
Tests use HTTP Basic Authentication with credentials from environment variables:
```javascript
function grampsAuthHeaders() {
  const token = Buffer.from(`${GRAMPS_USER}:${GRAMPS_PASS}`).toString('base64');
  return { Authorization: `Basic ${token}` };
}
```

### Error Handling
Tests are designed to handle various response scenarios:
- **Success responses**: 200, 201
- **Authentication errors**: 401, 403
- **Client errors**: 400
- **Server errors**: 500
- **Connection errors**: Network timeouts, unreachable services

### Integration Test Flow
The integration test follows this workflow:
1. **Create Person**: Add a test person to Grampsweb
2. **Trigger Sync**: Call the sync-worker endpoint
3. **Validate Grampsweb**: Confirm person exists in Grampsweb
4. **Validate RootsMagic**: Check if person synced to RootsMagic (if endpoint available)

## Troubleshooting

### Common Issues

#### Authentication Failures (401)
- Verify `.env` file contains correct credentials
- Ensure Grampsweb service is fully initialized
- Check that the admin user exists in the Grampsweb database

#### Service Unavailable Errors
- Confirm all Docker containers are running: `docker ps`
- Check service logs: `docker logs <container_name>`
- Verify port mappings in `docker-compose.yml`

#### Test Timeouts
- Increase Jest timeout if services are slow to respond
- Check network connectivity between containers
- Verify service health endpoints

### Debug Mode
To run tests with verbose output:
```bash
npm test -- --verbose
```

To run a specific test:
```bash
npm test -- --testNamePattern="Grampsweb API"
```

## Continuous Integration

### Branch Testing
Tests are automatically run on:
- `feature/integration-tests` branch
- Pull requests to `main`
- Security hardening branches

### Test Coverage
Current test coverage includes:
- ✅ Service availability
- ✅ Authentication flows
- ✅ Data creation/validation
- ✅ Error handling
- ✅ Basic integration workflows

### Future Enhancements
Planned test additions:
- [ ] Performance benchmarking
- [ ] Load testing for concurrent operations
- [ ] Database integrity validation
- [ ] File system sync verification
- [ ] MCP server protocol testing

## Contributing

When adding new tests:
1. Follow the existing test structure
2. Include both positive and negative test cases
3. Handle authentication appropriately
4. Add proper error handling
5. Update this documentation

### Test Naming Convention
- Use descriptive test names that explain the expected behavior
- Group related tests in describe blocks
- Include service names in test descriptions

### Example Test Structure
```javascript
test('Service should perform expected action', async () => {
  // Arrange
  const testData = { /* test data */ };
  
  // Act
  const response = await axios.post('endpoint', testData, {
    headers: authHeaders()
  }).catch(e => e.response);
  
  // Assert
  expect([200, 201]).toContain(response.status);
  if (response.status === 200) {
    expect(response.data).toBeDefined();
  }
});
```

## Security Considerations

- Tests use environment variables for credentials
- No hardcoded passwords in test files
- Authentication tokens are generated dynamically
- Test data uses non-sensitive placeholder information
- Cleanup procedures should be implemented for persistent test data