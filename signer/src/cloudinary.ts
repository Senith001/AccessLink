import { createHash } from 'crypto';

interface UploadParams {
  [key: string]: string;
}

interface SignedViewOptions {
  cloudName: string;
  apiKey: string;
  apiSecret: string;
  expiry?: number; // seconds from now, default 1 hour
}

interface PromoteOptions {
  submissionId: string;
  placeId: string;
  currentPublicId: string;
  cloudName: string;
  apiKey: string;
  apiSecret: string;
}

/**
 * Build Cloudinary upload signature
 * Signature = SHA1(sorted_params + api_secret)
 * Server-side only - never expose api_secret to client
 */
export function buildUploadSignature(params: UploadParams, apiSecret: string): string {
  // Remove parameters that Cloudinary excludes from signature calculation
  const { signature, api_key, cloud_name, file, resource_type, ...paramsToSign } = params;
  
  // Sort parameters alphabetically
  const sortedKeys = Object.keys(paramsToSign).sort();
  
  // Build query string
  const queryString = sortedKeys
    .map(key => `${key}=${paramsToSign[key]}`)
    .join('&');
  
  // Append API secret
  const stringToSign = queryString + apiSecret;
  
  // Generate SHA1 hash
  const hash = createHash('sha1');
  hash.update(stringToSign);
  
  return hash.digest('hex');
}

/**
 * Generate signed authenticated delivery URL
 * For viewing private/authenticated assets
 * 
 * Cloudinary authenticated images are delivered via a signed URL of the form:
 * https://res.cloudinary.com/{cloud}/image/authenticated/s--{sig}--/{transformations?}/{public_id}.{format}
 * where sig = first 8 chars of base64url(sha1(transformation+public_id+api_secret))
 * 
 * Note: Cloudinary authenticated signed URLs don't expire by default - acceptable for demo
 */
export function signedViewUrl(publicId: string, options: SignedViewOptions): string {
  const { cloudName, apiSecret } = options;
  
  // For authenticated delivery, we need to sign: transformation + public_id + api_secret
  // For simplicity, no transformations are applied here
  const stringToSign = publicId + apiSecret;
  const hash = createHash('sha1');
  hash.update(stringToSign);
  const signature = hash.digest('base64url'); // base64url encoding
  
  // Build authenticated delivery URL with proper signature format
  return `https://res.cloudinary.com/${cloudName}/image/authenticated/s--${signature.substring(0, 8)}--/${publicId}`;
}

/**
 * Promote asset from private/authenticated to public using Cloudinary RENAME API
 * Performs the actual server-side API call and returns the real secure_url
 */
export async function promoteToPublic(options: PromoteOptions): Promise<{ secureUrl: string }> {
  const { submissionId, placeId, currentPublicId, cloudName, apiKey, apiSecret } = options;
  
  // Target public ID for promoted assets
  const newPublicId = `place_photos/${placeId}/${submissionId}`;
  
  // Prepare rename API call parameters
  const timestamp = Math.floor(Date.now() / 1000);
  const params = {
    from_public_id: currentPublicId,
    to_public_id: newPublicId,
    type: 'authenticated',  // Source type
    to_type: 'upload',      // Target type (makes it public)
    overwrite: 'true',
    api_key: apiKey,
    timestamp: timestamp.toString(),
  };
  
  // Generate signature for admin API call (same method as buildUploadSignature)
  const signature = buildUploadSignature(params, apiSecret);
  
  // Build the rename API request
  const renameUrl = `https://api.cloudinary.com/v1_1/${cloudName}/image/rename`;
  const body = new URLSearchParams({
    ...params,
    signature,
  }).toString();
  
  // Perform the server-side Cloudinary API call
  const response = await fetch(renameUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });
  
  if (!response.ok) {
    let errorMessage = `Cloudinary rename failed (${response.status})`;
    try {
      const errorData = await response.json() as { error?: { message?: string } };
      errorMessage = errorData.error?.message || errorMessage;
    } catch {
      // Failed to parse error response, use default message
    }
    throw new Error(errorMessage);
  }
  
  // Parse successful response and return the real secure_url
  const result = await response.json() as { secure_url: string };
  return { secureUrl: result.secure_url };
}

/**
 * Utility function to validate Cloudinary public IDs
 */
export function isValidPublicId(publicId: string): boolean {
  // Basic validation - alphanumeric, underscores, hyphens, forward slashes
  const validPattern = /^[a-zA-Z0-9_\-/]+$/;
  return validPattern.test(publicId) && publicId.length > 0 && publicId.length <= 255;
}

/**
 * Extract submission ID from a public ID if it follows expected pattern
 */
export function extractSubmissionId(publicId: string): string | null {
  // Expected patterns:
  // place_photo_submissions/{uid}/{submissionId}
  // place_photos/{placeId}/{submissionId}
  
  const submissionPattern = /place_photo_submissions\/[^/]+\/([^/]+)$/;
  const publicPattern = /place_photos\/[^/]+\/([^/]+)$/;
  
  let match = publicId.match(submissionPattern);
  if (match) {
    return match[1];
  }
  
  match = publicId.match(publicPattern);
  if (match) {
    return match[1];
  }
  
  return null;
}