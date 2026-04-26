import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'services/app_backend.dart';
import 'tracking.dart' as tracking;
import '../../seller_dashboard/bottom_navi.dart';

class LoginAsSellerScreen extends StatefulWidget {
  final VoidCallback? onBackToRolePicker;

  const LoginAsSellerScreen({super.key, this.onBackToRolePicker});

  @override
  State<LoginAsSellerScreen> createState() => _LoginAsSellerScreenState();
}

class _LoginAsSellerScreenState extends State<LoginAsSellerScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool obscurePassword = true;
  bool isLoading = false;

  Future<void> _handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = AppBackend.instance.currentUid;
      final profile = await AppBackend.instance.getUserProfile(uid);

      if (profile.role != 'seller') {
        await FirebaseAuth.instance.signOut();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This account is not a seller account.')),
        );
        return;
      }

      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BottomNavScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.message ?? e.code}')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _onBackFromLogin() {
    if (widget.onBackToRolePicker != null) {
      widget.onBackToRolePicker!();
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const tracking.RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  onPressed: _onBackFromLogin,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Login as Seller",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              _buildTextField(
                label: 'Email',
                hintText: "Enter your email",
                controller: emailController,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                label: 'Password',
                hintText: "Enter your password",
                controller: passwordController,
                isPassword: true,
              ),

              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2),
                      )
                    : const Text("Login", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterAsSellerScreen()),
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    String? label,
    required String hintText,
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    final field = Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.emailAddress,
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
                    setState(() => obscurePassword = !obscurePassword);
                  },
                )
              : null,
        ),
      ),
    );
    if (label == null) return field;
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 6),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          field,
        ],
      ),
    );
  }
}

class RegisterAsSellerScreen extends StatefulWidget {
  const RegisterAsSellerScreen({super.key});

  @override
  State<RegisterAsSellerScreen> createState() => _RegisterAsSellerScreenState();
}

class _RegisterAsSellerScreenState extends State<RegisterAsSellerScreen> {
  final TextEditingController shopNameController = TextEditingController();
  final TextEditingController ownerNameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  Future<void> _handleRegister() async {
    final shopName = shopNameController.text.trim();
    final ownerName = ownerNameController.text.trim();
    final address = addressController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (shopName.isEmpty || ownerName.isEmpty || address.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await AppBackend.instance.createUserProfile(
        uid: cred.user!.uid,
        email: email,
        role: 'seller',
        name: ownerName,
        shopName: shopName,
        address: address,
        available: false,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful! Please login.")),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Register failed: ${e.message ?? e.code}')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                "Register as Seller",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              _buildTextField(
                label: 'Shop name',
                hintText: "Shop Name",
                controller: shopNameController,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                label: 'Owner name',
                hintText: "Owner Name",
                controller: ownerNameController,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                label: 'Shop address',
                hintText: "Address",
                controller: addressController,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                label: 'Email',
                hintText: "Email",
                controller: emailController,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                label: 'Password',
                hintText: "Password",
                controller: passwordController,
                isPassword: true,
                obscureAlt: obscurePassword,
                onToggle: () => setState(() => obscurePassword = !obscurePassword),
              ),
              const SizedBox(height: 15),
              _buildTextField(
                label: 'Confirm password',
                hintText: "Confirm Password",
                controller: confirmPasswordController,
                isPassword: true,
                obscureAlt: obscureConfirmPassword,
                onToggle: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2),
                      )
                    : const Text("Register", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    String? label,
    required String hintText,
    required TextEditingController controller,
    bool isPassword = false,
    bool obscureAlt = true,
    VoidCallback? onToggle,
  }) {
    final field = Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.text,
        obscureText: isPassword ? obscureAlt : false,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureAlt ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: onToggle,
                )
              : null,
        ),
      ),
    );
    if (label == null) return field;
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 6),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          field,
        ],
      ),
    );
  }
}

