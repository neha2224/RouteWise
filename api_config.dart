class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  // User Auth & Profile Endpoints
  static const String userSignup = '$baseUrl/user/signup';
  static const String userLogin = '$baseUrl/user/login';
  static const String userProfile = '$baseUrl/user/profile';
  static String userProfileById(int userId) => '$baseUrl/user/profile/$userId';

  // Driver Auth, Availability & Profile Endpoints
  static const String driverSignup = '$baseUrl/driver/signup';
  static const String driverLogin = '$baseUrl/driver/login';
  static const String driverAll = '$baseUrl/driver/all';
  static const String driverAvailability = '$baseUrl/driver/availability';
  static const String driverProfile = '$baseUrl/driver/profile';
  static String driverProfileById(int driverId) =>
      '$baseUrl/driver/profile/$driverId';

  // Driver Location Endpoints
  static String driverLocation(int driverId) =>
      '$baseUrl/api/drivers/$driverId/location';

  // Ride Endpoints
  static const String rideSearch = '$baseUrl/ride/search';
  static const String rideBook = '$baseUrl/ride/book';
  static const String rideAutoBook = '$baseUrl/ride/auto-book';
  static const String rideAll = '$baseUrl/ride/all';

  static String rideById(int rideId) => '$baseUrl/ride/$rideId';
  static String rideAccept(int rideId) => '$baseUrl/ride/accept/$rideId';
  static String rideByUser(int userId) => '$baseUrl/ride/user/$userId';
  static String rideByDriver(int driverId) => '$baseUrl/ride/driver/$driverId';
  static String rideUpdateStatus(int rideId, String status) =>
      '$baseUrl/ride/status/$rideId?status=${Uri.encodeQueryComponent(status)}';

  // Live Ride Tracking & ETA Endpoints
  static String rideTrackingLocation(int rideId) =>
      '$baseUrl/ride/$rideId/location';

  // Fare Estimation Endpoint
  static const String fareEstimate = '$baseUrl/fare/estimate';

  // Weather & Cargo Transport Risk Endpoints
  static String weatherCurrent(double latitude, double longitude) =>
      '$baseUrl/api/weather/current?latitude=$latitude&longitude=$longitude';
  static const String weatherTransportAnalysis =
      '$baseUrl/api/weather/transport-analysis';
}
