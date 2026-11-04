import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/ride_service.dart';
import 'login_screen.dart';
import 'ride_history_screen.dart';
import 'ride_search_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final _searchLocationController = TextEditingController(text: 'Pune');
  final _searchWeightController = TextEditingController(text: '300');
  String _selectedVehicleType = 'ALL';

  int? _userId;
  String _userName = 'Customer';
  String _userPhone = '';

  bool _isLoadingDashboard = true;
  bool _isSearching = false;
  bool _isAutoBooking = false;
  bool _hasSearched = false;
  List<Map<String, dynamic>> _searchResults = [];
  String? _aiRecommendation;
  List<Map<String, dynamic>> _recentRides = [];

  static const List<Map<String, dynamic>> _vehicleCards = [
    {
      'type': 'ALL',
      'title': 'All Fleet',
      'capacity': 'Up to 7000 kg',
      'icon': Icons.apps_rounded,
    },
    {
      'type': 'TEMPO',
      'title': 'Tempo',
      'capacity': 'Up to 1000 kg',
      'icon': Icons.electric_rickshaw_outlined,
    },
    {
      'type': 'PICKUP',
      'title': 'Pickup',
      'capacity': 'Up to 1500 kg',
      'icon': Icons.airport_shuttle_outlined,
    },
    {
      'type': 'MINI_TRUCK',
      'title': 'Mini Truck',
      'capacity': 'Up to 2500 kg',
      'icon': Icons.local_shipping_outlined,
    },
    {
      'type': 'TRUCK',
      'title': 'Heavy Truck',
      'capacity': 'Up to 7000 kg',
      'icon': Icons.fire_truck_outlined,
    },
  ];

  static const List<String> _quickCities = [
    'Pune',
    'Mumbai',
    'Nashik',
    'Nagpur',
  ];

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _deepNavy = Color(0xFF0F172A);
  static const Color _indigoMid = Color(0xFF1E3A8A);
  static const Color _accentAmber = Color(0xFFF59E0B);
  static const Color _emerald = Color(0xFF10B981);
  static const Color _scaffoldBg = Color(0xFFF4F7FB);
  static const Color _borderColor = Color(0xFFDCE4F2);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchLocationController.dispose();
    _searchWeightController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoadingDashboard = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId') ?? prefs.getInt('id');
      final name = prefs.getString('name') ?? 'Customer';
      final phone = prefs.getString('phone') ?? '';

      List<Map<String, dynamic>> rides = [];
      if (userId != null) {
        try {
          rides = await RideService.getUserRides(userId);
          rides = rides.reversed.toList();
        } catch (_) {}
      }

      List<Map<String, dynamic>> drivers = _searchResults;
      String? aiRec = _aiRecommendation;
      if (!_hasSearched) {
        try {
          final res = await RideService.searchDriversWithAI(
            pickupLocation: _searchLocationController.text.trim().isEmpty
                ? 'Pune'
                : _searchLocationController.text.trim(),
            vehicleType: _selectedVehicleType,
            goodsWeight:
                double.tryParse(_searchWeightController.text.trim()) ?? 300.0,
          );
          drivers = (res['drivers'] as List<Map<String, dynamic>>?) ?? [];
          aiRec = res['aiRecommendation']?.toString();
          _hasSearched = true;
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _userId = userId;
        _userName = name.isEmpty ? 'Customer' : name;
        _userPhone = phone;
        _recentRides = rides;
        _searchResults = drivers;
        _aiRecommendation = aiRec;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingDashboard = false);
      }
    }
  }

  Future<void> _searchDrivers() async {
    final pickup = _searchLocationController.text.trim();
    if (pickup.isEmpty) {
      _showSnack('Please enter a pickup location to search drivers',
          isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final weight =
          double.tryParse(_searchWeightController.text.trim()) ?? 300.0;
      final res = await RideService.searchDriversWithAI(
        pickupLocation: pickup,
        vehicleType: _selectedVehicleType,
        goodsWeight: weight,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = (res['drivers'] as List<Map<String, dynamic>>?) ?? [];
        _aiRecommendation = res['aiRecommendation']?.toString();
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _showAutoBookDialog() async {
    if (_userId == null) {
      _showSnack('Session expired. Please login again.', isError: true);
      return;
    }

    final pickupCtrl = TextEditingController(
      text: _searchLocationController.text.trim().isNotEmpty
          ? _searchLocationController.text.trim()
          : 'Pune',
    );
    final dropCtrl = TextEditingController(text: 'Mumbai');
    final goodsCtrl = TextEditingController(text: 'Agricultural Produce');
    final weightCtrl = TextEditingController(
      text: _searchWeightController.text.trim().isNotEmpty
          ? _searchWeightController.text.trim()
          : '300',
    );
    String selectedVehicle =
        _selectedVehicleType == 'ALL' ? 'MINI_TRUCK' : _selectedVehicleType;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Row(
                children: [
                  Icon(Icons.flash_on_rounded, color: _accentAmber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Instant Auto-Book Nearest Driver',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: pickupCtrl,
                        decoration:
                            _dialogInput('Pickup Location', Icons.my_location),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: dropCtrl,
                        decoration: _dialogInput(
                            'Drop Location', Icons.location_on_outlined),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: goodsCtrl,
                        decoration: _dialogInput(
                            'Goods Type', Icons.inventory_2_outlined),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: weightCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            _dialogInput('Cargo Weight (kg)', Icons.scale),
                        validator: (v) {
                          final val = double.tryParse(v?.trim() ?? '');
                          if (val == null || val <= 0) return 'Enter valid kg';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedVehicle,
                        decoration: _dialogInput(
                            'Vehicle Type', Icons.local_shipping_outlined),
                        items: RideService.allVehicleTypes
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.replaceAll('_', ' ')),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() => selectedVehicle = v);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: _primaryBlue),
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                  label: const Text('Auto-Book Now'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isAutoBooking = true);
    try {
      final ride = await RideService.autoBookRide(
        userId: _userId!,
        pickupLocation: pickupCtrl.text.trim(),
        dropLocation: dropCtrl.text.trim(),
        goodsType: goodsCtrl.text.trim(),
        vehicleType: selectedVehicle,
        goodsWeight: double.tryParse(weightCtrl.text.trim()) ?? 300.0,
      );
      if (!mounted) return;
      _showSnack(
        'Auto-Booked! Ride #${ride['id'] ?? ''} assigned to Driver #${ride['driverId'] ?? ''}',
      );
      await _loadDashboardData();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isAutoBooking = false);
      }
    }
  }

  Future<void> _showBookRideDialog(Map<String, dynamic> driver) async {
    if (_userId == null) {
      _showSnack('User session not found. Please log in again.', isError: true);
      return;
    }

    final rawDriverId = driver['driverId'] ?? driver['id'];
    final int? driverId = rawDriverId is int
        ? rawDriverId
        : int.tryParse(rawDriverId?.toString() ?? '');

    if (driverId == null) {
      _showSnack('Invalid driver selected.', isError: true);
      return;
    }

    final driverName =
        driver['driverName']?.toString() ?? driver['name']?.toString() ?? 'Driver';
    final vehicleType = driver['vehicleType']?.toString() ?? _selectedVehicleType;
    final price = driver['price'];
    final capacityKg = driver['capacityKg'] ?? 1500;

    final pickupController = TextEditingController(
      text: _searchLocationController.text.trim().isNotEmpty
          ? _searchLocationController.text.trim()
          : 'Pune',
    );
    final dropController = TextEditingController(text: 'Mumbai');
    final goodsController = TextEditingController(text: 'Electronics & Boxes');
    final weightController = TextEditingController(
      text: _searchWeightController.text.trim().isNotEmpty
          ? _searchWeightController.text.trim()
          : '300',
    );
    final formKey = GlobalKey<FormState>();
    bool isBooking = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: _primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Book $driverName',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${vehicleType.replaceAll('_', ' ')} • Max $capacityKg kg • ₹${price ?? 550}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: pickupController,
                        decoration:
                            _dialogInput('Pickup Location', Icons.my_location),
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? 'Enter pickup location'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: dropController,
                        decoration: _dialogInput(
                            'Drop Location', Icons.location_on_outlined),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter drop location';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: goodsController,
                        decoration: _dialogInput(
                            'Goods Type', Icons.inventory_2_outlined),
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? 'Enter goods type'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: weightController,
                        keyboardType: TextInputType.number,
                        decoration: _dialogInput(
                            'Cargo Weight (kg)', Icons.scale_outlined),
                        validator: (val) {
                          final w = double.tryParse(val?.trim() ?? '');
                          if (w == null || w <= 0) {
                            return 'Enter valid weight in kg';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isBooking ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isBooking
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isBooking = true);

                          try {
                            final ride = await RideService.bookRide(
                              userId: _userId!,
                              driverId: driverId,
                              pickupLocation: pickupController.text.trim(),
                              dropLocation: dropController.text.trim(),
                              goodsType: goodsController.text.trim(),
                              goodsWeight: double.tryParse(
                                      weightController.text.trim()) ??
                                  300.0,
                            );

                            if (!mounted) return;
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            _showSnack(
                              'Ride #${ride['id'] ?? ''} booked successfully with $driverName!',
                            );
                            await _loadDashboardData();
                          } catch (e) {
                            if (!mounted) return;
                            final msg =
                                e.toString().replaceFirst('Exception: ', '');
                            _showSnack(msg, isError: true);
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => isBooking = false);
                            }
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isBooking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirm Booking'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showFareEstimatorSheet() async {
    final pickupCtrl = TextEditingController(
      text: _searchLocationController.text.trim().isNotEmpty
          ? _searchLocationController.text.trim()
          : 'Pune',
    );
    final dropCtrl = TextEditingController(text: 'Mumbai');
    final waitCtrl = TextEditingController(text: '0');
    String vehicle =
        _selectedVehicleType == 'ALL' ? 'MINI_TRUCK' : _selectedVehicleType;
    bool loading = true;
    bool unloading = true;
    bool covered = false;
    bool refrigeration = false;
    bool isCalculating = false;
    Map<String, dynamic>? result;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calculate_rounded,
                              color: _primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI Fare & Distance Estimator',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _deepNavy,
                                  ),
                                ),
                                Text(
                                  'Instant breakdown via POST /fare/estimate',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: pickupCtrl,
                              decoration:
                                  _dialogInput('Pickup City', Icons.my_location),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: dropCtrl,
                              decoration: _dialogInput(
                                  'Drop City', Icons.location_on_outlined),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: vehicle,
                              decoration: _dialogInput(
                                  'Vehicle', Icons.local_shipping_outlined),
                              items: RideService.allVehicleTypes
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t.replaceAll('_', ' ')),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setSheetState(() => vehicle = v);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 125,
                            child: TextField(
                              controller: waitCtrl,
                              keyboardType: TextInputType.number,
                              decoration:
                                  _dialogInput('Wait (min)', Icons.timer),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          FilterChip(
                            label: const Text('Loading (+₹100)'),
                            selected: loading,
                            onSelected: (v) =>
                                setSheetState(() => loading = v),
                          ),
                          FilterChip(
                            label: const Text('Unloading (+₹100)'),
                            selected: unloading,
                            onSelected: (v) =>
                                setSheetState(() => unloading = v),
                          ),
                          FilterChip(
                            label: const Text('Covered (+₹150)'),
                            selected: covered,
                            onSelected: (v) => setSheetState(() {
                              covered = v;
                              if (!v) refrigeration = false;
                            }),
                          ),
                          FilterChip(
                            label: const Text('Refrigerated (+₹250)'),
                            selected: refrigeration,
                            onSelected: (v) => setSheetState(() {
                              refrigeration = v;
                              if (v) covered = true;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: isCalculating
                            ? null
                            : () async {
                                setSheetState(() => isCalculating = true);
                                try {
                                  final res = await RideService.estimateFare(
                                    pickupLocation: pickupCtrl.text.trim(),
                                    dropLocation: dropCtrl.text.trim(),
                                    vehicleType: vehicle,
                                    requiresLoading: loading,
                                    requiresUnloading: unloading,
                                    requiresCoveredVehicle: covered,
                                    requiresRefrigeration: refrigeration,
                                    waitingMinutes:
                                        int.tryParse(waitCtrl.text.trim()) ?? 0,
                                  );
                                  setSheetState(() => result = res);
                                } catch (e) {
                                  if (mounted) {
                                    _showSnack(
                                      e
                                          .toString()
                                          .replaceFirst('Exception: ', ''),
                                      isError: true,
                                    );
                                  }
                                } finally {
                                  setSheetState(() => isCalculating = false);
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: isCalculating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(
                          isCalculating
                              ? 'Calculating with RouteWise AI...'
                              : 'Calculate Fare Estimate',
                        ),
                      ),
                      if (result != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Distance: ${result!['estimatedDistanceKm'] ?? 0} km',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: _deepNavy,
                                    ),
                                  ),
                                  Text(
                                    'Total: ₹${result!['estimatedTotal'] ?? 0}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: _primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 18),
                              _fareRow('Base Fare', result!['baseFare']),
                              _fareRow(
                                  'Transport Charge', result!['transportCharge']),
                              _fareRow(
                                  'Loading / Unloading',
                                  ((result!['loadingCharge'] ?? 0) as num) +
                                      ((result!['unloadingCharge'] ?? 0)
                                          as num)),
                              _fareRow(
                                  'Covered / Reefers',
                                  ((result!['coveredVehicleCharge'] ?? 0)
                                          as num) +
                                      ((result!['refrigerationCharge'] ?? 0)
                                          as num)),
                              _fareRow(
                                  'Waiting Charge', result!['waitingCharge']),
                              if (result!['aiFareExplanation'] != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    result!['aiFareExplanation'].toString(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _deepNavy,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _fareRow(String label, dynamic val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
          Text(
            '₹${val ?? 0}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _deepNavy,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showWeatherSafetySheet() async {
    final pickupCtrl = TextEditingController(
      text: _searchLocationController.text.trim().isNotEmpty
          ? _searchLocationController.text.trim()
          : 'Pune',
    );
    final dropCtrl = TextEditingController(text: 'Mumbai');
    final goodsCtrl = TextEditingController(text: 'Fresh Vegetables & Fruits');
    final weightCtrl = TextEditingController(text: '500');
    bool covered = true;
    bool refrigeration = false;
    bool isAnalyzing = false;
    Map<String, dynamic>? analysis;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.thunderstorm_outlined,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Weather & Cargo Risk AI',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _deepNavy,
                                  ),
                                ),
                                Text(
                                  'Live pickup & destination weather safety check',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: pickupCtrl,
                              decoration:
                                  _dialogInput('Pickup City', Icons.my_location),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: dropCtrl,
                              decoration: _dialogInput(
                                  'Drop City', Icons.location_on_outlined),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: goodsCtrl,
                              decoration: _dialogInput(
                                  'Cargo Type', Icons.inventory_2_outlined),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 115,
                            child: TextField(
                              controller: weightCtrl,
                              keyboardType: TextInputType.number,
                              decoration:
                                  _dialogInput('Weight (kg)', Icons.scale),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Covered Vehicle'),
                            selected: covered,
                            onSelected: (v) =>
                                setSheetState(() => covered = v),
                          ),
                          FilterChip(
                            label: const Text('Refrigeration Available'),
                            selected: refrigeration,
                            onSelected: (v) =>
                                setSheetState(() => refrigeration = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: isAnalyzing
                            ? null
                            : () async {
                                setSheetState(() => isAnalyzing = true);
                                try {
                                  final res = await RideService
                                      .analyzeWeatherTransport(
                                    pickupLocation: pickupCtrl.text.trim(),
                                    dropLocation: dropCtrl.text.trim(),
                                    goodsType: goodsCtrl.text.trim(),
                                    goodsWeight: double.tryParse(
                                            weightCtrl.text.trim()) ??
                                        500.0,
                                    vehicleType: _selectedVehicleType == 'ALL'
                                        ? 'MINI_TRUCK'
                                        : _selectedVehicleType,
                                    coveredVehicle: covered,
                                    refrigerationAvailable: refrigeration,
                                  );
                                  setSheetState(() => analysis = res);
                                } catch (e) {
                                  if (mounted) {
                                    _showSnack(
                                      e
                                          .toString()
                                          .replaceFirst('Exception: ', ''),
                                      isError: true,
                                    );
                                  }
                                } finally {
                                  setSheetState(() => isAnalyzing = false);
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: isAnalyzing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_sync_outlined),
                        label: Text(
                          isAnalyzing
                              ? 'Analyzing Route Weather...'
                              : 'Run Weather & Cargo Risk Check',
                        ),
                      ),
                      if (analysis != null) ...[
                        const SizedBox(height: 16),
                        _buildWeatherResultCard(analysis!),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWeatherResultCard(Map<String, dynamic> data) {
    final riskLevel = data['riskLevel']?.toString().toUpperCase() ?? 'LOW';
    final pickupW = data['pickupWeather'] is Map
        ? Map<String, dynamic>.from(data['pickupWeather'] as Map)
        : <String, dynamic>{};
    final dropW = data['destinationWeather'] is Map
        ? Map<String, dynamic>.from(data['destinationWeather'] as Map)
        : <String, dynamic>{};
    final risks = (data['risks'] is List)
        ? (data['risks'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final recs = (data['recommendations'] is List)
        ? (data['recommendations'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final aiExp = data['aiExplanation']?.toString() ?? '';

    final riskColor = riskLevel == 'HIGH'
        ? Colors.red.shade700
        : (riskLevel == 'MODERATE' ? Colors.orange.shade800 : _emerald);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Route Risk Assessment',
                style: TextStyle(fontWeight: FontWeight.w800, color: _deepNavy),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$riskLevel RISK',
                  style: TextStyle(
                    color: riskColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniWeatherTile('Pickup', pickupW),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniWeatherTile('Destination', dropW),
              ),
            ],
          ),
          if (risks.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Detected Risks:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
            ...risks.map(
              (r) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('• $r', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
          if (recs.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Recommended Precautions:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
            ...recs.map(
              (r) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('• $r', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
          if (aiExp.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                aiExp,
                style: const TextStyle(
                  fontSize: 12,
                  color: _deepNavy,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniWeatherTile(String title, Map<String, dynamic> w) {
    final temp = w['temperatureCelsius'] ?? 28;
    final cond = w['condition'] ?? 'Clear';
    final hum = w['humidity'] ?? 55;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$temp°C • $cond',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: _deepNavy,
            ),
          ),
          Text(
            'Humidity: $hum%',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Future<void> _showLiveTrackingModal(Map<String, dynamic> ride) async {
    final rawId = ride['id'];
    final int? rideId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (rideId == null) return;

    Map<String, dynamic>? tracking;
    try {
      tracking = await RideService.getRideTracking(rideId);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final driverName = tracking?['driverName'] ?? 'Assigned Driver';
        final currentLoc = tracking?['currentLocation'] ?? 'In Transit Hub';
        final remDist = tracking?['remainingDistanceKm'] ?? 12.5;
        final etaMin = tracking?['estimatedArrivalMinutes'] ?? 22;
        final status = tracking?['status']?.toString() ??
            ride['status']?.toString() ??
            'BOOKED';
        final note = tracking?['etaNote']?.toString() ?? '';

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              const Icon(Icons.gps_fixed_rounded, color: _primaryBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Live Tracking • Ride #$rideId',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_deepNavy, _primaryBlue],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'REMAINING',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$remDist km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 30, color: Colors.white24),
                    Column(
                      children: [
                        const Text(
                          'EST. ARRIVAL',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$etaMin mins',
                          style: const TextStyle(
                            color: _accentAmber,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Driver: $driverName',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text('Current GPS Hub: $currentLoc'),
              const SizedBox(height: 4),
              Text('Status: $status'),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  note,
                  style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: _primaryBlue),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditProfileDialog() async {
    if (_userId == null) return;
    final nameCtrl = TextEditingController(text: _userName);
    final phoneCtrl = TextEditingController(text: _userPhone);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Customer Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: _dialogInput('Full Name', Icons.person_outline),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _dialogInput('Phone Number', Icons.phone_outlined),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _primaryBlue),
            child: const Text('Save Profile'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      try {
        final updated = await AuthService.updateUserProfile(
          userId: _userId!,
          name: nameCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
        );
        if (!mounted) return;
        setState(() {
          _userName = updated['name']?.toString() ?? nameCtrl.text.trim();
          _userPhone = updated['phone']?.toString() ?? phoneCtrl.text.trim();
        });
        _showSnack('Profile updated successfully!');
      } catch (e) {
        if (!mounted) return;
        _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : _primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'BOOKED':
        return Colors.orange.shade800;
      case 'ACCEPTED':
        return _primaryBlue;
      case 'IN_TRANSIT':
        return Colors.purple.shade700;
      case 'DELIVERED':
        return _emerald;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeRides = _recentRides
        .where((r) => r['status']?.toString().toUpperCase() != 'DELIVERED')
        .length;

    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: _primaryBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'RouteWise',
              style: TextStyle(
                color: _deepNavy,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Edit Profile',
            onPressed: _showEditProfileDialog,
            icon: const Icon(Icons.account_circle_outlined, color: _deepNavy),
          ),
          IconButton(
            tooltip: 'Ride History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RideHistoryScreen(isDriver: false),
                ),
              ).then((_) => _loadDashboardData());
            },
            icon: const Icon(Icons.history_rounded, color: _deepNavy),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          ),
        ],
      ),
      body: _isLoadingDashboard
          ? const Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            )
          : RefreshIndicator(
              color: _primaryBlue,
              onRefresh: _loadDashboardData,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Welcome Hero Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_deepNavy, _indigoMid, _primaryBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryBlue.withValues(alpha: 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.18),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'CUSTOMER COMMAND CENTER',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Hello, $_userName!',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        _userPhone.isNotEmpty
                                            ? 'ID #${_userId ?? '-'} • +91 $_userPhone'
                                            : 'Customer ID #${_userId ?? '-'}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildMiniStat(
                                    '${_recentRides.length}',
                                    'Total Bookings',
                                  ),
                                  Container(
                                    width: 1,
                                    height: 24,
                                    color: Colors.white24,
                                  ),
                                  _buildMiniStat('$activeRides', 'In Progress'),
                                  Container(
                                    width: 1,
                                    height: 24,
                                    color: Colors.white24,
                                  ),
                                  _buildMiniStat('AI + GPS', 'Smart Match'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Smart Tools Row: Fare Estimator & Weather Risk AI
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _showFareEstimatorSheet,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _borderColor),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.calculate_rounded,
                                      color: _primaryBlue,
                                      size: 22,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Fare Estimator',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: _deepNavy,
                                            ),
                                          ),
                                          Text(
                                            'AI cost breakdown',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: _showWeatherSafetySheet,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _borderColor),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.thunderstorm_outlined,
                                      color: Color(0xFF0284C7),
                                      size: 22,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Weather Risk AI',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: _deepNavy,
                                            ),
                                          ),
                                          Text(
                                            'Cargo safety check',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Fleet Selector
                      const Text(
                        'Select Fleet Type',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _deepNavy,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 86,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _vehicleCards.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final item = _vehicleCards[index];
                            final type = item['type'] as String;
                            final isSelected = _selectedVehicleType == type;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedVehicleType = type);
                                if (_searchLocationController.text
                                    .trim()
                                    .isNotEmpty) {
                                  _searchDrivers();
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 115,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _primaryBlue
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? _primaryBlue
                                        : _borderColor,
                                    width: 1.3,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Icon(
                                      item['icon'] as IconData,
                                      color: isSelected
                                          ? Colors.white
                                          : _primaryBlue,
                                      size: 22,
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title'] as String,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: isSelected
                                                ? Colors.white
                                                : _deepNavy,
                                          ),
                                        ),
                                        Text(
                                          item['capacity'] as String,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isSelected
                                                ? Colors.white70
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search Drivers Card
                      Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: _borderColor),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Find Available Drivers',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _deepNavy,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => RideSearchScreen(
                                            initialPickup:
                                                _searchLocationController.text
                                                    .trim(),
                                            initialVehicleType:
                                                _selectedVehicleType,
                                          ),
                                        ),
                                      ).then((_) => _loadDashboardData());
                                    },
                                    icon: const Icon(Icons.open_in_new,
                                        size: 16),
                                    label: const Text('Full Search'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: _searchLocationController,
                                      onSubmitted: (_) => _searchDrivers(),
                                      decoration: _dialogInput(
                                        'Pickup Location',
                                        Icons.my_location_rounded,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _searchWeightController,
                                      keyboardType: TextInputType.number,
                                      onSubmitted: (_) => _searchDrivers(),
                                      decoration: _dialogInput(
                                        'Weight (kg)',
                                        Icons.scale_outlined,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Quick City Chips
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: _quickCities.map((city) {
                                  return ActionChip(
                                    label: Text(
                                      city,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    avatar: const Icon(
                                      Icons.place_outlined,
                                      size: 15,
                                      color: _primaryBlue,
                                    ),
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    onPressed: () {
                                      _searchLocationController.text = city;
                                      _searchDrivers();
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 46,
                                      child: FilledButton.icon(
                                        onPressed:
                                            _isSearching ? null : _searchDrivers,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: _primaryBlue,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: _isSearching
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(Icons.search_rounded),
                                        label: Text(
                                          _isSearching
                                              ? 'Searching...'
                                              : 'Search Drivers',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 46,
                                    child: OutlinedButton.icon(
                                      onPressed: _isAutoBooking
                                          ? null
                                          : _showAutoBookDialog,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _deepNavy,
                                        side: const BorderSide(
                                            color: _primaryBlue),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.flash_on_rounded,
                                        color: _accentAmber,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Auto-Book',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // AI Recommendation Banner (from Backend AIRecommendationService)
                      if (_aiRecommendation != null &&
                          _aiRecommendation!.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _primaryBlue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: false,
                            leading: const Icon(
                              Icons.auto_awesome_rounded,
                              color: _primaryBlue,
                            ),
                            title: const Text(
                              'RouteWise AI Cargo & Fare Insights',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: _deepNavy,
                              ),
                            ),
                            subtitle: const Text(
                              'Tap to view AI driver, cargo & fare analysis',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.black54,
                              ),
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                                16, 0, 16, 14),
                            children: [
                              Text(
                                _aiRecommendation!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _deepNavy,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Search Results Section
                      if (_hasSearched) ...[
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Available Drivers (${_searchResults.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _deepNavy,
                              ),
                            ),
                            TextButton(
                              onPressed: _searchDrivers,
                              child: const Text('Refresh Fleet'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_isSearching)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: _primaryBlue,
                              ),
                            ),
                          )
                        else if (_searchResults.isEmpty)
                          Card(
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: _borderColor),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 40,
                                    color: Colors.black38,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No rides found',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._searchResults.map((driver) {
                            final dName =
                                driver['driverName']?.toString() ??
                                driver['name']?.toString() ??
                                'Driver';
                            final vType = driver['vehicleType']?.toString() ??
                                _selectedVehicleType;
                            final price = driver['price'] ?? 550;
                            final cap = driver['capacityKg'] ?? 1500;
                            final rating = driver['rating'] ?? 4.8;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              color: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: _borderColor),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15.5,
                                              color: _deepNavy,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${vType.replaceAll('_', ' ')} • Cap: ${cap}kg • ★$rating',
                                            style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Base Fare: ₹$price',
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
                                      onPressed: () =>
                                          _showBookRideDialog(driver),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _primaryBlue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: const Text('Book Ride'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],

                      const SizedBox(height: 20),

                      // Recent Ride History Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Your Recent Rides',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _deepNavy,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const RideHistoryScreen(isDriver: false),
                                ),
                              ).then((_) => _loadDashboardData());
                            },
                            child: const Text(
                              'View All',
                              style: TextStyle(
                                color: _primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      if (_recentRides.isEmpty)
                        Card(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: _borderColor),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(28),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 40,
                                  color: Colors.black38,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No rides found',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Select a driver above to book your first delivery.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._recentRides.take(4).map((ride) {
                          final status =
                              ride['status']?.toString() ?? 'BOOKED';
                          final pickup =
                              ride['pickupLocation']?.toString() ?? '-';
                          final drop = ride['dropLocation']?.toString() ?? '-';
                          final goods = ride['goodsType']?.toString() ?? '-';
                          final amount = ride['amount'];
                          final badgeColor = _statusColor(status);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: _borderColor),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Ride #${ride['id'] ?? '-'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: _deepNavy,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: badgeColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$pickup  →  $drop',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Goods: $goods • ₹${amount ?? 550}',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () =>
                                            _showLiveTrackingModal(ride),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        icon: const Icon(
                                          Icons.gps_fixed_rounded,
                                          size: 15,
                                          color: _primaryBlue,
                                        ),
                                        label: const Text(
                                          'Track Live ETA',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: _primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ],
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

  Widget _buildMiniStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  InputDecoration _dialogInput(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _primaryBlue, size: 19),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
