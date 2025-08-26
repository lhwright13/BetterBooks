import 'package:flutter_test/flutter_test.dart';
import 'package:echowright/models/user.dart';

void main() {
  group('User initials tests', () {
    test('should return correct initials for full name', () {
      final user = User(
        id: '1',
        displayName: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime.now(),
      );
      
      expect(user.initials, 'JD');
    });
    
    test('should return correct initial for single name', () {
      final user = User(
        id: '1',
        displayName: 'John',
        email: 'john@example.com',
        createdAt: DateTime.now(),
      );
      
      expect(user.initials, 'J');
    });
    
    test('should return email initial when displayName is empty', () {
      final user = User(
        id: '1',
        displayName: '',
        email: 'john@example.com',
        createdAt: DateTime.now(),
      );
      
      expect(user.initials, 'J');
    });
    
    test('should return email initial when displayName is null', () {
      final user = User(
        id: '1',
        displayName: null,
        email: 'john@example.com',
        createdAt: DateTime.now(),
      );
      
      expect(user.initials, 'J');
    });
    
    test('should return U when both displayName and email are empty/null', () {
      final user = User(
        id: '1',
        displayName: null,
        email: null,
        createdAt: DateTime.now(),
      );
      
      expect(user.initials, 'U');
    });
    
    test('should return U when email is empty string', () {
      final user = User(
        id: '1',
        displayName: null,
        email: '',
        createdAt: DateTime.now(),
      );
      
      expect(user.initials, 'U');
    });

    test('should handle names with only spaces gracefully', () {
      final user = User(
        id: '1',
        displayName: '   ',
        email: 'john@example.com',
        createdAt: DateTime.now(),
      );
      
      expect(user.initials, 'J');
    });
  });
}