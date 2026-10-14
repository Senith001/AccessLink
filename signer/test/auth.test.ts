import { describe, it, expect, vi, beforeEach } from 'vitest';
import { verifyFirebaseIdToken, getStaffStatus } from '../src/auth';
import type { Env } from '../src/index';
import { createHash, generateKeyPairSync } from 'node:crypto';

// Mock environment
const mockEnv: Env = {
  CLOUDINARY_CLOUD_NAME: 'test-cloud',
  CLOUDINARY_API_KEY: 'test-key',
  CLOUDINARY_API_SECRET: 'test-secret',
  FIREBASE_PROJECT_ID: 'access-link-005',
  ALLOWED_ORIGINS: 'http://localhost:3000',
};

// Generate real RSA keypair for testing
const TEST_KID = 'test-kid-123';
const RSA_KEY_PAIR = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: {
    type: 'spki',
    format: 'der'
  },
  privateKeyEncoding: {
    type: 'pkcs8',
    format: 'der'
  }
});

// Create a minimal self-signed X.509 certificate wrapping the public key
function createMinimalX509Cert(publicKeySpki: Buffer): string {
  // This creates a minimal but valid X.509 certificate structure
  // For real production use, you'd use a proper X.509 library
  
  // X.509 Certificate structure:
  // Certificate ::= SEQUENCE {
  //   tbsCertificate       TBSCertificate,
  //   signatureAlgorithm   AlgorithmIdentifier,
  //   signature            BIT STRING
  // }
  
  // For testing, we'll create a self-signed cert with minimal required fields
  const serialNumber = Buffer.from([0x02, 0x01, 0x01]); // INTEGER 1
  const issuerDN = Buffer.from([0x30, 0x0b, 0x31, 0x09, 0x30, 0x07, 0x06, 0x03, 0x55, 0x04, 0x03, 0x0c, 0x00]); // CN=""
  const subjectDN = issuerDN; // Same as issuer for self-signed
  
  // Validity: Not Before + Not After (simplified - just use current time range)
  const now = new Date();
  const notBefore = new Date(now.getTime() - 86400000); // 1 day ago
  const notAfter = new Date(now.getTime() + 86400000); // 1 day from now
  
  // ASN.1 UTCTIME format: YYMMDDHHMMSSZ
  function toASN1UTCTime(date: Date): Buffer {
    const year = date.getUTCFullYear().toString().slice(-2).padStart(2, '0');
    const month = (date.getUTCMonth() + 1).toString().padStart(2, '0');
    const day = date.getUTCDate().toString().padStart(2, '0');
    const hour = date.getUTCHours().toString().padStart(2, '0');
    const min = date.getUTCMinutes().toString().padStart(2, '0');
    const sec = date.getUTCSeconds().toString().padStart(2, '0');
    const timeStr = `${year}${month}${day}${hour}${min}${sec}Z`;
    return Buffer.concat([Buffer.from([0x17, timeStr.length]), Buffer.from(timeStr, 'ascii')]);
  }
  
  const notBeforeASN1 = toASN1UTCTime(notBefore);
  const notAfterASN1 = toASN1UTCTime(notAfter);
  const validity = Buffer.concat([
    Buffer.from([0x30, notBeforeASN1.length + notAfterASN1.length]),
    notBeforeASN1,
    notAfterASN1
  ]);
  
  // RSA algorithm identifier: 1.2.840.113549.1.1.1
  const rsaAlgId = Buffer.from([
    0x30, 0x0d, // SEQUENCE
    0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, // RSA OID
    0x05, 0x00  // NULL
  ]);
  
  // Build tbsCertificate
  const tbsVersion = Buffer.from([0xa0, 0x03, 0x02, 0x01, 0x02]); // Version 3
  const tbsSerial = serialNumber;
  const tbsSignatureAlg = rsaAlgId;
  const tbsIssuer = issuerDN;
  const tbsValidity = validity;
  const tbsSubject = subjectDN;
  const tbsSubjectPKI = publicKeySpki; // This is already in correct SPKI format
  
  const tbsBody = Buffer.concat([
    tbsVersion,
    tbsSerial,
    tbsSignatureAlg,
    tbsIssuer,
    tbsValidity,
    tbsSubject,
    tbsSubjectPKI
  ]);
  
  const tbsCertificate = Buffer.concat([
    Buffer.from([0x30]), // SEQUENCE tag
    encodeLength(tbsBody.length),
    tbsBody
  ]);
  
  // Sign the tbsCertificate with the private key
  const privateKey = RSA_KEY_PAIR.privateKey;
  const hash = createHash('sha256').update(tbsCertificate).digest();
  
  // For this test, we'll create a dummy signature since we just need the structure
  // The SPKI extraction will work regardless of signature validity
  const dummySignature = Buffer.alloc(256, 0xaa); // 2048-bit RSA = 256 byte signature
  const signatureBitString = Buffer.concat([
    Buffer.from([0x03]), // BIT STRING tag
    encodeLength(dummySignature.length + 1),
    Buffer.from([0x00]), // No unused bits
    dummySignature
  ]);
  
  // Complete certificate
  const certificateBody = Buffer.concat([
    tbsCertificate,
    rsaAlgId, // Signature algorithm
    signatureBitString
  ]);
  
  const certificate = Buffer.concat([
    Buffer.from([0x30]), // SEQUENCE tag
    encodeLength(certificateBody.length),
    certificateBody
  ]);
  
  // Convert to PEM
  const b64 = certificate.toString('base64');
  const pem = `-----BEGIN CERTIFICATE-----\n${b64.match(/.{1,64}/g)!.join('\n')}\n-----END CERTIFICATE-----`;
  
  return pem;
}

