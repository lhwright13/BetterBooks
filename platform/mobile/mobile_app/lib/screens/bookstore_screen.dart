import 'package:flutter/material.dart';

class BookstoreScreen extends StatefulWidget {
  @override
  _BookstoreScreenState createState() => _BookstoreScreenState();
}

class _BookstoreScreenState extends State<BookstoreScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bookstore'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Card(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search for audiobooks...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Featured Section
            Text(
              'Featured',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 12),
            
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.store,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Bookstore Coming Soon',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'We\'re working on bringing you an amazing selection of audiobooks. Stay tuned!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Categories
            Text(
              'Categories',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 12),
            
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildCategoryCard(context, 'Fiction', Icons.book, Colors.blue),
                _buildCategoryCard(context, 'Non-Fiction', Icons.school, Colors.green),
                _buildCategoryCard(context, 'Mystery', Icons.search, Colors.purple),
                _buildCategoryCard(context, 'Romance', Icons.favorite, Colors.pink),
                _buildCategoryCard(context, 'Sci-Fi', Icons.rocket_launch, Colors.orange),
                _buildCategoryCard(context, 'Biography', Icons.person, Colors.teal),
              ],
            ),
            
            SizedBox(height: 20),
            
            // Recommendations
            Text(
              'Recommended for You',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 12),
            
            Card(
              child: ListTile(
                leading: Icon(Icons.lightbulb_outline),
                title: Text('Personalized Recommendations'),
                subtitle: Text('Coming soon based on your reading history'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, String title, IconData icon, Color color) {
    return Card(
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title category coming soon!')),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}