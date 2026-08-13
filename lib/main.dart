import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error initializing cameras: $e');
  }
  runApp(const LeicaCameraApp());
}

class LeicaCameraApp extends StatelessWidget {
  const LeicaCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leica Lux Clone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  int _selectedCameraIndex = 0;
  String _selectedFilter = 'Normal';
  bool _isBackgroundBlurActive = false;

  final List<String> _filters = [
    'Normal',
    'Leica M Monochrom',
    'Leica Classic Warm',
    'Cinematic Teal',
    'High Contrast B&W'
  ];

  @override
  void initState() {
    super.initState();
    _initializePermissionsAndCamera();
  }

  Future<void> _initializePermissionsAndCamera() async {
    var cameraStatus = await Permission.camera.request();
    var storageStatus = await Permission.storage.request();

    if (cameraStatus.isGranted) {
      if (cameras.isNotEmpty) {
        _initCamera(cameras[_selectedCameraIndex]);
      }
    } else {
      debugPrint('Camera permission denied');
    }
  }

  Future<void> _initCamera(CameraDescription cameraDescription) async {
    final previousController = _controller;
    if (previousController != null) {
      await previousController.dispose();
    }

    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _switchCamera() {
    if (cameras.length < 2) return;
    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;
      _isCameraInitialized = false;
    });
    _initCamera(cameras[_selectedCameraIndex]);
  }

  ColorFilter? _getFilterColorMatrix(String filterName) {
    switch (filterName) {
      case 'Leica M Monochrom':
        return const ColorFilter.matrix(<double>[
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'Leica Classic Warm':
        return const ColorFilter.matrix(<double>[
          1.2, 0, 0, 0, 10,
          0, 1.1, 0, 0, 5,
          0, 0, 0.9, 0, -10,
          0, 0, 0, 1, 0,
        ]);
      case 'Cinematic Teal':
        return const ColorFilter.matrix(<double>[
          0.9, 0, 0, 0, 0,
          0, 1.1, 0.1, 0, 5,
          0, 0, 1.3, 0, 20,
          0, 0, 0, 1, 0,
        ]);
      case 'High Contrast B&W':
        return const ColorFilter.matrix(<double>[
          1.5, 0, 0, 0, -30,
          0, 1.5, 0, 0, -30,
          0, 0, 1.5, 0, -30,
          0, 0, 0, 1, 0,
        ]);
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          bool isLandscape = orientation == Orientation.landscape;
          
          return Stack(
            fit: StackFit.expand,
            children: [
              // Camera Preview with Filter & Background Simulation Layer
              Center(
                child: CameraPreview(_controller!),
              ),
              
              // Filter Overlay Effect
              if (_getFilterColorMatrix(_selectedFilter) != null)
                ColorFiltered(
                  colorFilter: _getFilterColorMatrix(_selectedFilter)!,
                  child: IgnorePointer(
                    child: Container(color: Colors.transparent),
                  ),
                ),

              // Portrait Mode / Background Isolation Simulated Effect Overlay
              if (_isBackgroundBlurActive)
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                        radius: 0.8,
                      ),
                    ),
                  ),
                ),

              // Top Bar Controls
              Positioned(
                top: isLandscape ? 15 : 50,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Leica Style Logo Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red[900],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LEICA LUX',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    // Background Isolation Toggle
                    IconButton(
                      icon: Icon(
                        Icons.blur_on,
                        color: _isBackgroundBlurActive ? Colors.amber : Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        setState(() {
                          _isBackgroundBlurActive = !_isBackgroundBlurActive;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Bottom Bar Controls & Filters
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Filter Selector Horizontal Scroll
                    SizedBox(
                      height: 45,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        itemBuilder: (context, index) {
                          bool isSelected = _selectedFilter == _filters[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: ChoiceChip(
                              label: Text(_filters[index]),
                              selected: isSelected,
                              selectedColor: Colors.amber,
                              backgroundColor: Colors.black54,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  _selectedFilter = _filters[index];
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Shutter & Switch Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 32),
                          onPressed: _switchCamera,
                        ),
                        GestureDetector(
                          onTap: () {
                            // Capture action simulation
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم التقاط الصورة بفلتر لايكا')),
                            );
                          },
                          child: Container(
                            width: 75,
                            height: 75,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Center(
                              child: Container(
                                width: 63,
                                height: 63,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 32), // Spacer for symmetry
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