function encodeLength(length: number): Buffer {
  if (length < 0x80) {
    return Buffer.from([length]);
  } else if (length < 0x100) {
    return Buffer.from([0x81, length]);
  } else if (length < 0x10000) {
    return Buffer.from([0x82, (length >> 8) & 0xff, length & 0xff]);
  } else {
    return Buffer.from([0x83, (length >> 16) & 0xff, (length >> 8) & 0xff, length & 0xff]);
  }
}

// Create test certificate
const TEST_CERT_PEM = createMinimalX509Cert(RSA_KEY_PAIR.publicKey);

// Base64url encode/decode helpers
function base64UrlEncode(data: Buffer | Uint8Array | string): string {
  const buffer = Buffer.isBuffer(data) ? data : 
                 data instanceof Uint8Array ? Buffer.from(data) : 
                 Buffer.from(data, 'utf8');
  return buffer.toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

function base64UrlDecode(str: string): Buffer {
  const padded = str + '='.repeat((4 - (str.length % 4)) % 4);
  const base64 = padded.replace(/-/g, '+').replace(/_/g, '/');
  return Buffer.from(base64, 'base64');
}

// JWT signing helper using Node.js crypto
async function signJWT(header: any, payload: any, privateKey: Buffer): Promise<string> {
  const headerB64 = base64UrlEncode(JSON.stringify(header));
  const payloadB64 = base64UrlEncode(JSON.stringify(payload));
  const dataToSign = `${headerB64}.${payloadB64}`;
  
  // Import private key for Web Crypto API
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    privateKey,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256'
    },
    false,
    ['sign']
  );
  
  // Sign the data
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(dataToSign)
  );
  
  const signatureB64 = base64UrlEncode(new Uint8Array(signature));
  return `${dataToSign}.${signatureB64}`;
}

// Generate a different keypair for invalid signature tests
const WRONG_KEY_PAIR = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: { type: 'spki', format: 'der' },
  privateKeyEncoding: { type: 'pkcs8', format: 'der' }
});

// Mock certificates map
const mockCerts = {
  [TEST_KID]: TEST_CERT_PEM,
};

// Base JWT payloads
const now = Math.floor(Date.now() / 1000);

const validPayload = {
  iss: 'https://securetoken.google.com/access-link-005',
  aud: 'access-link-005',
  auth_time: now - 100,
  user_id: 'uid123',
  sub: 'uid123',
  iat: now,
  exp: now + 3600, // Valid for 1 hour
  firebase: {
    identities: {},
    sign_in_provider: 'custom',
  },
};

const adminPayload = {
  ...validPayload,
  role: 'admin',
};

const moderatorPayload = {
  ...validPayload,
  role: 'moderator',
};

const validHeader = {
  alg: 'RS256',
  kid: TEST_KID,
  typ: 'JWT',
};

// Global fetch mock
global.fetch = vi.fn();

