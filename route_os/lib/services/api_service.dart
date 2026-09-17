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
  Future<Map<String, dynamic>> login(String email, String password) async =>
      (await _client.dio.post('/auth/login', data: {'email': email, 'password': password})).data;
  Future<void> register({required String email, required String password, String role = 'operator'}) async =>
      _client.dio.post('/auth/register', data: {'email': email, 'password': password, 'role': role});
  Future<User> getMe() async => User.fromJson((await _client.dio.get('/auth/me')).data);
  Future<User> updateMe(Map<String, dynamic> data) async => User.fromJson((await _client.dio.put('/users/me', data: data)).data);
  Future<List<User>> getUsers({String? role}) async => (await _client.dio.get('/users', queryParameters: {if (role != null) 'role': role})).data.map<User>((x) => User.fromJson(x)).toList();
  Future<User> updateUser(int id, Map<String, dynamic> data) => throw UnsupportedError('User updates are not exposed by the backend');

  Future<List<Customer>> getCustomers({String? search, String? customerType}) async =>
      (await _client.dio.get('/customers', queryParameters: {if (search?.isNotEmpty ?? false) 'search': search})).data.map<Customer>((x) => Customer.fromJson(x)).toList();
  Future<Customer> createCustomer(Map<String, dynamic> data) async => Customer.fromJson((await _client.dio.post('/customers', data: data)).data);
  Future<Customer> updateCustomer(int id, Map<String, dynamic> data) async => Customer.fromJson((await _client.dio.put('/customers/$id', data: data)).data);

  Future<List<Vehicle>> getVehicles() async => (await _client.dio.get('/vehicles')).data.map<Vehicle>((x) => Vehicle.fromJson(x)).toList();
  Future<Vehicle> createVehicle(Map<String, dynamic> data) async => Vehicle.fromJson((await _client.dio.post('/vehicles', data: data)).data);
  Future<Vehicle> updateVehicle(int id, Map<String, dynamic> data) => throw UnsupportedError('The backend does not expose vehicle updates');
  Future<void> pushLocation({required double lat, required double lng, int? vehicleId, double? accuracy, int? tripId}) async {
    if (vehicleId == null) return;
    await _client.dio.post('/vehicles/$vehicleId/location', data: {'latitude': lat, 'longitude': lng});
  }
  Future<List<Map<String, dynamic>>> getLiveLocations() async =>
      ((await _client.dio.get('/vehicles')).data as List).cast<Map<String, dynamic>>();

  Future<List<Route>> getRoutes({int? driverId}) async => (await _client.dio.get('/routes', queryParameters: {if (driverId != null) 'driver_id': driverId})).data.map<Route>((x) => Route.fromJson(x)).toList();
  Future<Route> getRoute(int id) async => Route.fromJson((await _client.dio.get('/routes/$id')).data);
  Future<Route> createRoute(Map<String, dynamic> data) async => Route.fromJson((await _client.dio.post('/routes', data: data)).data);
  Future<Route> updateRoute(int id, Map<String, dynamic> data) async => Route.fromJson((await _client.dio.put('/routes/$id', data: data)).data);
  Future<Route> addStop(int routeId, Map<String, dynamic> data) async => Route.fromJson((await _client.dio.post('/routes/$routeId/stops', data: data)).data);
  Future<Route> quickAddStop(int routeId, Map<String, dynamic> data) async => throw UnsupportedError('Create a customer first, then add its customer_id to the route');
  Future<Route> reorderStops(int routeId, List<int> ids) async => Route.fromJson((await _client.dio.put('/routes/$routeId/stops/reorder', data: {'stop_ids': ids})).data);
  Future<dynamic> getRouteChanges({String? status}) async => (await _client.dio.get('/route-changes', queryParameters: {if (status != null) 'status': status})).data;
  Future<dynamic> approveChange(int id) async => (await _client.dio.put('/route-changes/$id/approve')).data;
  Future<dynamic> rejectChange(int id) async => (await _client.dio.put('/route-changes/$id/reject')).data;

  Future<List<Trip>> getTrips({String? date, String? status}) async => (await _client.dio.get('/trips', queryParameters: {if (date != null) 'date': date, if (status != null) 'status': status})).data.map<Trip>((x) => Trip.fromJson(x)).toList();
  Future<Trip> startTrip(int routeId) async => Trip.fromJson((await _client.dio.post('/trips', data: {'route_id': routeId})).data);
  Future<Trip> getTrip(int id) async => Trip.fromJson((await _client.dio.get('/trips/$id')).data);
  Future<TripStop> updateTripStop(int tripId, int stopId, Map<String, dynamic> data) async => TripStop.fromJson((await _client.dio.put('/trips/$tripId/stops/$stopId', data: data)).data);
  Future<void> completeTrip(int id) async { await _client.dio.put('/trips/$id/complete'); }
  Future<void> cancelTrip(int id) async { await _client.dio.put('/trips/$id/cancel'); }
  Future<TripStop> uploadPod(int tripId, int stopId, {required String receiverName, String? notes, String? signatureData, File? imageFile, double? latitude, double? longitude}) async {
    final data = FormData.fromMap({'receiver_name': receiverName, if (notes != null) 'notes': notes, if (signatureData != null) 'signature_data': signatureData, if (latitude != null) 'latitude': latitude, if (longitude != null) 'longitude': longitude, if (imageFile != null) 'photo': await MultipartFile.fromFile(imageFile.path)});
    return TripStop.fromJson((await _client.dio.post('/trips/$tripId/stops/$stopId/pod', data: data, options: Options(contentType: 'multipart/form-data'))).data);
  }
  Future<Map<String, dynamic>> getDashboard() async => (await _client.dio.get('/analytics/dashboard')).data;
  Future<Map<String, dynamic>> getRouteAnalytics(int id) async => (await _client.dio.get('/analytics/routes/$id')).data;
}
