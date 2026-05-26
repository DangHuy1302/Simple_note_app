import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'services/calendar_sync_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/r2_storage_service.dart';
import 'services/weather_service.dart';
import 'screens/auth_screen.dart';

// TODO: Thay đổi Cloud Name và Upload Preset từ Cloudinary Console
const String cloudinaryCloudName = 'dq1kso9do';
const String cloudinaryUploadPreset = 'simple_note_unsigned';
const String openWeatherApiKey = String.fromEnvironment(
  'OPEN_WEATHER_API_KEY',
  defaultValue: '',
);
const String defaultWeatherCity = 'Ho Chi Minh City';
const String weatherCityPrefsKey = 'weather_city';

// --- Model ---
class Note {
  String? id;
  String title;
  String content;
  List<String> imagePaths;
  List<String> filePaths;
  String? signaturePath;
  DateTime? timestamp;
  String? userId;
  DateTime? deadline;
  int reminderMinutesBefore;
  bool isRecurringWeekly;
  DateTime? timeBlockStart;
  DateTime? timeBlockEnd;
  String? calendarEventId;
  bool isImportant;
  String? weatherCity;
  double? weatherTempC;
  String? weatherDescription;
  String? weatherIconCode;
  double? weatherLatitude;
  double? weatherLongitude;
  int? weatherAirQualityIndex;
  String? weatherAirQualityLabel;
  DateTime? weatherFetchedAt;
  List<Map<String, dynamic>> weatherHistory;

  Note({
    this.id,
    required this.title,
    required this.content,
    this.imagePaths = const [],
    this.filePaths = const [],
    this.signaturePath,
    this.timestamp,
    this.userId,
    this.deadline,
    this.reminderMinutesBefore = 0,
    this.isRecurringWeekly = false,
    this.timeBlockStart,
    this.timeBlockEnd,
    this.calendarEventId,
    this.isImportant = false,
    this.weatherCity,
    this.weatherTempC,
    this.weatherDescription,
    this.weatherIconCode,
    this.weatherLatitude,
    this.weatherLongitude,
    this.weatherAirQualityIndex,
    this.weatherAirQualityLabel,
    this.weatherFetchedAt,
    this.weatherHistory = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'imagePaths': imagePaths,
      'filePaths': filePaths,
      'signaturePath': signaturePath,
      'userId': userId,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'reminderMinutesBefore': reminderMinutesBefore,
      'isRecurringWeekly': isRecurringWeekly,
      'timeBlockStart': timeBlockStart != null
          ? Timestamp.fromDate(timeBlockStart!)
          : null,
      'timeBlockEnd': timeBlockEnd != null
          ? Timestamp.fromDate(timeBlockEnd!)
          : null,
      'calendarEventId': calendarEventId,
      'isImportant': isImportant,
      'weatherCity': weatherCity,
      'weatherTempC': weatherTempC,
      'weatherDescription': weatherDescription,
      'weatherIconCode': weatherIconCode,
      'weatherLatitude': weatherLatitude,
      'weatherLongitude': weatherLongitude,
      'weatherAirQualityIndex': weatherAirQualityIndex,
      'weatherAirQualityLabel': weatherAirQualityLabel,
      'weatherFetchedAt': weatherFetchedAt != null
          ? Timestamp.fromDate(weatherFetchedAt!)
          : null,
      'weatherHistory': weatherHistory,
      'timestamp': timestamp != null
          ? Timestamp.fromDate(timestamp!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map, {String? id}) {
    return Note(
      id: id,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      imagePaths: List<String>.from(map['imagePaths'] ?? []),
      filePaths: List<String>.from(map['filePaths'] ?? []),
      signaturePath: map['signaturePath'],
      userId: map['userId'],
      deadline: (map['deadline'] as Timestamp?)?.toDate(),
      reminderMinutesBefore: (map['reminderMinutesBefore'] ?? 0) as int,
      isRecurringWeekly: (map['isRecurringWeekly'] ?? false) as bool,
      timeBlockStart: (map['timeBlockStart'] as Timestamp?)?.toDate(),
      timeBlockEnd: (map['timeBlockEnd'] as Timestamp?)?.toDate(),
      calendarEventId: map['calendarEventId'] as String?,
      isImportant: (map['isImportant'] ?? false) as bool,
      weatherCity: map['weatherCity'] as String?,
      weatherTempC: (map['weatherTempC'] as num?)?.toDouble(),
      weatherDescription: map['weatherDescription'] as String?,
      weatherIconCode: map['weatherIconCode'] as String?,
      weatherLatitude: (map['weatherLatitude'] as num?)?.toDouble(),
      weatherLongitude: (map['weatherLongitude'] as num?)?.toDouble(),
      weatherAirQualityIndex: (map['weatherAirQualityIndex'] as num?)?.toInt(),
      weatherAirQualityLabel: map['weatherAirQualityLabel'] as String?,
      weatherFetchedAt: (map['weatherFetchedAt'] as Timestamp?)?.toDate(),
      weatherHistory: (map['weatherHistory'] as List<dynamic>? ?? const [])
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await NotificationService.initialize();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
    debugPrint("Lỗi khởi tạo Firebase: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Note App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: ColorScheme.fromSeed(
            seedColor: Colors.teal,
          ).inversePrimary,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Đang kiểm tra trạng thái auth
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Đã đăng nhập -> HomeScreen, chưa đăng nhập -> AuthScreen
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}

// --- HomeScreen ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final LocationService _locationService = const LocationService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _weatherCity = defaultWeatherCity;
  WeatherSnapshot? _currentWeather;
  bool _isRefreshingCurrentWeather = false;

  Future<void> _loadWeatherCity() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCity = prefs.getString(weatherCityPrefsKey)?.trim();
    if (!mounted) return;

    setState(() {
      _weatherCity = (savedCity == null || savedCity.isEmpty)
          ? defaultWeatherCity
          : savedCity;
    });
  }

  Future<void> _openWeatherSettings() async {
    final updatedCity = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => WeatherSettingsScreen(initialCity: _weatherCity),
      ),
    );

    if (!mounted || updatedCity == null) return;
    setState(() => _weatherCity = updatedCity);
    unawaited(_refreshCurrentLocationWeather(showFeedback: false));
  }

