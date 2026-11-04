import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/ride_service.dart';
import 'login_screen.dart';
import 'ride_history_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int? _driverId;
  String _driverName = 'Driver';
  String _driverPhone = '';
  String _currentLocation = 'Pune';
  String _vehicleType = 'MINI_TRUCK';
  double _capacityKg = 2500.0;
  double _price = 850.0;
  double _rating = 4.8;
  int _completedRides = 0;
  bool _isAvailable = true;

  bool _isLoading = true;
  bool _isCreatingDemoRide = false;
  bool _isTogglingAvailability = false;
  String _selectedFilter = 'ALL'; // 'ALL', 'ACTIVE', 'DELIVERED'
  List<Map<String, dynamic>> _rides = [];
  final Set<int> _updatingRideIds = {};

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
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final int? driverId = prefs.getInt('driverId');
      final String name = prefs.getString('name') ?? 'Driver';
      final String phone = prefs.getString('phone') ?? '';

      List<Map<String, dynamic>> fetchedRides = [];
      String currentLoc = _currentLocation;
      String vehicleType = _vehicleType;
      double capKg = _capacityKg;
      double price = _price;
      double rating = _rating;
      int completedRides = _completedRides;
      bool available = _isAvailable;

      if (driverId != null) {
        try {
          final profile = await AuthService.getDriverProfile(driverId: driverId);
          if (profile.isNotEmpty) {
            currentLoc =
                profile['currentLocation']?.toString() ?? currentLoc;
            vehicleType =
                profile['vehicleType']?.toString() ?? vehicleType;
            capKg = (profile['capacityKg'] is num)
                ? (profile['capacityKg'] as num).toDouble()
                : capKg;
            price = (profile['price'] is num)
                ? (profile['price'] as num).toDouble()
                : price;
            rating = (profile['rating'] is num)
                ? (profile['rating'] as num).toDouble()
                : rating;
            completedRides = (profile['completedRides'] is num)
                ? (profile['completedRides'] as num).toInt()
                : completedRides;
            available = profile['available'] == true;
          }
        } catch (_) {}

        try {
          final locData = await RideService.getDriverLocation(driverId);
          if (locData != null && locData['currentLocation'] != null) {
            currentLoc = locData['currentLocation'].toString();
          } else {
            final updatedLoc = await RideService.updateDriverLocation(
              driverId: driverId,
              currentLocation: 'Pune',
            );
            currentLoc =
                updatedLoc['currentLocation']?.toString() ?? 'Pune';
          }
        } catch (_) {}

        final Map<int, Map<String, dynamic>> mergedRides = {};
        try {
          final driverRides = await RideService.getDriverRides(driverId);
          for (final r in driverRides) {
            final rId = _parseRideId(r['id']);
            if (rId != null) mergedRides[rId] = r;
          }
        } catch (_) {}

        try {
          final allRides = await RideService.getAllRides();
          for (final r in allRides) {
            final rId = _parseRideId(r['id']);
            if (rId != null && !mergedRides.containsKey(rId)) {
              mergedRides[rId] = r;
            }
          }
        } catch (_) {}

        fetchedRides = mergedRides.values.toList()
          ..sort((a, b) =>
              (_parseRideId(b['id']) ?? 0).compareTo(_parseRideId(a['id']) ?? 0));
      }

      if (!mounted) return;
      setState(() {
        _driverId = driverId;
        _driverName = name.isEmpty ? 'Driver' : name;
        _driverPhone = phone;
        _currentLocation = currentLoc;
        _vehicleType = vehicleType;
        _capacityKg = capKg;
        _price = price;
        _rating = rating;
        _completedRides = completedRides;
        _isAvailable = available;
        _rides = fetchedRides;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleAvailability(bool newValue) async {
    if (_driverId == null || _isTogglingAvailability) return;
    setState(() => _isTogglingAvailability = true);
    try {
      final res = await AuthService.updateDriverAvailability(
        driverId: _driverId!,
        available: newValue,
      );
      if (!mounted) return;
      setState(() {
        _isAvailable = res['available'] == true;
      });
      _showSnack(
        res['message']?.toString() ??
            (_isAvailable ? 'You are now Online' : 'You are now Offline'),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isTogglingAvailability = false);
      }
    }
  }

  Future<void> _showDriverProfileSheet() async {
    if (_driverId == null) return;
    final nameCtrl = TextEditingController(text: _driverName);
    final priceCtrl = TextEditingController(text: _price.toStringAsFixed(0));
    final capCtrl = TextEditingController(text: _capacityKg.toStringAsFixed(0));
    final locCtrl = TextEditingController(text: _currentLocation);
    String selectedVehicle =
        RideService.allVehicleTypes.contains(_vehicleType)
            ? _vehicleType
            : 'MINI_TRUCK';
    bool isSaving = false;

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
                              Icons.manage_accounts_rounded,
                              color: _primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Driver & Fleet Profile',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _deepNavy,
                                  ),
                                ),
                                Text(
                                  'Rating: ★$_rating • Completed: $_completedRides rides',
                                  style: const TextStyle(
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
                      TextField(
                        controller: nameCtrl,
                        decoration:
                            _sheetInput('Driver Name', Icons.person_outline),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedVehicle,
                        decoration: _sheetInput(
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
                            setSheetState(() => selectedVehicle = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _sheetInput(
                                  'Base Fare (₹)', Icons.currency_rupee),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: capCtrl,
                              keyboardType: TextInputType.number,
                              decoration:
                                  _sheetInput('Capacity (kg)', Icons.scale),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: locCtrl,
                        decoration: _sheetInput(
                            'Current Hub City', Icons.my_location_rounded),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setSheetState(() => isSaving = true);
                                try {
                                  final coords = RideService.resolveCoordinates(
                                      locCtrl.text.trim());
                                  final updated =
                                      await AuthService.updateDriverProfile(
                                    driverId: _driverId!,
                                    profileData: {
                                      'name': nameCtrl.text.trim(),
                                      'vehicleType': selectedVehicle,
                                      'price': double.tryParse(
                                              priceCtrl.text.trim()) ??
                                          _price,
                                      'capacityKg': double.tryParse(
                                              capCtrl.text.trim()) ??
                                          _capacityKg,
                                      'currentLocation': locCtrl.text.trim(),
                                      'latitude': coords[0],
                                      'longitude': coords[1],
                                    },
                                  );
                                  if (!mounted) return;
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  setState(() {
                                    _driverName = updated['name']?.toString() ??
                                        nameCtrl.text.trim();
                                    _vehicleType =
                                        updated['vehicleType']?.toString() ??
                                            selectedVehicle;
                                    _price = (updated['price'] is num)
                                        ? (updated['price'] as num).toDouble()
                                        : _price;
                                    _capacityKg = (updated['capacityKg'] is num)
                                        ? (updated['capacityKg'] as num)
                                            .toDouble()
                                        : _capacityKg;
                                    _currentLocation =
                                        updated['currentLocation']
                                                ?.toString() ??
                                            locCtrl.text.trim();
                                  });
                                  _showSnack(
                                      'Driver profile & vehicle updated!');
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
                                  if (ctx.mounted) {
                                    setSheetState(() => isSaving = false);
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: Text(
                            isSaving ? 'Saving...' : 'Save Fleet Settings'),
                      ),
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

  Future<void> _broadcastRideLocation(int rideId) async {
    final locCtrl = TextEditingController(text: _currentLocation);
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Broadcast Live GPS • Ride #$rideId',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update your live location for customer ETA calculation:',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locCtrl,
              decoration:
                  _sheetInput('Current Checkpoint / City', Icons.gps_fixed),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: ['Pune', 'Lonavala', 'Mumbai', 'Nashik'].map((c) {
                return ActionChip(
                  label: Text(c, style: const TextStyle(fontSize: 12)),
                  onPressed: () => locCtrl.text = c,
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, locCtrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: _primaryBlue),
            child: const Text('Update Live ETA'),
          ),
        ],
      ),
    );

    if (confirmed == null || confirmed.isEmpty || !mounted) return;
    try {
      final tracking = await RideService.updateRideTrackingLocation(
        rideId: rideId,
        currentLocation: confirmed,
      );
      if (!mounted) return;
      setState(() => _currentLocation = confirmed);
      _showSnack(
        'Live GPS updated to $confirmed • ETA: ${tracking['estimatedArrivalMinutes'] ?? 20} mins',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _simulateIncomingRide() async {
    if (_driverId == null) return;
    setState(() => _isCreatingDemoRide = true);
    try {
      await RideService.updateDriverLocation(
        driverId: _driverId!,
        currentLocation: _currentLocation,
      );
      await AuthService.updateDriverAvailability(
        driverId: _driverId!,
        available: true,
      );

      final ride = await RideService.bookRide(
        userId: 1,
        driverId: _driverId!,
        pickupLocation: _currentLocation,
        dropLocation: _currentLocation.toLowerCase().contains('mumbai')
            ? 'Pune Logistics Park'
            : 'Mumbai JNPT Port',
        goodsType: 'Industrial & FMCG Pallets',
        goodsWeight: 350.0,
      );

      if (!mounted) return;
      _showSnack(
        'New Ride #${ride['id'] ?? ''} assigned to your vehicle!',
      );
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isCreatingDemoRide = false);
      }
    }
  }

  Future<void> _handleRideAction(Map<String, dynamic> ride) async {
    final rawId = ride['id'];
    final int? rideId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (rideId == null) return;

    final String status = ride['status']?.toString().toUpperCase() ?? 'BOOKED';

    setState(() => _updatingRideIds.add(rideId));

    try {
      if (status == 'BOOKED') {
        await RideService.acceptRide(rideId);
        _showSnack('Ride #$rideId accepted!');
      } else if (status == 'ACCEPTED') {
        await RideService.updateRideStatus(rideId, 'IN_TRANSIT');
        _showSnack('Ride #$rideId is now In Transit!');
      } else if (status == 'IN_TRANSIT') {
        await RideService.updateRideStatus(rideId, 'DELIVERED');
        _showSnack('Ride #$rideId marked as Delivered!');
      }
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      _showSnack(msg, isError: true);
    } finally {
      if (mounted) {
        setState(() => _updatingRideIds.remove(rideId));
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

  String? _actionLabelForStatus(String status) {
    switch (status.toUpperCase()) {
      case 'BOOKED':
        return 'Accept ride';
      case 'ACCEPTED':
        return 'Start delivery';
      case 'IN_TRANSIT':
        return 'Mark delivered';
      default:
        return null;
    }
  }

  IconData _actionIconForStatus(String status) {
    switch (status.toUpperCase()) {
      case 'BOOKED':
        return Icons.check_circle_outline_rounded;
      case 'ACCEPTED':
        return Icons.local_shipping_outlined;
      case 'IN_TRANSIT':
        return Icons.task_alt_rounded;
      default:
        return Icons.check;
    }
  }

  int _statusStep(String status) {
    switch (status.toUpperCase()) {
      case 'BOOKED':
        return 1;
      case 'ACCEPTED':
        return 2;
      case 'IN_TRANSIT':
        return 3;
      case 'DELIVERED':
        return 4;
      default:
        return 1;
    }
  }

  int? _parseRideId(dynamic val) {
    if (val is int) return val;
    if (val != null) return int.tryParse(val.toString());
    return null;
  }

  List<Map<String, dynamic>> get _filteredRides {
    if (_selectedFilter == 'ACTIVE') {
      return _rides
          .where((r) => r['status']?.toString().toUpperCase() != 'DELIVERED')
          .toList();
    } else if (_selectedFilter == 'DELIVERED') {
      return _rides
          .where((r) => r['status']?.toString().toUpperCase() == 'DELIVERED')
          .toList();
    }
    return _rides;
  }

  @override
  Widget build(BuildContext context) {
    final deliveredCount = _rides
        .where((r) => r['status']?.toString().toUpperCase() == 'DELIVERED')
        .length;
    final activeCount = _rides.length - deliveredCount;

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
              'Driver Console',
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
            tooltip: 'Driver & Fleet Settings',
            onPressed: _showDriverProfileSheet,
            icon: const Icon(Icons.tune_rounded, color: _deepNavy),
          ),
          IconButton(
            tooltip: 'Ride History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RideHistoryScreen(isDriver: true),
                ),
              ).then((_) => _loadDashboard());
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            )
          : RefreshIndicator(
              color: _primaryBlue,
              onRefresh: _loadDashboard,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Driver Hero Card with Online/Offline Availability Switch
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
                                    Icons.drive_eta_rounded,
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
                                      Text(
                                        '${_vehicleType.replaceAll('_', ' ')} • ${_capacityKg.toStringAsFixed(0)} KG • ₹${_price.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: _accentAmber,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Welcome, $_driverName!',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        'Driver #${_driverId ?? '-'} • ★$_rating • $_driverPhone',
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
                            const SizedBox(height: 14),

                            // Online / Offline Availability Bar + GPS Hub
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: _isAvailable
                                        ? _emerald
                                        : Colors.redAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _isAvailable
                                          ? 'ONLINE • Hub: $_currentLocation'
                                          : 'OFFLINE • Hub: $_currentLocation',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: _isAvailable,
                                    activeThumbColor: _emerald,
                                    onChanged: _isTogglingAvailability
                                        ? null
                                        : _toggleAvailability,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceAround,
                              children: [
                                _buildHeroStat(
                                  '${_rides.length}',
                                  'Total Rides',
                                ),
                                Container(
                                  width: 1,
                                  height: 26,
                                  color: Colors.white24,
                                ),
                                _buildHeroStat('$activeCount', 'Active'),
                                Container(
                                  width: 1,
                                  height: 26,
                                  color: Colors.white24,
                                ),
                                _buildHeroStat(
                                  '$deliveredCount',
                                  'Delivered',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Assigned Rides Header & Filter Chips
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Assigned Rides',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _deepNavy,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _showDriverProfileSheet,
                            icon: const Icon(Icons.edit_note_rounded, size: 18),
                            label: const Text(
                              'Edit Vehicle',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildFilterChip('ALL', 'All (${_rides.length})'),
                          _buildFilterChip(
                            'ACTIVE',
                            'Active ($activeCount)',
                          ),
                          _buildFilterChip(
                            'DELIVERED',
                            'Delivered ($deliveredCount)',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (_filteredRides.isEmpty)
                        Card(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: _borderColor),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 36,
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.inbox_outlined,
                                  size: 52,
                                  color: Colors.black38,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No rides found',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: _deepNavy,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Book a ride from a Customer account or tap below to receive a test booking right now.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _isCreatingDemoRide
                                      ? null
                                      : _simulateIncomingRide,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _primaryBlue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: _isCreatingDemoRide
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.add_task_rounded),
                                  label: Text(
                                    _isCreatingDemoRide
                                        ? 'Creating Booking...'
                                        : 'Receive Sample Ride Request',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._filteredRides.map((ride) {
                          final rideId = ride['id']?.toString() ?? '-';
                          final parsedId = _parseRideId(ride['id']);
                          final isUpdating =
                              parsedId != null && _updatingRideIds.contains(parsedId);

                          final status =
                              ride['status']?.toString().toUpperCase() ??
                              'BOOKED';
                          final pickup =
                              ride['pickupLocation']?.toString() ?? '-';
                          final drop =
                              ride['dropLocation']?.toString() ?? '-';
                          final goods =
                              ride['goodsType']?.toString() ?? 'General Cargo';
                          final amount = ride['amount'];
                          final amountStr =
                              amount != null ? '₹$amount' : '₹550';
                          final badgeColor = _statusColor(status);
                          final step = _statusStep(status);
                          final actionLabel = _actionLabelForStatus(status);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 14),
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: _borderColor),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.local_shipping_rounded,
                                          color: _primaryBlue,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Ride #$rideId',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: _deepNavy,
                                              ),
                                            ),
                                            Text(
                                              'Goods: $goods',
                                              style: const TextStyle(
                                                color: Colors.black54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
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
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Progress Stepper Bar
                                  Row(
                                    children: [
                                      _buildStepDot(1, step, 'Booked'),
                                      _buildStepLine(step >= 2),
                                      _buildStepDot(2, step, 'Accepted'),
                                      _buildStepLine(step >= 3),
                                      _buildStepDot(3, step, 'Transit'),
                                      _buildStepLine(step >= 4),
                                      _buildStepDot(4, step, 'Done'),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _borderColor),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.my_location_rounded,
                                              size: 16,
                                              color: _primaryBlue,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Pickup: $pickup',
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on_outlined,
                                              size: 16,
                                              color: Colors.redAccent,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Drop: $drop',
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Payout: $amountStr',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: _primaryBlue,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                      if (parsedId != null &&
                                          (status == 'ACCEPTED' ||
                                              status == 'IN_TRANSIT'))
                                        TextButton.icon(
                                          onPressed: () =>
                                              _broadcastRideLocation(parsedId),
                                          icon: const Icon(
                                            Icons.gps_fixed_rounded,
                                            size: 15,
                                          ),
                                          label: const Text(
                                            'Update Live GPS',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  // Single Action Button per Status
                                  if (actionLabel != null) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 46,
                                      child: FilledButton.icon(
                                        onPressed: isUpdating
                                            ? null
                                            : () => _handleRideAction(ride),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: _primaryBlue,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: isUpdating
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Icon(
                                                _actionIconForStatus(status),
                                                size: 19,
                                              ),
                                        label: Text(
                                          isUpdating
                                              ? 'Updating...'
                                              : actionLabel,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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

  Widget _buildHeroStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11.5),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedFilter = key),
      selectedColor: _primaryBlue,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : _deepNavy,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
      side: BorderSide(color: selected ? _primaryBlue : _borderColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildStepDot(int index, int currentStep, String label) {
    final active = currentStep >= index;
    return Column(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: active ? _primaryBlue : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            active ? Icons.check : Icons.circle,
            size: 13,
            color: active ? Colors.white : Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? _primaryBlue : Colors.black38,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool active) {
    return Expanded(
      child: Container(
        height: 2.5,
        margin: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
        color: active ? _primaryBlue : Colors.grey.shade300,
      ),
    );
  }

  InputDecoration _sheetInput(String label, IconData icon) {
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
