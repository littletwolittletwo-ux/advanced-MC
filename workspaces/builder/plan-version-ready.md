# Plan for tasks: stress-version-1776866444 & stress-ready-1776866444

## Acceptance criteria
### /version (stress-version-1776866444)
- [ ] src/routes/version.js exists and exports versionHandler
- [ ] GET /version returns HTTP 200 with Content-Type application/json
- [ ] Response body is {"version":"0.1.0"} reading from package.json
- [ ] test/version.test.js exists and passes
- [ ] Test asserts status 200 and correct body shape
- [ ] app.js imports and chains versionHandler

### /ready (stress-ready-1776866444)
- [ ] src/routes/ready.js exists and exports readyHandler
- [ ] GET /ready returns HTTP 200 with Content-Type application/json
- [ ] Response body has ready:true and uptime as positive number
- [ ] test/ready.test.js exists and passes
- [ ] Test asserts status 200 and correct body shape
- [ ] app.js imports and chains readyHandler

### Global
- [ ] npm test passes all tests (existing + new) with zero failures
