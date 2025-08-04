import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../api_config_prod.dart';
import '../theme/retro_theme.dart';
import '../widgets/filing_system_components.dart';
import '../widgets/retro_effects.dart';

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
          // Matrix background effect
          Positioned.fill(
            child: MatrixBackground(opacity: 0.05),
          ),
          
          // Main content with scanline overlay
          ScanlineOverlay(
            opacity: 0.08,
            child: Consumer<AppState>(
              builder: (context, appState, child) {
                return SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Terminal Header
                        _buildTerminalHeader(),
                        SizedBox(height: 16),
                        
                        // Main dashboard content
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // System Status Panel
                                _buildSystemStatusPanel(appState),
                                SizedBox(height: 16),
                                
                                // Current Session Panel
                                if (appState.currentBook != null)
                                  _buildCurrentSessionPanel(appState),
                                
                                SizedBox(height: 16),
                                
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
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF0F0F23),
        border: Border.all(
          color: RetroColors.neonCyan.withOpacity(0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: RetroColors.neonCyan.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeonGlow(
                glowColor: RetroColors.neonCyan,
                child: GlitchText(
                  text: 'MUUCHI SYSTEM v2.1',
                  style: GoogleFonts.orbitron(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: RetroColors.neonCyan,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: RetroColors.phosphorGreen.withOpacity(0.2),
                  border: Border.all(
                    color: RetroColors.phosphorGreen,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: RetroColors.phosphorGreen.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: FlickeringText(
                  text: 'ONLINE',
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: RetroColors.phosphorGreen,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          TypewriterText(
            text: 'AI-POWERED AUDIOBOOK INTERFACE',
            style: GoogleFonts.sourceCodePro(
              fontSize: 10,
              color: RetroColors.terminalAmber,
              letterSpacing: 1.0,
            ),
            duration: Duration(milliseconds: 30),
          ),
          SizedBox(height: 4),
          VhsProgressBar(
            value: 1.0,
            color: RetroColors.neonCyan,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusPanel(AppState appState) {
    return TerminalWindow(
      title: 'SYSTEM STATUS',
      titleBarColor: Color(0xFF16213E),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusLine('BOOKS_LOADED', '${appState.books.length}', RetroColors.phosphorGreen),
            _buildStatusLine('LIBRARY_STATUS', 'ACTIVE', RetroColors.neonCyan),
            _buildStatusLine('AI_PERSONAS', '4', RetroColors.terminalAmber),
            _buildStatusLine('SESSION_TIME', _formatUptime(), RetroColors.neonPink),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLine(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label:',
            style: GoogleFonts.sourceCodePro(
              fontSize: 10,
              color: RetroColors.terminalAmber.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          Spacer(),
          Text(
            value,
            style: GoogleFonts.sourceCodePro(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSessionPanel(AppState appState) {
    return TerminalWindow(
      title: 'ACTIVE SESSION - FILE_${appState.currentBook!.id.toUpperCase()}',
      titleBarColor: Color(0xFF16213E).withOpacity(0.8),
      child: IndexCard(
        title: appState.currentBook!.title.toUpperCase(),
        subtitle: appState.currentChapter?.title?.toUpperCase() ?? 'SINGLE TRACK',
        metadata: 'PLAY',
        tabColor: RetroColors.neonCyan,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: RetroColors.gridBlue.withOpacity(0.2),
            border: Border.all(
              color: RetroColors.gridBlue,
              width: 1,
            ),
          ),
          child: ClipRect(
            child: Image.network(
              '$apiBaseUrl/books/cover/${Uri.encodeComponent(appState.currentBook!.title)}',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.library_books,
                  color: RetroColors.neonCyan,
                  size: 20,
                );
              },
            ),
          ),
        ),
        onTap: () => Navigator.pushNamed(context, '/player'),
      ),
    );
  }

  Widget _buildQuickAccessPanel(AppState appState) {
    final recentBooks = appState.books.take(3).toList();
    
    return FileDrawer(
      title: 'QUICK ACCESS FILES',
      tabColor: RetroColors.neonOrange,
      initiallyExpanded: true,
      children: [
        ...recentBooks.map((book) => IndexCard(
          title: book.title.toUpperCase(),
          subtitle: 'AUDIOBOOK',
          metadata: book.id.substring(0, 3).toUpperCase(),
          tabColor: RetroColors.tabBlue,
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: RetroColors.gridBlue.withOpacity(0.2),
              border: Border.all(
                color: RetroColors.gridBlue,
                width: 1,
              ),
            ),
            child: Icon(
              Icons.library_books,
              color: RetroColors.terminalGreen,
              size: 16,
            ),
          ),
          onTap: () {
            appState.playBook(book);
            Navigator.pushNamed(context, '/player');
          },
        )).toList(),
        
        // Quick actions
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                'BROWSE_LIB',
                Icons.folder_open,
                RetroColors.phosphorGreen,
                () => Navigator.pushNamed(context, '/library'),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildQuickActionButton(
                'SETTINGS',
                Icons.settings,
                RetroColors.neonPink,
                () => Navigator.pushNamed(context, '/settings'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFF0F0F23),
          border: Border.all(color: color.withOpacity(0.6), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.sourceCodePro(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
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