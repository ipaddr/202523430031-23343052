import 'package:belajarflutter/constans/routes.dart';
import 'package:belajarflutter/enums/menu_action.dart';
import 'package:belajarflutter/services/auth/auth_service.dart';
import 'package:flutter/material.dart';

class NotesView extends StatefulWidget {
  const NotesView({super.key});

  @override
  State<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main UI'),
        actions: [
          PopupMenuButton<menuAction>(
            onSelected: (value) async {
              switch (value) {
                case menuAction.logout:
                  final shouldLogout = await showlogoutDialog(context);
                  if (shouldLogout) {
                    await AuthService.firebase().logOut();
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil(loginRoute, (route) => false);
                  }
              }
            },
            itemBuilder: (context) {
              return [
                const PopupMenuItem<menuAction>(
                  value: menuAction.logout,
                  child: const Text('Logout'),
                ),
              ];
            },
          ),
        ],
      ),
      body: const Text('Hello World!'),
    );
  }
}

Future<bool> showlogoutDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (builder) {
      return AlertDialog(
        title: const Text("Sign out"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: const Text("Log out"),
          ),
        ],
      );
    },
  ).then((value) => value ?? false);
}
