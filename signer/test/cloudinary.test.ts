import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createHash } from 'crypto';
import { 
  buildUploadSignature, 
  signedViewUrl, 
  promoteToPublic,
  isValidPublicId,
  extractSubmissionId 
} from '../src/cloudinary';

// Mock fetch globally
global.fetch = vi.fn();

describe('Cloudinary Module', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });
  describe('buildUploadSignature', () => {
    it('should generate deterministic signatures', () => {
      const params = {
        timestamp: '1698789600',
        folder: 'test-folder',
        public_id: 'test-id',
        type: 'authenticated',
        cloud_name: 'test-cloud',
        api_key: 'test-key',
      };
      const apiSecret = 'test-secret';

      const signature1 = buildUploadSignature(params, apiSecret);
      const signature2 = buildUploadSignature(params, apiSecret);

      expect(signature1).toBe(signature2);
      expect(signature1).toMatch(/^[a-f0-9]{40}$/); // SHA1 hex string
    });

    it('should exclude signature and api_key from signing params', () => {
      const paramsWithExtra = {
        timestamp: '1698789600',
        folder: 'test-folder',
        public_id: 'test-id',
        type: 'authenticated',
        api_key: 'test-key',
        signature: 'should-be-ignored',
      };
      const apiSecret = 'test-secret';

      const signature = buildUploadSignature(paramsWithExtra, apiSecret);
      expect(signature).toMatch(/^[a-f0-9]{40}$/);
      
      // Should produce same result as params without extra fields
      const cleanParams = {
        timestamp: '1698789600',
        folder: 'test-folder',
        public_id: 'test-id',
        type: 'authenticated',
      };
      const expectedSignature = buildUploadSignature(cleanParams, apiSecret);
      expect(signature).toBe(expectedSignature);
    });

    it('should ignore cloud_name, api_key, signature, file, and resource_type in signature calculation', () => {
      const coreParams = {
        timestamp: '1698789600',
        folder: 'test-folder',
        public_id: 'test-id',
        type: 'authenticated',
      };
      const paramsWithExtras = {
        ...coreParams,
        cloud_name: 'test-cloud',
        api_key: 'test-key',
        signature: 'should-be-ignored',
        file: 'file-content',
        resource_type: 'image',
      };
      const apiSecret = 'test-secret';

      const signature1 = buildUploadSignature(coreParams, apiSecret);
      const signature2 = buildUploadSignature(paramsWithExtras, apiSecret);

      // Both should produce identical signatures
      expect(signature1).toBe(signature2);
      expect(signature1).toMatch(/^[a-f0-9]{40}$/);
    });

    it('should produce Cloudinary-compatible string to sign format', () => {
      const params = {
        folder: 'f',
        public_id: 'p', 
        timestamp: '123',
        type: 'authenticated',
      };
      const apiSecret = 'secret';
      
      // Expected string-to-sign: folder=f&public_id=p&timestamp=123&type=authenticated + secret
      const expectedStringToSign = 'folder=f&public_id=p&timestamp=123&type=authenticated' + apiSecret;
      
      // Calculate expected signature manually
      const expectedHash = createHash('sha1');
      expectedHash.update(expectedStringToSign);
      const expectedSignature = expectedHash.digest('hex');
      
      const actualSignature = buildUploadSignature(params, apiSecret);
      expect(actualSignature).toBe(expectedSignature);
    });

    it('should not expose API secret in any output', () => {
      const params = {
        timestamp: '1698789600',
        folder: 'test-folder',
        public_id: 'test-id',
        type: 'authenticated',
        cloud_name: 'test-cloud',
        api_key: 'test-key',
      };
      const apiSecret = 'super-secret-key';

      const signature = buildUploadSignature(params, apiSecret);
      
      // Signature should not contain the secret
      expect(signature).not.toContain(apiSecret);
      expect(signature).not.toContain('super');
      expect(signature).not.toContain('secret');
    });

    it('should produce different signatures for different parameters', () => {
      const baseParams = {
        timestamp: '1698789600',
        folder: 'test-folder',
        public_id: 'test-id',
        type: 'authenticated',
        cloud_name: 'test-cloud',
        api_key: 'test-key',
      };
      const apiSecret = 'test-secret';

      const signature1 = buildUploadSignature(baseParams, apiSecret);
      const signature2 = buildUploadSignature({ ...baseParams, folder: 'different-folder' }, apiSecret);

      expect(signature1).not.toBe(signature2);
    });
  });

  describe('signedViewUrl', () => {
    const options = {
      cloudName: 'test-cloud',
      apiKey: 'test-api-key',
      apiSecret: 'test-secret',
    };

    it('should generate signed authenticated URLs with proper format', () => {
      const publicId = 'test/image';
      const url = signedViewUrl(publicId, options);

      expect(url).toContain('res.cloudinary.com/test-cloud/image/authenticated');
      expect(url).toMatch(/\/s--[a-zA-Z0-9_-]{8}--\//); // Should have signature format s--{8chars}--
      expect(url).toContain('test/image');
    });

    it('should not expose API secret in URL', () => {
      const publicId = 'test/image';
      const url = signedViewUrl(publicId, options);

      expect(url).not.toContain('test-secret');
      expect(url).not.toContain(options.apiSecret);
    });

    it('should produce different signatures for different public IDs', () => {
      const url1 = signedViewUrl('image1', options);
      const url2 = signedViewUrl('image2', options);

      expect(url1).not.toBe(url2);
      
      // Extract signatures
      const sig1Match = url1.match(/\/s--([a-zA-Z0-9_-]{8})--\//);
      const sig2Match = url2.match(/\/s--([a-zA-Z0-9_-]{8})--\//);
      
      expect(sig1Match).toBeTruthy();
      expect(sig2Match).toBeTruthy();
      expect(sig1Match![1]).not.toBe(sig2Match![1]);
    });

    it('should generate deterministic URLs for same input', () => {
      const publicId = 'consistent/image';
      const url1 = signedViewUrl(publicId, options);
      const url2 = signedViewUrl(publicId, options);

      expect(url1).toBe(url2);
    });
  });

  describe('promoteToPublic', () => {
    const promoteOptions = {
      submissionId: 'sub-123',
      placeId: 'place-456',
      currentPublicId: 'place_photo_submissions/uid123/sub-123',
      cloudName: 'test-cloud',
      apiKey: 'test-key',
      apiSecret: 'test-secret',
    };

    it('should perform actual Cloudinary rename API call', async () => {
      // Mock successful Cloudinary API response
      vi.mocked(fetch).mockResolvedValueOnce(new Response(JSON.stringify({
        public_id: 'place_photos/place-456/sub-123',
        secure_url: 'https://res.cloudinary.com/test-cloud/image/upload/place_photos/place-456/sub-123',
        version: 1234567890,
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }));

      const result = await promoteToPublic(promoteOptions);

      expect(result.secureUrl).toBe('https://res.cloudinary.com/test-cloud/image/upload/place_photos/place-456/sub-123');
      
      // Verify fetch was called with correct parameters
      expect(fetch).toHaveBeenCalledWith(
        'https://api.cloudinary.com/v1_1/test-cloud/image/rename',
        expect.objectContaining({
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: expect.stringContaining('from_public_id=place_photo_submissions%2Fuid123%2Fsub-123'),
        })
      );

      const fetchCall = vi.mocked(fetch).mock.calls[0];
      const body = fetchCall[1]?.body as string;
      expect(body).toContain('to_public_id=place_photos%2Fplace-456%2Fsub-123');
      expect(body).toContain('type=authenticated');
      expect(body).toContain('to_type=upload');
      expect(body).toContain('overwrite=true');
      expect(body).toContain('signature=');
    });

    it('should handle Cloudinary API errors gracefully', async () => {
      // Mock Cloudinary API error response
      vi.mocked(fetch).mockResolvedValueOnce(new Response(JSON.stringify({
        error: { message: 'Asset not found' }
      }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' },
      }));

      await expect(promoteToPublic(promoteOptions)).rejects.toThrow('Asset not found');
    });

    it('should handle malformed error responses', async () => {
      // Mock malformed error response
      vi.mocked(fetch).mockResolvedValueOnce(new Response('Invalid response', {
        status: 500,
        headers: { 'Content-Type': 'text/plain' },
      }));

      await expect(promoteToPublic(promoteOptions)).rejects.toThrow('Cloudinary rename failed (500)');
    });

    it('should not expose API secret in request', async () => {
      vi.mocked(fetch).mockResolvedValueOnce(new Response(JSON.stringify({
        secure_url: 'https://res.cloudinary.com/test-cloud/image/upload/test'
      }), { status: 200 }));

      await promoteToPublic(promoteOptions);

      const fetchCall = vi.mocked(fetch).mock.calls[0];
      const body = fetchCall[1]?.body as string;
      expect(body).not.toContain('test-secret');
    });
  });

  describe('isValidPublicId', () => {
    it('should accept valid public IDs', () => {
      expect(isValidPublicId('simple_id')).toBe(true);
      expect(isValidPublicId('folder/subfolder/image')).toBe(true);
      expect(isValidPublicId('test-image-123')).toBe(true);
      expect(isValidPublicId('place_photos/place123/submission456')).toBe(true);
    });

    it('should reject invalid characters', () => {
      expect(isValidPublicId('invalid@id')).toBe(false);
      expect(isValidPublicId('id with spaces')).toBe(false);
      expect(isValidPublicId('id#with#hash')).toBe(false);
      expect(isValidPublicId('id?with?query')).toBe(false);
    });

    it('should reject empty or too long IDs', () => {
      expect(isValidPublicId('')).toBe(false);
      expect(isValidPublicId('a'.repeat(256))).toBe(false);
    });
  });

  describe('extractSubmissionId', () => {
    it('should extract submission ID from submission public ID', () => {
      const publicId = 'place_photo_submissions/user123/submission456';
      const submissionId = extractSubmissionId(publicId);
      
      expect(submissionId).toBe('submission456');
    });

    it('should extract submission ID from promoted public ID', () => {
      const publicId = 'place_photos/place789/submission123';
      const submissionId = extractSubmissionId(publicId);
      
      expect(submissionId).toBe('submission123');
    });

    it('should return null for invalid patterns', () => {
      expect(extractSubmissionId('invalid/pattern')).toBe(null);
      expect(extractSubmissionId('place_photos/only-one-part')).toBe(null);
      expect(extractSubmissionId('random_folder/user/submission')).toBe(null);
      expect(extractSubmissionId('')).toBe(null);
    });
  });
});