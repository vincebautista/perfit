import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/screens/main_navigation.dart';
import 'package:quickalert/quickalert.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final oldPasswordCtrl = TextEditingController();
  final newPasswordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  bool hideOldPassword = true;
  bool hideNewPassword = true;
  bool hideConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Change Password")),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: oldPasswordCtrl,
                validator: (value) {
                  final requiredError = ValidationUtils.required(
                    field: "Old Password",
                    value: value!,
                  );

                  if (requiredError != null) return requiredError;

                  return null;
                },
                obscureText: hideOldPassword,
                decoration: InputDecoration(
                  label: Text("Old Password"),
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        hideOldPassword = !hideOldPassword;
                      });
                    },
                    icon: Icon(
                      hideOldPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              Gap(AppSizes.gap20),
              TextFormField(
                controller: newPasswordCtrl,
                validator:
                    (value) => ValidationUtils.required(
                      field: "New Password",
                      value: value!,
                    ),
                obscureText: hideNewPassword,
                decoration: InputDecoration(
                  label: Text("New Password"),
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        hideNewPassword = !hideNewPassword;
                      });
                    },
                    icon: Icon(
                      hideNewPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              Gap(AppSizes.gap20),
              TextFormField(
                controller: confirmPasswordCtrl,
                validator: (value) {
                  final requiredError = ValidationUtils.required(
                    field: "Confirm Password",
                    value: value!,
                  );

                  if (requiredError != null) return requiredError;

                  if (value != newPasswordCtrl.text) {
                    return "Password do not match.";
                  }
                  return null;
                },
                obscureText: hideConfirmPassword,
                decoration: InputDecoration(
                  label: Text("Confirm Password"),
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        hideConfirmPassword = !hideConfirmPassword;
                      });
                    },
                    icon: Icon(
                      hideConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(AppSizes.padding20),
        child: ElevatedButton(
          onPressed: changePassword,
          child: Text("Change Password"),
        ),
      ),
    );
  }

  Future<void> changePassword() async {
    if (!formKey.currentState!.validate()) return;

    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null && user.email != null) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: oldPasswordCtrl.text.trim(),
        );

        QuickAlert.show(
          context: context,
          type: QuickAlertType.loading,
          title: "Please wait",
          text: "Updating password...",
          barrierDismissible: false,
        );

        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newPasswordCtrl.text);

        QuickAlert.show(
          context: context,
          type: QuickAlertType.success,
          title: "Success",
          text: "Password changed successfully.",
          confirmBtnText: "OK",
          onConfirmBtnTap: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => MainNavigation(initialIndex: 4),
              ),
              (route) => false,
            );
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);

      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: "Error",
        text: e.message ?? "Something went wrong.",
        confirmBtnText: "OK",
        onConfirmBtnTap: () {
          NavigationUtils.pop(context);
          NavigationUtils.pop(context);
        },
      );
    }
  }
}
