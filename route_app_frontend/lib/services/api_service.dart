import 'dart:io';
import 'package:dio/dio.dart';
import '../config/api.dart';
import '../models/user.dart';
import '../models/customer.dart';
import '../models/vehicle.dart';
import '../models/route.dart';
import '../models/trip.dart';

class ApiService {
  final _client = ApiClient();

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return response.data;
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    await _client.dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
  }

  // Live Location Tracking
  Future<void> pushLocation({
    required double lat,
    required double lng,
    double? accuracy,
    int? tripId,
  }) async {
    await _client.dio.post('/tracking/location', data: {
      'lat': lat,
      'lng': lng,
      if (accuracy != null) 'accuracy': accuracy,
      if (tripId != null) 'trip_id': tripId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getLiveLocations() async {
    final response = await _client.dio.get('/tracking/live');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  // Users
  Future<List<User>> getUsers({String? role}) async {
    final response = await _client.dio.get('/users/', queryParameters: {if (role != null) 'role': role});
    return (response.data as List).map((u) => User.fromJson(u)).toList();
  }

  Future<User> getMe() async {
    final response = await _client.dio.get('/users/me');
    return User.fromJson(response.data);
  }

  Future<User> updateMe(Map<String, dynamic> data) async {
    final response = await _client.dio.put('/users/me', data: data);
    return User.fromJson(response.data);
  }

  Future<User> updateUser(int id, Map<String, dynamic> data) async {
    final response = await _client.dio.put('/users/$id', data: data);
    return User.fromJson(response.data);
  }

  // Customers
  Future<List<Customer>> getCustomers({String? search, String? customerType}) async {
    final response = await _client.dio.get('/customers/', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (customerType != null) 'customer_type': customerType,
    });
    return (response.data as List).map((c) => Customer.fromJson(c)).toList();
  }

  Future<Customer> createCustomer(Map<String, dynamic> data) async {
    final response = await _client.dio.post('/customers/', data: data);
    return Customer.fromJson(response.data);
  }

  Future<Customer> updateCustomer(int id, Map<String, dynamic> data) async {
    final response = await _client.dio.put('/customers/$id', data: data);
    return Customer.fromJson(response.data);
  }

  // Vehicles
  Future<List<Vehicle>> getVehicles() async {
    final response = await _client.dio.get('/vehicles/');
    return (response.data as List).map((v) => Vehicle.fromJson(v)).toList();
  }

  Future<Vehicle> createVehicle(Map<String, dynamic> data) async {
    final response = await _client.dio.post('/vehicles/', data: data);
    return Vehicle.fromJson(response.data);
  }

  Future<Vehicle> updateVehicle(int id, Map<String, dynamic> data) async {
    final response = await _client.dio.put('/vehicles/$id', data: data);
    return Vehicle.fromJson(response.data);
  }

  // Routes
  Future<List<Route>> getRoutes({int? driverId}) async {
    final response = await _client.dio.get('/routes/', queryParameters: {
      if (driverId != null) 'driver_id': driverId,
    });
    return (response.data as List).map((r) => Route.fromJson(r)).toList();
  }

  Future<Route> getRoute(int id) async {
    final response = await _client.dio.get('/routes/$id');
    return Route.fromJson(response.data);
  }

  Future<Route> createRoute(Map<String, dynamic> data) async {
    final response = await _client.dio.post('/routes/', data: data);
    return Route.fromJson(response.data);
  }

  Future<Route> updateRoute(int id, Map<String, dynamic> data) async {
    final response = await _client.dio.put('/routes/$id', data: data);
    return Route.fromJson(response.data);
  }

  Future<Map<String, dynamic>> calculateInsertion(int routeId, int customerId) async {
    final response = await _client.dio.post('/routes/$routeId/calculate-insertion', data: {
      'customer_id': customerId,
    });
    return response.data;
  }

  Future<Route> addStop(int routeId, Map<String, dynamic> data) async {
    final response = await _client.dio.post('/routes/$routeId/stops', data: data);
    return Route.fromJson(response.data);
  }

  Future<Route> quickAddStop(int routeId, Map<String, dynamic> data) async {
    final response = await _client.dio.post('/routes/$routeId/stops/quick-add', data: data);
    return Route.fromJson(response.data);
  }


  Future<Route> reorderStops(int routeId, List<int> stopIds) async {
    final response = await _client.dio.put('/routes/$routeId/stops/reorder', data: {
      'stop_ids': stopIds,
    });
    return Route.fromJson(response.data);
  }

  Future<dynamic> getRouteChanges({String? status}) async {
    final endpoint = status == 'pending' ? '/routes/changes/pending' : '/routes/changes/';
    final response = await _client.dio.get(endpoint);
    return response.data;
  }

  Future<dynamic> approveChange(int changeId) async {
    final response = await _client.dio.put('/routes/changes/$changeId/approve');
    return response.data;
  }

  Future<dynamic> rejectChange(int changeId) async {
    final response = await _client.dio.put('/routes/changes/$changeId/reject');
    return response.data;
  }

  // Trips
  Future<List<Trip>> getTrips({String? date, String? status}) async {
    final response = await _client.dio.get('/trips/', queryParameters: {
      if (date != null) 'date': date,
      if (status != null) 'status': status,
    });
    return (response.data as List).map((t) => Trip.fromJson(t)).toList();
  }

  Future<Trip> startTrip(int routeId) async {
    final response = await _client.dio.post('/trips/', data: {'route_id': routeId});
    return Trip.fromJson(response.data);
  }

  Future<Trip> getTrip(int id) async {
    final response = await _client.dio.get('/trips/$id');
    return Trip.fromJson(response.data);
  }

  Future<TripStop> updateTripStop(int tripId, int stopId, Map<String, dynamic> data) async {
    final response = await _client.dio.put('/trips/$tripId/stops/$stopId', data: data);
    return TripStop.fromJson(response.data);
  }

  Future<void> completeTrip(int tripId) async {
    await _client.dio.put('/trips/$tripId/complete');
  }

  Future<void> cancelTrip(int tripId) async {
    await _client.dio.put('/trips/$tripId/cancel');
  }

  Future<String?> uploadStopPhoto(int tripId, int stopId, File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'pod_${tripId}_$stopId.jpg',
      ),
    });
    final response = await _client.dio.post(
      '/trips/$tripId/stops/$stopId/photo',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data['photo_url'] as String?;
  }

  // Analytics
  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _client.dio.get('/analytics/dashboard');
    return response.data;
  }

  Future<Map<String, dynamic>> getRouteAnalytics(int routeId) async {
    final response = await _client.dio.get('/analytics/routes/$routeId');
    return response.data;
  }
}
