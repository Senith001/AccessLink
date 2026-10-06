import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/accessibility_rating.dart';
import '../models/place.dart';
import '../models/place_photo.dart';
import '../models/place_review.dart';
import '../services/directions_service.dart';
import '../services/photo_service.dart';
import '../services/place_service.dart';
import '../services/rating_service.dart';
import '../services/report_service.dart';
import '../services/review_service.dart';
import '../services/travel_time_service.dart';

/// Full dedicated details screen for a place.
/// Displays verified accessibility status, accessibility features (Yes/No/Unknown),
/// live ratings, written reviews, photo gallery, directions, and report actions.
class PlaceDetailsScreen extends StatefulWidget {
  final Place place;
  final LatLng? currentLocation;

  const PlaceDetailsScreen({
    super.key,
    required this.place,
    this.currentLocation,
  });

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  final PlaceService _placeService = PlaceService();
  final RatingService _ratingService = RatingService();
  final ReportService _reportService = ReportService();
  final ReviewService _reviewService = ReviewService();
  final PhotoService _photoService = PhotoService();
  final DirectionsService _directionsService = DirectionsService();
  final TravelTimeService _travelTimeService = TravelTimeService();

  late Place _place;
  bool _isSyncing = true;
  int? _userRating;
  bool _isSubmittingRating = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _place = widget.place;
    _syncWithFirestore();
    _loadUserRating();
  }

  Future<void> _syncWithFirestore() async {
    try {
      final updatedPlace =
          await _placeService.syncPlaceWithFirestore(widget.place);
      if (!mounted) return;
      setState(() {
        _place = updatedPlace;
        _isSyncing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _loadUserRating() async {
    try {
      final rating = await _ratingService.getUserRating(widget.place.id);
      if (!mounted) return;
      setState(() {
        _userRating = rating?.rating;
      });
    } catch (_) {}
  }

  Future<void> _submitRating(int rating) async {
    if (!RatingService.isValidRating(rating)) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please sign in to rate this place.');
      return;
    }

    setState(() => _isSubmittingRating = true);

    try {
      await _ratingService.submitRating(
        placeId: _place.id,
        rating: rating,
      );

      if (!mounted) return;
      setState(() {
        _userRating = rating;
        _isSubmittingRating = false;
      });
      _showSnackBar('Rating saved!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingRating = false);
      _showSnackBar('Failed to save rating: $e');
    }
  }

  void _showReportDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please sign in to report incorrect information.');
      return;
    }

    final reasonController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.flag, color: Colors.orange.shade700),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Report Incorrect Info',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Place: ${_place.name}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Reason for report *',
                        hintText:
                            'Describe what is inaccurate (e.g. ramp is broken or entrance has 3 steps)...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final text = reasonController.text.trim();
                          if (text.isEmpty) {
                            _showSnackBar('Please provide a reason.');
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            await _reportService.submitReport(
                              placeId: _place.id,
                              placeName: _place.name,
                              reason: text,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(dialogCtx);
                            _showSnackBar(
                                'Report submitted. Our team will review it.');
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (!ctx.mounted) return;
                            _showSnackBar('Submission failed: $e');
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, size: 16),
                  label: Text(isSubmitting ? 'Submitting...' : 'Submit Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReviewDialog({PlaceReview? existingReview}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please sign in to write a review.');
      return;
    }

    final contentController =
        TextEditingController(text: existingReview?.content ?? '');
    bool isSubmitting = false;
    String? localError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.rate_review, color: Colors.blue.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      existingReview == null ? 'Write Review' : 'Edit Review',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sharing feedback for: ${_place.name}',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      maxLines: 5,
                      maxLength: ReviewService.maxContentLength,
                      decoration: InputDecoration(
                        labelText: 'Your accessibility review *',
                        hintText:
                            'Describe accessibility details: doors, ramps, corridors, staff assistance, or washrooms...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        errorText: localError,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final text = contentController.text.trim();
                          try {
                            ReviewService.validateReviewContent(text);
                          } catch (e) {
                            setDialogState(() {
                              localError = e.toString().replaceFirst(
                                  'ArgumentError: ', '');
                            });
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            localError = null;
                          });

                          try {
                            await _reviewService.submitReview(
                              placeId: _place.id,
                              content: text,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(dialogCtx);
                            _showSnackBar(existingReview == null
                                ? 'Review published!'
                                : 'Review updated!');
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              localError = 'Error: $e';
                            });
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 16),
                  label: Text(isSubmitting ? 'Saving...' : 'Save Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please sign in to upload photos.');
      return;
    }

    setState(() => _isUploadingPhoto = true);

    try {
      final photo = await _photoService.pickAndUploadPhoto(
        placeId: _place.id,
        source: source,
      );

      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);

      if (photo != null) {
        _showSnackBar('Photo uploaded successfully!');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      final msg = e.toString().replaceFirst('ArgumentError: ', '');
      _showSnackBar('Upload failed: $msg');
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadPhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color _categoryColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('wash') || lower.contains('toilet')) return Colors.teal;
    if (lower.contains('hotel')) return Colors.deepPurple;
    if (lower.contains('rest') || lower.contains('food')) return Colors.orange;
    if (lower.contains('hosp') || lower.contains('clinic')) return Colors.red;
    if (lower.contains('pharm') || lower.contains('med')) return Colors.green;
    if (lower.contains('school') || lower.contains('edu')) return Colors.blue;
    if (lower.contains('bank')) return Colors.amber.shade800;
    if (lower.contains('fuel')) return Colors.deepOrange;
    if (lower.contains('park')) return Colors.indigo;
    if (lower.contains('super')) return Colors.pink;
    if (lower.contains('bus')) return Colors.cyan;
    return Colors.indigo;
  }

  IconData _categoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('wash') || lower.contains('toilet')) return Icons.wc;
    if (lower.contains('hotel')) return Icons.hotel;
    if (lower.contains('rest') || lower.contains('food')) return Icons.restaurant;
    if (lower.contains('hosp') || lower.contains('clinic')) {
      return Icons.local_hospital;
    }
    if (lower.contains('pharm') || lower.contains('med')) {
      return Icons.medical_services;
    }
    if (lower.contains('school') || lower.contains('edu')) return Icons.school;
    if (lower.contains('bank')) return Icons.account_balance;
    if (lower.contains('fuel')) return Icons.local_gas_station;
    if (lower.contains('park')) return Icons.local_parking;
    if (lower.contains('super')) return Icons.shopping_cart;
    if (lower.contains('bus')) return Icons.directions_bus;
    return Icons.place;
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(_place.categoryName);

    double? distanceKm;
    int? travelMinutes;
    if (widget.currentLocation != null) {
      distanceKm = _travelTimeService.calculateDistanceKm(
        startLatitude: widget.currentLocation!.latitude,
        startLongitude: widget.currentLocation!.longitude,
        destinationLatitude: _place.latitude,
        destinationLongitude: _place.longitude,
      );
      travelMinutes = _travelTimeService.calculateEstimatedTravelTime(
        distanceKm: distanceKm,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _place.name,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report information',
            onPressed: _showReportDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _syncWithFirestore();
          await _loadUserRating();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // ── Header Card ──
            _buildHeaderCard(color, distanceKm, travelMinutes),

            const SizedBox(height: 16),

            // ── Admin-Approved Correction Alert (if present) ──
            if (_place.correctedAccessibilityInfo != null &&
                _place.correctedAccessibilityInfo!.trim().isNotEmpty) ...[
              _buildCorrectedInfoBanner(),
              const SizedBox(height: 16),
            ],

            // ── Accessibility Features Grid (Yes / No / Unknown) ──
            _buildFeaturesSection(),

            const SizedBox(height: 20),

            // ── Accessibility Rating Section ──
            _buildRatingSection(),

            const SizedBox(height: 20),

            // ── Action Buttons: Directions & Report ──
            _buildActionButtons(color),

            const SizedBox(height: 24),

            // ── Accessibility Photos Gallery ──
            _buildPhotoGallerySection(),

            const SizedBox(height: 24),

            // ── Written Reviews Section ──
            _buildReviewsSection(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
      Color color, double? distanceKm, int? travelMinutes) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  child: Icon(_categoryIcon(_place.categoryName), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _place.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildChip(_place.categoryName,
                              color: color.withValues(alpha: 0.15),
                              textColor: color),
                          if (_place.isVerified)
                            _buildChip('Verified',
                                icon: Icons.verified,
                                color: Colors.green.shade50,
                                textColor: Colors.green.shade800)
                          else
                            _buildChip('Unverified Data',
                                icon: Icons.help_outline,
                                color: Colors.grey.shade100,
                                textColor: Colors.grey.shade700),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Address & Distance
            Row(
              children: [
                Icon(Icons.location_on, size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _place.address.isNotEmpty
                        ? _place.address
                        : 'Coordinates: ${_place.latitude.toStringAsFixed(4)}, ${_place.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                  ),
                ),
              ],
            ),
            if (distanceKm != null && travelMinutes != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.near_me_outlined,
                      size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '${distanceKm.toStringAsFixed(2)} km away • ~${travelMinutes} min travel',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCorrectedInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 20, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'Admin-Verified Update',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _place.correctedAccessibilityInfo!,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.green.shade900,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.accessibility_new, color: Color(0xFF1976D2)),
            const SizedBox(width: 8),
            const Text(
              'Accessibility Features',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (_isSyncing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                _featureTile(
                    'Wheelchair Accessible', Icons.accessible, _place.wheelchair),
                const Divider(height: 1),
                _featureTile('Access Ramp', Icons.accessible_forward, _place.ramp),
                const Divider(height: 1),
                _featureTile('Elevator / Lift', Icons.elevator, _place.elevator),
                const Divider(height: 1),
                _featureTile('Accessible Restroom', Icons.wc, _place.accessibleToilet),
                const Divider(height: 1),
                _featureTile('Accessible Parking', Icons.local_parking,
                    _place.accessibleParking),
                const Divider(height: 1),
                _featureTile('Tactile Paving', Icons.touch_app, _place.tactilePaving),
                const Divider(height: 1),
                _featureTile(
                    'Hearing Loop Support', Icons.hearing, _place.hearingSupport),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _featureTile(
      String label, IconData icon, AccessibilityStatus status) {
    Color iconColor;
    IconData statusIcon;
    Color badgeColor;
    Color badgeTextColor;

    switch (status) {
      case AccessibilityStatus.yes:
        iconColor = Colors.green.shade700;
        statusIcon = Icons.check_circle;
        badgeColor = Colors.green.shade50;
        badgeTextColor = Colors.green.shade800;
        break;
      case AccessibilityStatus.no:
        iconColor = Colors.red.shade700;
        statusIcon = Icons.cancel;
        badgeColor = Colors.red.shade50;
        badgeTextColor = Colors.red.shade800;
        break;
      case AccessibilityStatus.unknown:
        iconColor = Colors.grey.shade500;
        statusIcon = Icons.help_outline;
        badgeColor = Colors.grey.shade100;
        badgeTextColor = Colors.grey.shade700;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.blueGrey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: iconColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: badgeTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return StreamBuilder<PlaceAccessibilityScore>(
      stream: _ratingService.placeScoreStream(_place.id),
      builder: (context, snapshot) {
        final score = snapshot.data ?? PlaceAccessibilityScore.empty();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber.shade800, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Community Accessibility Rating',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (score.ratingCount > 0)
                Row(
                  children: [
                    ...List.generate(5, (i) {
                      final starVal = i + 1;
                      IconData icon;
                      if (score.averageScore >= starVal) {
                        icon = Icons.star;
                      } else if (score.averageScore >= starVal - 0.5) {
                        icon = Icons.star_half;
                      } else {
                        icon = Icons.star_border;
                      }
                      return Icon(icon, color: Colors.amber.shade700, size: 22);
                    }),
                    const SizedBox(width: 8),
                    Text(
                      score.averageScore.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${score.ratingCount} ${score.ratingCount == 1 ? 'rating' : 'ratings'})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'No ratings recorded yet. Tap below to be the first!',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.amber.shade900,
                  ),
                ),
              const Divider(height: 20),
              if (FirebaseAuth.instance.currentUser != null) ...[
                Text(
                  _userRating != null
                      ? 'Your rating: $_userRating / 5 (tap to update)'
                      : 'Tap to submit your rating:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ...List.generate(5, (i) {
                      final star = i + 1;
                      final isFilled =
                          _userRating != null && star <= _userRating!;
                      return GestureDetector(
                        onTap: _isSubmittingRating
                            ? null
                            : () => _submitRating(star),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            isFilled ? Icons.star : Icons.star_border,
                            color: isFilled
                                ? Colors.amber.shade700
                                : Colors.amber.shade400,
                            size: 34,
                          ),
                        ),
                      );
                    }),
                    if (_isSubmittingRating) ...[
                      const SizedBox(width: 10),
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ] else
                Text(
                  'Sign in to submit your accessibility rating.',
                  style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(Color color) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _directionsService.openDirections(
                destinationLatitude: _place.latitude,
                destinationLongitude: _place.longitude,
                originLatitude: widget.currentLocation?.latitude,
                originLongitude: widget.currentLocation?.longitude,
              ),
              icon: const Icon(Icons.directions, size: 20),
              label: const Text(
                'Directions',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _showReportDialog,
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text(
                'Report',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade800,
                side: BorderSide(color: Colors.orange.shade700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.photo_library, color: Color(0xFF1976D2)),
                SizedBox(width: 8),
                Text(
                  'Accessibility Photos',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _isUploadingPhoto ? null : _showPhotoOptions,
              icon: _isUploadingPhoto
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo, size: 16),
              label: Text(_isUploadingPhoto ? 'Uploading...' : 'Add Photo'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<PlacePhoto>>(
          stream: _photoService.getPlacePhotosStream(_place.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            final photos = snapshot.data ?? [];
            if (photos.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.no_photography_outlined,
                          size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 6),
                      Text(
                        'No accessibility photos yet.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upload photos of ramps, entrances, or elevators to help others.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  return GestureDetector(
                    onTap: () => _viewFullPhoto(photo),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Image.network(
                            photo.downloadUrl,
                            width: 150,
                            height: 130,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                width: 150,
                                height: 130,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              width: 150,
                              height: 130,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey),
                            ),
                          ),
                          if (photo.uploaderUid ==
                              FirebaseAuth.instance.currentUser?.uid)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _confirmDeletePhoto(photo),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.delete,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  void _viewFullPhoto(PlacePhoto photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                photo.downloadUrl,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Added ${DateFormat('MMM d, yyyy').format(photo.createdAt)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePhoto(PlacePhoto photo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo?'),
        content: const Text('Are you sure you want to remove this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _photoService.deletePhoto(photo);
                _showSnackBar('Photo removed.');
              } catch (e) {
                _showSnackBar('Failed to remove photo: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.comment_outlined, color: Color(0xFF1976D2)),
                SizedBox(width: 8),
                Text(
                  'Community Reviews',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => _showReviewDialog(),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Write Review'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<PlaceReview>>(
          stream: _reviewService.getReviewsStream(_place.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            final reviews = snapshot.data ?? [];
            if (reviews.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.rate_review_outlined,
                          size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 6),
                      Text(
                        'No written reviews yet.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Be the first to share your accessibility experience!',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final review = reviews[index];
                final isOwner =
                    currentUid != null && review.userId == currentUid;

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                review.authorName.isNotEmpty
                                    ? review.authorName[0].toUpperCase()
                                    : 'A',
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    review.authorName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM d, yyyy')
                                        .format(review.updatedAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isOwner)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    _showReviewDialog(existingReview: review);
                                  } else if (val == 'delete') {
                                    _confirmDeleteReview(review);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 16),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete,
                                            size: 16, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          review.content,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Colors.black87,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _confirmDeleteReview(PlaceReview review) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Review?'),
        content: const Text('Are you sure you want to remove your review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _reviewService.deleteReview(review.placeId);
                _showSnackBar('Review removed.');
              } catch (e) {
                _showSnackBar('Failed to remove review: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    String label, {
    IconData? icon,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
