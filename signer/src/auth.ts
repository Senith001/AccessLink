import type { Env } from './index';

interface GoogleJWTHeader {
  alg: string;
  kid: string;
  typ: string;
}

interface GoogleJWTPayload {
  iss: string;
  aud: string;
  auth_time: number;
  user_id: string;
  sub: string;
  iat: number;
  exp: number;
  firebase: {
    identities: Record<string, any>;
    sign_in_provider: string;
  };
  // Custom claims
  role?: string;
  [key: string]: any;
}

interface GoogleCerts {
  [kid: string]: string;
}

interface TokenVerificationResult {
  uid: string;
  claims: GoogleJWTPayload;
}

interface UserIdentity {
  uid: string;
  claims: GoogleJWTPayload;
}

// Cache for Google's public certificates
let certCache: { certs: GoogleCerts; expiry: number } | null = null;

async function fetchGoogleCerts(): Promise<GoogleCerts> {
  const now = Date.now();
  
  // Return cached certs if still valid
  if (certCache && certCache.expiry > now) {
    return certCache.certs;
  }

  const response = await fetch('https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com');
  
  if (!response.ok) {
    throw new Error(`Failed to fetch Google certs: ${response.status}`);
  }

  const cacheControl = response.headers.get('cache-control');
  let maxAge = 3600; // Default 1 hour
  
  if (cacheControl) {
    const maxAgeMatch = cacheControl.match(/max-age=(\d+)/);
    if (maxAgeMatch) {
      maxAge = parseInt(maxAgeMatch[1], 10);
    }
  }

  const certs = await response.json() as GoogleCerts;
  
  // Cache the certificates
  certCache = {
    certs,
    expiry: now + (maxAge * 1000),
  };

  return certs;
}

function base64UrlDecode(str: string): Uint8Array {
  // Add padding if needed
  const padded = str + '='.repeat((4 - (str.length % 4)) % 4);
  // Convert base64url to base64
  const base64 = padded.replace(/-/g, '+').replace(/_/g, '/');
  
  const binaryString = atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

function parseJWT(token: string): { header: GoogleJWTHeader; payload: GoogleJWTPayload; signature: string } {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('Invalid JWT format');
  }

  const [headerB64, payloadB64, signatureB64] = parts;
  
  const header = JSON.parse(new TextDecoder().decode(base64UrlDecode(headerB64))) as GoogleJWTHeader;
  const payload = JSON.parse(new TextDecoder().decode(base64UrlDecode(payloadB64))) as GoogleJWTPayload;
  
  return { header, payload, signature: signatureB64 };
}

/**
 * Extracts SubjectPublicKeyInfo (SPKI) from an X.509 certificate DER bytes
 * Uses minimal ASN.1/DER parsing to locate the SPKI within the certificate
 */
function extractSPKIFromX509(certDer: Uint8Array): Uint8Array | null {
  try {
    let pos = 0;

    // Helper to read ASN.1 length
    function readLength(): number {
      if (pos >= certDer.length) return -1;
      
      const firstByte = certDer[pos++];
      if ((firstByte & 0x80) === 0) {
        // Short form: length is in the first byte
        return firstByte;
      } else {
        // Long form: first byte indicates number of subsequent length bytes
        const lengthBytes = firstByte & 0x7F;
        if (lengthBytes === 0 || lengthBytes > 4 || pos + lengthBytes > certDer.length) {
          return -1;
        }
        
        let length = 0;
        for (let i = 0; i < lengthBytes; i++) {
          length = (length << 8) | certDer[pos++];
        }
        return length;
      }
    }

    // Helper to skip a tag and its content
    function skipTagAndContent(): boolean {
      if (pos >= certDer.length) return false;
      
      pos++; // Skip tag
      const length = readLength();
      if (length === -1 || pos + length > certDer.length) return false;
      
      pos += length;
      return true;
    }

    // Certificate ::= SEQUENCE { ... }
    if (pos >= certDer.length || certDer[pos++] !== 0x30) return null;
    const certLength = readLength();
    if (certLength === -1) return null;

    // tbsCertificate ::= SEQUENCE { ... }
    if (pos >= certDer.length || certDer[pos++] !== 0x30) return null;
    const tbsLength = readLength();
    if (tbsLength === -1) return null;

    const tbsStart = pos;
    const tbsEnd = pos + tbsLength;

    // Skip version [0] EXPLICIT Version DEFAULT v1
    if (pos < tbsEnd && certDer[pos] === 0xA0) {
      if (!skipTagAndContent()) return null;
    }

    // Skip serialNumber
    if (!skipTagAndContent()) return null;

    // Skip signature AlgorithmIdentifier
    if (!skipTagAndContent()) return null;

    // Skip issuer
    if (!skipTagAndContent()) return null;

    // Skip validity
    if (!skipTagAndContent()) return null;

    // Skip subject
    if (!skipTagAndContent()) return null;

    // Now we should be at subjectPublicKeyInfo
    if (pos >= tbsEnd || certDer[pos] !== 0x30) return null;
    
    const spkiStart = pos;
    pos++; // Skip SEQUENCE tag
    const spkiLength = readLength();
    if (spkiLength === -1 || pos + spkiLength > tbsEnd) return null;

    // Verify this is an RSA public key by checking the algorithm identifier
    const algorithmStart = pos;
    if (pos >= certDer.length || certDer[pos++] !== 0x30) return null;
    const algIdLength = readLength();
    if (algIdLength === -1 || pos + algIdLength > certDer.length) return null;

    // Check for RSA encryption OID (1.2.840.113549.1.1.1)
    if (pos >= certDer.length || certDer[pos++] !== 0x06) return null;
    const oidLength = readLength();
    if (oidLength !== 9) return null;

    const rsaOid = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01];
    for (let i = 0; i < 9; i++) {
      if (pos >= certDer.length || certDer[pos++] !== rsaOid[i]) return null;
    }

    // Extract the complete SPKI SEQUENCE
    return certDer.slice(spkiStart, spkiStart + 1 + getLengthBytes(spkiLength) + spkiLength);
  } catch {
    return null;
  }
}

