import assert from "node:assert/strict";
import { test } from "node:test";
import {
  createAccessToken,
  createRateLimiter,
  requireRole,
  verifyAccessToken,
} from "../src/security.js";

test("creates and verifies bearer tokens", () => {
  const token = createAccessToken({
    subject: "ci-bot",
    roles: ["security-reader"],
    secret: "development-only-secret-change-before-production",
  });

  const payload = verifyAccessToken(token, {
    secret: "development-only-secret-change-before-production",
  });

  assert.equal(payload.sub, "ci-bot");
  assert.deepEqual(payload.roles, ["security-reader"]);
});

test("enforces role-based access", () => {
  const middleware = requireRole("security-reader");
  const calls = [];

  middleware(
    { user: { sub: "user-1", roles: ["viewer"] } },
    { status: () => ({ json: (body) => calls.push(body) }) },
    () => calls.push("next"),
  );

  assert.equal(calls.length, 1);
  assert.equal(calls[0].error, "forbidden");
});

test("applies rate limiting after threshold", () => {
  const limiter = createRateLimiter({ windowMs: 60_000, maxRequests: 2 });
  const responses = [];

  const req = { ip: "127.0.0.1", log: { warn: () => {} } };
  const res = {
    headers: {},
    set(name, value) {
      this.headers[name] = value;
    },
    status(code) {
      this.statusCode = code;
      return {
        json: (body) => responses.push({ code, body }),
      };
    },
  };

  limiter(req, res, () => responses.push({ code: 200 }));
  limiter(req, res, () => responses.push({ code: 200 }));
  limiter(req, res, () => responses.push({ code: 200 }));

  assert.equal(responses.length, 3);
  assert.equal(responses[2].code, 429);
});
