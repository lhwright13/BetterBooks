import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../providers/auth_provider.dart';
import '../api_config.dart';
import '../theme/retro_theme.dart';
import '../widgets/space_background.dart';
import '../widgets/holographic_components.dart';

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
      body: Consumer2<AppState, AuthProvider>(
        builder: (context, appState, authProvider, child) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.all(SpaceSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Space Mission Control Header
                  _buildSpaceMissionHeader(authProvider),
                  SizedBox(height: SpaceSpacing.lg),
                  
                  // Main dashboard content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // PRIMARY: Current Reading (Active Book)
                          if (appState.currentBook != null) ...[
                            _buildCurrentBookCard(appState),
                            SizedBox(height: SpaceSpacing.xl),
                          ] else ...[
                            _buildBookSelectCard(appState, authProvider),
                            SizedBox(height: SpaceSpacing.xl),
                          ],
                          
                          // SECONDARY: Recent Books
                          _buildRecentBooksSection(appState),
                          SizedBox(height: SpaceSpacing.xl),
                          
                          // TERTIARY: Reading Statistics
                          _buildReadingStatsPanel(appState),
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

  Widget _buildSpaceMissionHeader(AuthProvider authProvider) {
    return SpaceCommandPanel(
      accentColor: SpaceColors.tealBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EchoWrightLogo(size: 40, animate: true),
              SizedBox(width: SpaceSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ECHOWRIGHT',
                      style: GoogleFonts.orbitron(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: SpaceColors.dustyRed,
                        letterSpacing: 2.0,
                      ),
                    ),
                    Text(
                      'INTELLIGENT AUDIO BOOKS',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: SpaceColors.commandGray,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              MissionStatusIndicator(
                status: 'ONLINE',
                color: SpaceColors.successGreen,
                isActive: true,
              ),
            ],
          ),
          SizedBox(height: SpaceSpacing.md),
          MissionProgressIndicator(
            value: 1.0,
            color: SpaceColors.tealBlue,
            showEnergyFlow: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBookCard(AppState appState) {
    return SpaceCommandPanel(
      accentColor: SpaceColors.dustyRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mission status header
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SpaceColors.successGreen,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: SpaceColors.successGreen.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: SpaceColors.starWhite,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'CURRENT READING',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: SpaceColors.starWhite,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Spacer(),
              Icon(
                appState.isPlaying ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: appState.isPlaying ? SpaceColors.successGreen : SpaceColors.systemGray,
                size: 18,
              ),
            ],
          ),
          SizedBox(height: SpaceSpacing.lg),
          
          // Mission details
          Row(
            children: [
              // Mission icon/cover
              Container(
                width: 64,
                height: 80,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      SpaceColors.dustyRed.withOpacity(0.3),
                      SpaceColors.dustyRed.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: SpaceColors.dustyRed.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.auto_stories,
                  color: SpaceColors.dustyRed,
                  size: 32,
                ),
              ),
              SizedBox(width: SpaceSpacing.lg),
              
              // Mission info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appState.currentBook?.title ?? 'Unknown Book',
                      style: GoogleFonts.orbitron(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: SpaceColors.missionBlack,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    if (appState.currentChapter != null)
                      Text(
                        'CHAPTER ${appState.currentChapter!.chapterNumber}: ${appState.currentChapter!.title.toUpperCase()}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: SpaceColors.commandGray,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: SpaceSpacing.sm),
                    
                    // Mission progress
                    Row(
                      children: [
                        Text(
                          _formatDuration(appState.currentPosition),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: SpaceColors.goldenYellow,
                          ),
                        ),
                        Text(
                          ' / ${_formatDuration(appState.totalDuration)}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: SpaceColors.systemGray,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Mission control button
              OrbitButton(
                isCircular: true,
                width: 50,
                height: 50,
                color: SpaceColors.dustyRed,
                onPressed: () => Navigator.pushNamed(context, '/player'),
                child: Icon(
                  appState.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: SpaceColors.starWhite,
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookSelectCard(AppState appState, AuthProvider authProvider) {
    return SpaceCommandPanel(
      accentColor: SpaceColors.goldenYellow,
      child: Column(
        children: [
          EchoWrightLogo(size: 60, animate: true),
          SizedBox(height: SpaceSpacing.lg),
          Text(
            authProvider.currentUser != null 
                ? 'WELCOME BACK, ${authProvider.userDisplayName.toUpperCase()}'
                : 'WELCOME TO ECHOWRIGHT',
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SpaceColors.missionBlack,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: SpaceSpacing.sm),
          Text(
            'SELECT AN AUDIOBOOK TO BEGIN YOUR\nAI-ENHANCED LISTENING EXPERIENCE',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: SpaceColors.commandGray,
              letterSpacing: 0.5,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: SpaceSpacing.lg),
          OrbitButton(
            onPressed: () => Navigator.pushNamed(context, '/library'),
            color: SpaceColors.goldenYellow,
            borderRadius: BorderRadius.circular(25),
            width: double.infinity,
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_books,
                  color: SpaceColors.starWhite,
                  size: 20,
                ),
                SizedBox(width: SpaceSpacing.sm),
                Text(
                  'START READING',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SpaceColors.starWhite,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
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
        Text(
          'RECENT BOOKS',
          style: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: SpaceColors.missionBlack,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: SpaceSpacing.md),
        
        if (appState.books.isEmpty) ...[
          _buildEmptyArchiveCard(),
        ] else ...[
          // Show first 3 books as mission cards
          ...appState.books.take(3).map((book) => Container(
            margin: EdgeInsets.only(bottom: SpaceSpacing.md),
            child: _buildBookCard(book, appState),
          )).toList(),
          
          // View all books button
          if (appState.books.length > 3)
            Padding(
              padding: EdgeInsets.only(top: SpaceSpacing.sm),
              child: OrbitButton(
                onPressed: () => Navigator.pushNamed(context, '/library'),
                color: SpaceColors.tealBlue,
                borderRadius: BorderRadius.circular(25),
                width: double.infinity,
                height: 42,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.library_books,
                      color: SpaceColors.starWhite,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'VIEW ALL ${appState.books.length} BOOKS',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: SpaceColors.starWhite,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildBookCard(book, AppState appState) {
    return GestureDetector(
      onTap: () {
        appState.playBook(book);
        Navigator.pushNamed(context, '/player');
      },
      child: SpaceCommandPanel(
        accentColor: SpaceColors.tealBlue,
        padding: EdgeInsets.all(SpaceSpacing.md),
        child: Row(
          children: [
            // Mission type icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    SpaceColors.tealBlue.withOpacity(0.3),
                    SpaceColors.tealBlue.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: SpaceColors.tealBlue.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Icon(
                book.hasChapters ? Icons.view_module : Icons.headphones,
                color: SpaceColors.tealBlue,
                size: 20,
              ),
            ),
            SizedBox(width: SpaceSpacing.md),
            
            // Mission info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SpaceColors.missionBlack,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    book.hasChapters ? '${book.chapters!.length} CHAPTERS' : 'SINGLE TRACK',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: SpaceColors.commandGray,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            
            // Launch button
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: SpaceColors.tealBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: SpaceColors.tealBlue.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.play_arrow,
                color: SpaceColors.starWhite,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyArchiveCard() {
    return SpaceCommandPanel(
      accentColor: SpaceColors.systemGray,
      child: Column(
        children: [
          Icon(
            Icons.library_books_outlined,
            color: SpaceColors.systemGray,
            size: 40,
          ),
          SizedBox(height: SpaceSpacing.md),
          Text(
            'NO BOOKS IN LIBRARY',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: SpaceColors.commandGray,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Add audiobooks to begin reading',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: SpaceColors.systemGray,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingStatsPanel(AppState appState) {
    return MissionDataPanel(
      title: 'READING STATISTICS',
      accentColor: SpaceColors.goldenYellow,
      isActive: true,
      rows: [
        MissionDataRow(
          label: 'BOOKS_LOADED',
          value: '${appState.books.length}',
          valueColor: SpaceColors.successGreen,
        ),
        MissionDataRow(
          label: 'LIBRARY_STATUS',
          value: 'ACTIVE',
          valueColor: SpaceColors.tealBlue,
        ),
        MissionDataRow(
          label: 'AI_PERSONAS',
          value: '4',
          valueColor: SpaceColors.dustyRed,
        ),
        MissionDataRow(
          label: 'SYSTEM_TIME',
          value: _getCurrentTime(),
          valueColor: SpaceColors.goldenYellow,
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