import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../application/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = true;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).authenticate(
        register: _register,
        name: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is AuthException
              ? 'No se pudo acceder: ${e.message}'
              : e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final user = app.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Tu cuenta')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 50),
            children: [
              Center(
                child: Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    CupertinoIcons.person_crop_circle,
                    size: 42,
                    color: AppColors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                user == null
                    ? 'Tu espacio para\nelegir mejor.'
                    : 'Hola, ${user.name.split(' ').first}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 33,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                app.auth.isCloud
                    ? 'Tu cuenta conecta tu bitácora con la comunidad uBuy.'
                    : 'Modo local · cuentas y productos guardados en este navegador.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondary(context),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 30),
              if (user == null) ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Crear cuenta')),
                    ButtonSegment(value: false, label: Text('Iniciar sesión')),
                  ],
                  selected: {_register},
                  onSelectionChanged: _busy
                      ? null
                      : (selection) => setState(() {
                          _register = selection.first;
                          _error = null;
                        }),
                ),
                const SizedBox(height: 22),
                ContentCard(
                  child: Form(
                    key: _form,
                    child: AutofillGroup(
                      child: Column(
                        children: [
                          if (_register) ...[
                            TextFormField(
                              controller: _name,
                              autofillHints: const [AutofillHints.name],
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Tu nombre',
                              ),
                              maxLength: 80,
                              validator: (value) =>
                                  (value?.trim().length ?? 0) < 2
                                  ? 'Escribe tu nombre.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextFormField(
                            controller: _email,
                            autofillHints: const [AutofillHints.email],
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                            ),
                            maxLength: 200,
                            validator: (value) =>
                                RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(value?.trim() ?? '')
                                ? null
                                : 'Escribe un correo válido.',
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            autofillHints: [
                              _register
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            obscureText: _obscure,
                            maxLength: 128,
                            onFieldSubmitted: (_) {
                              if (!_busy) _submit();
                            },
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              helperText: _register
                                  ? 'Al menos 8 caracteres.'
                                  : null,
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                tooltip: _obscure
                                    ? 'Mostrar contraseña'
                                    : 'Ocultar contraseña',
                                icon: Icon(
                                  _obscure
                                      ? CupertinoIcons.eye
                                      : CupertinoIcons.eye_slash,
                                  size: 19,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                (value?.length ?? 0) < (_register ? 8 : 1)
                                ? 'Revisa la contraseña${_register ? ': mínimo 8 caracteres' : ''}.'
                                : null,
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.red,
                                  fontSize: 12,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: Text(
                                _busy
                                    ? 'Un momento…'
                                    : _register
                                    ? 'Crear mi cuenta'
                                    : 'Entrar a mi cuenta',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'También puedes explorar, escanear y guardar productos como invitado. Cada cuenta conserva su propia bitácora.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.7,
                    color: AppColors.secondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                ContentCard(
                  child: Column(
                    children: [
                      _profileRow('Nombre', user.name),
                      const Divider(height: 28),
                      _profileRow('Correo', user.email),
                      const Divider(height: 28),
                      _profileRow(
                        'Tus productos',
                        '${app.entries.length} entradas',
                      ),
                      const Divider(height: 28),
                      _profileRow(
                        'Almacenamiento',
                        app.auth.isCloud
                            ? 'Local + Supabase'
                            : 'Este dispositivo',
                      ),
                    ],
                  ),
                ),
                if (app.canSync) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: app.syncing
                        ? null
                        : () => runAction(
                            context,
                            app.sync,
                            success:
                                'Bitácora sincronizada. Tus aportaciones compartidas ya están publicadas.',
                          ),
                    icon: const Icon(
                      CupertinoIcons.arrow_2_circlepath,
                      size: 19,
                    ),
                    label: Text(
                      app.syncing
                          ? 'Sincronizando…'
                          : 'Sincronizar mi bitácora',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Conserva tus datos en la nube y publica las aportaciones que elegiste compartir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      color: AppColors.secondary(context),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => runAction(context, app.signOut),
                  icon: const Icon(CupertinoIcons.square_arrow_right, size: 17),
                  label: const Text('Cerrar sesión'),
                ),
              ],
              const SectionLabel('A tu manera'),
              ContentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Apariencia',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Clara'),
                            icon: Icon(CupertinoIcons.sun_max, size: 16),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Oscura'),
                            icon: Icon(CupertinoIcons.moon, size: 16),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('Auto'),
                          ),
                        ],
                        selected: {app.themeMode},
                        onSelectionChanged: (modes) =>
                            runAction(context, () => app.setTheme(modes.first)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileRow(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 115,
        child: Text(
          label,
          style: TextStyle(color: AppColors.secondary(context), fontSize: 12),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    ],
  );
}
