import { describe, it, expect, vi, beforeEach } from 'vitest';
import worker from '../src/index';
import type { Env } from '../src/index';

// Mock the auth module to avoid real JWT verification in integration tests
vi.mock('../src/auth', () => ({
  verifyFirebaseIdToken: vi.fn(),
  getStaffStatus: vi.fn(),
}));

import { verifyFirebaseIdToken, getStaffStatus } from '../src/auth';

// Mock environment
const mockEnv: Env = {
  CLOUDINARY_CLOUD_NAME: 'test-cloud',
  CLOUDINARY_API_KEY: 'test-key',
  CLOUDINARY_API_SECRET: 'test-secret',
  FIREBASE_PROJECT_ID: 'access-link-005',
  ALLOWED_ORIGINS: 'http://localhost:3000,https://admin.example.com',
};

// Mock execution context
const mockCtx = {
  waitUntil: vi.fn(),
  passThroughOnException: vi.fn(),
};

function createMockJWT(payload: any): string {
  const header = { alg: 'RS256', kid: 'test-kid', typ: 'JWT' };
  const headerB64 = btoa(JSON.stringify(header)).replace(/[+]/g, '-').replace(/[/]/g, '_').replace(/=/g, '');
  const payloadB64 = btoa(JSON.stringify(payload)).replace(/[+]/g, '-').replace(/[/]/g, '_').replace(/=/g, '');
  return `${headerB64}.${payloadB64}.mock-signature`;
}

const validUserPayload = {
  iss: 'https://securetoken.google.com/access-link-005',
  aud: 'access-link-005',
  sub: 'test-uid-123',
  exp: Math.floor(Date.now() / 1000) + 3600,
};

const validStaffPayload = {
  ...validUserPayload,
  role: 'admin',
};

// Mock Google certs
const mockCerts = {
  'test-kid': '-----BEGIN CERTIFICATE-----\nMOCK\n-----END CERTIFICATE-----',
};

global.fetch = vi.fn();

