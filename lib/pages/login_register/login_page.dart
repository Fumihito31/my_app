import 'package:flutter/material.dart';
import 'package:my_app/components/my_button.dart';
import 'package:my_app/components/my_textfield.dart';
import 'package:my_app/components/square_tile.dart';
import 'package:my_app/pages/account_setup/verification_page.dart';
import 'package:my_app/pages/login_register/signup_page.dart' as signup;
import '../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../account_setup/iam_page.dart';


class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  // text editing controllers
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  // sign user in method
  void signUserIn(BuildContext context) async {
    final authService = AuthService();
    await authService.signin(
      email: usernameController.text,
      password: passwordController.text,
      context: context,
    );
  }


  signInWithGoogle(BuildContext context) async {
    try {
      print("Starting Google Sign-In process...");

      GoogleSignIn googleSignIn = GoogleSignIn();
      GoogleSignInAccount? googleUser = googleSignIn.currentUser;

      if (googleUser != null) {
        print("Existing Google Sign-In session found. Signing out...");
        await googleSignIn.signOut();
        print("Signed out of existing Google session.");
      } else {
        print("No existing Google Sign-In session found.");
      }

      print("Initiating new Google Sign-In...");
      googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        print("Google Sign-In was canceled by the user.");
        return;
      }

      print("Google Sign-In successful. User: ${googleUser.displayName}");

      GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print("Firebase credential obtained, signing in with Firebase...");
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      print("Firebase Sign-In successful. Firebase User: ${userCredential.user?.displayName}");

      print("Navigating to IamPage...");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) => IamPage(),
        ),
      );

      print("Navigation to IamPage successful.");
    } catch (e) {
      print("Error during Google Sign-In: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 50),

                // logo
                Image.asset(
                  'lib/images/logo.png',
                  height: 100,
                ),

                const SizedBox(height: 50),

                // welcome back, you've been missed!
                const Text(
                  'Greetings!',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 25),

                // username textfield
                MyTextField(
                  controller: usernameController,
                  hintText: 'Username',
                  obscureText: false,
                ),

                const SizedBox(height: 10),

                // password textfield
                MyTextField(
                  controller: passwordController,
                  hintText: 'Password',
                  obscureText: true,
                ),

                const SizedBox(height: 10),

                // forgot password?
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [
                      Text(
                        'Forgot Password?',
                        style: TextStyle(color: Colors.black),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // sign in button
                MyButton(
                  onTap: () => signUserIn(context), // Pass context to signUserIn method
                ),

                const SizedBox(height: 50),

                // or continue with
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          thickness: 0.5,
                          color: Colors.grey[400],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Text(
                          'Or sign up with',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          thickness: 0.5,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 50),


                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    signup.SquareTile(imagePath: 'lib/images/fb.png'), // Removed const
                    signup.SquareTile(
                      imagePath: 'lib/images/google.png',
                      onTap: () => signInWithGoogle(context), // Handle Google Sign-In
                    ), // Removed const because onTap is not a constant expression
                    signup.SquareTile(imagePath: 'lib/images/apple.png'), // Removed const
                  ],
                ),

                const SizedBox(height: 50),

                // not a member? register now
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Not a member?',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => signup.SignUpPage()),
                        );
                      },
                      child: const Text(
                        'Register now',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
