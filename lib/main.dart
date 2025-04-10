
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Screens
import 'screens/login.dart';
import 'screens/add_group.dart';
import 'screens/user_profile.dart';
import 'screens/members_list.dart';
import 'screens/event.dart';
import 'screens/team_list.dart';
import 'screens/team_management.dart';
import 'screens/add_member.dart';
import 'screens/albums.dart';
import 'screens/registration.dart';
import 'screens/social_linking.dart';
import 'screens/unified_login.dart';
import 'screens/team_management_bio.dart';
import 'screens/group_list.dart';
import 'screens/group_chat.dart';
import 'screens/assign_team_pickers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  Map<String, dynamic> _getArguments(RouteSettings settings) {
    return settings.arguments is Map<String, dynamic>
        ? settings.arguments as Map<String, dynamic>
        : {};
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sporty Groups App',
      debugShowCheckedModeBanner: false,
      initialRoute: '/registration',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blueGrey[600],
        primarySwatch: Colors.blueGrey,
        textTheme: const TextTheme(
          // Updated text theme with modern property names and smaller sizes.
          displayLarge: TextStyle(fontSize: 20),
          displayMedium: TextStyle(fontSize: 18),
          displaySmall: TextStyle(fontSize: 16),
          headlineLarge: TextStyle(fontSize: 16),
          headlineMedium: TextStyle(fontSize: 16),
          headlineSmall: TextStyle(fontSize: 16),
          titleLarge: TextStyle(fontSize: 16),
          titleMedium: TextStyle(fontSize: 14),
          titleSmall: TextStyle(fontSize: 12),
          bodyLarge: TextStyle(fontSize: 14),
          bodyMedium: TextStyle(fontSize: 12),
          bodySmall: TextStyle(fontSize: 10),
          labelLarge: TextStyle(fontSize: 14),
          labelMedium: TextStyle(fontSize: 12),
          labelSmall: TextStyle(fontSize: 10),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blueGrey[600],
          elevation: 4,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 16, // Reduced font size
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      onGenerateRoute: (settings) {
        final args = _getArguments(settings);
        final user = FirebaseAuth.instance.currentUser;

        switch (settings.name) {
          case '/registration':
            return MaterialPageRoute(builder: (_) => RegistrationScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/addGroup':
            return MaterialPageRoute(builder: (_) => const AddGroupScreen());
          case '/userProfile': {
            final userId = args['userId'] ?? user?.uid ?? '';
            return MaterialPageRoute(
              builder: (_) => UserProfileScreen(userId: userId),
            );
          }
          case '/membersList': {
            final groupId = args['groupId'] ?? '';
            final currentUserId = args['currentUserId'] ?? user?.uid ?? '';
            return MaterialPageRoute(
              builder: (_) => MembersListScreen(
                groupId: groupId,
                currentUserId: currentUserId,
              ),
            );
          }
          case '/event': {
            final eventId = args['eventId'] ?? '';
            final groupId = args['groupId'] ?? '';
            return MaterialPageRoute(
              builder: (_) => EventScreen(
                eventId: eventId,
                groupId: groupId,
              ),
            );
          }
          case '/teamList': {
            final eventId = args['eventId'] ?? '';
            final groupId = args['groupId'] ?? '';
            return MaterialPageRoute(
              builder: (_) => TeamListScreen(
                eventId: eventId,
                groupId: groupId,
              ),
            );
          }
          case '/groupChat':
            return MaterialPageRoute(
              builder: (_) => GroupChatScreen(
                eventId: args['eventId'] ?? '',
                groupId: args['groupId'] ?? '',
                groupName: args['groupName'] ?? '',
              ),
            );
          case '/teamManagementBio':
            return MaterialPageRoute(
              builder: (_) => TeamManagementBio(
                eventId: args['eventId'] ?? '',
                groupId: args['groupId'] ?? '',
                groupName: args['groupName'] ?? '',
                access: args['access'] as String, // required access parameter
              ),
            );
          case '/teamManagement':
            return MaterialPageRoute(
              builder: (_) => TeamManagementScreen(
                eventId: args['eventId'] ?? '',
                groupId: args['groupId'] ?? '',
                groupName: args['groupName'] ?? '',
              ),
            );
          case '/addMember':
            return MaterialPageRoute(
              builder: (_) => AddMemberScreen(
                groupId: args['groupId'] ?? '',
                groupName: args['groupName'] ?? '',
              ),
            );
          case '/albums':
            return MaterialPageRoute(
              builder: (_) => AlbumsPage(
                groupId: args['groupId'] ?? '',
              ),
            );
          case '/assignTeamPickers':
            return MaterialPageRoute(
              builder: (_) => AssignTeamPickersScreen(
                groupId: args['groupId'] ?? '',
                groupName: args['groupName'] ?? '',
              ),
            );
          case '/':
            if (user == null) {
              return MaterialPageRoute(
                builder: (_) => const UnifiedLoginScreen(),
              );
            }
            return MaterialPageRoute(
              builder: (_) => GroupListScreen(
                userId: user.uid,
                userName: user.displayName ?? 'Unknown User',
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Route not defined')),
              ),
            );
        }
      },
    );
  }
}
