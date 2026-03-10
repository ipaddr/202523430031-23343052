import 'package:belajarflutter/helpers/loading/loading_screen.dart';
import 'package:belajarflutter/services/auth/bloc/auth_bloc.dart';
import 'package:belajarflutter/services/auth/bloc/auth_event.dart';
import 'package:belajarflutter/services/auth/bloc/auth_state.dart';
import 'package:belajarflutter/services/auth/firebase_auth_provider.dart';
import 'package:belajarflutter/constants/routes.dart';
import 'package:belajarflutter/views/login_view.dart';
import 'package:belajarflutter/views/notes/create_update_note_view.dart';
import 'package:belajarflutter/views/notes/notes_view.dart';
import 'package:belajarflutter/views/register_view.dart';
import 'package:belajarflutter/views/verify_email_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: false,
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      home: BlocProvider<AuthBloc>(
        create: (context) => AuthBloc(FirebaseAuthProvider()),
        child: const HomePage(),
      ),
      routes: {
        CreateOrUpdateNoteRoute: (context) => const CreateUpdateNoteView(),
      },
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    context.read<AuthBloc>().add(const AuthEventInitialize());
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.isLoading) {
          LoadingScreen().show(
            context: context,
            text: state.loadingText ?? 'Please wait a moment',
          );
        } else {
          LoadingScreen().hide();
        }
      },
      builder: (context, state) {
        if (state is AuthStateLoggedIn) {
          return const NotesView();
        } else if (state is AuthStateNeedsVerification) {
          return const VerifyEmailView();
        } else if (state is AuthStateLoggedOut) {
          return const LoginView();
        } else if (state is AuthStateRegistering) {
          return const RegisterView();
        } else {
          return Scaffold(body: CircularProgressIndicator());
        }
      },
    );
  }
}
