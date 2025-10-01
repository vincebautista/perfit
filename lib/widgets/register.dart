import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/services/firebase_auth_service.dart';
import 'package:perfit/core/services/firebase_firestore_service.dart';
import 'package:perfit/core/utils/form_utils.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/data/models/user_model.dart';
import 'package:perfit/screens/assessment/gender_screen.dart';
import 'package:perfit/widgets/text_field_styles.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:quickalert/quickalert.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final key = GlobalKey<FormState>();

  final fullnameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  final _authService = FirebaseAuthService();
  final _firestoreService = FirebaseFirestoreService();

  bool hidePassword = true;
  bool hideConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: key,
      child: Column(
        spacing: AppSizes.gap20,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Gap(AppSizes.gap10),
          TextFormField(
            controller: fullnameCtrl,
            validator:
                (value) =>
                    ValidationUtils.required(field: "Full Name", value: value!),
            decoration: TextFieldStyles.primary(
              label: "Full Name",
              icon: Icons.person,
            ),
          ),
          TextFormField(
            controller: emailCtrl,
            validator:
                (value) =>
                    ValidationUtils.required(field: "Email", value: value!),
            decoration: TextFieldStyles.primary(
              label: "Email",
              icon: Icons.email,
            ),
          ),
          TextFormField(
            controller: passwordCtrl,
            validator:
                (value) =>
                    ValidationUtils.required(field: "Password", value: value!),
            obscureText: hidePassword,
            decoration: InputDecoration(
              label: Text("Password"),
              border: OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    hidePassword = !hidePassword;
                  });
                },
                icon: Icon(
                  hidePassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          TextFormField(
            controller: confirmPasswordCtrl,
            validator: (value) {
              final requiredError = ValidationUtils.required(
                field: "Confirm Password",
                value: value!,
              );

              if (requiredError != null) return requiredError;

              if (value != passwordCtrl.text) {
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
                  hideConfirmPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: doRegister,
            child: Text("Register", style: TextStyles.buttonLarge),
          ),
        ],
      ),
    );
  }

  void doRegister() {
    if (!key.currentState!.validate()) {
      return;
    }

    QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: "Are you sure?",
      confirmBtnText: "Yes",
      cancelBtnText: "No",
      onConfirmBtnTap: () {
        NavigationUtils.pop(context);

        register();
      },
    );
  }

  void register() async {
    try {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.loading,
        title: "Please wait",
        text: "Registering your account.",
      );

      UserCredential userCredential = await _authService.register(
        email: emailCtrl.text,
        password: passwordCtrl.text,
      );

      await _firestoreService.setUserData(
        UserModel(
          uid: userCredential.user!.uid,
          fullname: fullnameCtrl.text,
          assessmentDone: false,
        ),
      );

      FormUtils.clearFields(
        controllers: [
          fullnameCtrl,
          emailCtrl,
          passwordCtrl,
          confirmPasswordCtrl,
        ],
      );

      QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: "Registration",
        text: "Your account has been registered.",
        onConfirmBtnTap: () {
          NavigationUtils.pop(context);
          NavigationUtils.pushAndRemoveUntil(context, GenderScreen());
        },
      );
    } on FirebaseAuthException catch (ex) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: "Error",
        text: ex.message,
        onConfirmBtnTap: () {
          NavigationUtils.pop(context);
          NavigationUtils.pop(context);
        },
      );
    } catch (ex) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: "Unexpected Error",
        text: "$ex",
        onConfirmBtnTap: () => NavigationUtils.pop(context),
      );
    }
  }
}
