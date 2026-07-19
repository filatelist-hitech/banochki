import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/banochki_theme.dart';

Future<int?> showQuantityDialog(
  BuildContext context, {
  required String title,
  int initial = 1,
  bool large = false,
}) async {
  var quantity = initial;
  final controller = TextEditingController(text: '$initial');
  return showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title, style: TextStyle(fontSize: large ? 28 : null)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('action-quantity'),
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: large ? 42 : 30,
                fontWeight: FontWeight.w800,
              ),
              decoration: const InputDecoration(labelText: 'Количество банок'),
              onChanged: (value) => quantity = int.tryParse(value) ?? 0,
            ),
            const SizedBox(height: BanochkiSpacing.md),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: large
                        ? BanochkiTargets.large
                        : BanochkiTargets.standard,
                    child: OutlinedButton(
                      onPressed: quantity <= 1
                          ? null
                          : () => setState(() {
                              quantity--;
                              controller.text = '$quantity';
                            }),
                      child: const Text('−', style: TextStyle(fontSize: 30)),
                    ),
                  ),
                ),
                const SizedBox(width: BanochkiSpacing.sm),
                Expanded(
                  child: SizedBox(
                    height: large
                        ? BanochkiTargets.large
                        : BanochkiTargets.standard,
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        quantity++;
                        controller.text = '$quantity';
                      }),
                      child: const Text('+', style: TextStyle(fontSize: 30)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const Key('confirm-quantity'),
            onPressed: quantity > 0
                ? () => Navigator.pop(context, quantity)
                : null,
            child: Text('Подтвердить $quantity'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> showUnderflowWarning(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, size: 48),
        title: const Text('Банок меньше по расчёту'),
        content: const Text(
          'Если действие уже произошло, мы сохраним его и пометим партию «Нужно уточнить». История не исчезнет.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Да, сохранить действие'),
          ),
        ],
      ),
    ) ??
    false;

Future<bool> showQuantityConfirmation(
  BuildContext context, {
  required String title,
  required int remaining,
  required bool large,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.check_circle,
          size: large ? 72 : 52,
          color: Theme.of(context).colorScheme.secondary,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Осталось', style: TextStyle(fontSize: large ? 24 : 18)),
            Text(
              '$remaining',
              style: TextStyle(
                fontSize: large ? 68 : 48,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text('банок', style: TextStyle(fontSize: large ? 24 : 18)),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Исправить действие'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Готово'),
          ),
        ],
      ),
    ) ??
    false;
