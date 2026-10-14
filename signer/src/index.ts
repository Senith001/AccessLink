import { verifyFirebaseIdToken, getStaffStatus } from './auth';
import { buildUploadSignature, signedViewUrl, promoteToPublic } from './cloudinary';

export interface Env {
  CLOUDINARY_CLOUD_NAME: string;
  CLOUDINARY_API_KEY: string;
  CLOUDINARY_API_SECRET: string;
  FIREBASE_PROJECT_ID: string;
  ALLOWED_ORIGINS: string;
}

interface ErrorResponse {
  error: string;
  code: string;
}

// Simple in-memory rate limiter - production should use Durable Objects/KV
class InMemoryRateLimiter {
  private requests = new Map<string, number[]>();
  private maxRequests = 100;
  private windowMs = 15 * 60 * 1000; // 15 minutes

  isAllowed(key: string): boolean {
    const now = Date.now();
    const requests = this.requests.get(key) || [];
    
    // Clean old requests
    const recentRequests = requests.filter(time => now - time < this.windowMs);
    
    if (recentRequests.length >= this.maxRequests) {
      return false;
    }
    
    recentRequests.push(now);
    this.requests.set(key, recentRequests);
    return true;
  }
}

const rateLimiter = new InMemoryRateLimiter();

function jsonError(error: string, code: string, status: number): Response {
  return new Response(JSON.stringify({ error, code }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function getCorsHeaders(origin: string, env: Env): Headers {
  const headers = new Headers();
  const allowedOrigins = env.ALLOWED_ORIGINS.split(',').map(o => o.trim());
  
  if (allowedOrigins.includes(origin)) {
    headers.set('Access-Control-Allow-Origin', origin);
  }
  
  headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  headers.set('Access-Control-Max-Age', '86400');
  
  return headers;
}

async function handleSignUpload(request: Request, env: Env): Promise<Response> {
  try {
    const authHeader = request.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return jsonError('Missing or invalid authorization header', 'INVALID_AUTH', 401);
    }

    const token = authHeader.slice(7);
    const { uid } = await verifyFirebaseIdToken(token, env);

    const body = await request.json() as { submissionId: string };
    if (!body.submissionId) {
      return jsonError('Missing submissionId', 'INVALID_INPUT', 400);
    }

    // Build upload signature for private pending folder
    const timestamp = Math.floor(Date.now() / 1000);
    // Construct the params-to-sign as ONLY what Cloudinary signs for /image/upload
    const paramsToSign = {
      timestamp: timestamp.toString(),
      folder: `place_photo_submissions/${uid}`,
      public_id: `${body.submissionId}`,
      type: 'authenticated',
    };

    const signature = buildUploadSignature(paramsToSign, env.CLOUDINARY_API_SECRET);

    // Return to client: signed params + api_key (unsigned) + signature
    // Do NOT return cloud_name (client builds URL from its own config)
    return new Response(JSON.stringify({
      ...paramsToSign,
      api_key: env.CLOUDINARY_API_KEY,
      signature,
      // Never return the API secret or cloud_name
    }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Sign upload error:', error);
    return jsonError('Internal server error', 'INTERNAL_ERROR', 500);
  }
}

async function handleSignView(request: Request, env: Env): Promise<Response> {
  try {
    const authHeader = request.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return jsonError('Missing or invalid authorization header', 'INVALID_AUTH', 401);
    }

    const token = authHeader.slice(7);
    const { uid, claims } = await verifyFirebaseIdToken(token, env);
    
    const isStaff = await getStaffStatus({ uid, claims }, env);
    if (!isStaff) {
      return jsonError('Staff access required', 'INSUFFICIENT_PERMISSIONS', 403);
    }

    const body = await request.json() as { publicId: string };
    if (!body.publicId) {
      return jsonError('Missing publicId', 'INVALID_INPUT', 400);
    }

    const signedUrl = signedViewUrl(body.publicId, {
      cloudName: env.CLOUDINARY_CLOUD_NAME,
      apiKey: env.CLOUDINARY_API_KEY,
      apiSecret: env.CLOUDINARY_API_SECRET,
    });

    return new Response(JSON.stringify({
      url: signedUrl,
    }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Sign view error:', error);
    return jsonError('Internal server error', 'INTERNAL_ERROR', 500);
  }
}

async function handlePromote(request: Request, env: Env): Promise<Response> {
  try {
    const authHeader = request.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return jsonError('Missing or invalid authorization header', 'INVALID_AUTH', 401);
    }

    const token = authHeader.slice(7);
    const { uid, claims } = await verifyFirebaseIdToken(token, env);
    
    const isStaff = await getStaffStatus({ uid, claims }, env);
    if (!isStaff) {
      return jsonError('Staff access required', 'INSUFFICIENT_PERMISSIONS', 403);
    }

    const body = await request.json() as { 
      submissionId: string; 
      placeId: string; 
      publicId: string; 
    };
    
    if (!body.submissionId || !body.placeId || !body.publicId) {
      return jsonError('Missing required fields', 'INVALID_INPUT', 400);
    }

    // Perform actual Cloudinary promotion and get real secure_url
    const result = await promoteToPublic({
      submissionId: body.submissionId,
      placeId: body.placeId,
      currentPublicId: body.publicId,
      cloudName: env.CLOUDINARY_CLOUD_NAME,
      apiKey: env.CLOUDINARY_API_KEY,
      apiSecret: env.CLOUDINARY_API_SECRET,
    });

    return new Response(JSON.stringify({
      secureUrl: result.secureUrl,
    }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Promote error:', error);
    return jsonError('Internal server error', 'INTERNAL_ERROR', 500);
  }
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const origin = request.headers.get('Origin') || '';
    const corsHeaders = getCorsHeaders(origin, env);

    // Handle preflight requests
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    // Rate limiting
    const clientIP = request.headers.get('CF-Connecting-IP') || 'unknown';
    const rateLimitKey = `${clientIP}`;
    
    if (!rateLimiter.isAllowed(rateLimitKey)) {
      const response = jsonError('Rate limit exceeded', 'RATE_LIMITED', 429);
      corsHeaders.forEach((value, key) => response.headers.set(key, value));
      return response;
    }

    let response: Response;

    try {
      if (request.method === 'POST') {
        switch (url.pathname) {
          case '/sign-upload':
            response = await handleSignUpload(request, env);
            break;
          case '/sign-view':
            response = await handleSignView(request, env);
            break;
          case '/promote':
            response = await handlePromote(request, env);
            break;
          default:
            response = jsonError('Not found', 'NOT_FOUND', 404);
        }
      } else {
        response = jsonError('Method not allowed', 'METHOD_NOT_ALLOWED', 405);
      }
    } catch (error) {
      console.error('Request error:', error);
      response = jsonError('Internal server error', 'INTERNAL_ERROR', 500);
    }

    // Apply CORS headers to response
    corsHeaders.forEach((value, key) => response.headers.set(key, value));
    return response;
  },
};