import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/diagnosis_result.dart';
import '../services/diagnosis_quota_service.dart';
import '../services/diagnosis_store.dart';
import '../services/disease_diagnosis_service.dart';
import '../theme/app_theme.dart';
import '../widgets/diagnosis_result_card.dart';

class DiagnosisScreen extends StatefulWidget {
  final DiseaseDiagnosisService? diagnosisService;
  final DiagnosisQuotaService? quotaService;

  const DiagnosisScreen({
    super.key,
    this.diagnosisService,
    this.quotaService,
  });

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen>
    with TickerProviderStateMixin {
  static const _green = Color(0xFF2E7D4F);
  static const _red = Color(0xFFE05252);
  static const _orange = Color(0xFFE0A852);

  final ImagePicker _picker = ImagePicker();
  late final DiseaseDiagnosisService _service;
  late final DiagnosisQuotaService _quota;

  Uint8List? _imageBytes;
  String _mimeType = 'image/jpeg';
  String? _fileName;
  bool _analyzing = false;
  DiagnosisResult? _result;
  String? _error;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool get _supportsCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _service = widget.diagnosisService ?? GeminiDiseaseDiagnosisService();
    _quota = widget.quotaService ?? DiagnosisQuotaService();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _mimeType = picked.mimeType ?? _mimeTypeForName(picked.name);
        _fileName = picked.name;
        _result = null;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = source == ImageSource.camera
            ? 'Gagal membuka kamera. Pastikan izin kamera sudah diberikan.'
            : 'Gagal mengambil foto dari galeri.';
        _result = null;
      });
    }
  }

  Future<void> _analyze() async {
    final bytes = _imageBytes;
    if (bytes == null || _analyzing) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _analyzing = true;
      _error = null;
      _result = null;
    });

    try {
      // 1-3. Cek kuota sebelum menembak API Gemini.
      await _quota.enforce();

      final result = await _service.diagnose(bytes, mimeType: _mimeType);

      // 4. Kunci kuota setelah Gemini sukses merespon.
      try {
        await _quota.lock();
      } on DiagnosisQuotaException catch (error) {
        if (!mounted) return;
        setState(() => _error = error.message);
      }

      if (!mounted) return;
      setState(() => _result = result);

      await DiagnosisStore.instance.addDiagnosis(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hasil disimpan ke Riwayat & Tugas Harian.',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } on DiagnosisQuotaExceededException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on DiagnosisQuotaException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on DiseaseDiagnosisException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = 'Terjadi kesalahan saat menganalisa foto.',
      );
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  String _mimeTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Diagnosa Penyakit'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Foto tanaman yang gejalanya mau diperiksa. AI akan bantu '
                'menebak penyakit, penyebab, dan cara menanganinya.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              if (!_service.isConfigured) ...[
                _buildConfigBanner(textTheme),
                const SizedBox(height: 16),
              ],
              _buildPhotoBox(textTheme),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_supportsCamera) ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _analyzing
                            ? null
                            : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined, size: 20),
                        label: const Text('Kamera'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _analyzing
                          ? null
                          : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 20),
                      label: const Text('Galeri'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: _green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _imageBytes == null || _analyzing || !_service.isConfigured
                      ? null
                      : _analyze,
                  icon: _analyzing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.biotech_outlined, size: 20),
                  label: Text(_analyzing ? 'Menganalisa...' : 'Analisa Foto'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              if (_analyzing) ...[
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: const CircularProgressIndicator(color: _green),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'AI sedang memeriksa foto...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                _buildErrorBox(_error!),
              ],
              if (_result != null) ...[
                const SizedBox(height: 20),
                DiagnosisResultCard(result: _result!),
              ],
              const SizedBox(height: 20),
              Text(
                'Tips: ambil foto dari jarak dekat dengan cahaya cukup, fokus '
                'pada bagian daun yang sakit. Foto yang buram atau gelap bikin '
                'hasil kurang akurat.',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.black38,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoBox(TextTheme textTheme) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: _imageBytes == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_a_photo_outlined,
                      color: _green,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada foto',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Ambil foto lewat kamera atau pilih dari galeri',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    _imageBytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    right: 10,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _fileName ?? 'Foto terpilih',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildConfigBanner(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _orange.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.key_outlined, color: Color(0xFFB07A29)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'API key Gemini belum diset',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB07A29),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Isi GEMINI_API_KEY di lib/secrets.dart, atau jalankan:\n'
                  'flutter run --dart-define=GEMINI_API_KEY=API_KEY_KAMU',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _red.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: _red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
