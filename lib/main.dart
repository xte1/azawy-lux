import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui';
import 'dart:io';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error getting cameras: $e');
  }
  runApp(const LeicaLuxApp());
}

class LeicaLuxApp extends StatelessWidget {
  const LeicaLuxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Azawy Lux Leica Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const LeicaCameraScreen(),
    );
  }
}

class LeicaCameraScreen extends StatefulWidget {
  const LeicaCameraScreen({super.key});

  @override
  State<LeicaCameraScreen> createState() => _LeicaCameraScreenState();
}

class _LeicaCameraScreenState extends State<LeicaCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  String _errorMessage = '';
  
  // حالات التحكم
  bool _isVideoMode = false;
  bool _isRecording = false;
  double _exposureOffset = 0.0;
  double _minExposure = 0.0;
  double _maxExposure = 0.0;
  double _blurIntensity = 0.0; // شدة عزل الخلفية
  double _aspectRatio = 3.0 / 4.0; // الأبعاد الافتراضية 3:4
  int _selectedFilter = 0; // الفلتر النشط
  
  String? _lastMediaPath;

  final List<String> _filterNames = ['Leica M', 'Monochrom', 'Cinematic Warm', 'Moody Noir'];

  final List<ColorFilter> _leicaFilters = [
    const ColorFilter.matrix(<double>[
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ]), // طبيعي
    const ColorFilter.matrix(<double>[
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0, 0, 0, 1, 0,
    ]), // مونوكروم
    const ColorFilter.matrix(<double>[
      1.2, 0.1, 0, 0, 10,
      0, 1.1, 0, 0, 5,
      0, 0, 0.9, 0, -10,
      0, 0, 0, 1, 0,
    ]), // سينمائي دافئ
    const ColorFilter.matrix(<double>[
      1.3, 0, 0, 0, -20,
      0, 1.3, 0, 0, -20,
      0, 0, 1.3, 0, -20,
      0, 0, 0, 1, 0,
    ]), // نوير غامق
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndInitCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // التعامل مع دورة حياة التطبيق لإعادة تفعيل الكاميرا عند العودة للتطبيق
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _checkAndInitCamera() async {
    // طلب صلاحية الكاميرا والميكروفون بانتظام وثبات
    var cameraStatus = await Permission.camera.request();
    var micStatus = await Permission.microphone.request();

    if (cameraStatus.isGranted) {
      await _initCamera();
    } else {
      setState(() {
        _errorMessage = 'تم رفض إذن الكاميرا. يرجى السماح به من إعدادات الهاتف.';
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      if (cameras.isEmpty) {
        cameras = await availableCameras();
      }
      if (cameras.isNotEmpty) {
        _controller = CameraController(
          cameras[0],
          ResolutionPreset.high,
          enableAudio: true,
        );
        await _controller!.initialize();
        
        _minExposure = await _controller!.getMinExposureOffset();
        _maxExposure = await _controller!.getMaxExposureOffset();
        
        if (!mounted) return;
        setState(() {
          _isInitialized = true;
          _errorMessage = '';
        });
      } else {
        setState(() {
          _errorMessage = 'لا توجد كاميرا متاحة على هذا الجهاز.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في تشغيل الكاميرا: $e';
      });
    }
  }

  Future<void> _captureAction() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      if (_isVideoMode) {
        if (_isRecording) {
          final file = await _controller!.stopVideoRecording();
          setState(() {
            _isRecording = false;
            _lastMediaPath = file.path;
          });
          _showSnackBar('تم حفظ الفيديو بنجاح!');
        } else {
          await _controller!.startVideoRecording();
          setState(() {
            _isRecording = true;
          });
          _showSnackBar('جاري تسجيل الفيديو...');
        }
      } else {
        final image = await _controller!.takePicture();
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'Leica_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = path.join(directory.path, fileName);
        await File(image.path).copy(savedPath);

        setState(() {
          _lastMediaPath = savedPath;
        });
        _showSnackBar('تم التقاط الصورة وحفظها بنجاح!');
      }
    } catch (e) {
      debugPrint('Error during capture: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(milliseconds: 900)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _checkAndInitCamera,
                  child: const Text('إعادة المحاولة ومنح الأذونات'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // المعاينة الخاصة بالكاميرا
          Center(
            child: AspectRatio(
              aspectRatio: _aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    colorFilter: _leicaFilters[_selectedFilter],
                    child: CameraPreview(_controller!),
                  ),
                  if (_blurIntensity > 0)
                    BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: _blurIntensity * 12,
                        sigmaY: _blurIntensity * 12,
                      ),
                      child: Container(color: Colors.black.withOpacity(0.0)),
                    ),
                ],
              ),
            ),
          ),

          // شريط التحكم العلوي
          Positioned(
            top: 45,
            left: 15,
            right: 15,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'LEICA LUX M11',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16),
                    ),
                    PopupMenuButton<double>(
                      icon: const Icon(Icons.aspect_ratio, color: Colors.white),
                      onSelected: (val) => setState(() => _aspectRatio = val),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 1.0, child: Text('مربع (1:1)')),
                        const PopupMenuItem(value: 3.0 / 4.0, child: Text('قياسي (3:4)')),
                        const PopupMenuItem(value: 9.0 / 16.0, child: Text('سينمائي (9:16)')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 35,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filterNames.length,
                    itemBuilder: (context, index) {
                      bool isSelected = _selectedFilter == index;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(_filterNames[index], style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12)),
                          selected: isSelected,
                          selectedColor: Colors.white,
                          backgroundColor: Colors.black54,
                          onSelected: (selected) => setState(() => _selectedFilter = index),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // أشرطة التحكم الجانبية (الإضاءة والعزل)
          Positioned(
            right: 15,
            top: 150,
            bottom: 150,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wb_sunny, color: Colors.amber, size: 18),
                const Text('الإضاءة', style: TextStyle(color: Colors.white70, fontSize: 9)),
                SizedBox(
                  height: 110,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Slider(
                      value: _exposureOffset,
                      min: _minExposure,
                      max: _maxExposure,
                      activeColor: Colors.amber,
                      inactiveColor: Colors.white24,
                      onChanged: (val) {
                        setState(() => _exposureOffset = val);
                        _controller?.setExposureOffset(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Icon(Icons.blur_on, color: Colors.cyanAccent, size: 18),
                const Text('العزل', style: TextStyle(color: Colors.white70, fontSize: 9)),
                SizedBox(
                  height: 110,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Slider(
                      value: _blurIntensity,
                      min: 0.0,
                      max: 1.0,
                      activeColor: Colors.cyanAccent,
                      inactiveColor: Colors.white24,
                      onChanged: (val) => setState(() => _blurIntensity = val),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // الشريط السفلي (التقاط، صورة/فيديو، المعرض)
          Positioned(
            bottom: 25,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isVideoMode = false),
                      child: Text(
                        'صورة',
                        style: TextStyle(
                          color: !_isVideoMode ? Colors.amber : Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 30),
                    GestureDetector(
                      onTap: () => setState(() => _isVideoMode = true),
                      child: Text(
                        'فيديو',
                        style: TextStyle(
                          color: _isVideoMode ? Colors.redAccent : Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white54, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: _lastMediaPath != null
                            ? Image.file(File(_lastMediaPath!), fit: BoxFit.cover)
                            : const Icon(Icons.photo_library, color: Colors.white30),
                      ),
                    ),
                    GestureDetector(
                      onTap: _captureAction,
                      child: Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isVideoMode
                                ? (_isRecording ? Colors.red : Colors.white)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 50, height: 50),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
