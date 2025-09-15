import 'package:flutter_test/flutter_test.dart';
import 'package:echowright_rebuilt/data/repositories/user_repository.dart';
import 'package:get_it/get_it.dart';
import '../../helpers/test_helpers.dart';
import '../../helpers/simple_mocks.dart';

void main() {
  group('UserRepository Tests', () {
    late MockUserRepository mockUserRepository;
    
    setUp(() {
      TestHelpers.resetGetIt();
      mockUserRepository = MockUserRepository();
      GetIt.instance.registerSingleton<UserRepository>(mockUserRepository);
    });
    
    tearDown(() {
      GetIt.instance.reset();
    });
    
    group('Authentication State', () {
      test('should return false when user is not authenticated', () {
        // Arrange
        mockUserRepository.setAuthenticated(false);
        
        // Act
        final result = mockUserRepository.isAuthenticated();
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should return true when user is authenticated', () {
        // Arrange
        final testUser = TestDataFactory.createUser();
        mockUserRepository.setAuthenticated(true, user: testUser);
        
        // Act
        final result = mockUserRepository.isAuthenticated();
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should return null when no user is logged in', () {
        // Arrange
        mockUserRepository.setAuthenticated(false);
        
        // Act
        final result = mockUserRepository.getCurrentUser();
        
        // Assert
        expect(result, isNull);
      });
      
      test('should return user data when authenticated', () {
        // Arrange
        final testUser = TestDataFactory.createUser(
          email: 'test@example.com',
          displayName: 'Test User',
        );
        mockUserRepository.setAuthenticated(true, user: testUser);
        
        // Act
        final result = mockUserRepository.getCurrentUser();
        
        // Assert
        expect(result, isNotNull);
        expect(result!['email'], equals('test@example.com'));
        expect(result['display_name'], equals('Test User'));
      });
    });
    
    group('Sign In', () {
      test('should successfully sign in with valid credentials', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'testpassword';
        
        // Act
        final result = await mockUserRepository.signIn(email, password);
        
        // Assert
        expect(result.accessToken, equals('mock-access-token'));
        expect(result.refreshToken, equals('mock-refresh-token'));
        expect(result.user['email'], equals(email));
        expect(result.user['display_name'], equals('Test User'));
        expect(result.expiresAt, greaterThan(DateTime.now().millisecondsSinceEpoch));
      });
      
      test('should update authentication state after successful sign in', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'testpassword';
        
        // Verify initial state
        expect(mockUserRepository.isAuthenticated(), isFalse);
        expect(mockUserRepository.getCurrentUser(), isNull);
        
        // Act
        await mockUserRepository.signIn(email, password);
        
        // Assert
        expect(mockUserRepository.isAuthenticated(), isTrue);
        expect(mockUserRepository.getCurrentUser(), isNotNull);
        expect(mockUserRepository.getCurrentUser()!['email'], equals(email));
      });
      
      test('should handle empty email', () async {
        // Act
        final result = await mockUserRepository.signIn('', 'password');
        
        // Assert
        expect(result.user['email'], isEmpty);
        expect(mockUserRepository.isAuthenticated(), isTrue);
      });
      
      test('should handle empty password', () async {
        // Act
        final result = await mockUserRepository.signIn('test@example.com', '');
        
        // Assert
        expect(result.user['email'], equals('test@example.com'));
        expect(mockUserRepository.isAuthenticated(), isTrue);
      });
    });
    
    group('Token Management', () {
      test('should provide valid access token after sign in', () async {
        // Act
        final result = await mockUserRepository.signIn('test@example.com', 'password');
        
        // Assert
        expect(result.accessToken, isNotEmpty);
        expect(result.accessToken, startsWith('mock'));
      });
      
      test('should provide valid refresh token after sign in', () async {
        // Act
        final result = await mockUserRepository.signIn('test@example.com', 'password');
        
        // Assert
        expect(result.refreshToken, isNotEmpty);
        expect(result.refreshToken, startsWith('mock'));
      });
      
      test('should provide expiration time in future', () async {
        // Arrange
        final beforeSignIn = DateTime.now().millisecondsSinceEpoch;
        
        // Act
        final result = await mockUserRepository.signIn('test@example.com', 'password');
        
        // Assert
        expect(result.expiresAt, greaterThan(beforeSignIn));
        expect(result.expiresAt, lessThan(DateTime.now().add(Duration(hours: 2)).millisecondsSinceEpoch));
      });
    });
    
    group('Edge Cases', () {
      test('should handle special characters in email', () async {
        // Act
        final result = await mockUserRepository.signIn('test+tag@example.com', 'password');
        
        // Assert
        expect(result.user['email'], equals('test+tag@example.com'));
      });
      
      test('should handle very long email', () async {
        // Arrange
        final longEmail = 'very.long.email.address.with.many.dots@example.com';
        
        // Act
        final result = await mockUserRepository.signIn(longEmail, 'password');
        
        // Assert
        expect(result.user['email'], equals(longEmail));
      });
      
      test('should handle unicode characters in email', () async {
        // Arrange
        final unicodeEmail = 'тест@example.com';
        
        // Act
        final result = await mockUserRepository.signIn(unicodeEmail, 'password');
        
        // Assert
        expect(result.user['email'], equals(unicodeEmail));
      });
    });
  });
}