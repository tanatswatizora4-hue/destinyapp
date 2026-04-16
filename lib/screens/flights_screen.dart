import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:destiny/config/theme/app_theme.dart';
import 'package:destiny/services/api_service.dart';
import 'package:destiny/screens/profile_screen.dart';

class FlightsScreen extends StatefulWidget {
  // Add a user ID to the constructor to link the request to a user.
  final int userId;
  const FlightsScreen({super.key, required this.userId});

  @override
  State<FlightsScreen> createState() => _FlightsScreenState();
}

class _FlightsScreenState extends State<FlightsScreen> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();
  final List<TextEditingController> _midPlaceControllers = [TextEditingController()];

  DateTime? _departureDate;
  DateTime? _returnDate;

  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  // State variable to manage the visibility of the profile prompt
  bool _showProfilePrompt = false;

  bool _isEnquiry = false;
  bool _needsAccommodation = false;
  bool _needsInterchangeAssistance = false;
  bool _needsTaxi = false;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _peopleController.dispose();
    for (var controller in _midPlaceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addMidPlaceField() {
    setState(() {
      _midPlaceControllers.add(TextEditingController());
    });
  }

  void _removeMidPlaceField(int index) {
    setState(() {
      _midPlaceControllers[index].dispose();
      _midPlaceControllers.removeAt(index);
    });
  }

  // New method to show the date picker for both departure and return dates
  Future<void> _selectDates() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = _departureDate ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      initialDateRange: _departureDate != null && _returnDate != null
          ? DateTimeRange(start: _departureDate!, end: _returnDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppTheme.primary,
            colorScheme: const ColorScheme.light(primary: AppTheme.primary),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _departureDate = picked.start;
        _returnDate = picked.end;
      });
    }
  }

  Future<void> _submitForm() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fromLocation = _fromController.text;
      final toLocation = _toController.text;
      final numPeople = int.tryParse(_peopleController.text) ?? 1;
      final midPlaces = _midPlaceControllers.where((c) => c.text.isNotEmpty).map((c) => c.text).toList();

      // Call the new API method to submit the data
      await _apiService.createFlightBooking(
        userId: widget.userId,
        origin: fromLocation,
        destination: toLocation,
        midPlaces: midPlaces,
        numTravelers: numPeople,
        isEnquiry: _isEnquiry,
        needsAccommodation: _needsAccommodation,
        needsInterchangeAssistance: _needsInterchangeAssistance,
        needsTaxi: _needsTaxi,
        departureDate: _departureDate,
        returnDate: _returnDate,
      );

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip enquiry submitted successfully! Our agents will contact you shortly.'),
          duration: Duration(seconds: 4),
        ),
      );

      // Show the profile prompt after a short delay
      await Future.delayed(const Duration(seconds: 4));
      setState(() {
        _showProfilePrompt = true;
      });

      // Clear the form after successful submission
      _fromController.clear();
      _toController.clear();
      _peopleController.clear();
      setState(() {
        _midPlaceControllers.clear();
        _midPlaceControllers.add(TextEditingController());
        _isEnquiry = false;
        _needsAccommodation = false;
        _needsInterchangeAssistance = false;
        _needsTaxi = false;
        _departureDate = null;
        _returnDate = null;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit request: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildProfilePrompt() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Almost There!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'For a smooth booking experience, please complete your profile, especially with a phone number so our agents can reach you.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Navigate to the ProfileScreen from the main navigation bar.
              // This is a placeholder and should be implemented in NavigationScreen.
              // We'll reset the state to hide this prompt after navigation.
              setState(() {
                _showProfilePrompt = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 4,
            ),
            child: const Text(
              'Update Profile',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Adventure, Designed by You',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your travel aspirations and let us craft a perfect itinerary for you.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 48),

            // Journey Details Section
            Text(
              'Journey Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _fromController,
              label: 'Departing From',
              hint: 'e.g., New York, NY',
              icon: Icons.flight_takeoff_rounded,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _toController,
              label: 'Arriving At',
              hint: 'e.g., London, UK',
              icon: Icons.flight_land_rounded,
            ),
            const SizedBox(height: 24),
            // Date Picker Section
            _buildDateRangePicker(),
            const SizedBox(height: 24),


            // Mid-places Section
            _buildMidPlacesSection(),
            const SizedBox(height: 40),

            // Travelers Section
            Text(
              'Travelers',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _peopleController,
              label: 'Number of Travelers',
              hint: 'e.g., 2',
              icon: Icons.group_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 40),

            // Additional Services Section
            Text(
              'Additional Services',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text(
                'Enquiry for Custom Services',
                style: TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textPrimary, fontFamily: 'Poppins'),
              ),
              value: _isEnquiry,
              onChanged: (bool value) {
                setState(() {
                  _isEnquiry = value;
                });
              },
              activeColor: AppTheme.primary,
              tileColor: AppTheme.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            if (_isEnquiry) ...[
              const SizedBox(height: 16),
              _buildEnquiryCheckbox(label: 'Accommodation', value: _needsAccommodation, onChanged: (value) => setState(() => _needsAccommodation = value!)),
              _buildEnquiryCheckbox(label: 'Flight Interchange Assistance', value: _needsInterchangeAssistance, onChanged: (value) => setState(() => _needsInterchangeAssistance = value!)),
              _buildEnquiryCheckbox(label: 'Ride', value: _needsTaxi, onChanged: (value) => setState(() => _needsTaxi = value!)),
            ],
            const SizedBox(height: 48),

            // Submit Button with loading indicator
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 8,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                'Submit My Request',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            // Conditionally show the profile prompt after submission
            if (_showProfilePrompt) _buildProfilePrompt(),
          ],
        ),
      ),
    );
  }

  Widget _buildMidPlacesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mid-Places',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontFamily: 'Poppins',
              ),
            ),
            IconButton(
              onPressed: _addMidPlaceField,
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._midPlaceControllers.asMap().entries.map((entry) {
          int index = entry.key;
          TextEditingController controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Stopover #${index + 1}',
                        prefixIcon: const Icon(Icons.location_on_rounded, color: AppTheme.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                ),
                if (_midPlaceControllers.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent),
                      onPressed: () => _removeMidPlaceField(index),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildEnquiryCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CheckboxListTile(
        title: Text(label, style: const TextStyle(color: AppTheme.textPrimary)),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primary,
        checkColor: Colors.white,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Travel Dates',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _selectDates,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: AppTheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _departureDate == null || _returnDate == null
                        ? 'Select Departure and Return Dates'
                        : 'Departure: ${_departureDate!.toIso8601String().substring(0, 10)}\nReturn:     ${_returnDate!.toIso8601String().substring(0, 10)}',
                    style: TextStyle(
                      fontSize: 16,
                      color: _departureDate == null ? AppTheme.textSecondary : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
