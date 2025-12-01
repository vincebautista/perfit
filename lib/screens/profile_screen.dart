import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/services/firebase_auth_service.dart';
import 'package:perfit/core/services/notification_service.dart';
import 'package:perfit/core/services/setting_service.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/main.dart';
import 'package:perfit/screens/change_password_screen.dart';
import 'package:perfit/screens/main_navigation.dart';
import 'package:perfit/screens/test_exercise.dart';
import 'package:perfit/screens/test_mediapipe_screen.dart';
import 'package:perfit/screens/thums_up_timer_screen.dart';
import 'package:perfit/widgets/welcome_guest.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = FirebaseAuthService();

  int rest = 60;
  int countdown = 3;
  TimeOfDay? workoutReminder;

  @override
  void initState() {
    super.initState();

    loadSettings();
  }

  Future<void> loadSettings() async {
    final service = SettingService();

    final restMap = await service.loadRest();
    final countdownMap = await service.loadCountdown();
    final reminderMap = await service.loadReminder();

    setState(() {
      rest = restMap["rest"]!;
      countdown = countdownMap["countdown"]!;
      workoutReminder = TimeOfDay(
        hour: reminderMap["hour"]!,
        minute: reminderMap["minute"]!,
      );
    });
  }

  Future<void> pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: workoutReminder ?? const TimeOfDay(hour: 6, minute: 0),
    );

    if (picked != null) {
      setState(() => workoutReminder = picked);

      await SettingService().saveReminder(picked.hour, picked.minute);
      await NotificationService.scheduleNotification(
        title: "Test",
        body: "Test",
        hour: picked.hour,
        minute: picked.minute,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            );
          }

          if (snapshot.hasData) {
            final user = snapshot.data!;

            return FutureBuilder(
              future:
                  FirebaseFirestore.instance
                      .collection("users")
                      .doc(user.uid)
                      .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data()!;
                  return Padding(
                    padding: const EdgeInsets.all(AppSizes.padding20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text("Email: ${user.email}"),
                        Text("Name: ${userData['fullname']}"),
                        Card(
                          child: ListTile(
                            title: Text("Rest Time"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("$rest secs"),
                                Gap(AppSizes.gap10),
                                IconButton(
                                  onPressed: () {
                                    editDialog(
                                      title: "Rest Time",
                                      currentValue: rest,
                                      onSave: (newValue) async {
                                        setState(() => rest = newValue);
                                        await SettingService().saveRest(
                                          newValue,
                                        );
                                      },
                                    );
                                  },
                                  icon: Icon(Icons.edit),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          child: ListTile(
                            title: Text("Countdown Timer"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("$countdown secs"),
                                Gap(AppSizes.gap10),
                                IconButton(
                                  onPressed: () {
                                    editDialog(
                                      title: "Countdown Timer",
                                      currentValue: countdown,
                                      onSave: (newValue) async {
                                        setState(() => countdown = newValue);
                                        await SettingService().saveCountdown(
                                          newValue,
                                        );
                                      },
                                    );
                                  },
                                  icon: Icon(Icons.edit),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          child: ListTile(
                            title: Text("Workout Reminder"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  workoutReminder != null
                                      ? workoutReminder!.format(context)
                                      : "Not set",
                                ),
                                Gap(AppSizes.gap10),
                                IconButton(
                                  onPressed: pickReminderTime,
                                  icon: Icon(Icons.access_time),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // ElevatedButton(
                        //   onPressed: () async {
                        //     await NotificationService.showImmediateTestNotification();

                        //     // await NotificationService.scheduleNotification(
                        //     //   title: "Test",
                        //     //   body: "Test",
                        //     //   hour: 17,
                        //     //   minute: 18,
                        //     // );
                        //   },
                        //   child: const Text("Test Notification"),
                        // ),
                        ElevatedButton(
                          onPressed:
                              () => NavigationUtils.push(
                                context,
                                ChangePasswordScreen(),
                              ),
                          child: const Text("Change Password"),
                        ),
                        Gap(AppSizes.gap10),
                        ElevatedButton(
                          onPressed:
                              () => NavigationUtils.push(
                                context,
                                TestMediapipeScreen(),
                              ),
                          child: const Text("Test Mediapipe"),
                        ),
                        Card(
                          child: SwitchListTile(
                            title: Text("Dark Mode"),
                            value: themeNotifier.value == ThemeMode.dark,
                            onChanged: (value) {
                              themeNotifier.value =
                                  value ? ThemeMode.dark : ThemeMode.light;
                            },
                          ),
                        ),
                        ElevatedButton(
                          onPressed:
                              () => NavigationUtils.push(
                                context,
                                ThumbsUpTimerScreen(),
                              ),
                          child: const Text("Test ThumbsUpTimerScreen"),
                        ),
                        ElevatedButton(
                          onPressed:
                              () =>
                                  NavigationUtils.push(context, TestExercise()),
                          child: const Text("Test Exercise"),
                        ),
                        Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            _authService.logout();

                            NavigationUtils.push(context, MainNavigation());
                          },
                          child: Text("LOGOUT"),
                        ),
                      ],
                    ),
                  );
                }

                return Text("No user data found.");
              },
            );
          }

          return WelcomeGuest();
        },
      ),
    );
  }

  Future<void> editDialog({
    required String title,
    required int currentValue,
    required Function(int) onSave,
  }) async {
    final controller = TextEditingController(text: currentValue.toString());

    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text("Edit $title"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "Enter $title in seconds",
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text("Cancel"),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final value = int.tryParse(controller.text);
                          if (value != null && value > 0) {
                            onSave(value);
                            Navigator.pop(ctx);
                          }
                        },
                        child: Text("Save"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }
}
