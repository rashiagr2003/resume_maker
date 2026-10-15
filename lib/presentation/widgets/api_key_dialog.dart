import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/resume_providers.dart';

class ApiKeyDialog extends ConsumerStatefulWidget {
  const ApiKeyDialog({super.key});

  @override
  ConsumerState<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends ConsumerState<ApiKeyDialog> {
  late TextEditingController _keyController;
  late TextEditingController _backendUrlController;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final currentKey = ref.read(apiKeyProvider).valueOrNull ?? '';
    _keyController = TextEditingController(text: currentKey);
    _backendUrlController = TextEditingController(text: 'http://localhost:8080');
    _loadBackendUrl();
  }

  Future<void> _loadBackendUrl() async {
    final settings = ref.read(settingsLocalDataSourceProvider);
    final url = await settings.getBackendUrl();
    if (mounted) {
      _backendUrlController.text = url;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _backendUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_rounded,
                          color: AppColors.primary, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'AI Backend & Security Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.darkTextSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Security Architecture Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            color: AppColors.primaryLight, size: 18),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Production Architecture: Secure Backend Proxy',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Gemini & Groq fallback API keys are kept safe on the backend.\n'
                      '• Keys are NEVER exposed in compiled client JavaScript or localStorage.\n'
                      '• Automatic fallback switches to Groq if Gemini faces rate limits or errors.\n'
                      '• If the backend is offline, the intelligent local heuristic engine activates automatically.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.darkTextSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Secure Backend Service URL',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _backendUrlController,
                decoration: const InputDecoration(
                  hintText: 'http://localhost:8080',
                  prefixIcon: Icon(Icons.dns_rounded, size: 18),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Optional Ephemeral Dev Key (In-Memory Only)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _keyController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'Optional direct test key (not persisted)',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.darkTextSecondary,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _keyController.clear();
                      ref.read(apiKeyProvider.notifier).setKey('');
                      Navigator.of(context).pop();
                    },
                    child: const Text('Reset Keys',
                        style: TextStyle(color: AppColors.darkTextSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final settings = ref.read(settingsLocalDataSourceProvider);
                      await settings.saveBackendUrl(_backendUrlController.text);
                      await ref
                          .read(apiKeyProvider.notifier)
                          .setKey(_keyController.text);

                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Settings saved securely!'),
                            backgroundColor: AppColors.matchHigh,
                          ),
                        );
                      }
                    },
                    child: const Text('Save Settings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
