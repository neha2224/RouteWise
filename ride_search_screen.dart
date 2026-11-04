import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ride_service.dart';

class RideSearchScreen extends StatefulWidget {
  final String initialPickup;
  final String initialVehicleType;

  const RideSearchScreen({
    super.key,
    this.initialPickup = 'Pune',
    this.initialVehicleType = 'ALL',
  });

  @override
  State<RideSearchScreen> createState() => _RideSearchScreenState();
}

class _RideSearchScreenState extends State<RideSearchScreen> {
  late final TextEditingController _pickupController;
  final _dropController = TextEditingController(text: 'Mumbai');
  final _goodsController = TextEditingController(text: 'General Cargo');
  final _weightController = TextEditingController(text: '300');

  late String _selectedVehicleType;
  bool _isLoading = false;
  List<Map<String, dynamic>> _drivers = [];
  String? _aiRecommendation;

  static const List<String> _vehicleTypes = [
    'ALL',
    'TEMPO',
    'MINI_TRUCK',
    'PICKUP',
    'TRUCK',
  ];

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _deepNavy = Color(0xFF0F172A);
  static const Color _scaffoldBg = Color(0xFFF4F7FB);
  static const Color _borderColor = Color(0xFFDCE4F2);

  @override
  void initState() {
    super.initState();
    _pickupController = TextEditingController(
      text: widget.initialPickup.isEmpty ? 'Pune' : widget.initialPickup,
    );
    _selectedVehicleType = _vehicleTypes.contains(widget.initialVehicleType)
        ? widget.initialVehicleType
        : 'ALL';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSearch();
    });
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _goodsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final pickup = _pickupController.text.trim();
    if (pickup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a pickup location'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await RideService.searchDriversWithAI(
        pickupLocation: pickup,
        vehicleType: _selectedVehicleType,
        dropLocation: _dropController.text.trim(),
        goodsType: _goodsController.text.trim(),
        goodsWeight: double.tryParse(_weightController.text.trim()) ?? 300.0,
      );
      if (!mounted) return;
      setState(() {
        _drivers = (res['drivers'] as List<Map<String, dynamic>>?) ?? [];
        _aiRecommendation = res['aiRecommendation']?.toString();
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _bookWithDriver(Map<String, dynamic> driver) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId') ?? prefs.getInt('id');
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Session expired. Please login again.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final rawDriverId = driver['driverId'] ?? driver['id'];
    final int? driverId = rawDriverId is int
        ? rawDriverId
        : int.tryParse(rawDriverId?.toString() ?? '');

    if (driverId == null) return;

    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();
    final goods = _goodsController.text.trim();
    final weight = double.tryParse(_weightController.text.trim()) ?? 300.0;

    if (pickup.isEmpty || drop.isEmpty || goods.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Please fill Pickup, Drop, and Goods Type fields.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final ride = await RideService.bookRide(
        userId: userId,
        driverId: driverId,
        pickupLocation: pickup,
        dropLocation: drop,
        goodsType: goods,
        goodsWeight: weight,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ride #${ride['id'] ?? ''} booked successfully!'),
          backgroundColor: _primaryBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Search & Book Drivers',
          style: TextStyle(fontWeight: FontWeight.w800, color: _deepNavy),
        ),
      ),
      body: RefreshIndicator(
        color: _primaryBlue,
        onRefresh: _performSearch,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: _borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _pickupController,
                          decoration: _inputDecoration(
                            'Pickup Location',
                            Icons.my_location_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _dropController,
                          decoration: _inputDecoration(
                            'Drop Location',
                            Icons.location_on_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _goodsController,
                                decoration: _inputDecoration(
                                  'Goods Type',
                                  Icons.inventory_2_outlined,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _weightController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration(
                                  'Weight (kg)',
                                  Icons.scale_outlined,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedVehicleType,
                          decoration: _inputDecoration(
                            'Vehicle Type',
                            Icons.local_shipping_outlined,
                          ),
                          items: _vehicleTypes.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text(
                                t == 'ALL'
                                    ? 'All Vehicles'
                                    : t.replaceAll('_', ' '),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedVehicleType = val);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 46,
                          child: FilledButton.icon(
                            onPressed: _isLoading ? null : _performSearch,
                            style: FilledButton.styleFrom(
                              backgroundColor: _primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.search_rounded),
                            label: const Text(
                              'Search Available Drivers',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_aiRecommendation != null &&
                    _aiRecommendation!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _primaryBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome,
                                color: _primaryBlue, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'RouteWise AI Recommendation',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _deepNavy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _aiRecommendation!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _deepNavy,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: _primaryBlue),
                    ),
                  )
                else if (_drivers.isEmpty)
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: _borderColor),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 44,
                            color: Colors.black38,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No rides found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._drivers.map((driver) {
                    final name =
                        driver['driverName']?.toString() ??
                        driver['name']?.toString() ??
                        'Driver';
                    final vType = driver['vehicleType']?.toString() ??
                        _selectedVehicleType;
                    final price = driver['price'] ?? 550;
                    final cap = driver['capacityKg'] ?? 1500;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: _borderColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.local_shipping_rounded,
                                color: _primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _deepNavy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${vType.replaceAll('_', ' ')} • Max ${cap}kg',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Fare: ₹$price',
                                    style: const TextStyle(
                                      color: _primaryBlue,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: () => _bookWithDriver(driver),
                              style: FilledButton.styleFrom(
                                backgroundColor: _primaryBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Book'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _primaryBlue),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor),
      ),
    );
  }
}