// Helper to calculate how many bytes were used to encode the length
function getLengthBytes(length: number): number {
  if (length < 0x80) return 1;
  if (length < 0x100) return 2;
  if (length < 0x10000) return 3;
  if (length < 0x1000000) return 4;
  return 5;
}

async function verifyJWTSignature(token: string, cert: string): Promise<boolean> {
  try {
    const [headerB64, payloadB64, signatureB64] = token.split('.');
    if (!headerB64 || !payloadB64 || !signatureB64) {
      return false;
    }

    // Extract PEM body and convert to DER bytes
    const pemBody = cert
      .replace(/-----BEGIN CERTIFICATE-----/, '')
      .replace(/-----END CERTIFICATE-----/, '')
      .replace(/\s/g, '');
    
    const certDer = Uint8Array.from(atob(pemBody), c => c.charCodeAt(0));
    
    // Extract SPKI from X.509 certificate
    const spkiBytes = extractSPKIFromX509(certDer);
    if (!spkiBytes) {
      return false;
    }

    // Import the RSA public key for verification
    const publicKey = await crypto.subtle.importKey(
      'spki',
      spkiBytes,
      {
        name: 'RSASSA-PKCS1-v1_5',
        hash: 'SHA-256'
      },
      false,
      ['verify']
    );

    // Prepare signature and data for verification
    const signature = base64UrlDecode(signatureB64);
    const data = new TextEncoder().encode(`${headerB64}.${payloadB64}`);

    // Verify the signature
    return await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      publicKey,
      signature,
      data
    );
  } catch (error) {
    // On any parse/import error, return false (don't throw past caller's try/catch)
    return false;
  }
}

export async function verifyFirebaseIdToken(token: string, env: Env): Promise<TokenVerificationResult> {
  try {
    const { header, payload } = parseJWT(token);

    // Verify algorithm
    if (header.alg !== 'RS256') {
      throw new Error('Invalid algorithm');
    }

    // Verify issuer
    const expectedIssuer = `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`;
    if (payload.iss !== expectedIssuer) {
      throw new Error('Invalid issuer');
    }

    // Verify audience
    if (payload.aud !== env.FIREBASE_PROJECT_ID) {
      throw new Error('Invalid audience');
    }

    // Verify expiration
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp <= now) {
      throw new Error('Token expired');
    }

    // Verify subject is present
    if (!payload.sub) {
      throw new Error('Missing subject');
    }

    // Fetch and verify signature
    const certs = await fetchGoogleCerts();
    const cert = certs[header.kid];
    
    if (!cert) {
      throw new Error('Certificate not found');
    }

    const isSignatureValid = await verifyJWTSignature(token, cert);
    if (!isSignatureValid) {
      throw new Error('Invalid signature');
    }

    return {
      uid: payload.sub,
      claims: payload,
    };
  } catch (error) {
    throw new Error(`Token verification failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
}

export async function getStaffStatus(userIdentity: UserIdentity, env: Env): Promise<boolean> {
  const { uid, claims } = userIdentity;
  
  // Check custom claims first - matches AdminService's ['admin','moderator'] set
  if (claims.role === 'admin' || claims.role === 'moderator') {
    return true;
  }

  // Optional Firestore REST API fallback
  // Note: This requires read access to Firestore and should be behind a feature flag
  // Implementation kept correct but documented as requiring proper access
  const ENABLE_FIRESTORE_FALLBACK = false; // Feature flag
  
  if (ENABLE_FIRESTORE_FALLBACK) {
    try {
      const firestoreUrl = `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/users/${uid}`;
      
      // In production, you'd need proper authentication for Firestore REST API
      // This is a placeholder showing the correct endpoint structure
      const response = await fetch(firestoreUrl);
      
      if (response.ok) {
        const doc = await response.json() as any;
        const role = doc.fields?.role?.stringValue;
        return role === 'admin' || role === 'moderator';
      }
    } catch (error) {
      console.warn('Firestore fallback failed:', error);
      // Fall through to return false
    }
  }

  return false;
}