/**
 * email_verification_screen.dart - Email verification screen for EchoWright
 * 
 * This screen is shown after a user signs up with email to verify their email address.
 * It provides options to resend the verification email and handles the verification flow.
 * 
 * Key features:
 * - Clear instructions for email verification
 * - Resend verification email functionality
 * - Auto-refresh to check verification status
 * - Navigation back to login or continue to app
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  
  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResending = false;
  String? _resendMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verify Email'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Email verification icon
                  Icon(
                    Icons.mark_email_unread,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 32),
                  
                  // Title
                  Text(
                    'Verify Your Email',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Instructions
                  Text(
                    'We\'ve sent a verification email to:',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  // Email address
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.email,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Instructions
                  Text(
                    'Please check your email and click the verification link to activate your account.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Success message for resend
                  if (_resendMessage != null) ...[
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        border: Border.all(color: Colors.green[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _resendMessage!,
                              style: TextStyle(color: Colors.green[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  // Error message display
                  if (authProvider.errorMessage != null) ...[
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authProvider.errorMessage!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.red[700]),
                            onPressed: authProvider.clearError,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  // Resend verification email button
                  OutlinedButton.icon(
                    onPressed: (_isResending || authProvider.isLoading) ? null : _resendVerification,
                    icon: _isResending 
                        ? SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.refresh),
                    label: Text(_isResending ? 'Sending...' : 'Resend Verification Email'),
                  ),
                  const SizedBox(height: 16),
                  
                  // Check verification status button
                  ElevatedButton.icon(
                    onPressed: authProvider.isLoading ? null : _checkVerificationStatus,
                    icon: authProvider.isLoading 
                        ? SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.check_circle),
                    label: Text(authProvider.isLoading ? 'Checking...' : 'I\'ve Verified My Email'),
                  ),
                  const SizedBox(height: 32),
                  
                  // Footer instructions
                  Text(
                    'Didn\'t receive the email? Check your spam folder or try resending.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Back to login
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Back to Login'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Resend verification email
  Future<void> _resendVerification() async {
    setState(() {
      _isResending = true;
      _resendMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.sendEmailVerification(widget.email);
    
    setState(() {
      _isResending = false;
      if (success) {
        _resendMessage = 'Verification email sent successfully!';
      }
    });
  }

  /// Check if email has been verified and navigate if so
  Future<void> _checkVerificationStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Refresh user data to check verification status
    await authProvider.refreshUser();
    
    if (authProvider.isAuthenticated && !authProvider.needsEmailVerification) {
      // Email is verified, continue to app
      Navigator.of(context).pushReplacementNamed('/');
    } else {
      // Still not verified
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email not yet verified. Please check your email.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}