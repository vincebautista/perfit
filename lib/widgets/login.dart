import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/core/utils/navigation_utils.dart';
import 'package:perfit/core/utils/validation_utils.dart';
import 'package:perfit/screens/main_navigation.dart';
import 'package:perfit/widgets/text_field_styles.dart';
import 'package:perfit/widgets/text_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final key = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  bool hide = true;

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
            controller: emailCtrl,
            decoration: TextFieldStyles.primary(
              label: "Email",
              icon: Icons.email,
            ),
            validator:
                (value) =>
                    ValidationUtils.required(field: "Email", value: value!),
          ),
          TextFormField(
            controller: passwordCtrl,
            obscureText: hide,
            decoration: InputDecoration(
              label: Text("Password"),
              border: OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    hide = !hide;
                  });
                },
                icon: Icon(hide ? Icons.visibility_off : Icons.visibility),
              ),
            ),
            validator:
                (value) =>
                    ValidationUtils.required(field: "Password", value: value!),
          ),
          ElevatedButton(
            onPressed: doLogin,
            child: Text("Login", style: TextStyles.buttonLarge),
          ),
        ],
      ),
    );
  }

  void doLogin() async {
    if (!key.currentState!.validate()) {
      return;
    }

    QuickAlert.show(context: context, type: QuickAlertType.loading);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtrl.text,
        password: passwordCtrl.text,
      );

      NavigationUtils.pushAndRemoveUntil(context, MainNavigation());
    } on FirebaseAuthException catch (ex) {
      Navigator.pop(context);
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        text: ex.message,
      );
    }
  }
}