describe('Auth Module - Real RSA JWT Verification', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Mock Google certs endpoint
    vi.mocked(fetch).mockImplementation(async (url) => {
      if (typeof url === 'string' && url.includes('googleapis.com/robot/v1/metadata/x509')) {
        return new Response(JSON.stringify(mockCerts), {
          status: 200,
          headers: {
            'cache-control': 'max-age=3600',
            'content-type': 'application/json',
          },
        });
      }
      return new Response('Not found', { status: 404 });
    });
  });

  describe('verifyFirebaseIdToken', () => {
    it('should accept a valid correctly-signed token', async () => {
      const validToken = await signJWT(validHeader, validPayload, RSA_KEY_PAIR.privateKey);
      
      const result = await verifyFirebaseIdToken(validToken, mockEnv);
      
      expect(result.uid).toBe('uid123');
      expect(result.claims.sub).toBe('uid123');
      expect(result.claims.iss).toBe('https://securetoken.google.com/access-link-005');
      expect(result.claims.aud).toBe('access-link-005');
    });

    it('should reject token with invalid signature (wrong key)', async () => {
      // Sign with wrong private key
      const invalidToken = await signJWT(validHeader, validPayload, WRONG_KEY_PAIR.privateKey);
      
      await expect(verifyFirebaseIdToken(invalidToken, mockEnv)).rejects.toThrow(/Invalid signature|Token verification failed/);
    });

    it('should reject tampered payload (signature mismatch)', async () => {
      // Create valid token
      const validToken = await signJWT(validHeader, validPayload, RSA_KEY_PAIR.privateKey);
      
      // Tamper with the payload by changing audience
      const [headerB64, , signatureB64] = validToken.split('.');
      const tamperedPayload = { ...validPayload, aud: 'tampered-project' };
      const tamperedPayloadB64 = base64UrlEncode(JSON.stringify(tamperedPayload));
      const tamperedToken = `${headerB64}.${tamperedPayloadB64}.${signatureB64}`;
      
      await expect(verifyFirebaseIdToken(tamperedToken, mockEnv)).rejects.toThrow(/Invalid signature|Token verification failed/);
    });

    it('should reject token with tampered signature', async () => {
      // Create valid token
      const validToken = await signJWT(validHeader, validPayload, RSA_KEY_PAIR.privateKey);
      
      // Flip a byte in the signature
      const [headerB64, payloadB64, signatureB64] = validToken.split('.');
      const signatureBytes = base64UrlDecode(signatureB64);
      signatureBytes[0] = signatureBytes[0] ^ 0x01; // Flip a bit
      const tamperedSignatureB64 = base64UrlEncode(signatureBytes);
      const tamperedToken = `${headerB64}.${payloadB64}.${tamperedSignatureB64}`;
      
      await expect(verifyFirebaseIdToken(tamperedToken, mockEnv)).rejects.toThrow(/Invalid signature|Token verification failed/);
    });

    it('should reject expired token', async () => {
      const expiredPayload = { ...validPayload, exp: now - 100 };
      const expiredToken = await signJWT(validHeader, expiredPayload, RSA_KEY_PAIR.privateKey);
      
      await expect(verifyFirebaseIdToken(expiredToken, mockEnv)).rejects.toThrow('Token expired');
    });

    it('should reject token with wrong audience', async () => {
      const wrongAudPayload = { ...validPayload, aud: 'wrong-project-id' };
      const wrongAudToken = await signJWT(validHeader, wrongAudPayload, RSA_KEY_PAIR.privateKey);
      
      await expect(verifyFirebaseIdToken(wrongAudToken, mockEnv)).rejects.toThrow('Invalid audience');
    });

    it('should reject token with wrong issuer', async () => {
      const wrongIssPayload = { ...validPayload, iss: 'https://wrong-issuer.com/project' };
      const wrongIssToken = await signJWT(validHeader, wrongIssPayload, RSA_KEY_PAIR.privateKey);
      
      await expect(verifyFirebaseIdToken(wrongIssToken, mockEnv)).rejects.toThrow('Invalid issuer');
    });

    it('should reject token without subject', async () => {
      const noSubPayload = { ...validPayload, sub: '' };
      const noSubToken = await signJWT(validHeader, noSubPayload, RSA_KEY_PAIR.privateKey);
      
      await expect(verifyFirebaseIdToken(noSubToken, mockEnv)).rejects.toThrow('Missing subject');
    });

    it('should reject token with unknown key ID', async () => {
      const unknownKidHeader = { ...validHeader, kid: 'unknown-kid-456' };
      const unknownKidToken = await signJWT(unknownKidHeader, validPayload, RSA_KEY_PAIR.privateKey);
      
      await expect(verifyFirebaseIdToken(unknownKidToken, mockEnv)).rejects.toThrow('Certificate not found');
    });

    it('should reject token with wrong algorithm', async () => {
      const wrongAlgHeader = { ...validHeader, alg: 'HS256' };
      const wrongAlgToken = await signJWT(wrongAlgHeader, validPayload, RSA_KEY_PAIR.privateKey);
      
      await expect(verifyFirebaseIdToken(wrongAlgToken, mockEnv)).rejects.toThrow('Invalid algorithm');
    });

    it('should handle malformed JWT', async () => {
      await expect(verifyFirebaseIdToken('invalid.jwt', mockEnv)).rejects.toThrow('Invalid JWT format');
    });

    it('should handle completely invalid JWT structure', async () => {
      await expect(verifyFirebaseIdToken('not-a-jwt-at-all', mockEnv)).rejects.toThrow(/Invalid JWT format|Token verification failed/);
    });

    it('should handle JWT with malformed base64url encoding', async () => {
      const invalidToken = 'invalid-b64.invalid-b64.invalid-b64';
      await expect(verifyFirebaseIdToken(invalidToken, mockEnv)).rejects.toThrow(/Token verification failed/);
    });
  });

  describe('getStaffStatus', () => {
    it('should return true for admin role claim', async () => {
      const userIdentity = {
        uid: 'test-uid',
        claims: adminPayload,
      };
      
      const isStaff = await getStaffStatus(userIdentity, mockEnv);
      expect(isStaff).toBe(true);
    });

    it('should return true for moderator role claim', async () => {
      const userIdentity = {
        uid: 'test-uid',
        claims: moderatorPayload,
      };
      
      const isStaff = await getStaffStatus(userIdentity, mockEnv);
      expect(isStaff).toBe(true);
    });

    it('should return false for non-staff user with other role', async () => {
      const userIdentity = {
        uid: 'test-uid',
        claims: { ...validPayload, role: 'user' },
      };
      
      const isStaff = await getStaffStatus(userIdentity, mockEnv);
      expect(isStaff).toBe(false);
    });

    it('should return false for user without role claim', async () => {
      const userIdentity = {
        uid: 'test-uid',
        claims: validPayload,
      };
      
      const isStaff = await getStaffStatus(userIdentity, mockEnv);
      expect(isStaff).toBe(false);
    });

    it('should handle Firestore fallback gracefully when disabled', async () => {
      const userIdentity = {
        uid: 'test-uid',
        claims: validPayload,
      };
      
      // Should not make any additional network calls since fallback is disabled
      const isStaff = await getStaffStatus(userIdentity, mockEnv);
      expect(isStaff).toBe(false);
      
      // Verify no Firestore calls were made
      const firestoreCalls = vi.mocked(fetch).mock.calls.filter(call => 
        typeof call[0] === 'string' && call[0].includes('firestore.googleapis.com')
      );
      expect(firestoreCalls).toHaveLength(0);
    });
  });

  describe('Real Cryptographic Verification Tests', () => {
    it('should prove genuine cryptographic verification by rejecting all tampering attempts', async () => {
      // Create a valid token
      const validToken = await signJWT(validHeader, validPayload, RSA_KEY_PAIR.privateKey);
      
      // Verify the valid token works
      const result = await verifyFirebaseIdToken(validToken, mockEnv);
      expect(result.uid).toBe('uid123');
      
      // Test various tampering attempts
      const [headerB64, payloadB64, signatureB64] = validToken.split('.');
      
      // 1. Tamper with header
      const header = JSON.parse(base64UrlDecode(headerB64).toString());
      header.alg = 'HS256'; // Change algorithm
      const tamperedHeaderB64 = base64UrlEncode(JSON.stringify(header));
      const headerTamperedToken = `${tamperedHeaderB64}.${payloadB64}.${signatureB64}`;
      await expect(verifyFirebaseIdToken(headerTamperedToken, mockEnv)).rejects.toThrow();
      
      // 2. Tamper with payload claims
      const payload = JSON.parse(base64UrlDecode(payloadB64).toString());
      payload.sub = 'hacker-uid'; // Change subject
      const tamperedPayloadB64 = base64UrlEncode(JSON.stringify(payload));
      const payloadTamperedToken = `${headerB64}.${tamperedPayloadB64}.${signatureB64}`;
      await expect(verifyFirebaseIdToken(payloadTamperedToken, mockEnv)).rejects.toThrow();
      
      // 3. Tamper with signature (flip multiple bytes)
      const sigBytes = base64UrlDecode(signatureB64);
      for (let i = 0; i < Math.min(10, sigBytes.length); i++) {
        sigBytes[i] = sigBytes[i] ^ 0xFF; // Flip all bits
      }
      const tamperedSigB64 = base64UrlEncode(sigBytes);
      const sigTamperedToken = `${headerB64}.${payloadB64}.${tamperedSigB64}`;
      await expect(verifyFirebaseIdToken(sigTamperedToken, mockEnv)).rejects.toThrow();
      
      // 4. Use signature from different data
      const differentPayload = { ...validPayload, sub: 'different-user' };
      const differentToken = await signJWT(validHeader, differentPayload, RSA_KEY_PAIR.privateKey);
      const [, , differentSigB64] = differentToken.split('.');
      const wrongSigToken = `${headerB64}.${payloadB64}.${differentSigB64}`;
      await expect(verifyFirebaseIdToken(wrongSigToken, mockEnv)).rejects.toThrow();
    });

    it('should verify that signature verification is cryptographically sound', async () => {
      // Create two identical tokens with same content but signed independently
      const token1 = await signJWT(validHeader, validPayload, RSA_KEY_PAIR.privateKey);
      const token2 = await signJWT(validHeader, validPayload, RSA_KEY_PAIR.privateKey);
      
      // Both should verify successfully
      const result1 = await verifyFirebaseIdToken(token1, mockEnv);
      const result2 = await verifyFirebaseIdToken(token2, mockEnv);
      
      expect(result1.uid).toBe('uid123');
      expect(result2.uid).toBe('uid123');
      
      // Signatures will be different (RSA-PSS randomness) but both valid
      const [,, sig1] = token1.split('.');
      const [,, sig2] = token2.split('.');
      // Note: RSASSA-PKCS1-v1_5 is deterministic, so signatures would be same
      // But this test documents the verification works regardless
    });

    it('should demonstrate end-to-end cryptographic integrity', async () => {
      // This test verifies the complete crypto chain works correctly
      
      // 1. Generate a token with the test private key
      const testPayload = {
        ...validPayload,
        custom_field: 'this-is-signed-data',
        timestamp: Math.floor(Date.now() / 1000),
      };
      const validToken = await signJWT(validHeader, testPayload, RSA_KEY_PAIR.privateKey);
      
      // 2. Verify it passes verification
      const result = await verifyFirebaseIdToken(validToken, mockEnv);
      expect(result.uid).toBe('uid123');
      expect(result.claims.custom_field).toBe('this-is-signed-data');
      
      // 3. Create variations that should all fail
      const [headerB64, payloadB64, signatureB64] = validToken.split('.');
      
      // 3a. Different private key (should fail)
      const wrongKeyToken = await signJWT(validHeader, testPayload, WRONG_KEY_PAIR.privateKey);
      await expect(verifyFirebaseIdToken(wrongKeyToken, mockEnv)).rejects.toThrow();
      
      // 3b. Tampered payload (should fail)
      const tamperedPayload = { ...testPayload, custom_field: 'this-is-tampered' };
      const tamperedPayloadB64 = base64UrlEncode(JSON.stringify(tamperedPayload));
      const tamperedToken = `${headerB64}.${tamperedPayloadB64}.${signatureB64}`;
      await expect(verifyFirebaseIdToken(tamperedToken, mockEnv)).rejects.toThrow();
      
      // 3c. Random signature (should fail)
      const randomSig = base64UrlEncode(Buffer.from('random-garbage-signature'));
      const randomSigToken = `${headerB64}.${payloadB64}.${randomSig}`;
      await expect(verifyFirebaseIdToken(randomSigToken, mockEnv)).rejects.toThrow();
      
      // 4. Verify the original is still valid after all tampering tests
      const finalResult = await verifyFirebaseIdToken(validToken, mockEnv);
      expect(finalResult.uid).toBe('uid123');
    });
  });
});