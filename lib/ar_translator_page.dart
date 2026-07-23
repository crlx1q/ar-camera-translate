import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'languages.dart';
import 'overlay_painter.dart';

class ARTranslatorPage extends StatefulWidget {
  const ARTranslatorPage({super.key});

  @override
  State<ARTranslatorPage> createState() => _ARTranslatorPageState();
}

class _ARTranslatorPageState extends State<ARTranslatorPage>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _isBusy = false;
  bool _initializing = true;
  String? _error;

  TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  ScriptChoice _script = ScriptChoice.latin;
  final LanguageIdentifier _identifier =
      LanguageIdentifier(confidenceThreshold: 0.4);
  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();
  final Map<TranslateLanguage, OnDeviceTranslator> _translators = {};
  final Map<String, String> _cache = {};
  final Set<String> _pending = {};
  TranslateLanguage _target = TranslateLanguage.russian;

  List<DetectedItem> _items = [];
  Size? _imageSize;
  InputImageRotation? _rotation;

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _error = 'Камера не найдена на устройстве';
      } else {
        _cameraIndex = _cameras
            .indexWhere((c) => c.lensDirection == CameraLensDirection.back);
        if (_cameraIndex < 0) _cameraIndex = 0;
        await _startController();
      }
    } catch (e) {
      _error = 'Не удалось запустить камеру: $e';
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _startController() async {
    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _controller = controller;
    await controller.initialize();
    await controller.startImageStream(_processImage);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _teardown();
    super.dispose();
  }

  Future<void> _teardown() async {
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    await _controller?.dispose();
    _controller = null;
    await _recognizer.close();
    await _identifier.close();
    for (final t in _translators.values) {
      await t.close();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive) {
      _teardown();
    } else if (state == AppLifecycleState.resumed &&
        (controller == null || !controller.value.isInitialized)) {
      _startController();
    }
  }

  Future<void> _processImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      final inputImage = _inputImageFromCamera(image);
      if (inputImage == null) return;
      final recognized = await _recognizer.processImage(inputImage);
      final items = <DetectedItem>[];
      for (final block in recognized.blocks) {
        final text = block.text.trim();
        if (text.isEmpty) continue;
        items.add(DetectedItem(
          corners: block.cornerPoints,
          original: text,
          translated: _cache[text],
        ));
        _ensureTranslation(text);
      }
      if (mounted) {
        setState(() {
          _items = items;
          _imageSize = inputImage.metadata?.size;
          _rotation = inputImage.metadata?.rotation;
        });
      }
    } catch (_) {
      // ignore transient per-frame errors
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _ensureTranslation(String text) async {
    if (_cache.containsKey(text) || _pending.contains(text)) return;
    _pending.add(text);
    try {
      final code = await _identifier.identifyLanguage(text);
      final src = _langFromCode(code);
      if (src == null || src == _target) {
        _cache[text] = text;
        return;
      }
      final translator = await _getTranslator(src);
      if (translator == null) return;
      final result = await translator.translateText(text);
      _cache[text] = result.isEmpty ? text : result;
      if (mounted) setState(() {});
    } catch (_) {
      // leave untranslated; retried when it reappears
    } finally {
      _pending.remove(text);
    }
  }

  Future<OnDeviceTranslator?> _getTranslator(TranslateLanguage src) async {
    final existing = _translators[src];
    if (existing != null) return existing;
    try {
      if (!await _modelManager.isModelDownloaded(src.bcpCode)) {
        await _modelManager.downloadModel(src.bcpCode, isWifiRequired: false);
      }
      if (!await _modelManager.isModelDownloaded(_target.bcpCode)) {
        await _modelManager.downloadModel(_target.bcpCode,
            isWifiRequired: false);
      }
    } catch (_) {
      return null;
    }
    final translator =
        OnDeviceTranslator(sourceLanguage: src, targetLanguage: _target);
    _translators[src] = translator;
    return translator;
  }

  TranslateLanguage? _langFromCode(String code) {
    if (code.isEmpty || code == 'und') return null;
    final norm = code.split('-').first.toLowerCase();
    for (final l in TranslateLanguage.values) {
      if (l.bcpCode.toLowerCase() == norm) return l;
    }
    return null;
  }

  Future<void> _changeTarget(TranslateLanguage lang) async {
    if (lang == _target) return;
    final old = _translators.values.toList();
    setState(() {
      _target = lang;
      _translators.clear();
      _cache.clear();
      _pending.clear();
    });
    for (final t in old) {
      await t.close();
    }
  }

  Future<void> _changeScript(ScriptChoice choice) async {
    if (choice == _script) return;
    final old = _recognizer;
    _recognizer = TextRecognizer(script: choice.script);
    setState(() {
      _script = choice;
      _items = [];
    });
    await old.close();
  }

  InputImage? _inputImageFromCamera(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      var compensation = _orientations[controller.value.deviceOrientation];
      if (compensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        compensation = (sensorOrientation + compensation) % 360;
      } else {
        compensation = (sensorOrientation - compensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(compensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _errorView(_error!);
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _errorView('Камера недоступна');
    }
    final camera = _cameras[_cameraIndex];
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: CameraPreview(
            controller,
            child: CustomPaint(
              painter: OverlayPainter(
                items: _items,
                imageSize: _imageSize,
                rotation: _rotation,
                lensDirection: camera.lensDirection,
              ),
            ),
          ),
        ),
        _topBar(),
        _hint(),
      ],
    );
  }

  Widget _errorView(String message) {
    return Container(
      color: const Color(0xFF0B0F14),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded,
                size: 56, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Разреши доступ к камере в настройках приложения.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _circleButton(Icons.arrow_back_rounded,
                () => Navigator.of(context).maybePop()),
            const Spacer(),
            _pill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.translate_rounded,
                      size: 18, color: Color(0xFF00E5A0)),
                  const SizedBox(width: 6),
                  _targetDropdown(),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _pill(child: _scriptDropdown()),
          ],
        ),
      ),
    );
  }

  Widget _targetDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<TranslateLanguage>(
        value: _target,
        dropdownColor: const Color(0xFF12181F),
        isDense: true,
        iconEnabledColor: Colors.white70,
        style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        items: kLanguages
            .map((l) => DropdownMenuItem(
                  value: l.lang,
                  child: Text(l.label),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) _changeTarget(v);
        },
      ),
    );
  }

  Widget _scriptDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<ScriptChoice>(
        value: _script,
        dropdownColor: const Color(0xFF12181F),
        isDense: true,
        iconEnabledColor: Colors.white70,
        style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        items: ScriptChoice.values
            .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.label),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) _changeScript(v);
        },
      ),
    );
  }

  Widget _pill({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC12181F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xCC12181F),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _hint() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xB3000000),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.center_focus_strong_rounded,
                      color: Color(0xFF00E5A0), size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Наведи камеру на текст — перевод появится прямо на нём',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
