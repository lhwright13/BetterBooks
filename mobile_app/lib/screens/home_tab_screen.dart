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
                                // System Status Panel
                                _buildSystemStatusPanel(appState),
                                SizedBox(height: ArchitecturalSpacing.lg),
                                
                                // Current Session Panel
                                if (appState.currentBook != null)
                                  GestureDetector(
                                    onTap: () => Navigator.pushNamed(context, '/player'),
                                    child: Container(
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
                                      child: _buildCurrentSessionPanel(appState),
                                    ),
                                  ),
                                
                                SizedBox(height: ArchitecturalSpacing.lg),
                                
                                // Quick Access Files
                                _buildQuickAccessPanel(appState),
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
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ArchitecturalColors.deepBlack,
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
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: ArchitecturalColors.pureWhite,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ArchitecturalSpacing.sm),
          Text(
            'AI-Powered Audiobook Interface',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: ArchitecturalColors.mediumGray,
              letterSpacing: 0,
            ),
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
}