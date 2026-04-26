import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../3d_marketplace.dart';
import 'forget_password.dart';
import 'register.dart';

class LoginUserScreen extends StatefulWidget {
  @override
  _LoginUserScreenState createState() => _LoginUserScreenState();
}

class _LoginUserScreenState extends State<LoginUserScreen> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool obscurePassword = true;
  bool isLoading = false;

  double logoHeight = 200;
  double titleSpace = 10;
  double fieldHeight = 55;
  double fieldWidthRatio = 0.85;
  double verticalFieldSpacing = 5;
  double forgetSpaceAbove = 5;
  double forgetSpaceBelow = 15;
  double forgetHorizontalPadding = 20;
  Alignment forgetAlignment = Alignment.centerRight;
  double loginButtonHorizontalPadding = 120;
  double loginButtonVerticalPadding = 15;
  double googleButtonHorizontalPadding = 60;
  double googleButtonVerticalPadding = 15;
  double bottomSpacing = 40;

  Future<void> _handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email address")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store login data in Firestore
      await FirebaseFirestore.instance.collection('login_app_user_login').add({
        'uid': userCredential.user?.uid,
        'email': email,
        'timestamp': FieldValue.serverTimestamp(),
        'action': 'login',
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MarketPlace3D()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "Login failed";
      if (e.code == 'user-not-found') {
        message = "No user found with this email.";
      } else if (e.code == 'wrong-password') {
        message = "Incorrect password.";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("An error occurred. Please try again.")));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    Widget buildTextField({
      required String hintText,
      required TextEditingController controller,
      bool isPassword = false,
    }) {
      double fieldWidth = MediaQuery.of(context).size.width * fieldWidthRatio;
      return Container(
        width: fieldWidth,
        height: fieldHeight,
        margin: EdgeInsets.symmetric(vertical: verticalFieldSpacing),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            const BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))
          ],
        ),
        child: TextField(
          controller: controller,
          obscureText: isPassword ? obscurePassword : false,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hintText,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  )
                : null,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Login as User",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              buildTextField(
                  hintText: "Enter your email", controller: emailController),
              buildTextField(
                  hintText: "Enter your password",
                  controller: passwordController,
                  isPassword: true),
              Padding(
                padding: EdgeInsets.only(
                  top: forgetSpaceAbove,
                  bottom: forgetSpaceBelow,
                  left: forgetHorizontalPadding,
                  right: forgetHorizontalPadding,
                ),
                child: Align(
                  alignment: forgetAlignment,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ForgetPasswordScreen()),
                      );
                    },
                    child: const Text(
                      "Forget Password?",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(
                      horizontal: loginButtonHorizontalPadding,
                      vertical: loginButtonVerticalPadding),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.deepPurple)
                    : const Text(
                        "Login",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RegisterScreen()),
                      );
                    },
                    child: const Text(
                      "Register now",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: bottomSpacing),
            ],
          ),
        ),
      ),
    );
  }
}
