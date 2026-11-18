import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'common.dart';

/// The camera is opened only after pressing the primary action.
class ScanLanding extends StatefulWidget {
  const ScanLanding({super.key});

  @override
  State<ScanLanding> createState() => _ScanLandingState();
}

class _ScanLandingState extends State<ScanLanding> {
  bool _opening = false;

  Future<void> _scan() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await runAction(context, () => scanAndOpen(context));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final buttonSize = math.min(
        (constraints.maxWidth - 48).clamp(160.0, 400.0),
        (constraints.maxHeight - 112).clamp(160.0, 400.0),
      );
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: buttonSize,
                    child: FilledButton(
                      key: const ValueKey('primary-scan-button'),
                      onPressed: _opening ? null : _scan,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                CupertinoIcons.barcode_viewfinder,
                                size: 112,
                              ),
                            ),
                            SizedBox(height: 28),
                            Text(
                              'Escanear',
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Escanea el código y descubre lo que compras.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: AppColors.secondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
