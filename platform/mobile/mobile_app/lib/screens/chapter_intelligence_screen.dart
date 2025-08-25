/// chapter_intelligence_screen.dart - AI-powered chapter analysis and engagement
///
/// This screen provides AI-powered features for chapter analysis including
/// automatic chapter detection, summary generation, and discussion questions.
/// It enhances the reading experience by providing deeper insights into
/// audiobook content using advanced AI capabilities.
///
/// Key features:
/// - AI chapter detection for automatic segmentation
/// - Multiple summary styles (brief, detailed, themes, key points)
/// - Educational discussion questions with different difficulty levels
/// - Chapter navigation and selection
/// - Integration with current book context
///
/// AI capabilities:
/// - Chapter boundary detection using machine learning
/// - Natural language summarization with multiple styles
/// - Question generation for educational engagement
/// - Theme and character extraction from content
///
/// User experience:
/// - Tab-based interface for different AI features
/// - Visual chapter timeline with confidence indicators
/// - Expandable summaries and question details
/// - Integration with audio player for seamless experience

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../theme/retro_theme.dart';
import '../widgets/space_background.dart';

/// AI-powered chapter intelligence screen with detection, summaries, and questions
class ChapterIntelligenceScreen extends StatefulWidget {
  final Book book;
  final Chapter? currentChapter;

  const ChapterIntelligenceScreen({
    Key? key,
    required this.book,
    this.currentChapter,
  }) : super(key: key);

  @override
  _ChapterIntelligenceScreenState createState() =>
      _ChapterIntelligenceScreenState();
}

