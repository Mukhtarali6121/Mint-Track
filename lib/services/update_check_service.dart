import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_colors.dart';

/// Service to check for app updates from Play Store
class UpdateCheckService {
  static final UpdateCheckService _instance = UpdateCheckService._internal();
  factory UpdateCheckService() => _instance;
  UpdateCheckService._internal();

  // Track if update dialog has been shown in this app session
  bool _hasShownUpdateDialog = false;

  /// Check if update is available by querying Play Store
  /// Returns the latest version if available, null otherwise
  Future<String?> checkForUpdate(String packageName) async {
    try {
      // Try to get version from Play Store web page
      final url = 'https://play.google.com/store/apps/details?id=$packageName';
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final body = response.body;
        
        // Try to extract version from the page
        // Play Store shows version in the HTML, we'll try to parse it
        // This is a simplified approach - for production, consider using Play Store API
        
        // Look for version pattern in the page
        final versionPattern = RegExp(r'"version":"([^"]+)"');
        final match = versionPattern.firstMatch(body);
        
        if (match != null) {
          return match.group(1);
        }
        
        // Alternative pattern
        final altPattern = RegExp(r'Current Version</div><span[^>]*>([^<]+)</span>');
        final altMatch = altPattern.firstMatch(body);
        
        if (altMatch != null) {
          return altMatch.group(1)?.trim();
        }
      }
      
      debugPrint('UpdateCheckService: Could not parse version from Play Store');
      return null;
    } catch (e) {
      debugPrint('UpdateCheckService: Error checking for updates: $e');
      return null;
    }
  }

  /// Compare two version strings
  /// Returns true if newVersion is newer than currentVersion
  bool isVersionNewer(String currentVersion, String newVersion) {
    try {
      final currentParts = currentVersion.split('.').map(int.parse).toList();
      final newParts = newVersion.split('.').map(int.parse).toList();

      // Pad with zeros to ensure same length
      while (currentParts.length < newParts.length) {
        currentParts.add(0);
      }
      while (newParts.length < currentParts.length) {
        newParts.add(0);
      }

      for (int i = 0; i < currentParts.length; i++) {
        if (newParts[i] > currentParts[i]) {
          return true;
        } else if (newParts[i] < currentParts[i]) {
          return false;
        }
      }

      return false; // Versions are equal
    } catch (e) {
      debugPrint('UpdateCheckService: Error comparing versions: $e');
      return false;
    }
  }

  /// Get current app version
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      debugPrint('UpdateCheckService: Error getting current version: $e');
      return '1.0.0';
    }
  }

  /// Get package name
  Future<String> getPackageName() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.packageName;
    } catch (e) {
      debugPrint('UpdateCheckService: Error getting package name: $e');
      return '';
    }
  }

  /// Open Play Store page for the app
  Future<void> openPlayStore(String packageName) async {
    try {
      final url = 'https://play.google.com/store/apps/details?id=$packageName';
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('UpdateCheckService: Could not launch Play Store URL');
      }
    } catch (e) {
      debugPrint('UpdateCheckService: Error opening Play Store: $e');
    }
  }

  /// Check if update dialog has already been shown in this session
  bool get hasShownUpdateDialog => _hasShownUpdateDialog;

  /// Mark that update dialog has been shown
  void markUpdateDialogAsShown() {
    _hasShownUpdateDialog = true;
  }

  /// Reset the flag (useful for testing or app restart)
  void resetUpdateDialogFlag() {
    _hasShownUpdateDialog = false;
  }

  /// Show update dialog with minimalist design
  /// Returns whether the dialog was shown (false if already shown in this session)
  static Future<bool> showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String newVersion,
    required String packageName,
  }) async {
    // Check if already shown in this session
    if (_instance._hasShownUpdateDialog) {
      debugPrint('UpdateCheckService: Update dialog already shown in this session');
      return false;
    }

    // Mark as shown before displaying
    _instance._hasShownUpdateDialog = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Section
                Container(
                  padding: const EdgeInsets.only(top: 32, bottom: 16),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accentGreen,
                          AppColors.accentGreen.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGreen.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Update Available',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Message
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'A new version is available on the Play Store',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Version Info
                // Container(
                //   margin: const EdgeInsets.symmetric(horizontal: 24),
                //   padding: const EdgeInsets.all(16),
                //   decoration: BoxDecoration(
                //     color: AppColors.backgroundScaffold,
                //     borderRadius: BorderRadius.circular(16),
                //     border: Border.all(
                //       color: AppColors.border,
                //       width: 1,
                //     ),
                //   ),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [
                //       Column(
                //         crossAxisAlignment: CrossAxisAlignment.start,
                //         children: [
                //           Text(
                //             'Current Version',
                //             style: TextStyle(
                //               fontSize: 12,
                //               color: AppColors.textSecondary,
                //               fontWeight: FontWeight.w500,
                //             ),
                //           ),
                //           const SizedBox(height: 4),
                //           Text(
                //             currentVersion,
                //             style: TextStyle(
                //               fontSize: 16,
                //               color: AppColors.textPrimary,
                //               fontWeight: FontWeight.w600,
                //             ),
                //           ),
                //         ],
                //       ),
                //       Container(
                //         padding: const EdgeInsets.symmetric(
                //           horizontal: 12,
                //           vertical: 6,
                //         ),
                //         decoration: BoxDecoration(
                //           color: AppColors.accentGreen.withValues(alpha: 0.1),
                //           borderRadius: BorderRadius.circular(20),
                //         ),
                //         child: Row(
                //           children: [
                //             Icon(
                //               Icons.arrow_forward_rounded,
                //               size: 16,
                //               color: AppColors.accentGreen,
                //             ),
                //             const SizedBox(width: 6),
                //             Column(
                //               crossAxisAlignment: CrossAxisAlignment.start,
                //               children: [
                //                 Text(
                //                   'New Version',
                //                   style: TextStyle(
                //                     fontSize: 11,
                //                     color: AppColors.accentGreen,
                //                     fontWeight: FontWeight.w500,
                //                   ),
                //                 ),
                //                 const SizedBox(height: 2),
                //                 Text(
                //                   newVersion,
                //                   style: TextStyle(
                //                     fontSize: 16,
                //                     color: AppColors.accentGreen,
                //                     fontWeight: FontWeight.w700,
                //                   ),
                //                 ),
                //               ],
                //             ),
                //           ],
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
                //
                // const SizedBox(height: 32),
                
                // Buttons
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Later',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(true);
                            UpdateCheckService().openPlayStore(packageName);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.download_rounded,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Update',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    
    return result ?? false;
  }
}

