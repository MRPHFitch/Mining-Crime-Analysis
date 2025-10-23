import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final VoidCallback toggleTheme;
  const HomePage({super.key, required this.toggleTheme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crime Analysis'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.brightness_6),
            onPressed: toggleTheme,
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.timeline),
            title: Text("Segment Crime on Time and Location"),
            onTap: ()=>Navigator.pushNamed(context, '/segment'),
          ),
          ListTile(
            leading: Icon(Icons.calendar_today),
            title: Text("Seasonal Crime Patterns"),
            onTap: ()=>Navigator.pushNamed(context, '/seasons'),
          ),
          ListTile(
            leading: Icon(Icons.repeat),
            title: Text("Recurring Crime Sequences"),
            onTap: ()=>Navigator.pushNamed(context, '/sequences'),
          ),
          ListTile(
            leading: Icon(Icons.data_exploration),
            title: Text("Data Used"),
            onTap: ()=>Navigator.pushNamed(context, '/data'),
          ),
          ListTile(
            leading: Icon(Icons.map_rounded),
            title: Text("Charts and Heatmaps"),
            onTap: ()=>Navigator.pushNamed(context, '/charts'),
          ),
        ],
      )
    );
  }
}