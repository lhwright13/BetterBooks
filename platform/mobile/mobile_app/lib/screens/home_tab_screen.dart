import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../providers/auth_provider.dart';
import '../theme/echowright_theme.dart';

class HomeTabScreen extends StatefulWidget {
  const HomeTabScreen({super.key});

  @override
  _HomeTabScreenState createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EchoWrightTheme.backgroundDark,
      body: Consumer2<AppState, AuthProvider>(
        builder: (context, appState, authProvider, child) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header
                  _buildWelcomeHeader(authProvider),
                  SizedBox(height: 24),
                  
                  // Main dashboard content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Current Reading
                          if (appState.currentBook != null) ...[
                            _buildCurrentBookCard(appState),
                            SizedBox(height: 32),
                          ] else ...[
                            _buildGetStartedCard(appState),
                            SizedBox(height: 32),
                          ],
                          
                          // Recent Books
                          if (appState.books.isNotEmpty) ...[
                            _buildRecentBooksSection(appState),
                            SizedBox(height: 32),
                          ],
                          
                          // Quick Actions
                          _buildQuickActionsSection(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeHeader(AuthProvider authProvider) {
    final greeting = _getGreeting();
    final displayName = authProvider.userDisplayName;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: TextStyle(
            fontSize: 16,
            color: EchoWrightTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          displayName,
          style: TextStyle(
            fontSize: 28,
            color: EchoWrightTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
  
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildCurrentBookCard(AppState appState) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EchoWrightTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EchoWrightTheme.primaryTurquoise.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: EchoWrightTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: EchoWrightTheme.primaryTurquoise.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Continue Reading',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: EchoWrightTheme.primaryTurquoise,
                  ),
                ),
              ),
              Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: appState.isPlaying 
                      ? EchoWrightTheme.successColor
                      : EchoWrightTheme.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Book info
          Row(
            children: [
              // Cover
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: EchoWrightTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: EchoWrightTheme.dividerDark,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.auto_stories,
                  color: EchoWrightTheme.primaryTurquoise,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appState.currentBook?.title ?? 'Unknown Book',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: EchoWrightTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    if (appState.currentChapter != null)
                      Text(
                        'Chapter ${appState.currentChapter!.chapterNumber}: ${appState.currentChapter!.title}',
                        style: TextStyle(
                          fontSize: 12,
                          color: EchoWrightTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: 8),
                    
                    // Progress
                    Text(
                      '${_formatDuration(appState.currentPosition)} / ${_formatDuration(appState.totalDuration)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: EchoWrightTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Play button
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: EchoWrightTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: EchoWrightTheme.subtleShadow,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(context, '/player'),
                    borderRadius: BorderRadius.circular(24),
                    child: Icon(
                      appState.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGetStartedCard(AppState appState) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: EchoWrightTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EchoWrightTheme.brandGold.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: EchoWrightTheme.subtleShadow,
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_stories,
            size: 64,
            color: EchoWrightTheme.brandGold,
          ),
          SizedBox(height: 16),
          Text(
            'Welcome to EchoWright',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: EchoWrightTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your AI-powered audiobook companion\nStart by adding books to your library',
            style: TextStyle(
              fontSize: 14,
              color: EchoWrightTheme.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/library'),
              style: ElevatedButton.styleFrom(
                backgroundColor: EchoWrightTheme.brandGold,
                foregroundColor: EchoWrightTheme.textOnPrimary,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Explore Library',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentBooksSection(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Library',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: EchoWrightTheme.textPrimary,
              ),
            ),
            if (appState.books.length > 3)
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/library'),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    color: EchoWrightTheme.primaryTurquoise,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 16),
        
        // Books grid/list
        ...appState.books.take(3).map((book) => Container(
          margin: EdgeInsets.only(bottom: 12),
          child: _buildBookCard(book, appState),
        )).toList(),
      ],
    );
  }

  Widget _buildBookCard(book, AppState appState) {
    return Container(
      decoration: BoxDecoration(
        color: EchoWrightTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: EchoWrightTheme.dividerDark,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            appState.playBook(book);
            Navigator.pushNamed(context, '/player');
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Cover/Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: EchoWrightTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: EchoWrightTheme.primaryTurquoise.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    book.hasChapters ? Icons.menu_book : Icons.headphones,
                    color: EchoWrightTheme.primaryTurquoise,
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: EchoWrightTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        book.hasChapters ? '${book.chapters!.length} chapters' : 'Audiobook',
                        style: TextStyle(
                          fontSize: 12,
                          color: EchoWrightTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Play button
                Icon(
                  Icons.play_arrow,
                  color: EchoWrightTheme.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Discover',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: EchoWrightTheme.textPrimary,
          ),
        ),
        SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                'Browse Store',
                Icons.storefront,
                EchoWrightTheme.accentCoral,
                () => Navigator.pushNamed(context, '/store'),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                'My Library',
                Icons.library_books,
                EchoWrightTheme.primaryTurquoise,
                () => Navigator.pushNamed(context, '/library'),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildQuickActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: EchoWrightTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: EchoWrightTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  /// Helper method for time formatting
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    
    if (duration.inHours > 0) {
      return "${duration.inHours}:${twoDigitMinutes}:${twoDigitSeconds}";
    } else {
      return "${duration.inMinutes}:${twoDigitSeconds}";
    }
  }
}