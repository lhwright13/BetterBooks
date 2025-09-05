import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../navigation/main_navigation.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final Set<String> _selectedGenres = {};
  bool _isLoading = false;

  final List<Genre> _genres = [
    Genre('fiction', 'Fiction', Icons.auto_stories, Colors.blue),
    Genre('mystery', 'Mystery & Thriller', Icons.search, Colors.purple),
    Genre('romance', 'Romance', Icons.favorite, Colors.pink),
    Genre('sci_fi', 'Science Fiction', Icons.rocket_launch, Colors.orange),
    Genre('fantasy', 'Fantasy', Icons.auto_awesome, Colors.indigo),
    Genre('biography', 'Biography', Icons.person, Colors.green),
    Genre('business', 'Business', Icons.business, Colors.teal),
    Genre('self_help', 'Self Development', Icons.trending_up, Colors.amber),
    Genre('history', 'History', Icons.history_edu, Colors.brown),
    Genre('health', 'Health & Wellness', Icons.health_and_safety, Colors.red),
    Genre('true_crime', 'True Crime', Icons.gavel, Colors.deepOrange),
    Genre('comedy', 'Comedy', Icons.theater_comedy, Colors.lime),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    SvgPicture.asset(
                      'assets/images/EchoWright.svg',
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).colorScheme.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _skipPreferences,
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title section
                      Text(
                        'What genres interest you?',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select your favorite genres to get personalized recommendations',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Progress indicator
                      Text(
                        'Select at least 3 genres',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_selectedGenres.length / 3).clamp(0.0, 1.0),
                        backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Genres grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _genres.length,
                        itemBuilder: (context, index) {
                          final genre = _genres[index];
                          final isSelected = _selectedGenres.contains(genre.id);
                          
                          return InkWell(
                            onTap: () => _toggleGenre(genre.id),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected 
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                    : Theme.of(context).colorScheme.surface,
                              ),
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: isSelected 
                                                ? genre.color
                                                : genre.color.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            genre.icon,
                                            size: 18,
                                            color: isSelected 
                                                ? Colors.white
                                                : genre.color,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            genre.name,
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: isSelected 
                                                  ? FontWeight.w600 
                                                  : FontWeight.normal,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.check,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 32),

                      // Benefits section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Why we ask for your preferences',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildBenefitItem(
                              icon: Icons.recommend,
                              text: 'Get personalized book recommendations',
                            ),
                            _buildBenefitItem(
                              icon: Icons.star,
                              text: 'Discover new favorites in your preferred genres',
                            ),
                            _buildBenefitItem(
                              icon: Icons.chat,
                              text: 'AI personas tailored to your interests',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom action
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canContinue() && !_isLoading 
                        ? _savePreferences
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : Text('Continue (${_selectedGenres.length}/3+)'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleGenre(String genreId) {
    setState(() {
      if (_selectedGenres.contains(genreId)) {
        _selectedGenres.remove(genreId);
      } else {
        _selectedGenres.add(genreId);
      }
    });
  }

  bool _canContinue() {
    return _selectedGenres.length >= 3;
  }

  Future<void> _savePreferences() async {
    setState(() => _isLoading = true);
    
    // TODO: Save preferences to backend
    // For now, simulate saving
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigation(),
        ),
        (route) => false,
      );
    }
    
    setState(() => _isLoading = false);
  }

  void _skipPreferences() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const MainNavigation(),
      ),
      (route) => false,
    );
  }
}

class Genre {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  Genre(this.id, this.name, this.icon, this.color);
}