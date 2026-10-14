/// Configuration for Cloudinary integration.
/// 
/// Values are provided at compile-time via --dart-define flags:
/// - CLOUDINARY_CLOUD_NAME: Your Cloudinary cloud name (public)
/// - SIGNER_BASE_URL: Base URL for the backend signer service
/// 
/// Example usage:
/// flutter run --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name \
///            --dart-define=SIGNER_BASE_URL=https://your-signer.com
/// 
/// Note: NO secrets (api_key, api_secret) should be stored in Flutter code.
/// These live only in the backend signer environment.
class CloudinaryConfig {
  /// The Cloudinary cloud name (public identifier)
  static String get cloudName => 
      const String.fromEnvironment('CLOUDINARY_CLOUD_NAME', defaultValue: '');

  /// The base URL for the backend signer service
  static String get signerBaseUrl => 
      const String.fromEnvironment('SIGNER_BASE_URL', defaultValue: '');

  /// Whether the configuration is properly set up
  static bool get isConfigured => 
      cloudName.isNotEmpty && signerBaseUrl.isNotEmpty;
}