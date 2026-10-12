import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/place_photo.dart';
import '../../services/photo_service.dart';

class UploadPhotoDialog extends StatefulWidget {
  final String placeId;
  final String placeName;

  const UploadPhotoDialog({
    super.key,
    required this.placeId,
    required this.placeName,
  });

  static Future<PlacePhoto?> show(
    BuildContext context, {
    required String placeId,
    required String placeName,
  }) {
    return showDialog<PlacePhoto>(
      context: context,
      builder: (_) => UploadPhotoDialog(placeId: placeId, placeName: placeName),
    );
  }

  @override
  State<UploadPhotoDialog> createState() => _UploadPhotoDialogState();
}

class _UploadPhotoDialogState extends State<UploadPhotoDialog> {
  final PhotoService _photoService = PhotoService();
  final TextEditingController _captionController = TextEditingController();

  Uint8List? _selectedBytes;
  String? _selectedFileName;
  double _uploadProgress = 0.0;
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _errorMessage = null);

    try {
      final file = await _photoService.pickImage(source: source);
      if (file == null) return; // User cancelled picker

      final bytes = await file.readAsBytes();
      final validation = PhotoService.validateImage(bytes);

      if (!validation.isValid) {
        setState(() {
          _errorMessage = validation.errorMessage;
        });
        return;
      }

      setState(() {
        _selectedBytes = bytes;
        _selectedFileName = file.name;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not access photo: $e';
      });
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedBytes = null;
      _selectedFileName = null;
      _errorMessage = null;
    });
  }

  Future<void> _upload() async {
    if (_selectedBytes == null || _selectedFileName == null) {
      setState(() => _errorMessage = 'Please select a photo first.');
      return;
    }

    if (_photoService.currentUser == null) {
      setState(() => _errorMessage = 'Please sign in to upload photos.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      final photo = await _photoService.uploadPlacePhoto(
        placeId: widget.placeId,
        bytes: _selectedBytes!,
        fileName: _selectedFileName!,
        caption: _captionController.text.trim(),
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );

      if (!mounted) return;

      Navigator.of(context).pop(photo);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Accessibility photo uploaded successfully!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _errorMessage = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('StateError: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.add_a_photo, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Upload Accessibility Photo',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isUploading
                        ? null
                        : () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.placeName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),

              // Image Selection Area
              if (_selectedBytes == null) ...[
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border.all(
                      color: colorScheme.outline,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 40,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Select a photo of ramps, doors, paths, or facilities',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isUploading
                                ? null
                                : () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _isUploading
                                ? null
                                : () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Supported formats: JPEG, PNG. Maximum file size: 10 MB.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                // Preview Area
                Stack(
                  children: [
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outline),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(_selectedBytes!, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          tooltip: 'Remove photo',
                          onPressed: _isUploading ? null : _clearSelection,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedFileName ?? 'Selected photo',
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isUploading
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Replace'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _captionController,
                  enabled: !_isUploading,
                  decoration: const InputDecoration(
                    labelText: 'Caption (Optional)',
                    hintText:
                        'e.g., Main entrance ramp and wide automatic door',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],

              // Upload Progress
              if (_isUploading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                ),
                const SizedBox(height: 8),
                Text(
                  _uploadProgress > 0
                      ? 'Uploading... ${(_uploadProgress * 100).toInt()}%'
                      : 'Preparing upload...',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],

              // Error State
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isUploading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isUploading || _selectedBytes == null
                        ? null
                        : _upload,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(_isUploading ? 'Uploading...' : 'Upload Photo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
