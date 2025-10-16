import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final VoidCallback toggleTheme;
  const HomePage({super.key, required this.toggleTheme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bastion'),
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
            leading: Icon(Icons.chat),
            title: Text('Chats'),
            onTap: () => Navigator.pushNamed(context, '/chats'),
          ),
          ListTile(
            leading: Icon(Icons.video_call),
            title: Text('Video Call'),
            onTap: () => Navigator.pushNamed(context, '/video'),
          ),
          ListTile(
            leading: Icon(Icons.flash_on),
            title: Text('Receive Burst'),
            onTap: () => Navigator.pushNamed(context, '/burst'),
          ),
        ],
      ),
    );
  }
}