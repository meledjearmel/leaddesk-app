import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../app/logo.dart';
import '../app/theme.dart';
import '../live_office/widgets/common.dart';
import 'auth_service.dart';
import 'session.dart';

/// Fond commun des écrans d'accueil : sombre, avec une lueur chaude, et une
/// carte centrée dans le style des panneaux du bureau.
class _AuthFrame extends StatelessWidget {
  const _AuthFrame({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.1,
            colors: <Color>[Color(0xFF2A2117), LdColors.background],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
                decoration: BoxDecoration(
                  color: LdColors.surface,
                  borderRadius: BorderRadius.circular(LdRadius.panel),
                  border: Border.all(color: LdColors.border),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 40,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        LeadDeskLogo(size: 36),
                        SizedBox(width: 12),
                        Text(
                          'LeadDesk',
                          style: TextStyle(
                            color: LdColors.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text(
                      title,
                      style: const TextStyle(
                        color: LdColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: LdColors.textMuted,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    ...children,
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: LdColors.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: obscure,
            autofocus: autofocus,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            onSubmitted: onSubmitted,
            style: const TextStyle(color: LdColors.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: LdColors.textFaint),
              isDense: true,
              filled: true,
              fillColor: LdColors.surfaceHigh,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LdRadius.control),
                borderSide: const BorderSide(color: LdColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LdRadius.control),
                borderSide: const BorderSide(color: LdColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LdRadius.control),
                borderSide: const BorderSide(color: LdColors.amber),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.6 : 1,
      child: LdPressable(
        onTap: busy ? null : onTap,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hovered && !busy
                ? const Color(0xFFE9E6E1)
                : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(LdRadius.control),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF161514),
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      widthFactor: 1,
      child: LdPressable(
        onTap: onTap,
        builder: (context, hovered) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: hovered ? LdColors.text : LdColors.textMuted,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 16, color: Color(0xFFF2617A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: LdColors.text,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Message d'erreur en français pour l'utilisateur.
String describeError(Object error) => switch (error) {
  ApiException(status: 422, :final errors) when errors.isNotEmpty =>
    errors.values.first.first,
  ApiException(status: 401) => 'Session expirée : reconnectez-vous.',
  ApiException(:final message) => message,
  _ => 'Serveur injoignable. Vérifiez l\'adresse et votre connexion.',
};

/// Écran de connexion du CEO (D-017).
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    required this.auth,
    required this.onSignedIn,
    this.onDemo,
    this.onCreateAccount,
    this.initialServer = '',
    super.key,
  });

  final AuthService auth;
  final ValueChanged<Session> onSignedIn;

  /// Ouvre la création de compte, avec l'adresse du serveur saisie.
  final ValueChanged<String>? onCreateAccount;

  /// Ouvre le bureau de démonstration, sans serveur.
  final VoidCallback? onDemo;
  final String initialServer;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final TextEditingController _server = TextEditingController(
    text: widget.initialServer,
  );
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final baseUrl = AuthService.normalizeBaseUrl(_server.text);
    if (baseUrl == null) {
      setState(() => _error = 'Indiquez l\'adresse du serveur LeadDesk.');
      return;
    }
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Indiquez votre e-mail et votre mot de passe.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await widget.auth.signIn(
        baseUrl: baseUrl,
        email: _email.text,
        password: _password.text,
      );
      if (mounted) {
        widget.onSignedIn(session);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      title: 'Connexion',
      subtitle: 'Connectez-vous pour retrouver votre bureau et vos agents.',
      children: <Widget>[
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Field(
                label: 'Adresse du serveur',
                controller: _server,
                hint: 'leaddesk.exemple.com',
                keyboardType: TextInputType.url,
                autofillHints: const <String>[AutofillHints.url],
              ),
              _Field(
                label: 'E-mail',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.email],
                autofocus: true,
              ),
              _Field(
                label: 'Mot de passe',
                controller: _password,
                obscure: true,
                autofillHints: const <String>[AutofillHints.password],
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        if (_error case final error?) _ErrorLine(error),
        _PrimaryButton(
          label: _busy ? 'Connexion…' : 'Se connecter',
          busy: _busy,
          onTap: _submit,
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (widget.onCreateAccount case final create?)
              _LinkButton(
                label: 'Créer un compte',
                onTap: () => create(_server.text),
              ),
            if (widget.onCreateAccount != null && widget.onDemo != null)
              const Text('·', style: TextStyle(color: LdColors.textFaint)),
            if (widget.onDemo case final demo?)
              _LinkButton(label: 'Voir la démonstration', onTap: demo),
          ],
        ),
      ],
    );
  }
}

/// Création du compte du CEO (D-019).
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    required this.auth,
    required this.onSignedUp,
    required this.onBack,
    this.initialServer = '',
    super.key,
  });

  final AuthService auth;
  final ValueChanged<Session> onSignedUp;

  /// Retour à la connexion, avec l'adresse du serveur saisie.
  final ValueChanged<String> onBack;
  final String initialServer;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late final TextEditingController _server = TextEditingController(
    text: widget.initialServer,
  );
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _server,
      _name,
      _email,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final baseUrl = AuthService.normalizeBaseUrl(_server.text);
    final error = switch (()) {
      _ when baseUrl == null => 'Indiquez l\'adresse du serveur LeadDesk.',
      _ when _name.text.trim().isEmpty => 'Indiquez votre nom.',
      _ when _email.text.trim().isEmpty => 'Indiquez votre e-mail.',
      _ when _password.text.isEmpty => 'Choisissez un mot de passe.',
      _ when _password.text != _confirmation.text =>
        'Les deux mots de passe ne sont pas identiques.',
      _ => null,
    };
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await widget.auth.signUp(
        baseUrl: baseUrl!,
        name: _name.text,
        email: _email.text,
        password: _password.text,
        confirmation: _confirmation.text,
      );
      if (mounted) {
        widget.onSignedUp(session);
      }
    } on Object catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeError(failure);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      title: 'Créer un compte',
      subtitle:
          'Un compte par CEO. Vous créerez ensuite votre entreprise et ses '
          'agents.',
      children: <Widget>[
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Field(
                label: 'Adresse du serveur',
                controller: _server,
                hint: 'leaddesk.exemple.com',
                keyboardType: TextInputType.url,
              ),
              _Field(
                label: 'Nom',
                controller: _name,
                autofillHints: const <String>[AutofillHints.name],
                autofocus: true,
              ),
              _Field(
                label: 'E-mail',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.email],
              ),
              _Field(
                label: 'Mot de passe',
                controller: _password,
                obscure: true,
                autofillHints: const <String>[AutofillHints.newPassword],
              ),
              _Field(
                label: 'Confirmer le mot de passe',
                controller: _confirmation,
                obscure: true,
                autofillHints: const <String>[AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        if (_error case final error?) _ErrorLine(error),
        _PrimaryButton(
          label: _busy ? 'Création…' : 'Créer le compte',
          busy: _busy,
          onTap: _submit,
        ),
        const SizedBox(height: 8),
        _LinkButton(
          label: 'J\'ai déjà un compte',
          onTap: () => widget.onBack(_server.text),
        ),
      ],
    );
  }
}