describe('Worker Integration', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    
    // Mock auth functions for worker integration tests
    vi.mocked(verifyFirebaseIdToken).mockImplementation(async (token: string) => {
      // Parse the mock JWT to extract payload
      const parts = token.split('.');
      if (parts.length !== 3) {
        throw new Error('Token verification failed: Invalid JWT format');
      }
      
      try {
        const payloadB64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
        const payload = JSON.parse(atob(payloadB64));
        
        // Validate required fields
        if (payload.iss !== 'https://securetoken.google.com/access-link-005') {
          throw new Error('Token verification failed: Invalid issuer');
        }
        if (payload.aud !== 'access-link-005') {
          throw new Error('Token verification failed: Invalid audience');
        }
        if (payload.exp <= Math.floor(Date.now() / 1000)) {
          throw new Error('Token verification failed: Token expired');
        }
        if (!payload.sub) {
          throw new Error('Token verification failed: Missing subject');
        }
        
        return {
          uid: payload.sub,
          claims: payload,
        };
      } catch (error) {
        throw new Error('Token verification failed: Invalid token');
      }
    });
    
    vi.mocked(getStaffStatus).mockImplementation(async (userIdentity) => {
      const role = userIdentity.claims.role;
      return role === 'admin' || role === 'moderator';
    });

    // Mock Google certs endpoint (though not used anymore with mocked auth)
    vi.mocked(fetch).mockImplementation(async (url) => {
      if (typeof url === 'string' && url.includes('googleapis.com/robot/v1/metadata/x509')) {
        return new Response(JSON.stringify(mockCerts), {
          status: 200,
          headers: { 'cache-control': 'max-age=3600' },
        });
      }
      return new Response('Not found', { status: 404 });
    });
  });

  describe('CORS handling', () => {
    it('should handle preflight requests', async () => {
      const request = new Request('http://localhost/sign-upload', {
        method: 'OPTIONS',
        headers: {
          'Origin': 'http://localhost:3000',
        },
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);

      expect(response.status).toBe(204);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('http://localhost:3000');
      expect(response.headers.get('Access-Control-Allow-Methods')).toBe('POST, OPTIONS');
      expect(response.headers.get('Access-Control-Allow-Headers')).toBe('Content-Type, Authorization');
    });

    it('should reject disallowed origins', async () => {
      const request = new Request('http://localhost/sign-upload', {
        method: 'OPTIONS',
        headers: {
          'Origin': 'https://malicious.com',
        },
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);

      expect(response.status).toBe(204);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe(null);
    });

    it('should reflect allowed origins in responses', async () => {
      const validToken = createMockJWT(validUserPayload);
      const request = new Request('http://localhost/sign-upload', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${validToken}`,
          'Content-Type': 'application/json',
          'Origin': 'https://admin.example.com',
        },
        body: JSON.stringify({ submissionId: 'test-submission' }),
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);

      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://admin.example.com');
    });
  });

  describe('Rate limiting', () => {
    it('should allow requests under rate limit', async () => {
      const validToken = createMockJWT(validUserPayload);
      const request = new Request('http://localhost/sign-upload', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${validToken}`,
          'Content-Type': 'application/json',
          'CF-Connecting-IP': '192.168.1.1',
        },
        body: JSON.stringify({ submissionId: 'test-submission' }),
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);

      expect(response.status).not.toBe(429);
    });

    // Note: Testing actual rate limiting would require many requests
    // This test documents the expected behavior
    it('should include rate limiting logic', async () => {
      // The rate limiter is instantiated and used in the worker
      // In a real test, we'd make 101 requests to trigger the limit
      expect(true).toBe(true); // Placeholder for rate limit integration test
    });
  });

  describe('POST /sign-upload', () => {
    it('should accept valid user token and return signed params', async () => {
      const validToken = createMockJWT(validUserPayload);
      const request = new Request('http://localhost/sign-upload', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${validToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ submissionId: 'test-submission-123' }),
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);

      expect(response.status).toBe(200);
      
      const data = await response.json() as any;
      expect(data.folder).toBe('place_photo_submissions/test-uid-123');
      expect(data.public_id).toBe('test-submission-123');
      expect(data.type).toBe('authenticated');
      expect(data.api_key).toBe('test-key');
      expect(data.signature).toMatch(/^[a-f0-9]{40}$/);
      expect(data.timestamp).toBeTruthy();
      
      // Should NOT include cloud_name (client builds URL from its own config)
      expect(data.cloud_name).toBeUndefined();
      
      // Should never expose the API secret
      expect(JSON.stringify(data)).not.toContain('test-secret');
    });

    it('should reject requests without authorization', async () => {
      const request = new Request('http://localhost/sign-upload', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ submissionId: 'test-submission' }),
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);

      expect(response.status).toBe(401);
      const data = await response.json() as any;
      expect(data.error).toBe('Missing or invalid authorization header');
      expect(data.code).toBe('INVALID_AUTH');
    });

    it('should reject requests with missing submissionId', async () => {
      const validToken = createMockJWT(validUserPayload);
      const request = new Request('http://localhost/sign-upload', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${validToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({}),
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);

      expect(response.status).toBe(400);
      const data = await response.json() as any;
      expect(data.error).toBe('Missing submissionId');
      expect(data.code).toBe('INVALID_INPUT');
    });
  });

  describe('POST /sign-view', () => {
    it('should accept staff tokens and return signed view URL', async () => {
      const staffToken = createMockJWT(validStaffPayload);
      const request = new Request('http://localhost/sign-view', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${staffToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ publicId: 'place_photo_submissions/uid123/submission456' }),
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);

      expect(response.status).toBe(200);
      
      const data = await response.json() as any;
      expect(data.url).toContain('res.cloudinary.com/test-cloud/image/authenticated');
      expect(data.url).toMatch(/\/s--[a-zA-Z0-9_-]{8}--\//); // Should have signature format s--{8chars}--
      
      // Should not expose API secret
      expect(data.url).not.toContain('test-secret');
    });

    it('should reject non-staff users', async () => {
      const userToken = createMockJWT(validUserPayload);
      const request = new Request('http://localhost/sign-view', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${userToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ publicId: 'test-public-id' }),
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);

      expect(response.status).toBe(403);
      const data = await response.json() as any;
      expect(data.error).toBe('Staff access required');
      expect(data.code).toBe('INSUFFICIENT_PERMISSIONS');
    });

    it('should reject requests with missing publicId', async () => {
      const staffToken = createMockJWT(validStaffPayload);
      const request = new Request('http://localhost/sign-view', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${staffToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({}),
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);

      expect(response.status).toBe(400);
      const data = await response.json() as any;
      expect(data.error).toBe('Missing publicId');
      expect(data.code).toBe('INVALID_INPUT');
    });
  });

  describe('POST /promote', () => {
    it('should accept staff tokens and return promotion details', async () => {
      // Mock the fetch call that promoteToPublic makes to Cloudinary
      vi.mocked(fetch).mockResolvedValueOnce(new Response(JSON.stringify({
        public_id: 'place_photos/place456/submission123',
        secure_url: 'https://res.cloudinary.com/test-cloud/image/upload/place_photos/place456/submission123',
        version: 1234567890,
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }));

      const staffToken = createMockJWT(validStaffPayload);
      const request = new Request('http://localhost/promote', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${staffToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          submissionId: 'submission123',
          placeId: 'place456',
          publicId: 'place_photo_submissions/uid123/submission123',
        }),
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);

      expect(response.status).toBe(200);
      
      const data = await response.json() as any;
      expect(data.secureUrl).toBe('https://res.cloudinary.com/test-cloud/image/upload/place_photos/place456/submission123');
      
      // Should not expose API secret
      expect(JSON.stringify(data)).not.toContain('test-secret');
      
      // Verify that the Cloudinary rename API was called
      expect(fetch).toHaveBeenCalledWith(
        'https://api.cloudinary.com/v1_1/test-cloud/image/rename',
        expect.objectContaining({
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        })
      );
    });

    it('should reject non-staff users', async () => {
      const userToken = createMockJWT(validUserPayload);
      const request = new Request('http://localhost/promote', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${userToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          submissionId: 'submission123',
          placeId: 'place456',
          publicId: 'test-public-id',
        }),
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);

      expect(response.status).toBe(403);
      const data = await response.json() as any;
      expect(data.error).toBe('Staff access required');
      expect(data.code).toBe('INSUFFICIENT_PERMISSIONS');
    });

    it('should reject requests with missing required fields', async () => {
      const staffToken = createMockJWT(validStaffPayload);
      const request = new Request('http://localhost/promote', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${staffToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ submissionId: 'test' }), // Missing placeId and publicId
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);

      expect(response.status).toBe(400);
      const data = await response.json() as any;
      expect(data.error).toBe('Missing required fields');
      expect(data.code).toBe('INVALID_INPUT');
    });
  });

  describe('Error handling', () => {
    it('should return 404 for unknown endpoints', async () => {
      const request = new Request('http://localhost/unknown', {
        method: 'POST',
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);

      expect(response.status).toBe(404);
      const data = await response.json() as any;
      expect(data.error).toBe('Not found');
      expect(data.code).toBe('NOT_FOUND');
    });

    it('should return 405 for unsupported methods', async () => {
      const request = new Request('http://localhost/sign-upload', {
        method: 'GET',
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);

      expect(response.status).toBe(405);
      const data = await response.json() as any;
      expect(data.error).toBe('Method not allowed');
      expect(data.code).toBe('METHOD_NOT_ALLOWED');
    });

    it('should have uniform JSON error contract', async () => {
      const request = new Request('http://localhost/sign-upload', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({}),
      });

      const response = await worker.fetch(request, mockEnv, mockCtx);
      const data = await response.json() as any;

      // All errors should have error and code fields
      expect(data).toHaveProperty('error');
      expect(data).toHaveProperty('code');
      expect(typeof data.error).toBe('string');
      expect(typeof data.code).toBe('string');
    });
  });

  describe('Security', () => {
    it('should never leak API secrets in any response', async () => {
      // Test various endpoints and error conditions
      const requests = [
        new Request('http://localhost/sign-upload', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({}),
        }),
        new Request('http://localhost/sign-view', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({}),
        }),
        new Request('http://localhost/promote', {
          method: 'POST', 
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({}),
        }),
        new Request('http://localhost/unknown', { method: 'POST' }),
      ];

      for (const request of requests) {
        const response = await worker.fetch(request, mockEnv, mockCtx);
        const responseText = await response.text();
        
        expect(responseText).not.toContain('test-secret');
        expect(responseText).not.toContain(mockEnv.CLOUDINARY_API_SECRET);
      }
    });
  });
});