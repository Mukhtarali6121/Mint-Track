import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../common/hive_storage.dart';
import '../../theme/app_colors.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  late final String _email;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final currentName = HiveStorage.getUserName().trim();
    final parts = currentName.split(' ').where((p) => p.isNotEmpty).toList();
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    _firstNameController.text = first;
    _lastNameController.text = last;
    _email = HiveStorage.getUserEmail();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final fullName = [first, last].where((s) => s.isNotEmpty).join(' ');
    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter first or last name')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? HiveStorage.getUserId();
      if (uid.isEmpty) throw Exception('No user');

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': fullName,
        'email': _email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await HiveStorage.saveUserProfile(userId: uid, name: fullName, email: _email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final namePreview = [
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundScaffold,
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First name',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last name',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              readOnly: true,
              controller: TextEditingController(text: namePreview),
              decoration: const InputDecoration(
                labelText: 'Name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              readOnly: true,
              controller: TextEditingController(text: _email),
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
          ],
        ),
      ),
    );
  }
}