/// Création de l'entreprise, quand le compte n'en a pas encore (RM-01,
/// RM-02).
class CompanySetupScreen extends StatefulWidget {
  const CompanySetupScreen({
    required this.auth,
    required this.session,
    required this.onCreated,
    required this.onSignOut,
    super.key,
  });

  final AuthService auth;
  final Session session;
  final ValueChanged<Session> onCreated;
  final VoidCallback onSignOut;

  @override
  State<CompanySetupScreen> createState() => _CompanySetupScreenState();
}

class _CompanySetupScreenState extends State<CompanySetupScreen> {
  final TextEditingController _name = TextEditingController();
  CompanyTemplate _template = CompanyTemplate.studio;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Donnez un nom à votre entreprise.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await widget.auth.createCompany(
        widget.session,
        name: _name.text,
        template: _template,
      );
      if (mounted) {
        widget.onCreated(session);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.session.userName.split(' ').first;
    return _AuthFrame(
      title: first.isEmpty ? 'Créez votre entreprise' : 'Bienvenue, $first',
      subtitle:
          'Créez votre entreprise. Les Ressources humaines et les Moyens '
          'généraux sont toujours là ; le reste s\'adapte ensuite.',
      children: <Widget>[
        _Field(
          label: 'Nom de l\'entreprise',
          controller: _name,
          autofocus: true,
          onSubmitted: (_) => _submit(),
        ),
        const Text(
          'Point de départ',
          style: TextStyle(
            color: LdColors.textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        for (final template in CompanyTemplate.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LdPressable(
              onTap: () => setState(() => _template = template),
              builder: (context, hovered) {
                final active = template == _template;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0x1AF2B34C)
                        : hovered
                        ? LdColors.hover
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(LdRadius.card),
                    border: Border.all(
                      color: active ? LdColors.amber : LdColors.border,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        active
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: active ? LdColors.amber : LdColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              template.label,
                              style: const TextStyle(
                                color: LdColors.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              template.description,
                              style: const TextStyle(
                                color: LdColors.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        if (_error case final error?) _ErrorLine(error),
        _PrimaryButton(
          label: _busy ? 'Création…' : 'Créer l\'entreprise',
          busy: _busy,
          onTap: _submit,
        ),
        const SizedBox(height: 8),
        _LinkButton(label: 'Se déconnecter', onTap: widget.onSignOut),
      ],
    );
  }
}
