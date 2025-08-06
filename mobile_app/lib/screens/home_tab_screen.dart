import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../api_config_prod.dart';
import '../theme/retro_theme.dart';

class HomeTabScreen extends StatefulWidget {
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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Clean architectural background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: ArchitecturalColors.primaryGradient,
                ),
              ),
            ),
          ),
          
          // Main content
          Consumer<AppState>(
            builder: (context, appState, child) {
                return SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(ArchitecturalSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Architectural Header
                        _buildArchitecturalHeader(),
                        SizedBox(height: ArchitecturalSpacing.lg),
                        
                        // Main dashboard content
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // PRIMARY: Current Session (Most Important)
                                if (appState.currentBook != null) ...[
                                  _buildPrimarySessionCard(appState),
                                  SizedBox(height: ArchitecturalSpacing.xl),
                                ] else ...[
                                  _buildWelcomeCard(appState),
                                  SizedBox(height: ArchitecturalSpacing.xl),
                                ],
                                
                                // SECONDARY: Recent Books (User's Content)
                                _buildRecentBooksSection(appState),
                                SizedBox(height: ArchitecturalSpacing.xl),
                                
                                // TERTIARY: System Status (Collapsed by default)
                                _buildCollapsibleSystemPanel(appState),
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
        ],
      ),
    );
  }

  Widget _buildArchitecturalHeader() {
    return Container(
      padding: EdgeInsets.all(ArchitecturalSpacing.lg),
      decoration: BoxDecoration(
        color: ArchitecturalColors.pureWhite,
        borderRadius: BorderRadius.circular(ArchitecturalSizes.borderRadius),
        border: Border.all(
          color: ArchitecturalColors.lightGray,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ArchitecturalColors.shadowBlack,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ECHOWRIGHT',
                style: ResponsiveText.heading3(context, color: ArchitecturalColors.deepBlack).copyWith(
                  fontSize: ResponsiveText.scaledFontSize(context, 20),
                  letterSpacing: -0.5,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ArchitecturalColors.primaryOrange,
                  borderRadius: BorderRadius.circular(ArchitecturalSizes.smallRadius),
                ),
                child: Text(
                  'ONLINE',
                  style: ResponsiveText.labelSmall(context, color: ArchitecturalColors.pureWhite).copyWith(
                    fontSize: ResponsiveText.scaledFontSize(context, 10),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ArchitecturalSpacing.sm),
          Text(
            'AI-Powered Audiobook Interface',
            style: ResponsiveText.bodyMedium(context, color: ArchitecturalColors.mediumGray),
          ),
          SizedBox(height: ArchitecturalSpacing.sm),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: ArchitecturalColors.lightGray,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: ArchitecturalColors.primaryOrange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusPanel(AppState appState) {
    return Container(
      padding: EdgeInsets.all(ArchitecturalSpacing.lg),
      decoration: BoxDecoration(
        color: ArchitecturalColors.pureWhite,
        borderRadius: BorderRadius.circular(ArchitecturalSizes.borderRadius),
        border: Border.all(
          color: ArchitecturalColors.lightGray,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ArchitecturalColors.shadowBlack,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SYSTEM STATUS',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ArchitecturalColors.deepBlack,
                  letterSpacing: -0.2,
                ),
              ),
              Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ArchitecturalColors.successGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          SizedBox(height: ArchitecturalSpacing.md),
          _buildStatusLine('Books Loaded', '${appState.books.length}', ArchitecturalColors.primaryOrange),
          _buildStatusLine('Library Status', 'ACTIVE', ArchitecturalColors.successGreen),
          _buildStatusLine('AI Personas', '4', ArchitecturalColors.architecturalBlue),
          _buildStatusLine('Session Time', _formatUptime(), ArchitecturalColors.mediumGray),
        ],
      ),
    );
  }

  Widget _buildStatusLine(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ArchitecturalSpacing.xs),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: ArchitecturalColors.darkGray,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSessionPanel(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACTIVE SESSION',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ArchitecturalColors.deepBlack,
            letterSpacing: -0.2,
          ),
        ),
        SizedBox(height: ArchitecturalSpacing.md),
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ArchitecturalSizes.borderRadius),
                color: ArchitecturalColors.lightGray,
                border: Border.all(
                  color: ArchitecturalColors.mediumGray,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ArchitecturalSizes.borderRadius - 1),
                child: Image.network(
                  '$apiBaseUrl/books/cover/${Uri.encodeComponent(appState.currentBook!.title)}',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.library_music,
                      color: ArchitecturalColors.mediumGray,
                      size: 28,
                    );
                  },
                ),
              ),
            ),
            SizedBox(width: ArchitecturalSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appState.currentBook!.title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ArchitecturalColors.deepBlack,
                      letterSpacing: 0,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: ArchitecturalSpacing.xs),
                  Text(
                    appState.currentChapter?.title ?? 'Single Track',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: ArchitecturalColors.mediumGray,
                      letterSpacing: 0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: ArchitecturalColors.primaryOrange,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => Navigator.pushNamed(context, '/player'),
                icon: Icon(
                  Icons.play_arrow,
                  color: ArchitecturalColors.pureWhite,
                  size: 28,
                ),
                padding: EdgeInsets.all(8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessPanel(AppState appState) {
    final recentBooks = appState.books.take(3).toList();
    
    return Container(
      padding: EdgeInsets.all(ArchitecturalSpacing.lg),
      decoration: BoxDecoration(
        color: ArchitecturalColors.pureWhite,
        borderRadius: BorderRadius.circular(ArchitecturalSizes.borderRadius),
        border: Border.all(
          color: ArchitecturalColors.lightGray,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ArchitecturalColors.shadowBlack,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECENT BOOKS',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ArchitecturalColors.deepBlack,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: ArchitecturalSpacing.md),
          ...recentBooks.map((book) => _buildBookCard(book, appState)),
          
          // Quick actions
          SizedBox(height: ArchitecturalSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'Library',
                  Icons.library_books_outlined,
                  ArchitecturalColors.architecturalBlue,
                  () => Navigator.pushNamed(context, '/library'),
                ),
              ),
              SizedBox(width: ArchitecturalSpacing.sm),
              Expanded(
                child: _buildQuickActionButton(
                  'Settings',
                  Icons.settings_outlined,
                  ArchitecturalColors.steelGray,
                  () => Navigator.pushNamed(context, '/settings'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(dynamic book, AppState appState) {
    return Container(
      margin: EdgeInsets.only(bottom: ArchitecturalSpacing.xs),
      padding: EdgeInsets.all(ArchitecturalSpacing.md),
      decoration: BoxDecoration(
        color: ArchitecturalColors.offWhite,
        borderRadius: BorderRadius.circular(ArchitecturalSizes.smallRadius),
        border: Border.all(
          color: ArchitecturalColors.lightGray,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          appState.playBook(book);
          Navigator.pushNamed(context, '/player');
        },
        child: Row(
          children: [
            Icon(
              Icons.library_books,
              color: ArchitecturalColors.primaryOrange,
              size: 20,
            ),
            SizedBox(width: ArchitecturalSpacing.sm),
            Expanded(
              child: Text(
                book.title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: ArchitecturalColors.deepBlack,
                  letterSpacing: 0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: ArchitecturalColors.mediumGray,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ArchitecturalSizes.smallRadius),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: ArchitecturalSpacing.md,
          vertical: ArchitecturalSpacing.sm,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          SizedBox(width: ArchitecturalSpacing.xs),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  String _formatUptime() {
    final now = DateTime.now();
    final hours = now.hour.toString().padLeft(2, '0');
    final minutes = now.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  /// PRIMARY SECTION: Enhanced current session with clear visual hierarchy
  Widget _buildPrimarySessionCard(AppState appState) {
    return Semantics(
      label: 'Currently playing ${appState.currentBook?.title}',
      hint: 'Double tap to open full player',
      button: true,
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/player'),
        child: Container(
          padding: EdgeInsets.all(ArchitecturalSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ArchitecturalColors.primaryOrange.withOpacity(0.05),
                ArchitecturalColors.pureWhite,
              ],
            ),
            borderRadius: BorderRadius.circular(ArchitecturalSizes.borderRadius),
            border: Border.all(
              color: ArchitecturalColors.primaryOrange.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: ArchitecturalColors.primaryOrange.withOpacity(0.1),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status indicator
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ArchitecturalColors.successGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '● NOW PLAYING',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ArchitecturalColors.pureWhite,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Spacer(),
                  Icon(
                    appState.isPlaying ? Icons.volume_up : Icons.volume_off,
                    color: ArchitecturalColors.mediumGray,
                    size: 20,
                  ),
                ],
              ),
              SizedBox(height: ArchitecturalSpacing.md),
              
              // Book info
              Row(
                children: [
                  // Mock book cover
                  Container(
                    width: 60,
                    height: 80,
                    decoration: BoxDecoration(
                      color: ArchitecturalColors.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ArchitecturalColors.primaryOrange.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.book,
                      color: ArchitecturalColors.primaryOrange,
                      size: 30,
                    ),
                  ),
                  SizedBox(width: ArchitecturalSpacing.lg),
                  
                  // Book details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appState.currentBook?.title ?? 'Unknown',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ArchitecturalColors.deepBlack,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        if (appState.currentChapter != null)
                          Text(
                            'Chapter ${appState.currentChapter!.chapterNumber}: ${appState.currentChapter!.title}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: ArchitecturalColors.mediumGray,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        SizedBox(height: 8),
                        
                        // Progress indicator
                        Row(
                          children: [
                            Text(
                              _formatDuration(appState.currentPosition),
                              style: ResponsiveText.monoMedium(context, color: ArchitecturalColors.primaryOrange),
                            ),
                            Text(
                              ' / ${_formatDuration(appState.totalDuration)}',
                              style: ResponsiveText.monoMedium(context, color: ArchitecturalColors.mediumGray),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Play button
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: ArchitecturalColors.primaryOrange,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ArchitecturalColors.primaryOrange.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      appState.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: ArchitecturalColors.pureWhite,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// WELCOME CARD: When no book is playing
  Widget _buildWelcomeCard(AppState appState) {
    return Container(
      padding: EdgeInsets.all(ArchitecturalSpacing.xl),
      decoration: BoxDecoration(
        color: ArchitecturalColors.pureWhite,
        borderRadius: BorderRadius.circular(ArchitecturalSizes.borderRadius),
        border: Border.all(
          color: ArchitecturalColors.lightGray,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ArchitecturalColors.shadowBlack,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.library_books,
            color: ArchitecturalColors.primaryOrange,
            size: 48,
          ),
          SizedBox(height: ArchitecturalSpacing.md),
          Text(
            'Welcome to EchoWright',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ArchitecturalColors.deepBlack,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Choose an audiobook to start your AI-enhanced listening experience',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: ArchitecturalColors.mediumGray,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ArchitecturalSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/library'),
            icon: Icon(Icons.library_books, size: 18),
            label: Text('Browse Library'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ArchitecturalColors.primaryOrange,
              foregroundColor: ArchitecturalColors.pureWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ArchitecturalSizes.smallRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// SECONDARY SECTION: Recent books with better organization
  Widget _buildRecentBooksSection(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Library',
          style: ResponsiveText.heading3(context, color: ArchitecturalColors.deepBlack).copyWith(
            fontSize: ResponsiveText.scaledFontSize(context, 18),
          ),
        ),
        SizedBox(height: ArchitecturalSpacing.md),
        
        if (appState.books.isEmpty) ...[
          _buildEmptyLibraryCard(),
        ] else ...[
          // Show first 3 books as cards
          ...appState.books.take(3).map((book) => Container(
            margin: EdgeInsets.only(bottom: ArchitecturalSpacing.md),
            child: _buildCompactBookCard(book, appState),
          )).toList(),
          
          // View all button if more books exist
          if (appState.books.length > 3)
            Padding(
              padding: EdgeInsets.only(top: ArchitecturalSpacing.sm),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/library'),
                icon: Icon(Icons.library_books, size: 16),
                label: Text('View All ${appState.books.length} Books'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ArchitecturalColors.primaryOrange,
                  side: BorderSide(color: ArchitecturalColors.primaryOrange),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ArchitecturalSizes.smallRadius),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildCompactBookCard(book, AppState appState) {
    return Semantics(
      label: 'Audiobook ${book.title}',
      hint: 'Double tap to play this audiobook',
      button: true,
      child: GestureDetector(
        onTap: () {
          appState.playBook(book);
          Navigator.pushNamed(context, '/player');
        },
        child: Container(
          padding: EdgeInsets.all(ArchitecturalSpacing.lg),
          decoration: BoxDecoration(
            color: ArchitecturalColors.pureWhite,
            borderRadius: BorderRadius.circular(ArchitecturalSizes.smallRadius),
            border: Border.all(
              color: ArchitecturalColors.lightGray,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: ArchitecturalColors.shadowBlack.withOpacity(0.5),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Book icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ArchitecturalColors.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ArchitecturalColors.primaryOrange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  book.hasChapters ? Icons.menu_book : Icons.headphones,
                  color: ArchitecturalColors.primaryOrange,
                  size: 20,
                ),
              ),
              SizedBox(width: ArchitecturalSpacing.md),
              
              // Book info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: ResponsiveText.labelLarge(context, color: ArchitecturalColors.deepBlack).copyWith(
                        fontSize: ResponsiveText.scaledFontSize(context, 15),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (book.author != null) ...[
                      SizedBox(height: 2),
                      Text(
                        book.author!,
                        style: ResponsiveText.bodySmall(context, color: ArchitecturalColors.mediumGray),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 4),
                    Text(
                      book.hasChapters ? '${book.chapters!.length} Chapters' : 'Audiobook',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: ArchitecturalColors.subtleGray,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Play button
              Builder(
                builder: (context) {
                  final minTouchTarget = ResponsiveLayout.getMinTouchTarget(context);
                  return Container(
                    width: minTouchTarget.clamp(36.0, 48.0),
                    height: minTouchTarget.clamp(36.0, 48.0),
                    decoration: BoxDecoration(
                      color: ArchitecturalColors.primaryOrange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: ArchitecturalColors.pureWhite,
                      size: ResponsiveLayout.isAccessibilityTextScale(context) ? 20 : 18,
                    ),
                  );
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLibraryCard() {
    return Container(
      padding: EdgeInsets.all(ArchitecturalSpacing.xl),
      decoration: BoxDecoration(
        color: ArchitecturalColors.offWhite,
        borderRadius: BorderRadius.circular(ArchitecturalSizes.smallRadius),
        border: Border.all(
          color: ArchitecturalColors.lightGray,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.library_add,
            color: ArchitecturalColors.mediumGray,
            size: 32,
          ),
          SizedBox(height: ArchitecturalSpacing.sm),
          Text(
            'No books in your library yet',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: ArchitecturalColors.mediumGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Add some audiobooks to get started',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: ArchitecturalColors.subtleGray,
            ),
          ),
        ],
      ),
    );
  }

  /// TERTIARY SECTION: Collapsible system status (progressive disclosure)
  Widget _buildCollapsibleSystemPanel(AppState appState) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool _isExpanded = false;
        
        return Container(
          decoration: BoxDecoration(
            color: ArchitecturalColors.offWhite,
            borderRadius: BorderRadius.circular(ArchitecturalSizes.smallRadius),
            border: Border.all(
              color: ArchitecturalColors.lightGray,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Collapsible header
              Semantics(
                label: 'System status panel',
                hint: _isExpanded ? 'Double tap to collapse' : 'Double tap to expand system details',
                button: true,
                child: GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Container(
                    padding: EdgeInsets.all(ArchitecturalSpacing.lg),
                    child: Row(
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          color: ArchitecturalColors.mediumGray,
                          size: 18,
                        ),
                        SizedBox(width: ArchitecturalSpacing.sm),
                        Text(
                          'System Status',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: ArchitecturalColors.mediumGray,
                          ),
                        ),
                        Spacer(),
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: ArchitecturalColors.mediumGray,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Expandable content
              if (_isExpanded) ...[
                Divider(
                  color: ArchitecturalColors.lightGray,
                  thickness: 1,
                  height: 1,
                ),
                Padding(
                  padding: EdgeInsets.all(ArchitecturalSpacing.lg),
                  child: _buildSystemStatusContent(appState),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSystemStatusContent(AppState appState) {
    return Column(
      children: [
        _buildStatusRow('Books Loaded', '${appState.books.length}', ArchitecturalColors.successGreen),
        SizedBox(height: ArchitecturalSpacing.sm),
        _buildStatusRow('Library Status', 'Active', ArchitecturalColors.primaryOrange),
        SizedBox(height: ArchitecturalSpacing.sm),
        _buildStatusRow('AI Personas', '4', ArchitecturalColors.architecturalBlue),
        SizedBox(height: ArchitecturalSpacing.sm),
        _buildStatusRow('Session Time', _getCurrentTime(), ArchitecturalColors.mediumGray),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: ArchitecturalColors.subtleGray,
            letterSpacing: 0.8,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  /// Helper method for current time
  String _getCurrentTime() {
    final now = DateTime.now();
    final hours = now.hour.toString().padLeft(2, '0');
    final minutes = now.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
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