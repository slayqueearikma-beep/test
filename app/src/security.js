import crypto from "node:crypto";

const issuer = "scad";
const audience = "scad-api";
const minimumSecretLength = 32;

function base64UrlEncode(value) {
  const buffer = Buffer.isBuffer(value) ? value : Buffer.from(value);
  return buffer.toString("base64url");
}

function base64UrlDecode(value) {
  return Buffer.from(value, "base64url").toString("utf8");
}

function getAuthSecret() {
  const secret = process.env.SCAD_AUTH_SECRET;

  if (!secret && process.env.NODE_ENV === "production") {
    throw new Error("SCAD_AUTH_SECRET is required in production.");
  }

  return secret || "development-only-secret-change-before-production";
}

function sign(input, secret) {
  return base64UrlEncode(crypto.createHmac("sha256", secret).update(input).digest());
}

function timingSafeEqual(left, right) {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);

  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }

  return crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

export function createAccessToken({
  subject,
  roles = [],
  expiresInSeconds = 900,
  secret = getAuthSecret(),
} = {}) {
  if (!subject) {
    throw new Error("Token subject is required.");
  }

  if (secret.length < minimumSecretLength) {
    throw new Error(`Token secret must be at least ${minimumSecretLength} characters.`);
  }

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "HS256", typ: "JWT" };
  const payload = {
    sub: subject,
    roles,
    iss: issuer,
    aud: audience,
    iat: now,
    exp: now + expiresInSeconds,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  return `${signingInput}.${sign(signingInput, secret)}`;
}

export function verifyAccessToken(token, { secret = getAuthSecret() } = {}) {
  if (!token || typeof token !== "string") {
    throw new Error("Bearer token is required.");
  }

  if (secret.length < minimumSecretLength) {
    throw new Error(`Token secret must be at least ${minimumSecretLength} characters.`);
  }

  const [encodedHeader, encodedPayload, tokenSignature] = token.split(".");
  if (!encodedHeader || !encodedPayload || !tokenSignature) {
    throw new Error("Bearer token is malformed.");
  }

  const header = JSON.parse(base64UrlDecode(encodedHeader));
  const payload = JSON.parse(base64UrlDecode(encodedPayload));
  const expectedSignature = sign(`${encodedHeader}.${encodedPayload}`, secret);

  if (header.alg !== "HS256" || header.typ !== "JWT") {
    throw new Error("Unsupported bearer token algorithm.");
  }

  if (!timingSafeEqual(tokenSignature, expectedSignature)) {
    throw new Error("Bearer token signature is invalid.");
  }

  const now = Math.floor(Date.now() / 1000);
  if (payload.exp <= now) {
    throw new Error("Bearer token is expired.");
  }

  if (payload.iss !== issuer || payload.aud !== audience) {
    throw new Error("Bearer token claims are invalid.");
  }

  return payload;
}

export function authenticateBearer(req, res, next) {
  try {
    const authorization = req.headers.authorization || "";
    const [scheme, token] = authorization.split(" ");

    if (scheme !== "Bearer") {
      return res.status(401).json({
        error: "unauthorized",
        message: "Bearer token is required.",
      });
    }

    req.user = verifyAccessToken(token);
    return next();
  } catch (error) {
    req.log?.warn({ event: "authentication_failed", reason: error.message }, "authentication failed");
    return res.status(401).json({
      error: "unauthorized",
      message: "Invalid or expired bearer token.",
    });
  }
}

export function requireRole(requiredRole) {
  return (req, res, next) => {
    const roles = Array.isArray(req.user?.roles) ? req.user.roles : [];

    if (!roles.includes(requiredRole)) {
      req.log?.warn(
        {
          event: "authorization_failed",
          subject: req.user?.sub,
          requiredRole,
          roles,
        },
        "authorization failed",
      );

      return res.status(403).json({
        error: "forbidden",
        message: `Role '${requiredRole}' is required.`,
      });
    }

    return next();
  };
}

export function requireJsonContentType(req, res, next) {
  const methodsWithBody = new Set(["POST", "PUT", "PATCH"]);

  if (methodsWithBody.has(req.method) && !req.is("application/json")) {
    return res.status(415).json({
      error: "unsupported_media_type",
      message: "Content-Type must be application/json.",
    });
  }

  return next();
}

export function createRateLimiter({ windowMs = 60_000, maxRequests = 120 } = {}) {
  const buckets = new Map();

  return (req, res, next) => {
    const key = req.ip || req.socket.remoteAddress || "unknown";
    const now = Date.now();
    const bucket = buckets.get(key) || { count: 0, resetAt: now + windowMs };

    if (now > bucket.resetAt) {
      bucket.count = 0;
      bucket.resetAt = now + windowMs;
    }

    bucket.count += 1;
    buckets.set(key, bucket);

    res.set("RateLimit-Limit", String(maxRequests));
    res.set("RateLimit-Remaining", String(Math.max(maxRequests - bucket.count, 0)));
    res.set("RateLimit-Reset", String(Math.ceil(bucket.resetAt / 1000)));

    if (bucket.count > maxRequests) {
      req.log?.warn({ event: "rate_limit_exceeded", key }, "rate limit exceeded");
      return res.status(429).json({
        error: "too_many_requests",
        message: "Too many requests. Retry later.",
      });
    }

    return next();
  };
}

export function addSecurityHeaders(_req, res, next) {
  res.set("X-SCAD-Security-Profile", "zero-trust-starter");
  res.set("Cache-Control", "no-store");
  next();
}
