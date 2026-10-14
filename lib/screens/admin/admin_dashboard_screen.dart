import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/submission.dart';
import '../../models/place_detail.dart';
import '../../repositories/submission_repository.dart';
import '../../services/admin_service.dart';
import '../../services/moderation_service.dart';
import '../../services/cloudinary_client.dart';

/// Admin dashboard for moderating photo and accessibility submissions.
/// 
/// Features:
/// - Access control: shows "Access denied" for non-staff users
/// - Two tabs: Pending Photos and Pending Accessibility Updates
/// - Approve/Reject actions with optional reason dialogs
/// - Place verification controls for staff
/// - Minimal, accessible UI with proper semantics and 48px+ touch targets
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AdminService _adminService;
  late SubmissionRepository _submissionRepository;
  late ModerationService _moderationService;
  late CloudinaryClient _cloudinaryClient;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _adminService = AdminService();
    _submissionRepository = SubmissionRepository();
    _cloudinaryClient = CloudinaryClient();
    _moderationService = ModerationService(cloudinaryClient: _cloudinaryClient);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(22) + 32,
        title: const Text('Admin'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending Photos'),
            Tab(text: 'Pending Accessibility'),
          ],
        ),
      ),
      body: FutureBuilder<bool>(
        future: _adminService.isCurrentUserStaff(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final isStaff = snapshot.data ?? false;
          if (!isStaff) {
            return const _AccessDeniedView();
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _PendingPhotosTab(
                submissionRepository: _submissionRepository,
                moderationService: _moderationService,
                cloudinaryClient: _cloudinaryClient,
              ),
              _PendingAccessibilityTab(
                submissionRepository: _submissionRepository,
                moderationService: _moderationService,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AccessDeniedView extends StatelessWidget {
  const _AccessDeniedView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Access Denied',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You are not authorized to access the admin panel.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingPhotosTab extends StatelessWidget {
  const _PendingPhotosTab({
    required this.submissionRepository,
    required this.moderationService,
    required this.cloudinaryClient,
  });

  final SubmissionRepository submissionRepository;
  final ModerationService moderationService;
  final CloudinaryClient cloudinaryClient;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PhotoSubmission>>(
      stream: submissionRepository.watchPendingPhotoSubmissions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading submissions: ${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }

        final submissions = snapshot.data ?? [];
        if (submissions.isEmpty) {
          return const Center(
            child: Text(
              'No pending photo submissions',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: submissions.length,
          itemBuilder: (context, index) {
            return _PhotoSubmissionCard(
              submission: submissions[index],
              moderationService: moderationService,
              cloudinaryClient: cloudinaryClient,
            );
          },
        );
      },
    );
  }
}

class _PendingAccessibilityTab extends StatelessWidget {
  const _PendingAccessibilityTab({
    required this.submissionRepository,
    required this.moderationService,
  });

  final SubmissionRepository submissionRepository;
  final ModerationService moderationService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AccessibilitySubmission>>(
      stream: submissionRepository.watchPendingAccessibilitySubmissions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading submissions: ${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }

        final submissions = snapshot.data ?? [];
        if (submissions.isEmpty) {
          return const Center(
            child: Text(
              'No pending accessibility submissions',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: submissions.length,
          itemBuilder: (context, index) {
            return _AccessibilitySubmissionCard(
              submission: submissions[index],
              moderationService: moderationService,
            );
          },
        );
      },
    );
  }
}

class _PhotoSubmissionCard extends StatelessWidget {
  const _PhotoSubmissionCard({
    required this.submission,
    required this.moderationService,
    required this.cloudinaryClient,
  });

  final PhotoSubmission submission;
  final ModerationService moderationService;
  final CloudinaryClient cloudinaryClient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            Text(
              submission.placeName,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Place ID: ${submission.placeId}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              'Submitted by: ${submission.submitterName}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              'Date: ${_formatDateTime(submission.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Image preview
            _CloudinaryImagePreview(
              cloudinaryPublicId: submission.cloudinaryPublicId,
              cloudinaryClient: cloudinaryClient,
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approvePhoto(context, submission),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectPhoto(context, submission),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),

            // Place verification toggle
            const SizedBox(height: 8),
            _PlaceVerificationToggle(
              placeId: submission.placeId,
              placeName: submission.placeName,
              moderationService: moderationService,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approvePhoto(BuildContext context, PhotoSubmission submission) async {
    try {
      await moderationService.approvePhoto(submission);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo approved successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving photo: $e')),
        );
      }
    }
  }

  Future<void> _rejectPhoto(BuildContext context, PhotoSubmission submission) async {
    final reason = await _showRejectDialog(context);
    if (reason == null) return; // User canceled

    try {
      await moderationService.reject(submission, reason: reason.isEmpty ? null : reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo rejected')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting photo: $e')),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _AccessibilitySubmissionCard extends StatelessWidget {
  const _AccessibilitySubmissionCard({
    required this.submission,
    required this.moderationService,
  });

  final AccessibilitySubmission submission;
  final ModerationService moderationService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            Text(
              submission.placeName,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Place ID: ${submission.placeId}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              'Submitted by: ${submission.submitterName}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              'Date: ${_formatDateTime(submission.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Changes summary
            Text(
              'Proposed Changes:',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...submission.payload.entries.map((entry) {
              final featureName = PlaceDetail.featureLabels[entry.key] ?? entry.key;
              final change = entry.value;
              final available = change['available'] as bool?;
              final notes = change['notes'] as String? ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      available == true ? Icons.check : Icons.close,
                      color: available == true 
                          ? theme.colorScheme.primary 
                          : theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$featureName: ${available == true ? 'Available' : 'Not Available'}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (notes.isNotEmpty)
                            Text(
                              'Notes: $notes',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveAccessibility(context, submission),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectAccessibility(context, submission),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),

            // Place verification toggle
            const SizedBox(height: 8),
            _PlaceVerificationToggle(
              placeId: submission.placeId,
              placeName: submission.placeName,
              moderationService: moderationService,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveAccessibility(BuildContext context, AccessibilitySubmission submission) async {
    try {
      await moderationService.approveAccessibility(submission);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accessibility update approved successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving accessibility update: $e')),
        );
      }
    }
  }

  Future<void> _rejectAccessibility(BuildContext context, AccessibilitySubmission submission) async {
    final reason = await _showRejectDialog(context);
    if (reason == null) return; // User canceled

    try {
      await moderationService.reject(submission, reason: reason.isEmpty ? null : reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accessibility update rejected')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting accessibility update: $e')),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _PlaceVerificationToggle extends StatefulWidget {
  const _PlaceVerificationToggle({
    required this.placeId,
    required this.placeName,
    required this.moderationService,
  });

  final String placeId;
  final String placeName;
  final ModerationService moderationService;

  @override
  State<_PlaceVerificationToggle> createState() => _PlaceVerificationToggleState();
}

class _PlaceVerificationToggleState extends State<_PlaceVerificationToggle> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : () => _toggleVerification(true),
            icon: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified),
            label: const Text('Mark Verified'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : () => _toggleVerification(false),
            icon: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cancel),
            label: const Text('Unverify'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleVerification(bool verified) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await widget.moderationService.markPlaceVerified(widget.placeId, verified);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.placeName} ${verified ? 'verified' : 'unverified'} successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating verification: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

/// Shows a dialog for entering an optional rejection reason
Future<String?> _showRejectDialog(BuildContext context) async {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reject Submission'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Provide a reason for rejection (optional):'),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Reason for rejection...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Reject'),
        ),
      ],
    ),
  );
}

/// Widget that fetches a signed view URL from CloudinaryClient and displays the image
class _CloudinaryImagePreview extends StatefulWidget {
  const _CloudinaryImagePreview({
    required this.cloudinaryPublicId,
    required this.cloudinaryClient,
  });

  final String cloudinaryPublicId;
  final CloudinaryClient cloudinaryClient;

  @override
  State<_CloudinaryImagePreview> createState() => _CloudinaryImagePreviewState();
}

class _CloudinaryImagePreviewState extends State<_CloudinaryImagePreview> {
  late Future<String?> _viewUrlFuture;

  @override
  void initState() {
    super.initState();
    _viewUrlFuture = _fetchViewUrl();
  }

  Future<String?> _fetchViewUrl() async {
    // Handle legacy submissions with empty cloudinaryPublicId
    if (widget.cloudinaryPublicId.isEmpty) {
      return null; // Will show fallback UI
    }

    try {
      return await widget.cloudinaryClient.getViewUrl(publicId: widget.cloudinaryPublicId);
    } catch (e) {
      // Log error but don't crash - will show error UI
      debugPrint('Failed to fetch view URL for ${widget.cloudinaryPublicId}: $e');
      rethrow; // Let FutureBuilder handle the error state
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FutureBuilder<String?>(
        future: _viewUrlFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Loading state
            return Container(
              height: 200,
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Loading preview...'),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            // Error state - could be not-configured or other issues
            return Container(
              height: 200,
              color: theme.colorScheme.errorContainer,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    color: theme.colorScheme.onErrorContainer,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preview unavailable',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    snapshot.error.toString().contains('not configured') 
                        ? '(Not configured)'
                        : '(Unable to load)',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }

          final viewUrl = snapshot.data;
          if (viewUrl == null) {
            // Legacy submission with empty cloudinaryPublicId
            return Container(
              height: 200,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No preview',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(Legacy or unconfigured)',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }

          // Success state - render the image with CachedNetworkImage
          return CachedNetworkImage(
            imageUrl: viewUrl,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 200,
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: theme.colorScheme.errorContainer,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error,
                    color: theme.colorScheme.onErrorContainer,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unable to load image',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}