class _ChapterIntelligenceScreenState extends State<ChapterIntelligenceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State management
  List<DetectedChapter> _detectedChapters = [];
  ChapterSummary? _currentSummary;
  List<ChapterQuestion> _currentQuestions = [];
  DetectedChapter? _selectedChapter;

  // Loading states
  bool _isDetectingChapters = false;
  bool _isGeneratingSummary = false;
  bool _isGeneratingQuestions = false;

  // Configuration
  String _summaryStyle = 'detailed';
  String _questionDifficulty = 'intermediate';
  String _readingMode = 'casual';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpaceColors.deepSpace,
      body: SpaceBackground(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildChaptersTab(),
                  _buildSummaryTab(),
                  _buildQuestionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SpaceColors.deepSpace,
            SpaceColors.deepSpace.withOpacity(0.9),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: SpaceColors.stellarWhite),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chapter Intelligence',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: SpaceColors.stellarWhite,
                      ),
                    ),
                    Text(
                      widget.book.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: SpaceColors.tealBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: SpaceColors.commandPanel,
        borderRadius: BorderRadius.circular(SpaceSizes.mediumRadius),
        border: Border.all(color: SpaceColors.tealBlue.withOpacity(0.3)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: SpaceColors.tealBlue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(SpaceSizes.mediumRadius),
        ),
        labelColor: SpaceColors.stellarWhite,
        unselectedLabelColor: SpaceColors.systemGray,
        tabs: [
          Tab(text: 'CHAPTERS'),
          Tab(text: 'SUMMARY'),
          Tab(text: 'QUESTIONS'),
        ],
      ),
    );
  }

  Widget _buildChaptersTab() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          _buildDetectChaptersButton(),
          SizedBox(height: 20),
          Expanded(
            child: _detectedChapters.isEmpty
                ? _buildEmptyChaptersState()
                : _buildChaptersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectChaptersButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isDetectingChapters ? null : _detectChapters,
        style: ElevatedButton.styleFrom(
          backgroundColor: SpaceColors.tealBlue,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SpaceSizes.mediumRadius),
          ),
        ),
        child: _isDetectingChapters
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          SpaceColors.stellarWhite),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Detecting Chapters...',
                    style: GoogleFonts.inter(
                      color: SpaceColors.stellarWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Text(
                'Detect Chapters with AI',
                style: GoogleFonts.inter(
                  color: SpaceColors.stellarWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyChaptersState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories,
            size: 64,
            color: SpaceColors.systemGray,
          ),
          SizedBox(height: 16),
          Text(
            'No Chapters Detected',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: SpaceColors.stellarWhite,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Use AI to automatically detect chapter boundaries in your audiobook',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: SpaceColors.systemGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChaptersList() {
    return ListView.builder(
      itemCount: _detectedChapters.length,
      itemBuilder: (context, index) {
        final chapter = _detectedChapters[index];
        final isSelected = _selectedChapter?.id == chapter.id;

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? SpaceColors.tealBlue.withOpacity(0.1)
                : SpaceColors.commandPanel,
            borderRadius: BorderRadius.circular(SpaceSizes.mediumRadius),
            border: Border.all(
              color: isSelected
                  ? SpaceColors.tealBlue
                  : SpaceColors.tealBlue.withOpacity(0.3),
            ),
          ),
          child: ListTile(
            onTap: () => _selectChapter(chapter),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: SpaceColors.tealBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(SpaceSizes.smallRadius),
              ),
              child: Center(
                child: Text(
                  '${chapter.chapterNumber}',
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.bold,
                    color: SpaceColors.tealBlue,
                  ),
                ),
              ),
            ),
            title: Text(
              chapter.title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: SpaceColors.stellarWhite,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter.formattedDuration,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: SpaceColors.systemGray,
                  ),
                ),
                if (chapter.summary != null) ...[
                  SizedBox(height: 4),
                  Text(
                    chapter.summary!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: SpaceColors.systemGray,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getConfidenceColor(chapter.confidence).withOpacity(0.2),
                borderRadius: BorderRadius.circular(SpaceSizes.smallRadius),
              ),
              child: Text(
                '${chapter.confidencePercentage}%',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getConfidenceColor(chapter.confidence),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryTab() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSummaryControls(),
          SizedBox(height: 20),
          Expanded(
            child: _currentSummary == null
                ? _buildEmptySummaryState()
                : _buildSummaryContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryControls() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _summaryStyle,
            decoration: InputDecoration(
              labelText: 'Summary Style',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SpaceSizes.mediumRadius),
              ),
            ),
            items: [
              DropdownMenuItem(value: 'brief', child: Text('Brief')),
              DropdownMenuItem(value: 'detailed', child: Text('Detailed')),
              DropdownMenuItem(value: 'themes', child: Text('Themes')),
              DropdownMenuItem(value: 'key_points', child: Text('Key Points')),
            ],
            onChanged: (value) {
              setState(() {
                _summaryStyle = value!;
              });
            },
          ),
        ),
        SizedBox(width: 12),
        ElevatedButton(
          onPressed: _selectedChapter == null || _isGeneratingSummary
              ? null
              : _generateSummary,
          style: ElevatedButton.styleFrom(
            backgroundColor: SpaceColors.tealBlue,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SpaceSizes.mediumRadius),
            ),
          ),
          child: _isGeneratingSummary
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(SpaceColors.stellarWhite),
                  ),
                )
              : Text(
                  'Generate',
                  style: GoogleFonts.inter(
                    color: SpaceColors.stellarWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptySummaryState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.summarize,
            size: 64,
            color: SpaceColors.systemGray,
          ),
          SizedBox(height: 16),
          Text(
            _selectedChapter == null
                ? 'Select a Chapter First'
                : 'Generate AI Summary',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: SpaceColors.stellarWhite,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _selectedChapter == null
                ? 'Choose a chapter from the Chapters tab to generate summaries'
                : 'Generate an AI-powered summary of the selected chapter content',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: SpaceColors.systemGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryContent() {
    final summary = _currentSummary!;

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: SpaceColors.commandPanel,
          borderRadius: BorderRadius.circular(SpaceSizes.mediumRadius),
          border: Border.all(color: SpaceColors.tealBlue.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.chapterTitle,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: SpaceColors.stellarWhite,
              ),
            ),
            SizedBox(height: 12),
            Text(
              summary.summaryText,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.6,
                color: SpaceColors.stellarWhite,
              ),
            ),
            if (summary.themes.isNotEmpty) ...[
              SizedBox(height: 20),
              Text(
                'Key Themes',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SpaceColors.tealBlue,
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: summary.themes
                    .map((theme) => Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: SpaceColors.tealBlue.withOpacity(0.2),
                            borderRadius:
                                BorderRadius.circular(SpaceSizes.smallRadius),
                          ),
                          child: Text(
                            theme,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: SpaceColors.tealBlue,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionsTab() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          _buildQuestionControls(),
          SizedBox(height: 20),
          Expanded(
            child: _currentQuestions.isEmpty
                ? _buildEmptyQuestionsState()
                : _buildQuestionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionControls() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _questionDifficulty,
                decoration: InputDecoration(
                  labelText: 'Difficulty',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(SpaceSizes.mediumRadius),
                  ),
                ),
                items: [
                  DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                  DropdownMenuItem(
                      value: 'intermediate', child: Text('Intermediate')),
                  DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                ],
                onChanged: (value) {
                  setState(() {
                    _questionDifficulty = value!;
                  });
                },
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _readingMode,
                decoration: InputDecoration(
                  labelText: 'Mode',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(SpaceSizes.mediumRadius),
                  ),
                ),
                items: [
                  DropdownMenuItem(value: 'casual', child: Text('Casual')),
                  DropdownMenuItem(
                      value: 'educational', child: Text('Educational')),
                  DropdownMenuItem(
                      value: 'professional', child: Text('Professional')),
                ],
                onChanged: (value) {
                  setState(() {
                    _readingMode = value!;
                  });
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selectedChapter == null || _isGeneratingQuestions
                ? null
                : _generateQuestions,
            style: ElevatedButton.styleFrom(
              backgroundColor: SpaceColors.tealBlue,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SpaceSizes.mediumRadius),
              ),
            ),
            child: _isGeneratingQuestions
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              SpaceColors.stellarWhite),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Generating Questions...',
                        style: GoogleFonts.inter(
                          color: SpaceColors.stellarWhite,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Generate Discussion Questions',
                    style: GoogleFonts.inter(
                      color: SpaceColors.stellarWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyQuestionsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.quiz,
            size: 64,
            color: SpaceColors.systemGray,
          ),
          SizedBox(height: 16),
          Text(
            _selectedChapter == null
                ? 'Select a Chapter First'
                : 'Generate Discussion Questions',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: SpaceColors.stellarWhite,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _selectedChapter == null
                ? 'Choose a chapter from the Chapters tab to generate questions'
                : 'Generate AI-powered discussion questions for deeper engagement',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: SpaceColors.systemGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList() {
    return ListView.builder(
      itemCount: _currentQuestions.length,
      itemBuilder: (context, index) {
        final question = _currentQuestions[index];

        return Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SpaceColors.commandPanel,
            borderRadius: BorderRadius.circular(SpaceSizes.mediumRadius),
            border: Border.all(color: SpaceColors.tealBlue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SpaceColors.tealBlue.withOpacity(0.2),
                      borderRadius:
                          BorderRadius.circular(SpaceSizes.smallRadius),
                    ),
                    child: Text(
                      'Q${index + 1}',
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.bold,
                        color: SpaceColors.tealBlue,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SpaceColors.dustyRed.withOpacity(0.2),
                      borderRadius:
                          BorderRadius.circular(SpaceSizes.smallRadius),
                    ),
                    child: Text(
                      question.questionType.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: SpaceColors.dustyRed,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                question.questionText,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SpaceColors.stellarWhite,
                ),
              ),
              if (question.suggestedAnswer.isNotEmpty) ...[
                SizedBox(height: 12),
                ExpansionTile(
                  title: Text(
                    'Answer Guide',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: SpaceColors.systemGray,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        question.suggestedAnswer,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.5,
                          color: SpaceColors.stellarWhite,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return SpaceColors.tealBlue;
    if (confidence >= 0.6) return SpaceColors.goldenYellow;
    return SpaceColors.dustyRed;
  }

  void _selectChapter(DetectedChapter chapter) {
    setState(() {
      _selectedChapter = chapter;
      _currentSummary = null;
      _currentQuestions = [];
    });
  }

  Future<void> _detectChapters() async {
    setState(() {
      _isDetectingChapters = true;
    });

    try {
      final chapters = await ApiService.detectChapters(
        widget.book.id,
        widget.currentChapter?.id,
      );

      setState(() {
        _detectedChapters = chapters;
        if (chapters.isNotEmpty) {
          _selectedChapter = chapters.first;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Detected ${chapters.length} chapters'),
          backgroundColor: SpaceColors.tealBlue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chapter detection failed: $e'),
          backgroundColor: SpaceColors.dustyRed,
        ),
      );
    } finally {
      setState(() {
        _isDetectingChapters = false;
      });
    }
  }

  Future<void> _generateSummary() async {
    if (_selectedChapter == null) return;

    setState(() {
      _isGeneratingSummary = true;
    });

    try {
      final summary = await ApiService.generateChapterSummary(
        widget.book.id,
        _selectedChapter!.id,
        _summaryStyle,
      );

      setState(() {
        _currentSummary = summary;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Summary generated successfully'),
          backgroundColor: SpaceColors.tealBlue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Summary generation failed: $e'),
          backgroundColor: SpaceColors.dustyRed,
        ),
      );
    } finally {
      setState(() {
        _isGeneratingSummary = false;
      });
    }
  }

  Future<void> _generateQuestions() async {
    if (_selectedChapter == null) return;

    setState(() {
      _isGeneratingQuestions = true;
    });

    try {
      final questions = await ApiService.generateChapterQuestions(
        widget.book.id,
        _selectedChapter!.id,
        _questionDifficulty,
        _readingMode,
      );

      setState(() {
        _currentQuestions = questions;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated ${questions.length} questions'),
          backgroundColor: SpaceColors.tealBlue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Question generation failed: $e'),
          backgroundColor: SpaceColors.dustyRed,
        ),
      );
    } finally {
      setState(() {
        _isGeneratingQuestions = false;
      });
    }
  }
}
