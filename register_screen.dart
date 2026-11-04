import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'driver_dashboard.dart';
import 'user_dashboard.dart';

class RegisterScreen extends StatefulWidget {
  final String initialRole;

  const RegisterScreen({super.key, this.initialRole = 'USER'});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _priceController = TextEditingController(text: '650');
  final _capacityController = TextEditingController(text: '1500');
  final _locationController = TextEditingController(text: 'Pune');

  late String _selectedRole;
  String _selectedVehicleType = 'TEMPO';
  bool _obscurePassword = true;
  bool _isLoading = false;

  static const List<String> _vehicleTypes = [
    'TEMPO',
    'MINI_TRUCK',
    'PICKUP',
    'TRUCK',
  ];

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _deepNavy = Color(0xFF0F172A);
  static const Color _indigoMid = Color(0xFF1E3A8A);
  static const Color _scaffoldBg = Color(0xFFF4F7FB);
  static const Color _borderColor = Color(0xFFDCE4F2);

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    String? targetRole;

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final password = _passwordController.text;

      final Map<String, dynamic> authData;
      if (_selectedRole == 'DRIVER') {
        final parsedPrice = double.tryParse(_priceController.text.trim());
        final parsedCapacity = double.tryParse(_capacityController.text.trim());
        authData = await AuthService.signupDriver(
          name: name,
          phone: phone,
          password: password,
          vehicleType: _selectedVehicleType,
          price: parsedPrice,
          capacityKg: parsedCapacity,
          currentLocation: _locationController.text.trim(),
        );
      } else {
        authData = await AuthService.signupCustomer(
          name: name,
          phone: phone,
          password: password,
        );
      }

      targetRole =
          (authData['role']?.toString().toUpperCase()) ?? _selectedRole;
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    if (!mounted || targetRole == null) return;

    final Widget destination = targetRole == 'DRIVER'
        ? const DriverDashboard()
        : const UserDashboard();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = _selectedRole == 'DRIVER';

    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _deepNavy,
        title: const Text(
          'Create RouteWise Account',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_deepNavy, _indigoMid, _primaryBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isDriver
                                ? Icons.local_shipping_rounded
                                : Icons.person_add_alt_1_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDriver
                                    ? 'Join RouteWise Fleet'
                                    : 'Customer Registration',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isDriver
                                    ? 'Set your vehicle, payload capacity & base fare'
                                    : 'Book verified goods vehicles with AI insights',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: _borderColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment<String>(
                                  value: 'USER',
                                  label: Text('Customer'),
                                  icon: Icon(Icons.person_outline),
                                ),
                                ButtonSegment<String>(
                                  value: 'DRIVER',
                                  label: Text('Driver'),
                                  icon: Icon(Icons.drive_eta_outlined),
                                ),
                              ],
                              selected: {_selectedRole},
                              onSelectionChanged: _isLoading
                                  ? null
                                  : (selection) {
                                      setState(() {
                                        _selectedRole = selection.first;
                                      });
                                    },
                              style: ButtonStyle(
                                backgroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return _primaryBlue;
                                  }
                                  return Colors.white;
                                }),
                                foregroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Colors.white;
                                  }
                                  return _deepNavy;
                                }),
                                side: WidgetStateProperty.all(
                                  const BorderSide(color: _borderColor),
                                ),
                                shape: WidgetStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Name
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _inputDecoration(
                                label: 'Full Name',
                                hint: 'Enter your full name',
                                icon: Icons.badge_outlined,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Phone
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _inputDecoration(
                                label: '10-Digit Phone Number',
                                hint: 'Enter 10-digit mobile number',
                                icon: Icons.phone_android_rounded,
                              ).copyWith(counterText: ''),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (!RegExp(r'^\d{10}$').hasMatch(v)) {
                                  return 'Enter a valid 10-digit phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Password
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: _inputDecoration(
                                label: 'Password',
                                hint: 'Create a password',
                                icon: Icons.lock_outline_rounded,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a password';
                                }
                                return null;
                              },
                            ),

                            if (isDriver) ...[
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedVehicleType,
                                decoration: _inputDecoration(
                                  label: 'Vehicle Type',
                                  hint: 'Select vehicle type',
                                  icon: Icons.local_shipping_outlined,
                                ),
                                items: _vehicleTypes.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type.replaceAll('_', ' ')),
                                  );
                                }).toList(),
                                onChanged: _isLoading
                                    ? null
                                    : (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedVehicleType = val;
                                          });
                                        }
                                      },
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _priceController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: _inputDecoration(
                                        label: 'Base Fare (₹)',
                                        hint: 'e.g. 650',
                                        icon: Icons.currency_rupee_rounded,
                                      ),
                                      validator: (value) {
                                        if (!isDriver) return null;
                                        final v = value?.trim() ?? '';
                                        final parsed = double.tryParse(v);
                                        if (parsed == null || parsed <= 0) {
                                          return 'Invalid fare';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _capacityController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: _inputDecoration(
                                        label: 'Capacity (kg)',
                                        hint: 'e.g. 1500',
                                        icon: Icons.scale_outlined,
                                      ),
                                      validator: (value) {
                                        if (!isDriver) return null;
                                        final v = value?.trim() ?? '';
                                        final parsed = double.tryParse(v);
                                        if (parsed == null || parsed <= 0) {
                                          return 'Invalid kg';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _locationController,
                                decoration: _inputDecoration(
                                  label: 'Operating Hub City',
                                  hint: 'e.g. Pune, Mumbai, Nashik',
                                  icon: Icons.location_city_rounded,
                                ),
                              ),
                            ],

                            const SizedBox(height: 22),
                            SizedBox(
                              height: 50,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _handleRegister,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        isDriver
                                            ? 'Register as Driver'
                                            : 'Register as Customer',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _primaryBlue),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
      ),
    );
  }
}
