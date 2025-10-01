import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:quickalert/quickalert.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final TextEditingController emailCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Forgot Password")),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Enter your email address to receive a password reset link.",
                style: TextStyle(fontSize: 16),
              ),
              Gap(AppSizes.gap20),
              TextFormField(
                controller: emailCtrl,
                validator: (value) {
                  final requiredError = ValidationUtils.required(
                    field: "Email",
                    value: value!,
                  );

                  if (requiredError != null) return requiredError;

                  return null;
                },
                decoration: InputDecoration(
                  label: Text("Email"),
                  border: OutlineInputBorder(),
                ),
              ),
              Spacer(),
              ElevatedButton(
                onPressed: sendResetLink,
                child: Text("Send Reset Link"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> sendResetLink() async {
    if (!formKey.currentState!.validate()) return;

    try {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.loading,
        title: "Please wait",
        text: "Sending reset email...",
        barrierDismissible: false,
      );

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailCtrl.text.trim(),
      );

      Navigator.pop(context);

      QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: "Email Sent",
        text: "Check your inbox for a password reset link.",
        confirmBtnText: "OK",
        onConfirmBtnTap: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      );
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);

      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: "Error",
        text: e.message ?? "Something went wrong.",
      );
    }
  }
}
