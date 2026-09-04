import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/models/user.dart';
import 'package:destiny/resources/app_colors.dart';
import 'package:destiny/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final picker = ImagePicker();

  AppUser? _currentUser;
  bool _isLoading = false;
  File? _facePhotoFile;
  File? _passportPhotoFile;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final user = await _authService.getAppUser(_authService.currentUser!.uid);
    if (user != null) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _fullNameController.text = user.displayName ?? '';
          _emailController.text = user.email;
          _phoneController.text = user.phone ?? '';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        if (type == 'face') {
          _facePhotoFile = File(pickedFile.path);
        } else {
          _passportPhotoFile = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _authService.updateUserProfile(
          sqlId: _currentUser!.sqlId!,
          fullName: _fullNameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          facePhotoFile: _facePhotoFile,
          passportPhotoFile: _passportPhotoFile,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update profile: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'Update Your Journey',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Help us tailor your perfect travel experience.',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildImagePicker(
                              context,
                              'Face Photo',
                              _facePhotoFile,
                              _currentUser?.facePhotoUrl,
                                  () => _pickImage(ImageSource.gallery, 'face'),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildImagePicker(
                              context,
                              'Passport',
                              _passportPhotoFile,
                              _currentUser?.passportPhotoUrl,
                                  () => _pickImage(ImageSource.gallery, 'passport'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: _inputDecoration('Full Name', Icons.person),
                        validator: (val) =>
                        val!.isEmpty ? 'Please enter your full name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: _inputDecoration('Email Address', Icons.email),
                        enabled: false,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: _inputDecoration('Phone Number', Icons.phone),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5.0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Update Profile'),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _authService.signOut();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: AppColors.accent),
                        ),
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, color: AppTheme.primary),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
    );
  }

  Widget _buildImagePicker(BuildContext context, String label, File? file, String? imageUrl, VoidCallback onPressed) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onPressed,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.textSecondary),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (file != null)
                    Image.file(file, fit: BoxFit.cover)
                  else if (imageUrl != null && imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: 'https://bymapara.com/$imageUrl',
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  Container(
                    color: Colors.black.withOpacity(0.3),
                  ),
                  const Center(
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
