import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../servicios/avatar_service.dart';
import '../servicios/customer_service.dart';
import '../servicios/rider_service.dart';
import '../widgets/profile_photo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _storeName = TextEditingController();
  final _address = TextEditingController();
  VehicleType? _vehicle;
  Uint8List? _photo;
  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _storeName.dispose();
    _address.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Completá este campo' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // El comercio todavía no guarda datos.
    if (widget.role == UserRole.store) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.role.formTitle}: datos válidos.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final bool needsConfirm;
      if (widget.role == UserRole.rider) {
        needsConfirm = await RiderService().register(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          vehicle: _vehicle!,
        );
      } else {
        needsConfirm = await CustomerService().register(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      // Foto opcional: si ya hay sesión se sube ahora; si falta confirmar el
      // email, queda guardada en el dispositivo y se sube en el primer ingreso.
      final photo = _photo;
      if (photo != null) {
        final avatars = AvatarService();
        if (needsConfirm) {
          await avatars.savePending(_email.text.trim(), photo);
        } else {
          await avatars.uploadSilently(photo);
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop();

      final String msg;
      if (widget.role == UserRole.rider) {
        msg = needsConfirm
            ? '¡Registro enviado! Confirmá tu email y revisaremos tu vehículo.'
            : '¡Registro enviado! Revisaremos tu vehículo y te avisamos.';
      } else {
        msg = needsConfirm
            ? '¡Cuenta creada! Confirmá tu email para ingresar.'
            : '¡Cuenta creada! Ya podés ingresar.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on RegistroException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(role.formTitle),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(role.description, style: text.bodyLarge),
                    const SizedBox(height: 24),
                    Center(
                      child: ProfilePhotoPicker(
                        name: _name.text,
                        color: role.color,
                        bytes: _photo,
                        radius: 44,
                        onPicked: (b) => setState(() => _photo = b),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Foto de perfil (opcional)',
                        style: text.bodySmall?.copyWith(color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (role == UserRole.store) ...[
                      TextFormField(
                        controller: _storeName,
                        decoration: const InputDecoration(
                            labelText: 'Nombre del comercio'),
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _address,
                        decoration: const InputDecoration(
                            labelText: 'Dirección del local'),
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: role == UserRole.store
                            ? 'Nombre del responsable'
                            : 'Nombre y apellido',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                      validator: _required,
                    ),
                    if (role == UserRole.rider) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<VehicleType>(
                        initialValue: _vehicle,
                        decoration:
                            const InputDecoration(labelText: 'Tu vehículo'),
                        items: [
                          for (final v in VehicleType.values)
                            DropdownMenuItem(value: v, child: Text(v.label)),
                        ],
                        onChanged: (v) => setState(() => _vehicle = v),
                        validator: (v) =>
                            v == null ? 'Elegí un vehículo' : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Solo se aceptan vehículos sin combustible.',
                        style: text.bodySmall?.copyWith(color: Colors.black54),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) {
                        if (v == null || !v.contains('@')) {
                          return 'Ingresá un email válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        suffixIcon: IconButton(
                          icon: Icon(_hidePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mínimo 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: role.color,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Crear cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
