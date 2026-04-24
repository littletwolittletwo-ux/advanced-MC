# Plan for task: status-endpoint

## Brief
Add GET /status endpoint returning {"uptime_seconds":<process.uptime()>,"version":"<from package.json>","timestamp":"<ISO-8601>"} with test and PR.

## Tags
["endpoint", "api", "status", "testing"]

## Repo State
- Established handler pattern: export named function, return true if handled, false otherwise
- app.js chains handlers before 404 fallback
- Tests use node:test + node:assert, ephemeral port

## Pieces
1. **status-handler** — Create src/routes/status.js
   - Export statusHandler(req, res)
   - If GET /status: respond 200 JSON {"uptime_seconds": process.uptime(), "version": require('../../package.json').version, "timestamp": new Date().toISOString()}
   - Return true if handled, false otherwise

2. **status-wiring** — Add to src/app.js: import and chain before 404

3. **status-test** — Create test/status.test.js
   - Assert GET /status returns 200
   - Assert Content-Type application/json
   - Assert body.uptime_seconds is a positive number
   - Assert body.version is a string matching package.json
   - Assert body.timestamp is a valid ISO-8601 string
   - Ephemeral port, cleanup

## Acceptance criteria
- [ ] src/routes/status.js exists and exports statusHandler
- [ ] GET /status returns HTTP 200 with Content-Type application/json
- [ ] Response body has uptime_seconds (positive number), version (string from package.json), timestamp (ISO-8601)
- [ ] test/status.test.js exists and passes
- [ ] Test asserts status 200, body shape, and types
- [ ] app.js imports and chains statusHandler
- [ ] npm test passes all tests with zero failures
- [ ] PR opened

## Risks
- Overlap with existing /uptime and /version endpoints — this combines both plus timestamp. No conflict, just redundancy. Not our call to refactor.

## Execution plan
Single AO worker, branch feature/status-endpoint.
