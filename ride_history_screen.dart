import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ride_service.dart';

class RideHistoryScreen extends StatefulWidget {
  final bool isDriver;

  const RideHistoryScreen({super.key, this.isDriver = false});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rides = [];

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _deepNavy = Color(0xFF0F172A);
  static const Color _emerald = Color(0xFF10B981);
  static const Color _scaffoldBg = Color(0xFFF4F7FB);
  static const Color _borderColor = Color(0xFFDCE4F2);

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> list = [];

      if (widget.isDriver) {
        final driverId = prefs.getInt('driverId');
        if (driverId != null) {
          list = await RideService.getDriverRides(driverId);
        }
      } else {
        final userId = prefs.getInt('userId') ?? prefs.getInt('id');
        if (userId != null) {
          list = await RideService.getUserRides(userId);
        }
      }

      if (!mounted) return;
      setState(() {
        _rides = list.reversed.toList();
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
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isDriver ? 'Driver Ride History' : 'Customer Ride History',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: _deepNavy,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            )
          : RefreshIndicator(
              color: _primaryBlue,
              onRefresh: _fetchHistory,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _rides.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            Card(
                              color: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: _borderColor),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 40,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.history_toggle_off_rounded,
                                      size: 48,
                                      color: Colors.black38,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'No rides found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _deepNavy,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _rides.length,
                          itemBuilder: (context, index) {
                            final ride = _rides[index];
                            final id = ride['id']?.toString() ?? '-';
                            final status =
                                ride['status']?.toString() ?? 'BOOKED';
                            final pickup =
                                ride['pickupLocation']?.toString() ?? '-';
                            final drop =
                                ride['dropLocation']?.toString() ?? '-';
                            final goods =
                                ride['goodsType']?.toString() ?? '-';
                            final amount = ride['amount'];
                            final badgeColor = _statusColor(status);

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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Ride #$id',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
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
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '$pickup  →  $drop',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Goods: $goods',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Fare: ₹${amount ?? 550}',
                                      style: const TextStyle(
                                        color: _primaryBlue,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
    );
  }
}