  WeatherService get _weatherService =>
      WeatherService(apiKey: openWeatherApiKey, city: _weatherCity);

  Future<void> _refreshCurrentLocationWeather({
    bool showFeedback = true,
  }) async {
    if (_isRefreshingCurrentWeather) return;

    if (!_weatherService.isConfigured) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chua cau hinh OpenWeather API key.')),
        );
      }
      return;
    }

    setState(() => _isRefreshingCurrentWeather = true);
    try {
      final location = await _locationService.getCurrentLocation();
      final weather = location != null
          ? await _weatherService.fetchCurrentWeatherByCoordinates(
              latitude: location.latitude,
              longitude: location.longitude,
            )
          : await _weatherService.fetchCurrentWeather();

      if (!mounted) return;

      if (weather == null) {
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Khong lay duoc thoi tiet hien tai. Kiem tra GPS/quyen vi tri.',
              ),
            ),
          );
        }
        return;
      }

      setState(() => _currentWeather = weather);
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Da cap nhat thoi tiet va vi tri hien tai.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted || !showFeedback) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cap nhat thoi tiet that bai: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshingCurrentWeather = false);
      }
    }
  }

  Widget _buildCurrentLocationWeatherCard() {
    if (!_weatherService.isConfigured) {
      return Card(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Chua cau hinh OpenWeather API key de hien thi vi tri + thoi tiet hien tai.',
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.my_location, color: Colors.teal),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Vi tri hien tai va thoi tiet',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: _isRefreshingCurrentWeather
                      ? null
                      : () => _refreshCurrentLocationWeather(),
                  icon: _isRefreshingCurrentWeather
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: 'Cap nhat lai vi tri/thoi tiet',
                ),
              ],
            ),
            if (_currentWeather == null)
              const Text(
                'Nhan nut lam moi de lay vi tri, nhiet do va ban do hien tai.',
                style: TextStyle(color: Colors.black54),
              )
            else ...[
              Row(
                children: [
                  Image.network(
                    'https://openweathermap.org/img/wn/${_currentWeather!.iconCode}@2x.png',
                    width: 30,
                    height: 30,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.cloud_outlined, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_currentWeather!.city} • ${_currentWeather!.temperatureC.toStringAsFixed(1)}°C • ${_currentWeather!.description}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  _currentWeather!.locationImageUrl,
                  width: double.infinity,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 140,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Text(
                        'Khong tai duoc anh ban do. Ban van mo duoc Google Maps.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Toa do: ${_currentWeather!.latitude.toStringAsFixed(5)}, ${_currentWeather!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openMapAt(
                      _currentWeather!.latitude,
                      _currentWeather!.longitude,
                    ),
                    icon: const Icon(Icons.map_outlined, size: 16),
                    label: const Text('Google Maps'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isRemoteUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Widget _buildLeadingPreview(Note note) {
    if (note.imagePaths.isNotEmpty) {
      final imagePath = note.imagePaths.first;
      return _isRemoteUrl(imagePath)
          ? Image.network(
              imagePath,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image_outlined, color: Colors.grey),
            )
          : Image.file(
              File(imagePath),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            );
    }

    if (note.signaturePath != null && note.signaturePath!.isNotEmpty) {
      final signaturePath = note.signaturePath!;
      return _isRemoteUrl(signaturePath)
          ? Image.network(
              signaturePath,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image_outlined, color: Colors.grey),
            )
          : Image.file(
              File(signaturePath),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            );
    }

    return const Icon(Icons.note);
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.teal),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.teal)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _extractFileName(String pathOrUrl) {
    if (_isRemoteUrl(pathOrUrl)) {
      final uri = Uri.tryParse(pathOrUrl);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        return Uri.decodeComponent(uri.pathSegments.last);
      }
      return 'file';
    }
    return pathOrUrl.split('/').last;
  }

  Future<void> _openMapAt(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildSignaturePreview(String signaturePath) {
    final image = _isRemoteUrl(signaturePath)
        ? Image.network(
            signaturePath,
            width: 120,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 120,
              height: 60,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                color: Colors.grey,
              ),
            ),
          )
        : Image.file(
            File(signaturePath),
            width: 120,
            height: 60,
            fit: BoxFit.cover,
          );

    return ClipRRect(borderRadius: BorderRadius.circular(8), child: image);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    unawaited(_loadWeatherCity());
    unawaited(_refreshCurrentLocationWeather(showFeedback: false));
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xoá'),
        content: const Text('Bạn có chắc muốn xoá ghi chú này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (note.id == null) return;

    try {
      await _firestore.collection('notes').doc(note.id!).delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể xoá ghi chú: $e')));
      return;
    }

    unawaited(() async {
      try {
        await NotificationService.cancelReminder(note.id!);
      } catch (e) {
        debugPrint('Huỷ nhắc nhở thất bại: $e');
      }

      try {
        await CalendarSyncService.deleteEventIfExists(
          note.calendarEventId,
          noteId: note.id,
        );
      } catch (e) {
        debugPrint('Xoá event Calendar thất bại: $e');
      }
    }());

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xoá ghi chú.')));
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.signOut();
            },
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openCalendarView(List<Note> notes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            NoteCalendarScreen(notes: notes, weatherCity: _weatherCity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email ?? 'Guest';
    final photoUrl = user?.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Tìm kiếm ghi chú...',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          // Avatar user
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: photoUrl != null
                  ? CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(photoUrl),
                    )
                  : CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.teal,
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Test thông báo',
            onPressed: () async {
              await NotificationService.showTestNotification();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã gửi test notification.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Cap nhat vi tri/thoi tiet hien tai',
            onPressed: _isRefreshingCurrentWeather
                ? null
                : () => _refreshCurrentLocationWeather(),
          ),
          // Nút đăng xuất
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Cài đặt thời tiết',
            onPressed: _openWeatherSettings,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _logout,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Chỉ lấy ghi chú của user đang đăng nhập theo userId
        stream: _firestore
            .collection('notes')
            .where('userId', isEqualTo: user?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Lỗi: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notes = snapshot.data!.docs
              .map(
                (doc) => Note.fromMap(
                  doc.data() as Map<String, dynamic>,
                  id: doc.id,
                ),
              )
              .where(
                (n) =>
                    n.title.toLowerCase().contains(_searchQuery) ||
                    n.content.toLowerCase().contains(_searchQuery),
              )
              .toList();

          if (notes.isEmpty) {
            return ListView(
              children: [
                _buildCurrentLocationWeatherCard(),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.note_add, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Xin chào, $displayName!',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Bạn chưa có ghi chú nào.\nNhấn + để tạo mới!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: notes.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  children: [
                    _buildCurrentLocationWeatherCard(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _openCalendarView(notes),
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('Xem lich ghi chu'),
                      ),
                    ),
                  ],
                );
              }

              final note = notes[index - 1];
              return Card(
                child: ListTile(
                  isThreeLine: true,
                  leading: _buildLeadingPreview(note),
                  title: Text(
                    note.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        note.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (note.imagePaths.isNotEmpty)
                            _buildMetaChip(
                              Icons.image_outlined,
                              '${note.imagePaths.length} ảnh',
                            ),
                          if (note.filePaths.isNotEmpty)
                            _buildMetaChip(
                              Icons.attach_file,
                              '${note.filePaths.length} file',
                            ),
                          if (note.signaturePath != null &&
                              note.signaturePath!.isNotEmpty)
                            _buildMetaChip(Icons.draw_outlined, 'Có chữ ký'),
                          if (note.deadline != null)
                            _buildMetaChip(
                              Icons.alarm,
                              'Hạn: ${_formatDateTime(note.deadline!)}',
                            ),
                          if (note.isRecurringWeekly)
                            _buildMetaChip(Icons.repeat, 'Lặp hàng tuần'),
                          if (note.timeBlockStart != null &&
                              note.timeBlockEnd != null)
                            _buildMetaChip(
                              Icons.schedule,
                              'Block: ${_formatDateTime(note.timeBlockStart!)} - ${note.timeBlockEnd!.hour.toString().padLeft(2, '0')}:${note.timeBlockEnd!.minute.toString().padLeft(2, '0')}',
                            ),
                          if (note.calendarEventId != null &&
                              note.calendarEventId!.isNotEmpty)
                            _buildMetaChip(
                              Icons.event_available,
                              'Đã sync Calendar',
                            ),
                          if (note.weatherTempC != null)
                            _buildMetaChip(
                              Icons.cloud_outlined,
                              '${note.weatherTempC!.toStringAsFixed(1)}°C',
                            ),
                          if (note.weatherAirQualityLabel != null &&
                              note.weatherAirQualityLabel!.isNotEmpty)
                            _buildMetaChip(
                              Icons.air,
                              note.weatherAirQualityIndex != null
                                  ? 'AQI ${note.weatherAirQualityIndex}: ${note.weatherAirQualityLabel}'
                                  : 'AQI: ${note.weatherAirQualityLabel}',
                            ),
                          if (note.weatherHistory.isNotEmpty)
                            _buildMetaChip(
                              Icons.history,
                              'LS thời tiết: ${note.weatherHistory.length}',
                            ),
                          if (note.isImportant)
                            _buildMetaChip(Icons.star, 'Quan trọng'),
                        ],
                      ),
                      if (note.weatherDescription != null &&
                          note.weatherDescription!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (note.weatherIconCode != null &&
                                note.weatherIconCode!.isNotEmpty)
                              Image.network(
                                'https://openweathermap.org/img/wn/${note.weatherIconCode}@2x.png',
                                width: 20,
                                height: 20,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.cloud_outlined,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                              ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${note.weatherDescription}${note.weatherCity != null ? ' • ${note.weatherCity}' : ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (note.weatherLatitude != null &&
                            note.weatherLongitude != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _openMapAt(
                                note.weatherLatitude!,
                                note.weatherLongitude!,
                              ),
                              icon: const Icon(Icons.map_outlined, size: 16),
                              label: const Text('Xem vi tri tren Google Maps'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 2,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                      ],
                      if (note.signaturePath != null &&
                          note.signaturePath!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildSignaturePreview(note.signaturePath!),
                      ],
                      if (note.filePaths.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.insert_drive_file_outlined,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _extractFileName(note.filePaths.first),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteEditorScreen(
                        note: note,
                        weatherCity: _weatherCity,
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteNote(note),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NoteEditorScreen(
              weatherCity: _weatherCity,
              initialWeatherSnapshot: _currentWeather,
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class NoteCalendarScreen extends StatefulWidget {
  final List<Note> notes;
  final String weatherCity;

  const NoteCalendarScreen({
    required this.notes,
    required this.weatherCity,
    super.key,
  });

  @override
  State<NoteCalendarScreen> createState() => _NoteCalendarScreenState();
}

class _NoteCalendarScreenState extends State<NoteCalendarScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  DateTime? _noteCalendarTime(Note note) {
    return note.timeBlockStart ?? note.deadline ?? note.timestamp;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final scheduledNotes = widget.notes.where((note) {
      final eventTime = _noteCalendarTime(note);
      final hasSchedule = eventTime != null;
      final hasCalendarSync =
          note.calendarEventId != null && note.calendarEventId!.isNotEmpty;
      return hasSchedule || hasCalendarSync;
    }).toList();

    final notesInSelectedDay =
        scheduledNotes.where((note) {
          final eventTime = _noteCalendarTime(note);
          if (eventTime == null) return false;
          return _isSameDate(eventTime, _selectedDate);
        }).toList()..sort((a, b) {
          final at = _noteCalendarTime(a) ?? DateTime(2000);
          final bt = _noteCalendarTime(b) ?? DateTime(2000);
          return at.compareTo(bt);
        });

    return Scaffold(
      appBar: AppBar(title: const Text('Lich ghi chu dong bo')),
      body: Column(
        children: [
          CalendarDatePicker(
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            onDateChanged: (date) => setState(() => _selectedDate = date),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Ngay ${_formatDate(_selectedDate)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text('${notesInSelectedDay.length} ghi chu'),
              ],
            ),
          ),
          Expanded(
            child: notesInSelectedDay.isEmpty
                ? const Center(
                    child: Text(
                      'Khong co ghi chu lich o ngay nay.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : ListView.builder(
                    itemCount: notesInSelectedDay.length,
                    itemBuilder: (context, index) {
                      final note = notesInSelectedDay[index];
                      final eventTime = _noteCalendarTime(note);
                      return ListTile(
                        leading: const Icon(Icons.event_note),
                        title: Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${eventTime != null ? _formatDate(eventTime) : 'Khong co thoi gian'}${note.calendarEventId != null && note.calendarEventId!.isNotEmpty ? ' • Da sync Calendar' : ''}',
                        ),
                        trailing: note.weatherTempC != null
                            ? Text('${note.weatherTempC!.toStringAsFixed(1)}°C')
                            : null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NoteEditorScreen(
                              note: note,
                              weatherCity: widget.weatherCity,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// --- NoteEditorScreen ---
class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final String weatherCity;
  final WeatherSnapshot? initialWeatherSnapshot;

  const NoteEditorScreen({
    this.note,
    this.weatherCity = defaultWeatherCity,
    this.initialWeatherSnapshot,
    super.key,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _storageService = CloudinaryStorageService(
    cloudName: cloudinaryCloudName,
    uploadPreset: cloudinaryUploadPreset,
  );
  final _locationService = const LocationService();
  WeatherService get _weatherService =>
      WeatherService(apiKey: openWeatherApiKey, city: widget.weatherCity);
  List<String> _imagePaths = [];
  List<String> _filePaths = [];
  String? _signaturePath;
  DateTime? _deadline;
  int _reminderMinutesBefore = 0;
  bool _isRecurringWeekly = false;
  bool _isImportant = false;
  DateTime? _timeBlockStart;
  DateTime? _timeBlockEnd;
  String? _weatherCity;
  double? _weatherTempC;
  String? _weatherDescription;
  String? _weatherIconCode;
  double? _weatherLatitude;
  double? _weatherLongitude;
  int? _weatherAirQualityIndex;
  String? _weatherAirQualityLabel;
  DateTime? _weatherFetchedAt;
  List<Map<String, dynamic>> _weatherHistory = [];
  bool _isSaving = false;
  bool _isRefreshingWeather = false;
  final List<int> _reminderOptions = const [0, 10, 30, 60, 1440];

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _imagePaths = List.from(widget.note!.imagePaths);
      _filePaths = List.from(widget.note!.filePaths);
      _signaturePath = widget.note!.signaturePath;
      _deadline = widget.note!.deadline;
      _reminderMinutesBefore = widget.note!.reminderMinutesBefore;
      _isRecurringWeekly = widget.note!.isRecurringWeekly;
      _isImportant = widget.note!.isImportant;
      _timeBlockStart = widget.note!.timeBlockStart;
      _timeBlockEnd = widget.note!.timeBlockEnd;
      _weatherCity = widget.note!.weatherCity;
      _weatherTempC = widget.note!.weatherTempC;
      _weatherDescription = widget.note!.weatherDescription;
      _weatherIconCode = widget.note!.weatherIconCode;
      _weatherLatitude = widget.note!.weatherLatitude;
      _weatherLongitude = widget.note!.weatherLongitude;
      _weatherAirQualityIndex = widget.note!.weatherAirQualityIndex;
      _weatherAirQualityLabel = widget.note!.weatherAirQualityLabel;
      _weatherFetchedAt = widget.note!.weatherFetchedAt;
      _weatherHistory = List<Map<String, dynamic>>.from(
        widget.note!.weatherHistory,
      );
    } else if (widget.initialWeatherSnapshot != null) {
      final weather = widget.initialWeatherSnapshot!;
      _weatherCity = weather.city;
      _weatherTempC = weather.temperatureC;
      _weatherDescription = weather.description;
      _weatherIconCode = weather.iconCode;
      _weatherLatitude = weather.latitude;
      _weatherLongitude = weather.longitude;
      _weatherAirQualityIndex = weather.airQualityIndex;
      _weatherAirQualityLabel = weather.airQualityLabel;
      _weatherFetchedAt = weather.fetchedAt;
      _imagePaths = _attachLocationImageIfNeeded(
        imagePaths: _imagePaths,
        weather: weather,
      );
    }
  }

  Future<void> _openMapAt(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _buildContentWithWeatherLine(
    String content,
    WeatherSnapshot? weather,
  ) {
    const prefix = '[Weather]';
    final lines = content
        .split('\n')
        .where((line) => !line.trimLeft().startsWith(prefix))
        .toList();

    if (weather == null) {
      return lines.join('\n').trim();
    }

    final weatherLine =
        '$prefix ${weather.temperatureC.toStringAsFixed(1)}°C, ${weather.description} (${weather.city}) - ${_formatDateTime(weather.fetchedAt)}';

    if (lines.isEmpty) {
      return weatherLine;
    }

    return '${lines.join('\n').trim()}\n\n$weatherLine';
  }

  Future<WeatherSnapshot?> _fetchCurrentWeatherSnapshot() async {
    if (!_weatherService.isConfigured) {
      return null;
    }

    final location = await _locationService.getCurrentLocation();
    if (location != null) {
      return _weatherService.fetchCurrentWeatherByCoordinates(
        latitude: location.latitude,
        longitude: location.longitude,
      );
    }

    return _weatherService.fetchCurrentWeather();
  }

  Future<void> _refreshWeatherNow() async {
    if (_isRefreshingWeather || _isSaving) return;

    if (!_weatherService.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa cấu hình OpenWeather API key.')),
      );
      return;
    }

    setState(() => _isRefreshingWeather = true);

    try {
      final weather = await _fetchCurrentWeatherSnapshot();
      if (!mounted) return;

      if (weather == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Khong lay duoc vi tri/thoi tiet hien tai. Hay bat GPS va cap quyen vi tri.',
            ),
          ),
        );
        return;
      }

      setState(() {
        _weatherCity = weather.city;
        _weatherTempC = weather.temperatureC;
        _weatherDescription = weather.description;
        _weatherIconCode = weather.iconCode;
        _weatherLatitude = weather.latitude;
        _weatherLongitude = weather.longitude;
        _weatherAirQualityIndex = weather.airQualityIndex;
        _weatherAirQualityLabel = weather.airQualityLabel;
        _weatherFetchedAt = weather.fetchedAt;
        _imagePaths = _attachLocationImageIfNeeded(
          imagePaths: _imagePaths,
          weather: weather,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Da cap nhat thoi tiet hien tai.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cap nhat thoi tiet that bai: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshingWeather = false);
      }
    }
  }

  List<String> _attachLocationImageIfNeeded({
    required List<String> imagePaths,
    required WeatherSnapshot? weather,
  }) {
    if (weather == null) {
      return imagePaths;
    }

    final locationImageUrl = weather.locationImageUrl.trim();
    if (locationImageUrl.isEmpty) {
      return imagePaths;
    }

    if (imagePaths.contains(locationImageUrl)) {
      return imagePaths;
    }

    return [...imagePaths, locationImageUrl];
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _reminderLabel(int minutes) {
    if (minutes == 0) return 'Không nhắc';
    if (minutes < 60) return 'Nhắc trước $minutes phút';
    if (minutes == 1440) return 'Nhắc trước 1 ngày';
    final hours = minutes ~/ 60;
    return 'Nhắc trước $hours giờ';
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initialDate = _deadline ?? now;

    final date = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
      initialDate: initialDate,
    );
    if (date == null || !mounted) return;

    final initialTime = TimeOfDay.fromDateTime(initialDate);
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (time == null || !mounted) return;

    setState(() {
      _deadline = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickTimeBlockStart() async {
    final now = DateTime.now();
    final initial = _timeBlockStart ?? now;

    final date = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
      initialDate: initial,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final start = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _timeBlockStart = start;
      if (_timeBlockEnd != null && _timeBlockEnd!.isBefore(start)) {
        _timeBlockEnd = start.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickTimeBlockEnd() async {
    if (_timeBlockStart == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy chọn thời gian bắt đầu trước.')),
      );
      return;
    }

    final initial =
        _timeBlockEnd ?? _timeBlockStart!.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      firstDate: _timeBlockStart!,
      lastDate: DateTime(_timeBlockStart!.year + 2),
      initialDate: initial,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final end = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (end.isBefore(_timeBlockStart!) ||
        end.isAtSameMomentAs(_timeBlockStart!)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thời gian kết thúc phải sau bắt đầu.')),
      );
      return;
    }

    setState(() => _timeBlockEnd = end);
  }

  Future<void> _syncMediaInBackground({
    required DocumentReference docRef,
    required String noteId,
    required String title,
    required String content,
    required String userId,
    required List<String> imagePaths,
    required List<String> filePaths,
    required String? signaturePath,
    required DateTime? deadline,
    required int reminderMinutesBefore,
    required bool isRecurringWeekly,
    required bool isImportant,
    required DateTime? timeBlockStart,
    required DateTime? timeBlockEnd,
    required String? weatherCity,
    required double? weatherTempC,
    required String? weatherDescription,
    required String? weatherIconCode,
    required double? weatherLatitude,
    required double? weatherLongitude,
    required int? weatherAirQualityIndex,
    required String? weatherAirQualityLabel,
    required DateTime? weatherFetchedAt,
    required List<Map<String, dynamic>> weatherHistory,
  }) async {
    try {
      final results = await Future.wait<dynamic>([
        _storageService.uploadPathList(
          paths: imagePaths,
          noteId: noteId,
          category: 'images',
        ),
        _storageService.uploadPathList(
          paths: filePaths,
          noteId: noteId,
          category: 'files',
        ),
        _storageService.uploadOptionalPath(
          path: signaturePath,
          noteId: noteId,
          category: 'signatures',
        ),
      ]).timeout(const Duration(seconds: 45));

      final syncedData = {
        'title': title,
        'content': content,
        'imagePaths': results[0] as List<String>,
        'filePaths': results[1] as List<String>,
        'signaturePath': results[2] as String?,
        'userId': userId,
        'deadline': deadline != null ? Timestamp.fromDate(deadline) : null,
        'reminderMinutesBefore': reminderMinutesBefore,
        'isRecurringWeekly': isRecurringWeekly,
        'isImportant': isImportant,
        'timeBlockStart': timeBlockStart != null
            ? Timestamp.fromDate(timeBlockStart)
            : null,
        'timeBlockEnd': timeBlockEnd != null
            ? Timestamp.fromDate(timeBlockEnd)
            : null,
        'weatherCity': weatherCity,
        'weatherTempC': weatherTempC,
        'weatherDescription': weatherDescription,
        'weatherIconCode': weatherIconCode,
        'weatherLatitude': weatherLatitude,
        'weatherLongitude': weatherLongitude,
        'weatherAirQualityIndex': weatherAirQualityIndex,
        'weatherAirQualityLabel': weatherAirQualityLabel,
        'weatherFetchedAt': weatherFetchedAt != null
            ? Timestamp.fromDate(weatherFetchedAt)
            : null,
        'weatherHistory': weatherHistory,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await docRef.update(syncedData).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Đồng bộ media nền thất bại: $e');
    }
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Vui lòng nhập tiêu đề")));
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Vui lòng đăng nhập lại.")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final collection = FirebaseFirestore.instance.collection('notes');
      final docRef = widget.note == null
          ? collection.doc()
          : collection.doc(widget.note!.id);
      final noteId = docRef.id;
      final baseContent = _contentController.text.trim();
      final localImagePaths = List<String>.from(_imagePaths);
      final localFilePaths = List<String>.from(_filePaths);
      final localSignaturePath = _signaturePath;
      final localDeadline = _deadline;
      final localReminderMinutesBefore = _reminderMinutesBefore;
      final localIsRecurringWeekly = _isRecurringWeekly;
      final localTimeBlockStart = _timeBlockStart;
      final localTimeBlockEnd = _timeBlockEnd;
      final localCalendarEventId = widget.note?.calendarEventId;
      final localIsImportant = _isImportant;

      WeatherSnapshot? fetchedWeather;
      try {
        fetchedWeather = await _fetchCurrentWeatherSnapshot().timeout(
          const Duration(seconds: 6),
          onTimeout: () => null,
        );
      } catch (e) {
        debugPrint('Lay thoi tiet khi luu bi loi, bo qua de luu note: $e');
      }

      final effectiveWeatherCity = fetchedWeather?.city ?? _weatherCity;
      final effectiveWeatherTempC =
          fetchedWeather?.temperatureC ?? _weatherTempC;
      final effectiveWeatherDescription =
          fetchedWeather?.description ?? _weatherDescription;
      final effectiveWeatherIconCode =
          fetchedWeather?.iconCode ?? _weatherIconCode;
      final effectiveWeatherLatitude =
          fetchedWeather?.latitude ?? _weatherLatitude;
      final effectiveWeatherLongitude =
          fetchedWeather?.longitude ?? _weatherLongitude;
      final effectiveWeatherAirQualityIndex =
          fetchedWeather?.airQualityIndex ?? _weatherAirQualityIndex;
      final effectiveWeatherAirQualityLabel =
          fetchedWeather?.airQualityLabel ?? _weatherAirQualityLabel;
      final effectiveWeatherFetchedAt =
          fetchedWeather?.fetchedAt ?? _weatherFetchedAt;
      final content = _buildContentWithWeatherLine(baseContent, fetchedWeather);
      final effectiveImagePaths = _attachLocationImageIfNeeded(
        imagePaths: localImagePaths,
        weather: fetchedWeather,
      );
      final weatherHistory = List<Map<String, dynamic>>.from(_weatherHistory);

      if (fetchedWeather != null && localIsImportant) {
        weatherHistory.add({
          'city': fetchedWeather.city,
          'latitude': fetchedWeather.latitude,
          'longitude': fetchedWeather.longitude,
          'temperatureC': fetchedWeather.temperatureC,
          'description': fetchedWeather.description,
          'iconCode': fetchedWeather.iconCode,
          'fetchedAt': fetchedWeather.fetchedAt.toIso8601String(),
        });
        if (weatherHistory.length > 20) {
          weatherHistory.removeRange(0, weatherHistory.length - 20);
        }
      }

      final data = {
        'title': title,
        'content': content,
        'imagePaths': effectiveImagePaths,
        'filePaths': localFilePaths,
        'signaturePath': localSignaturePath,
        'userId': currentUser.uid,
        'deadline': localDeadline != null
            ? Timestamp.fromDate(localDeadline)
            : null,
        'reminderMinutesBefore': localReminderMinutesBefore,
        'isRecurringWeekly': localIsRecurringWeekly,
        'isImportant': localIsImportant,
        'timeBlockStart': localTimeBlockStart != null
            ? Timestamp.fromDate(localTimeBlockStart)
            : null,
        'timeBlockEnd': localTimeBlockEnd != null
            ? Timestamp.fromDate(localTimeBlockEnd)
            : null,
        'weatherCity': effectiveWeatherCity,
        'weatherTempC': effectiveWeatherTempC,
        'weatherDescription': effectiveWeatherDescription,
        'weatherIconCode': effectiveWeatherIconCode,
        'weatherLatitude': effectiveWeatherLatitude,
        'weatherLongitude': effectiveWeatherLongitude,
        'weatherAirQualityIndex': effectiveWeatherAirQualityIndex,
        'weatherAirQualityLabel': effectiveWeatherAirQualityLabel,
        'weatherFetchedAt': effectiveWeatherFetchedAt != null
            ? Timestamp.fromDate(effectiveWeatherFetchedAt)
            : null,
        'weatherHistory': weatherHistory,
        'calendarEventId': localCalendarEventId,
        'timestamp': FieldValue.serverTimestamp(),
      };

      final writeFuture = widget.note == null
          ? docRef.set(data)
          : docRef.update(data);

      await writeFuture.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          unawaited(
            writeFuture.catchError(
              (error) => debugPrint('Ghi note nền thất bại: $error'),
            ),
          );
        },
      );

      unawaited(
        _syncMediaInBackground(
          docRef: docRef,
          noteId: noteId,
          title: title,
          content: content,
          userId: currentUser.uid,
          imagePaths: effectiveImagePaths,
          filePaths: localFilePaths,
          signaturePath: localSignaturePath,
          deadline: localDeadline,
          reminderMinutesBefore: localReminderMinutesBefore,
          isRecurringWeekly: localIsRecurringWeekly,
          isImportant: localIsImportant,
          timeBlockStart: localTimeBlockStart,
          timeBlockEnd: localTimeBlockEnd,
          weatherCity: effectiveWeatherCity,
          weatherTempC: effectiveWeatherTempC,
          weatherDescription: effectiveWeatherDescription,
          weatherIconCode: effectiveWeatherIconCode,
          weatherLatitude: effectiveWeatherLatitude,
          weatherLongitude: effectiveWeatherLongitude,
          weatherAirQualityIndex: effectiveWeatherAirQualityIndex,
          weatherAirQualityLabel: effectiveWeatherAirQualityLabel,
          weatherFetchedAt: effectiveWeatherFetchedAt,
          weatherHistory: weatherHistory,
        ),
      );
      final DateTime? calendarStart = localTimeBlockStart ?? localDeadline;
      final DateTime? calendarEnd =
          localTimeBlockEnd ?? localDeadline?.add(const Duration(hours: 1));

      var canSyncCalendar = false;
      if (calendarStart != null && calendarEnd != null) {
        try {
          canSyncCalendar = await CalendarSyncService.hasCalendarAccess()
              .timeout(const Duration(seconds: 8), onTimeout: () => false);

          if (!canSyncCalendar) {
            canSyncCalendar =
                await CalendarSyncService.requestCalendarAccessInteractively()
                    .timeout(
                      const Duration(seconds: 25),
                      onTimeout: () => false,
                    );
          }
        } catch (e) {
          debugPrint('Kiểm tra/cấp quyền Calendar thất bại: $e');
        }

        if (!canSyncCalendar && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Chưa cấp quyền Google Calendar. Note vẫn lưu bình thường.',
              ),
            ),
          );
        }
      }

      unawaited(() async {
        if (localDeadline != null) {
          try {
            final scheduled =
                await NotificationService.scheduleDeadlineNotifications(
                  noteId: noteId,
                  title: title,
                  deadline: localDeadline,
                  minutesBefore: localReminderMinutesBefore,
                  recurringWeekly: localIsRecurringWeekly,
                ).timeout(const Duration(seconds: 10), onTimeout: () => false);

            if (!scheduled) {
              debugPrint(
                'Chưa bật quyền thông báo hoặc thời gian chưa hợp lệ để nhắc.',
              );
            }
          } catch (e) {
            debugPrint('Đặt lịch nhắc thất bại: $e');
          }
        } else {
          unawaited(NotificationService.cancelReminder(noteId));
        }

        if (calendarStart != null && calendarEnd != null && canSyncCalendar) {
          try {
            final eventId =
                await CalendarSyncService.upsertNoteEvent(
                  noteId: noteId,
                  title: title,
                  description: content,
                  start: calendarStart,
                  end: calendarEnd,
                  existingEventId: localCalendarEventId,
                  recurringWeekly: localIsRecurringWeekly,
                ).timeout(
                  const Duration(seconds: 20),
                  onTimeout: () => localCalendarEventId,
                );

            if (eventId != null && eventId.isNotEmpty) {
              await docRef
                  .set({'calendarEventId': eventId}, SetOptions(merge: true))
                  .timeout(const Duration(seconds: 8));
            }
          } catch (e) {
            debugPrint('Đồng bộ Google Calendar thất bại: $e');
          }
        } else if (localCalendarEventId != null &&
            localCalendarEventId.isNotEmpty) {
          try {
            await CalendarSyncService.deleteEventIfExists(
              localCalendarEventId,
              noteId: noteId,
            ).timeout(const Duration(seconds: 12));
            await docRef
                .set({'calendarEventId': null}, SetOptions(merge: true))
                .timeout(const Duration(seconds: 8));
          } catch (e) {
            debugPrint('Xoá sync Calendar thất bại: $e');
          }
        }
      }());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu ghi chú, media sẽ đồng bộ nền.'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể lưu ghi chú: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildImagePreview(String path, {double size = 80}) {
    if (_storageService.isRemoteUrl(path)) {
      return Image.network(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      );
    }
    return Image.file(File(path), width: size, height: size, fit: BoxFit.cover);
  }

  Future<void> _openAttachment(String path) async {
    if (_storageService.isRemoteUrl(path)) {
      final uri = Uri.tryParse(path);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    await OpenFile.open(path);
  }

  Future<void> _openGoogleCalendarCreateEvent() async {
    final title = Uri.encodeComponent(
      _titleController.text.trim().isEmpty
          ? 'Lịch học / Deadline'
          : _titleController.text.trim(),
    );
    final details = Uri.encodeComponent(_contentController.text.trim());

    String dates = '';
    if (_timeBlockStart != null && _timeBlockEnd != null) {
      final start = _toGoogleDateTime(_timeBlockStart!);
      final end = _toGoogleDateTime(_timeBlockEnd!);
      dates = '$start/$end';
    } else if (_deadline != null) {
      final start = _toGoogleDateTime(_deadline!);
      final end = _toGoogleDateTime(_deadline!.add(const Duration(hours: 1)));
      dates = '$start/$end';
    }

    final url = Uri.parse(
      'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&details=$details${dates.isNotEmpty ? '&dates=$dates' : ''}',
    );

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  String _toGoogleDateTime(DateTime dateTime) {
    final utc = dateTime.toUtc();
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    return '$year$month${day}T$hour$minute${second}Z';
  }

  Future<bool> _confirmRemove(String itemLabel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xoá'),
        content: Text('Bạn có chắc muốn xoá $itemLabel này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Ghi chú mới' : 'Chỉnh sửa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: () async {
              final img = await ImagePicker().pickImage(
                source: ImageSource.gallery,
              );
              if (img != null) setState(() => _imagePaths.add(img.path));
            },
          ),
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () async {
              final res = await FilePicker.platform.pickFiles();
              if (res != null) {
                setState(() => _filePaths.add(res.files.single.path!));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.draw),
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SignatureScreen(),
                ),
              );
              if (res != null) setState(() => _signaturePath = res);
            },
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _saveNote,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Tiêu đề',
                border: InputBorder.none,
              ),
            ),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                hintText: 'Nội dung...',
                border: InputBorder.none,
              ),
              maxLines: null,
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ghi chú quan trọng'),
              subtitle: const Text('Ghi lại lịch sử thời tiết khi lưu note'),
              value: _isImportant,
              onChanged: (value) => setState(() => _isImportant = value),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _isRefreshingWeather ? null : _refreshWeatherNow,
                icon: _isRefreshingWeather
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _isRefreshingWeather
                      ? 'Dang lam moi thoi tiet...'
                      : 'Lam moi thoi tiet theo vi tri hien tai',
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (!_weatherService.isConfigured)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Chưa cấu hình OpenWeather API key (openWeatherApiKey).',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            if (_weatherTempC != null || _weatherDescription != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 6, bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (_weatherIconCode != null &&
                        _weatherIconCode!.isNotEmpty)
                      Image.network(
                        'https://openweathermap.org/img/wn/$_weatherIconCode@2x.png',
                        width: 32,
                        height: 32,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.cloud_outlined,
                              color: Colors.grey,
                            ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_weatherDescription ?? 'Không rõ'}${_weatherTempC != null ? ' • ${_weatherTempC!.toStringAsFixed(1)}°C' : ''}${_weatherCity != null ? ' • $_weatherCity' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            if (_weatherLatitude != null && _weatherLongitude != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vi tri hien tai: ${_weatherLatitude!.toStringAsFixed(5)}, ${_weatherLongitude!.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _openMapAt(_weatherLatitude!, _weatherLongitude!),
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('Mo Google Maps vi tri nay'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            if (_weatherAirQualityLabel != null &&
                _weatherAirQualityLabel!.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _weatherAirQualityIndex != null
                        ? 'AQI ${_weatherAirQualityIndex}: $_weatherAirQualityLabel'
                        : 'AQI: $_weatherAirQualityLabel',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ),
            if (_weatherHistory.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Đã lưu ${_weatherHistory.length} mốc lịch sử thời tiết',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Lên lịch & nhắc nhở',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              contentPadding: EdgeInsets.zero,
              title: Text(
                _deadline == null
                    ? 'Chọn deadline'
                    : 'Deadline: ${_formatDateTime(_deadline!)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_deadline != null)
                    IconButton(
                      onPressed: () => setState(() {
                        _deadline = null;
                        _reminderMinutesBefore = 0;
                      }),
                      icon: const Icon(Icons.clear),
                      tooltip: 'Bỏ deadline',
                    ),
                  IconButton(
                    onPressed: _pickDeadline,
                    icon: const Icon(Icons.edit_calendar),
                    tooltip: 'Chọn deadline',
                  ),
                ],
              ),
            ),
            DropdownButtonFormField<int>(
              initialValue: _reminderMinutesBefore,
              decoration: const InputDecoration(
                labelText: 'Nhắc trước hạn',
                border: OutlineInputBorder(),
              ),
              items: _reminderOptions
                  .map(
                    (value) => DropdownMenuItem<int>(
                      value: value,
                      child: Text(_reminderLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: _deadline == null
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _reminderMinutesBefore = value);
                    },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lặp hàng tuần'),
              subtitle: const Text('Dành cho bài tập/lịch học định kỳ'),
              value: _isRecurringWeekly,
              onChanged: (value) => setState(() => _isRecurringWeekly = value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time_outlined),
              title: Text(
                _timeBlockStart == null
                    ? 'Chọn thời gian bắt đầu (time-block)'
                    : 'Bắt đầu: ${_formatDateTime(_timeBlockStart!)}',
              ),
              trailing: IconButton(
                onPressed: _pickTimeBlockStart,
                icon: const Icon(Icons.edit),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_outlined),
              title: Text(
                _timeBlockEnd == null
                    ? 'Chọn thời gian kết thúc (time-block)'
                    : 'Kết thúc: ${_formatDateTime(_timeBlockEnd!)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_timeBlockStart != null || _timeBlockEnd != null)
                    IconButton(
                      onPressed: () => setState(() {
                        _timeBlockStart = null;
                        _timeBlockEnd = null;
                      }),
                      icon: const Icon(Icons.clear),
                    ),
                  IconButton(
                    onPressed: _pickTimeBlockEnd,
                    icon: const Icon(Icons.edit),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openGoogleCalendarCreateEvent,
                icon: const Icon(Icons.event_available),
                label: const Text('Tạo sự kiện trên Google Calendar'),
              ),
            ),
            const SizedBox(height: 8),
            if (_imagePaths.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _imagePaths
                    .map(
                      (p) => Stack(
                        children: [
                          _buildImagePreview(p),
                          Positioned(
                            right: 0,
                            child: GestureDetector(
                              onTap: () async {
                                final confirmed = await _confirmRemove('ảnh');
                                if (!confirmed || !mounted) return;
                                setState(() => _imagePaths.remove(p));
                              },
                              child: const CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.red,
                                child: Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            if (_signaturePath != null)
              Stack(
                children: [
                  _storageService.isRemoteUrl(_signaturePath!)
                      ? Image.network(
                          _signaturePath!,
                          height: 150,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 150,
                                width: 220,
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey,
                                ),
                              ),
                        )
                      : Image.file(File(_signaturePath!), height: 150),
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      onTap: () async {
                        final confirmed = await _confirmRemove('chữ ký');
                        if (!confirmed || !mounted) return;
                        setState(() => _signaturePath = null);
                      },
                      child: const CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ..._filePaths.map(
              (p) => ListTile(
                leading: const Icon(Icons.file_present),
                title: Text(p.split('/').last),
                onTap: () => _openAttachment(p),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirmed = await _confirmRemove('file');
                    if (!confirmed || !mounted) return;
                    setState(() => _filePaths.remove(p));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WeatherSettingsScreen extends StatefulWidget {
  final String initialCity;

  const WeatherSettingsScreen({required this.initialCity, super.key});

  @override
  State<WeatherSettingsScreen> createState() => _WeatherSettingsScreenState();
}

class _WeatherSettingsScreenState extends State<WeatherSettingsScreen> {
  late final TextEditingController _cityController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cityController = TextEditingController(text: widget.initialCity);
  }

  Future<void> _save() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên thành phố.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(weatherCityPrefsKey, city);
      if (!mounted) return;
      Navigator.pop(context, city);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể lưu cài đặt: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt thời tiết')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'Thành phố mặc định',
                hintText: 'Ví dụ: Ho Chi Minh City, Da Nang, Hanoi',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thành phố này sẽ dùng khi tự động lấy thời tiết lúc lưu ghi chú.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Đang lưu...' : 'Lưu cài đặt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- SignatureScreen ---
class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  late SignatureController _controller;
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3;

  final List<Color> _penColors = const [
    Colors.black,
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: _strokeWidth,
      penColor: _selectedColor,
      exportBackgroundColor: Colors.white,
    );
  }

  void _changePenColor(Color color) {
    final oldPoints = List<Point>.from(_controller.points);
    _controller.dispose();
    final newController = SignatureController(
      penStrokeWidth: _strokeWidth,
      penColor: color,
      exportBackgroundColor: Colors.white,
    );
    newController.points = oldPoints;

    setState(() {
      _selectedColor = color;
      _controller = newController;
    });
  }

  void _changeStrokeWidth(double value) {
    final oldPoints = List<Point>.from(_controller.points);
    _controller.dispose();
    final newController = SignatureController(
      penStrokeWidth: value,
      penColor: _selectedColor,
      exportBackgroundColor: Colors.white,
    );
    newController.points = oldPoints;

    setState(() {
      _strokeWidth = value;
      _controller = newController;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Viết tay"),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Xóa nét vẽ',
            onPressed: () => _controller.clear(),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              if (_controller.isNotEmpty) {
                final data = await _controller.toPngBytes();
                if (data != null) {
                  final dir = await getApplicationDocumentsDirectory();
                  final file = File(
                    '${dir.path}/sig_${DateTime.now().millisecondsSinceEpoch}.png',
                  );
                  await file.writeAsBytes(data);
                  if (context.mounted) Navigator.pop(context, file.path);
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Signature(
              controller: _controller,
              backgroundColor: Colors.grey[200]!,
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Màu bút',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: _penColors
                      .map(
                        (color) => GestureDetector(
                          onTap: () => _changePenColor(color),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColor == color
                                    ? Colors.teal
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Độ dày nét',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: _strokeWidth,
                  min: 1,
                  max: 8,
                  divisions: 7,
                  label: _strokeWidth.toStringAsFixed(0),
                  onChanged: _changeStrokeWidth,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
