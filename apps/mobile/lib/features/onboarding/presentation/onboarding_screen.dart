import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_controller.dart';
import '../../../core/ui/banochki_theme.dart';
import '../../../core/ui/components.dart';

final class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

final class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _familyController = TextEditingController();
  final _memberController = TextEditingController();
  var _step = 0;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _familyController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ваш семейный погреб')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BanochkiSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  _step == 0 ? Icons.home_outlined : Icons.person_outline,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: BanochkiSpacing.lg),
                Text(
                  _step == 0 ? 'Как назвать семью?' : 'Кто ведёт запасы?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: BanochkiSpacing.sm),
                Text(
                  _step == 0
                      ? 'Название хранится только на этом устройстве.'
                      : 'Создадим первого локального участника. Аккаунт и интернет не нужны.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: BanochkiSpacing.xl),
                TextField(
                  key: ValueKey('onboarding-field-$_step'),
                  controller: _step == 0
                      ? _familyController
                      : _memberController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: _step == 0 ? 'Название семьи' : 'Ваше имя',
                    hintText: _step == 0
                        ? 'Например, Семья Ивановых'
                        : 'Например, Валя',
                  ),
                  onSubmitted: (_) => _continue(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: BanochkiSpacing.md),
                  InlineError(message: _error!),
                ],
                const SizedBox(height: BanochkiSpacing.lg),
                PrimaryActionButton(
                  label: _step == 0 ? 'Дальше' : 'Создать семью',
                  icon: _step == 0 ? Icons.arrow_forward : Icons.check,
                  onPressed: _saving ? null : _continue,
                ),
                if (_step == 1) ...[
                  const SizedBox(height: BanochkiSpacing.xs),
                  TextButton(
                    onPressed: _saving ? null : () => setState(() => _step = 0),
                    child: const Text('Назад'),
                  ),
                ],
                if (kDebugMode && _step == 0)
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            try {
                              await ref
                                  .read(appControllerProvider.notifier)
                                  .seedDebugData();
                            } catch (error) {
                              if (mounted) setState(() => _error = '$error');
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          },
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Открыть debug-пример'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      if (_familyController.text.trim().isEmpty) {
        setState(() => _error = 'Введите название семьи.');
        return;
      }
      setState(() {
        _step = 1;
        _error = null;
      });
      return;
    }
    if (_memberController.text.trim().isEmpty) {
      setState(() => _error = 'Введите имя участника.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(appControllerProvider.notifier)
          .createFamily(_familyController.text, _memberController.text);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
